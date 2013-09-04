 module Yast
  class SystemdServiceClass < Module
    SERVICE_UNITS_COMMAND    = 'systemctl list-unit-files --type service'
    SERVICES_DETAILS_COMMAND = 'systemctl --all --type service'
    SERVICES_STATUS_COMMAND  = 'systemctl status'
    COMMAND_OPTIONS          = ' --no-legend --no-pager --no-ask-password '
    TERM_OPTIONS             = ' LANG=C TERM=dumb COLUMNS=1024 '
    SERVICE_SUFFIX           = '.service'

    DEFAULT_SERVICE_SETTINGS = {
      :enabled     => false,  # Whether the service has been enabled
      :modified    => false,  # Whether the service has been changed (got enabled/disabled)
      :active      => false,  # The high-level unit activation state, i.e. generalization of SUB
      :loaded      => false,  # Reflects whether the unit definition was properly loaded
      :description => nil     # English description of the service
    }

    module Status
      LOADED   = 'loaded'
      ACTIVE   = 'active'
      INACTIVE = 'inactive'
      ENABLED  = 'enabled'
      DISABLED = 'disabled'
      SUPPORTED_STATES = [ENABLED, DISABLED]
    end

    attr_reader   :services, :errors
    attr_accessor :modified

    def initialize
      textdomain 'services-manager'
      @services = {}
      @errors   = []
      @modified = false
    end

    def reset
      @errors = []
      @modified = false
      true
    end

    def list_services_units
      command = TERM_OPTIONS + SERVICE_UNITS_COMMAND + COMMAND_OPTIONS
      SCR.Execute(path('.target.bash_output'), command)
    end

    def list_services
      command = TERM_OPTIONS + SERVICES_DETAILS_COMMAND + COMMAND_OPTIONS
      SCR.Execute(path('.target.bash_output'), command)
    end

    def all
      services
    end

    def load_services
      command_output = list_services_units
      stdout = command_output.fetch 'stdout'
      stderr = command_output.fetch 'stderr'
      exit_code = command_output.fetch 'exit'
      stdout.each_line do |line|
        service, status = line.split(/[\s]+/)
        service.chomp! SERVICE_SUFFIX
        if Status::SUPPORTED_STATES.include?(status)
          services[service] = DEFAULT_SERVICE_SETTINGS.clone
          services[service][:enabled] = status == Status::ENABLED
        end
      end
      Builtins.y2milestone('Services loaded: %1', services.keys)
    end

    def load_services_units
      command_output = list_services
      stdout = command_output.fetch 'stdout'
      stderr = command_output.fetch 'stderr'
      exit_code = command_output.fetch 'exit'
      stdout.each_line do |line|
        service, loaded, active, _, *description = line.split(/[\s]+/)
        service.chomp! SERVICE_SUFFIX
        if services[service]
          services[service][:loaded] = loaded == Status::LOADED
          services[service][:active] = active == Status::ACTIVE
          services[service][:description] = description.join(' ')
        end
      end
      Builtins.y2debug("Services details loaded: #{services}")
    end

    def read
      load_services
      load_services_units
    end

    def exists? service
      !!services[service]
    end

    # Returns only enabled services, the rest is expected to be disabled
    def export
      all.collect {
        |service_name, service_def|
        (is_enabled(service_name) ? service_name : nil)
      }.compact
    end

    def import(data)
      if data == nil
        Builtins.y2error("Incorrect data for import: #{data.inspect}")
        return false
      end

      ret = true

      # All imported will be enabled
      data.each do |service|
        if exists?(service)
          Builtins.y2milestone("Enabling service #{service}")
          set_enabled(service, true)
        else
          Builtins.y2error("Service #{service} doesn't exist on this system")
          ret = false
        end
      end

      # All the rest will be disabled
      services_to_disable = all.collect{|service, service_def| service} - data
      services_to_disable.each do |service|
        Builtins.y2milestone("Disabling service #{service}")
        set_enabled(service, false)
      end

      ret
    end

    def reset_modified services
      services.each { |service| services[service][:modified] = false }
    end

    def toggle service
      enabled?(service) ? Service.Enable(service) : Service.Disable(service)
    end

    def switch service
      enabled?(service) ? Service.Start(service) : Service.Stop(service)
    end

    def toggle_services force=false
      services_changed = []
      all.each do |service_name, service_attributes|
        next unless service_attributes[:modified] || force
        if toggle(service_name)
          services_changed << service_name
        else
          change  = enabled?(service_name) ? 'enable' : 'disable'
          message = _("Could not %{change} %{service}. ") %
            { :change => change, :service => service_name }
          message << get_service_status
          errors << message
          Builtins.y2error("Error: %1", message)
        end
      end
      services_changed
    end

    def switch_services force=false
      all.each do |service_name, service_attributes|
        next unless service_attributes[:modified] || force
        unless switch(service_name)
          change  = running?(service_name) ? 'st' : 'disable'
          message = _("Could not %{change} %{service}. ") %
            { :change => change, :service => service_name }
          message << get_service_status
          errors << message
          error = {
            'message' => SystemdService.is_enabled(service) ?
              _('Could not start service %{service}') % {:service => service}
              :
              _('Could not stop service %{service}') % {:service => service},
            'details' => full_info(service),
          }
          @errors << error
          Builtins.y2error("Runtime error: %1", error)
        end
      end
    end

    # Saves the current configuration in memory.
    # Supported parameters:
    # - :force (boolean) to force writing even if not marked as modified, default is false
    # - :startstop (boolean) to start enabled or stop disabled services, default is true
    #
    # @param <Hash> params
    # @return <boolean> if successful
    def save(params = {})
      force = (params[:force].nil? ? false : params[:force])
      startstop = (params[:startstop].nil? ? true : params[:startstop])
      clear_errors

      # At first, only adjust services startup (enabled/disabled)
      changed_services = enable_disable_services(force)

      # Then try to adjust services run (active/inactive)
      # Might start or stop some services that would cause system instability
      start_stop_services(force) if startstop

      reset_modified(changed_services)

      @errors.size == 0
    end

    # Returns full information about the service
    #
    # @param String service name
    # @return String full unformatted information
    def get_service_status service
      command = "#{TERM_OPTIONS}#{SERVICES_STATUS_COMMAND} #{service}#{SERVICE_SUFFIX} 2>&1"
      SCR.Execute(path('.target.bash_output'), command)['stdout']
    end

    # Enables a given service (in memoery only, use save() later)
    # @param String service name
    # @param Boolean new service status
    def enable service
      services[service][:enabled]  = true
      services[service][:modified] = true
      self.modified = true
    end

    def disable service
      services[service][:enabled]  = false
      services[service][:modified] = true
      self.modified = true
    end

    # Returns whether the given service has been enabled
    # @param String service
    # @return Boolean enabled
    def enabled? service
      services[service][:enabled]
    end

    # Sets whether service should be running after writing the configuration
    #
    # @param String service name
    # @param Boolean running
    def set_running(service, new_running)
      @services[service]['active'] = new_running
    end

    # Returns the current setting whether service should be running
    #
    # @param String service name
    # @return Boolean running
    def running?(service)
      @services[service]['active']
    end

    publish({:function => :all, :type => "map <string, map>"})
    publish({:function => :save, :type => "boolean"})
    publish({:function => :reset, :type => "boolean"})
    publish({:function => :set_modified, :type => "void"})
    publish({:function => :is_modified, :type => "boolean"})

    publish({:function => :set_enabled, :type => "void"})
    publish({:function => :is_enabled, :type => "boolean"})

    publish({:function => :set_running, :type => "void"})
    publish({:function => :is_running, :type => "boolean"})

    publish({:function => :errors, :type => "list <map <string, string> >"})
    publish({:function => :clear_errors, :type => "boolean"})

    publish({:function => :export, :type => "list <string>"})
    publish({:function => :import, :type => "boolean"})
  end

  SystemdService = SystemdServiceClass.new
end
