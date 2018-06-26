require "yast"

module Yast
  import "Service"
  import "ServicesProposal"
  import "SystemdService"
  import "Stage"

  class ServicesManagerServiceClass < Module
    include Yast::Logger

    LIST_UNIT_FILES_COMMAND = 'systemctl list-unit-files --type service'
    LIST_UNITS_COMMAND      = 'systemctl list-units --all --type service'
    STATUS_COMMAND          = 'systemctl status'
    # FIXME: duplicated in Yast::Systemctl
    COMMAND_OPTIONS         = ' --no-legend --no-pager --no-ask-password '
    TERM_OPTIONS            = ' LANG=C TERM=dumb COLUMNS=1024 '
    SERVICE_SUFFIX          = '.service'

    # Used by ServicesManagerServiceClass to keep data about an individual service.
    # (Not a real class; documents the structure of a Hash)
    #
    # Why does this hash exist if we have Yast::SystemdServiceClass::Service?
    class Settings < Hash
      # @!method [](k)
      #   @option k :enabled  [Boolean] service has been enabled
      #   @option k :can_be_enabled [Boolean] service can be enabled/disabled by the user
      #   @option k :modified [Boolean] service has been changed (got enabled/disabled)
      #   @option k :active   [Boolean] The high-level unit activation state, i.e. generalization of SUB
      #   @option k :loaded   [Boolean] Reflects whether the unit definition was properly loaded
      #   @option k :description [String] English description of the service
    end

    # @return [Settings]
    DEFAULT_SERVICE_SETTINGS = {
      :enabled        => false,
      :can_be_enabled => true,
      :modified       => false,
      :active         => nil,
      :loaded         => false,
      :description    => nil
    }

    # FIXME: this is a mixture of
    # LoadState (the LOAD column of systemctl list-units) and
    # UnitFileState (STATE of systemctl list-unit-files)
    module Status
      # LoadState
      LOADED     = 'loaded'
      # LoadState
      NOTFOUND   = 'not-found'
      # masked is both a LoadState and a UnitFileState :-/
      # The service has been marked as completely unstartable, automatically or manually.
      MASKED     = 'masked'
      # UnitFileState
      # The service is missing the [Install] section in its init script, so you cannot enable or disable it.
      STATIC     = 'static'
    end

    # @api private
    class ServiceLoader
      include Yast::Logger

      # @return [Hash{String => String}] service name -> status, like "foo" => "enabled" (UnitFileState)
      # @see Status
      attr_reader :unit_files

      # @return [Hash{String => Hash}]
      #   like "foo" => { status: "loaded", description: "Features OO" }
      # @see Status
      attr_reader :units

      # @return [Hash{String => Settings}]
      #   like "foo" => { enabled: false, loaded: true, ..., description: "Features OO" }
      attr_reader :services

      # Like {#unit_files} except those that are "masked"
      # @return [Hash{String => String}] service name -> status, like "foo" => "enabled" (UnitFileState)
      # @see Status
      attr_reader :supported_unit_files

      # Like {#units} except those with status: "not-found"
      # @return [Hash{String => Hash}]
      #   like "foo" => { status: "loaded", description: "Features OO" }
      # @see Status
      attr_reader :supported_units

      # @return [Hash{String => Settings}]
      #   like "foo" => { enabled: false, loaded: true, ..., description: "Features OO" }
      def read
        @services   = {}
        @unit_files = {}
        @units      = {}

        load_unit_files
        load_units

        @supported_unit_files = unit_files.select do |_, status|
          status != Status::MASKED # masked services should not been shown at all
        end

        @supported_units = units.reject do |name, attributes|
          attributes[:status] == Status::NOTFOUND # definition file is not available anymore
        end

        extract_services
        services
      end

      private

      # FIXME: use Yast::Systemctl for this, remember to chomp SERVICE_SUFFIX

      # @return [Array<String>] "apache2.service   enabled\n"
      def list_unit_files
        command = TERM_OPTIONS + LIST_UNIT_FILES_COMMAND + COMMAND_OPTIONS
        out = SCR.Execute(Path.new('.target.bash_output'), command)['stdout']
        out.lines
      end

      # @return [Array<String>] "dbus.service   loaded active running D-Bus System Message Bus\n"
      def list_units
        command = TERM_OPTIONS + LIST_UNITS_COMMAND + COMMAND_OPTIONS
        out = SCR.Execute(Path.new('.target.bash_output'), command)['stdout']
        out.lines
      end

      def load_unit_files
        list_unit_files.each do |line|
          service, status = line.split(/[\s]+/)
          service.chomp! SERVICE_SUFFIX
          # Unit template, errors out when inquired with `systemctl show`
          # See systemd.unit(5)
          next if service.end_with?("@")
          unit_files[service] = status
        end
      end

      def load_units
        list_units.each do |line|
          service, status, _active, _sub_state, *description = line.split(/[\s]+/)
          service.chomp! SERVICE_SUFFIX
          units[service] = {
            :status => status,
            :description => description.join(' ')
          }
        end
      end

      def extract_services_from_unit_files
        @supported_unit_files.each do |name, status|
          services[name] = DEFAULT_SERVICE_SETTINGS.clone
          if @supported_units[name]
            # Services are loaded into the system. Taking that one because there are more
            # information
            services[name][:loaded] = @supported_units[name][:status] == Status::LOADED
            services[name][:description] = @supported_units[name][:description]
          end
          services[name][:can_be_enabled] = status == Status::STATIC ? false : true
        end
      end

      def extract_services_from_units
        @supported_units.each do |name, service|
          next if services[name]
          services[name] = DEFAULT_SERVICE_SETTINGS.clone
          services[name][:loaded] = service[:status] == Status::LOADED
          services[name][:description] = service[:description]
        end
      end

      def extract_services
        extract_services_from_unit_files
        # Add old LSB services (Services which are loaded but not available as a unit file)
        extract_services_from_units

        service_names = services.keys.sort
        ss = SystemdService.find_many(service_names)
        # Rest of settings
        service_names.zip(ss).each do |name, s|
          sh = services[name] # service hash
          sh[:enabled] = s && (s.enabled? || !!(s.socket && s.socket.enabled?))
          sh[:active] = s && s.active?
          if !sh[:description] || sh[:description].empty?
            sh[:description] = s ? s.description : ""
          end
        end
      end
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

    # Enables a given service (in memory only, use save() later)
    #
    # @param String service name
    # @param Boolean new service status
    def enable(service)
      exists?(service) do
        services[service][:enabled]  = true
        services[service][:modified] = true
        self.modified = true
      end
    end

    # Disables a given service (in memory only, use save() later)
    #
    # @param String service name
    # @param Boolean new service status
    def disable(service)
      exists?(service) do
        services[service][:enabled]  = false
        services[service][:modified] = true
        self.modified = true
      end
    end

    # Returns whether the given service has been enabled
    #
    # @param String service
    # @return Boolean enabled
    def enabled(service)
      exists?(service) do
        services[service][:enabled]
      end
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
        services[service] = DEFAULT_SERVICE_SETTINGS.clone
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

        service = SystemdService.find(service_name)
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
        if toggle! service_name
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
