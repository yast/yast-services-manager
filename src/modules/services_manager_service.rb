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
      manual:    N_('Manual')
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
    # @param [String] service name
    # @return [Boolean] whether the service exists
    def activate(service)
      exists?(service) do
        services[service].start
        log.info "Service #{service} has been marked for activation"
        true
      end
    end

    # Sets whether service should be running after writing the configuration
    #
    # @param [String] service name
    # @return [Boolean] whether the service exists
    def deactivate(service)
      exists?(service) do
        services[service].stop
        log.info "Service #{service} has been marked for de-activation"
        true
      end
    end

    # @param [String] service name
    # @return [Boolean] the current setting whether service should be running
    def active(service)
      exists?(service) { services[service].active? }
    end

    alias_method :active?, :active

    # @param service [String] service name
    # @param key [Symbol] value that has been changed (:active and :start_mode)
    # @return [Boolean] true if the key has changed
    def changed_value?(service, key)
      exists?(service) { services[service].changed_value?(:active) }
    end

    # Returns whether the given service has been enabled
    #
    # @param String service
    # @return Boolean enabled
    def enabled(service)
      exists?(service) do
        services[service].start_mode != :manual
      end
    end

    # Service state
    #
    # @param service [String] service name
    # @return [String]
    def state(service)
      return nil unless exists?(service)
      services[service].state
    end

    # Service substate
    #
    # @param service [String] service name
    # @return [String]
    def substate(service)
      return nil unless exists?(service)
      services[service].substate
    end

    # Service description
    #
    # @param service [String] service name
    # @return [String]
    def description(service)
      return nil unless exists?(service)
      services[service].description
    end

    # Returns whether the given service can be enabled/disabled by the user
    #
    # @param service [String] Service name
    # @return [Boolean] is it enabled or not
    def can_be_enabled(service)
      exists?(service) do
        services[service].can_be_enabled?
      end
    end

    def modified_services
      services.values.select(&:changed?)
    end

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
      services.values.each(&:reload)
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

      if modified_services.empty?
        Builtins.y2milestone "No service has been changed, nothing to do..."
        return true
      end

      Builtins.y2milestone "Modified services: #{modified_services.map(&:name)}"

      services.values.each { |s| s.save(ignore_status: Stage.initial) }
      services.values.each(&:reload)
      true
    end

    # @return [Array<Hash<Symbol,Object>>] Errors for each service
    def errors
      services.each_with_object({}) do |(name, err), all|
        all[name] = err unless err.empty?
      end
    end

    # Activates the service in cache
    #
    # @param [String] service name
    # @return [Boolean]
    def switch(service)
      active(service) ? deactivate(service) : activate(service)
    end

    def reset_service(service)
      services[service].reload
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
        services[service].start_mode = mode
        if active(service)
          services[service].start
        else
          services[service].stop
        end
      end
    end

    def start_mode(service)
      exists?(service) do
        services[service].start_mode
      end
    end

    def start_modes(service)
      exists?(service) do
        services[service].start_modes
      end
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

    # Determine whether some service has been modified
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
