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

    SERVICE_SUFFIX = '.service'

    START_MODE = {
      on_boot:   N_('On Boot'),
      on_demand: N_('On Demand'),
      manual:    N_('Manually')
    }.freeze

    # @return [Hash{String => Yast2::SystemService}]
    def services
      @services ||= read
    end

    attr_writer :services

    alias_method :all, :services

    def initialize
      textdomain 'services-manager'
      @modified = false
      @services = nil
    end

    # Finds a service
    #
    # @param service [String] service name
    # @return [Yast2::SystemService, nil]
    def find(service)
      services[service]
    end

    # Sets whether service should be running after writing the configuration
    #
    # @param name [String] service name
    # @return [Boolean] whether the service exists
    def activate(name)
      exists?(name) do |service|
        service.start
        log.info "Service #{name} has been marked for activation"
        true
      end
    end

    # Sets whether service should be running after writing the configuration
    #
    # @param name [String] service name
    # @return [Boolean] whether the service exists
    def deactivate(name)
      exists?(name) do |service|
        service.stop
        log.info "Service #{name} has been marked for de-activation"
        true
      end
    end

    # @param name [String] service name
    # @return [Boolean] the current setting whether service should be running
    def active(name)
      exists?(name, &:active?)
    end

    alias_method :active?, :active

    # @param name [String] service name
    # @param key [Symbol] value that has been changed (:active and :start_mode)
    # @return [Boolean] true if the key has changed
    def changed_value?(name, key)
      exists?(name) { |s| s.changed_value?(:active) }
    end

    # Returns whether the given service has been enabled
    #
    # @param name [String] service name
    # @return Boolean enabled
    def enabled(name)
      exists?(name) { |s| s.start_mode != :manual }
    end

    # Service state
    #
    # @param name [String] service name
    # @return [String]
    def state(name)
      exists?(name, &:state)
    end

    # Service substate
    #
    # @param name [String] service name
    # @return [String]
    def substate(name)
      exists?(name) { |s| s.substate }
    end

    # Service description
    #
    # @param name [String] service name
    # @return [String]
    def description(name)
      exists?(name) { |s| s.description }
    end

    # Returns whether the given service can be enabled/disabled by the user
    #
    # @param name [String] Service name
    # @return [Boolean] is it enabled or not
    def can_be_enabled(name)
      exists?(name) { |s| !s.static? }
    end

    # Returns services which have been modified (in memory)
    #
    # @return [Array<Yast2::SystemService>] List of modified services
    def modified_services
      services.values.select(&:changed?)
    end

    # Reloads services list
    def reload
      self.services = Y2ServicesManager::ServiceLoader.new.read
    end

    # Reads all services' data
    #
    # @return [Hash{String => Settings}]
    #   like "foo" => { enabled: false, loaded: true, ..., description: "Features OO" }
    def read
      Y2ServicesManager::ServiceLoader.new.read
    end

    # Resets the global status of the object
    #
    # @return [Boolean]
    def reset
      services.values.each(&:reset)
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
          log.error("Unknown status '#{service.status}' for service '#{service.name}'")
        end
      end

      return true if non_existent_services.empty?

      log.error("Services #{non_existent_services.inspect} don't exist on this system")
      false
    end

    # Saves the current configuration in memory
    #
    # @return [Boolean]
    def save
      log.info "Saving systemd services..."

      if modified_services.empty?
        log.info "No service has been changed, nothing to do..."
        return true
      end

      log.info "Modified services: #{modified_services.map(&:name)}"

      modified_services.each { |s| s.save(ignore_status: Stage.initial) }
      services.values.all? { |s| s.errors.empty? }
    end

    # Returns a list of errors detected when trying to write the changes to the underlying system
    #
    # @return [Array<String>] Detected errors or an empty string when no errors were detected
    def errors
      services.values.reject { |e| e.errors.empty? }.each_with_object([]) do |service, all|
        all.concat(error_messages_for(service))
      end
    end

    # Activates the service in cache
    #
    # @param name [String] service name
    # @return [Boolean]
    def switch(name)
      active(name) ? deactivate(name) : activate(name)
    end

    # Sets start_mode for a service (in memory only, use save())
    #
    # @param name [String] service name
    # @param mode    [Symbol] Start mode
    # @see Yast::SystemdServiceClass::Service#start_modes
    def set_start_mode(name, mode)
      exists?(name) { |s| s.start_mode = mode }
    end

    # Returns the start_mode for the given service (from memory)
    #
    # @param name [String] service name
    # @return [Symbol] Start mode
    def start_mode(name)
      exists?(name) { |s| s.start_mode }
    end

    # Returns the list of supported start modes for the given service
    #
    # @param name [String] service name
    # @return [Array<Symbol>] Supported start modes
    def start_modes(name)
      exists?(name) { |s| s.start_modes }
    end

    # Returns full information about the service as returned from systemctl command
    #
    # @param name [String] Service name
    # @return [String] full unformatted information
    def status(name)
      out = Systemctl.execute("status #{name}#{SERVICE_SUFFIX} 2>&1")
      out['stdout']
    end

    # Translates the start mode for a given service
    #
    # @param name [String] service name
    # @return [String] Translated start mode
    def start_mode_to_human_for(name)
      start_mode_to_human(start_mode(name))
    end

    # List of YaST supported start modes
    #
    # @return [Array<String>] Supported start modes
    def all_start_modes
      START_MODE.keys
    end

    # Returns the localized start mode
    #
    # @param mode [Symbol] Start mode
    # @return [String] Localized start mode
    def start_mode_to_human(mode)
      _(START_MODE[mode])
    end

    # Determines whether some service has been modified
    #
    # @return [Boolean] true if some service has been modified; false otherwise
    #
    # @see Yast2::SystemService#changed?
    def modified
      modified_services.any?
    end

    alias_method :modified?, :modified

    private

    # Helper method to avoid if-else branching
    # When passed a block, this will be executed only if the service exists
    # Whitout block it returns the boolean value
    #
    # @param name [String] service name
    # @yieldreturn [Boolean]
    # @return [Boolean] false if the service does not exist,
    #   otherwise what the block returned
    def exists?(name)
      if Stage.initial && !find(name)
        # We are in inst-sys. So we cannot check for installed services but generate entries
        # for these services if they still not exists.
        services[name] = Y2ServicesManager::ServiceLoader::DEFAULT_SERVICE_SETTINGS.clone
      end

      service = find(name)
      if service && block_given?
        yield service
      else
        !!service
      end
    end

    # Returns a list of error messages for the given service
    #
    # @param service [String] Service name
    # @return [Array<String>] List of error messages
    def error_messages_for(service)
      service.errors.keys.map do |key|
        send("#{key}_error_message_for", service)
      end
    end

    # Returns a error message related to the activation/deactivation of services
    #
    # @return [String] Error message
    def active_error_message_for(service)
      change = service.active? ? 'start' : 'stop'
      status = service.running? ? 'running' : 'not running'
      _("Could not %{change} %{service} which is currently %{status}." %
        { change: change, service: service.name, status: status })
    end

    # Start mode translations in error messages
    START_MODE_TEXT = {
      on_boot:   N_('on boot'),
      on_demand: N_('on demand'),
      manual:    N_('manually')
    }.freeze

    # Returns a error message related to setting services start modes
    #
    # @return [String] Error message
    def start_mode_error_message_for(service)
      _("Could not set %{service} to be started %{change}." %
        { service: service.name, change: START_MODE_TEXT[service.start_mode] })
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
