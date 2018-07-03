require "yast"
require "yast2/system_service"
require "services-manager/service_loader"

module Yast
  import "Service"
  import "ServicesProposal"
  import "SystemdService"
  import "Stage"

  class ServicesManagerServiceClass < Module
    include Yast::Logger
    extend Yast::I18n

    SERVICE_SUFFIX          = '.service'

    START_MODE = {
      on_boot:   N_('On Boot'),
      on_demand: N_('On Demand'),
      manual:    N_('Manual')
    }.freeze

    # Used by ServicesManagerServiceClass to keep data about an individual service.
    # (Not a real class; documents the structure of a Hash)
    #
    # Why does this hash exist if we have Yast::SystemdServiceClass::Service?
    class Settings < Hash
      # @!method [](k)
      #   @option k :start_mode  [Symbol] service's start mode
      #   @option k :start_modes [Symbol] supported start modes
      #   @option k :can_be_enabled [Boolean] service can be enabled/disabled by the user
      #   @option k :modified [Boolean] service has been changed (got enabled/disabled)
      #   @option k :active   [Boolean] The high-level unit activation state, i.e. generalization of SUB
      #   @option k :loaded   [Boolean] Reflects whether the unit definition was properly loaded
      #   @option k :description [String] English description of the service
    end

    attr_reader   :modified

    # @return [Array<String>]
    attr_accessor :errors

    alias_method :modified?, :modified

    # @return [Hash{String => Settings}]
    #   like "foo" => { enabled: false, loaded: true, ..., description: "Features OO" }
    def services
      @services ||= read
    end

    attr_writer :services

    alias_method :all, :services

    def initialize
      textdomain 'services-manager'
      @errors   = []
      @modified = false
    end

    # Finds a service
    #
    # @param service [String] service name
    # @return [Yast2::SystemService, nil]
    def find(service)
      services[service][:service]
    end

    # Sets whether service should be running after writing the configuration
    #
    # @param [String] service name
    # @return [Boolean] whether the service exists
    def activate(service)
      exists?(service) do
        services[service][:active]  = true
        Builtins.y2milestone "Service #{service} has been marked for activation"
        services[service][:modified] = true
        self.modified = true
      end
    end

    # Sets whether service should be running after writing the configuration
    #
    # @param [String] service name
    # @return [Boolean] whether the service exists
    def deactivate(service)
      exists?(service) do
        services[service][:active]   = false
        services[service][:modified] = true
        self.modified = true
      end
    end

    # @param [String] service name
    # @return [Boolean] the current setting whether service should be running
    def active(service)
      exists?(service) { services[service][:active] }
    end

    alias_method :active?, :active

    # Returns whether the given service has been enabled
    #
    # @param String service
    # @return Boolean enabled
    def enabled(service)
      exists?(service) do
        services[service][:start_mode] != :manual
      end
    end

    # Service state (ActiveState systemd property)
    #
    # @param service [String] service name
    # @return [String]
    def state(service)
      return nil unless exists?(service)
      services[service][:active_state]
    end

    # Service substate (SubState systemd property)
    #
    # @param service [String] service name
    # @return [String]
    def substate(service)
      return nil unless exists?(service)
      services[service][:sub_state]
    end

    # Service description
    #
    # @param service [String] service name
    # @return [String]
    def description(service)
      return nil unless exists?(service)
      services[service][:description]
    end

    # Returns whether the given service can be enabled/disabled by the user
    #
    # @param service [String] Service name
    # @return [Boolean] is it enabled or not
    def can_be_enabled(service)
      exists?(service) do
        services[service][:can_be_enabled]
      end
    end

    # Change the global modified status
    # Reverting modified to false also requires to set the flag for all services
    def modified=(required_status)
      reload if required_status == false
      @modified = required_status
    end

    def modified_services
      services.select do |name, attributes|
        attributes[:modified]
      end
    end

    def reload
      self.services = ServiceLoader.new.read
    end

    # Reads all services' data
    #
    # @return [Hash{String => Settings}]
    #   like "foo" => { enabled: false, loaded: true, ..., description: "Features OO" }
    def read
      ServiceLoader.new.read
    end

    # Resets the global status of the object
    #
    # @return [Boolean]
    def reset
      self.errors = []
      self.modified = false
      true
    end


    # Returns only enabled services, the rest is expected to be disabled
    def export
      enabled_services = services.select do |service_name, properties|
        enabled(service_name) && properties[:loaded] && can_be_enabled(service_name)
      end

      # Only services modifed by the user to be disabled are exported
      # to AutoYast profile, untouched services are not exported
      disabled_services = services.select do |service_name, properties|
        !enabled(service_name) && properties[:modified]
      end

      export_enable = enabled_services.keys | ServicesProposal.enabled_services
      export_disable = disabled_services.keys | ServicesProposal.disabled_services

      log.info "Export: enabled services: #{export_enable}, disabled services: #{export_disable}"

      {
        'enable' => export_enable,
        'disable' => export_disable,
      }
    end

    def import(profile)
      log.info "List of services from autoyast profile: #{profile.services.map(&:name)}"
      non_existent_services = []

      profile.services.each do |service|
        case service.status
        when 'enable'
          exists?(service.name) ? enable(service.name) : non_existent_services << service.name
        when 'disable'
          exists?(service.name) ? disable(service.name) : non_existent_services << service.name
        else
          Builtins.y2error("Unknown status '#{service.status}' for service '#{service.name}'")
        end
      end

      return true if non_existent_services.empty?

      Builtins.y2error("Services #{non_existent_services.inspect} don't exist on this system")
      false
    end

    # Saves the current configuration in memory
    #
    # @return [Boolean]
    def save
      Builtins.y2milestone "Saving systemd services..."

      if !modified
        Builtins.y2milestone "No service has been changed, nothing to do..."
        return true
      end

      Builtins.y2milestone "Modified services: #{modified_services}"

      if !errors.empty?
        Builtins.y2error "Not saving the changes due to errors: " + errors.join(', ')
        return false
      end

      # Set the services enabled/disabled first
      toggle_services
      if !errors.empty?
        Builtins.y2error "There were some errors during saving: " + errors.join(', ')
        return false
      end

      unless Stage.initial
        # Then try to adjust services run (active/inactive)
        # Might start or stop some services that would cause system instability
        # This makes only sense in an installed system (not inst-sys)
        switch_services
        if !errors.empty?
          Builtins.y2error "There were some errors during saving: " + errors.join(', ')
          return false
        end
      end

      modified_services.keys.each { |service_name| reset_service(service_name) }
      self.modified = false
      true
    end

    # Activates the service in cache
    #
    # @param [String] service name
    # @return [Boolean]
    def switch(service)
      active(service) ? deactivate(service) : activate(service)
    end

    # Starts or stops the service
    #
    # @param [String] service name
    # @return [Boolean]
    def switch!(service_name)
      if active(service_name)
        Yast::Service.Start(service_name)
      else
        Yast::Service.Stop(service_name)
      end
    end

    def reset_service(service)
      services[service][:modified] = false
    end

    # Enables the service in cache
    #
    # @param [String] service name
    # @return [Boolean]
    def toggle(service)
      enabled(service) ? disable(service) : enable(service)
    end

    # Sets start_mode for a service (in memory only, use save())
    #
    # @param service [String] service name
    # @param mode    [Symbol] Start mode
    # @see Yast::SystemdServiceClass::Service#start_modes
    def set_start_mode(service, mode)
      exists?(service) do
        services[service][:start_mode] = mode
        services[service][:modified] = true
        self.modified = true
      end
    end

    def set_start_mode!(name)
      service = Yast2::SystemService.find(name)
      return false unless service
      service.start_mode = services[name][:start_mode]
    end

    def start_mode(service)
      exists?(service) do
        services[service][:start_mode]
      end
    end

    def start_modes(service)
      exists?(service) do
        services[service][:start_modes]
      end
    end

    # Enable or disable the service
    #
    # @param [String] service name
    # @return [Boolean]
    def toggle!(service)
      enabled(service) ? Yast::Service.Enable(service) : Yast::Service.Disable(service)
    end

    # Returns full information about the service as returned from systemctl command
    #
    # @param String service name
    # @return String full unformatted information
    def status(service)
      out = Systemctl.execute("status #{service}#{SERVICE_SUFFIX} 2>&1")
      out['stdout']
    end

    # Translate start mode for a given service
    #
    # @param service [String] service name
    # @return [String] Translated start mode
    def start_mode_to_human_for(service)
      start_mode_to_human(start_mode(service))
    end

    # List of supported start modes
    #
    # @return [Array<String>] Supported start modes
    def all_start_modes
      START_MODE.keys
    end

    # Localized start mode
    #
    # @param mode [String] Start mode
    # @return [String] Localized start mode
    def start_mode_to_human(mode)
      _(START_MODE[mode])
    end

    private

    # Helper method to avoid if-else branching
    # When passed a block, this will be executed only if the service exists
    # Whitout block it returns the boolean value
    #
    # @param [String] service name
    # @yieldreturn [Boolean]
    # @return [Boolean] false if the service does not exist,
    #   otherwise what the block returned
    def exists?(service)
      if Stage.initial && !services[service]
        # We are in inst-sys. So we cannot check for installed services but generate entries
        # for these services if they still not exists.
        services[service] = Y2ServicesManager::ServiceLoader::DEFAULT_SERVICE_SETTINGS.clone
      end

      exists = !!services[service]
      if exists && block_given?
        yield
      else
        exists
      end
    end

    def switch_services
      log.info "Switching services"
      services_switched = []

      services.each do |service_name, service_attributes|
        next unless service_attributes[:modified]

        service = Yast2::SystemService.find(service_name)
        unless service
          log.error "Cannot find service #{service_name}"
          next
        end

        # Do not start or stop services that are already in the desired state.
        # They might be coming from AutoYast import and thus marked as :modified.
        if service.active? == service_attributes[:active]
          log.info "Skipping service #{service_name} - it's already in desired state"
        elsif switch!(service_name)
          services_switched << service_name
        else
          change  = active(service_name) ? 'stop' : 'start'
          status  = enabled(service_name) ? 'enabled' : 'disabled'
          message = _("Could not %{change} %{service} which is currently %{status}. ") %
            { :change => change, :service => service_name, :status => status }
          message << status(service_name)
          errors << message
          Builtins.y2error("Error: %1", message)
        end
      end

      services_switched
    end

    def toggle_services
      services_toggled = []
      services.each do |service_name, service_attributes|
        next unless service_attributes[:modified]
        if set_start_mode!(service_name)
          services_toggled << service_name
        else
          change  = enabled(service_name) ? 'enable' : 'disable'
          message = _("Could not %{change} %{service}. ") %
            { :change => change, :service => service_name }
          message << status(service_name)
          errors << message
          Builtins.y2error("Error: %1", message)
        end
      end
      services_toggled
    end

    publish({:function => :active,         :type => "boolean ()"              })
    publish({:function => :activate,       :type => "string (boolean)"        })
    publish({:function => :all,            :type => "map <string, map> ()"    })
    publish({:function => :disable,        :type => "string (boolean)"        })
    publish({:function => :enable,         :type => "string (boolean)"        })
    publish({:function => :enabled,        :type => "boolean ()"              })
    publish({:function => :can_be_enabled, :type => "boolean ()"              })
    publish({:function => :errors,         :type => "list ()"                 })
    publish({:function => :export,         :type => "list <string> ()"        })
    publish({:function => :import,         :type => "boolean (list <string>)" })
    publish({:function => :modified,       :type => "boolean ()"              })
    publish({:function => :modified=,      :type => "boolean (boolean)"       })
    publish({:function => :read,           :type => "map <string, map> ()"    })
    publish({:function => :reset,          :type => "boolean ()"              })
    publish({:function => :save,           :type => "boolean ()"              })
    publish({:function => :status,         :type => "string (string)"         })
  end

  ServicesManagerService = ServicesManagerServiceClass.new
end
