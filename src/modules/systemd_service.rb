# encoding: utf-8

require "ycp"

module Yast
  class SystemdServiceClass < Module
    TERM_OPTIONS = ' LANG=C TERM=dumb COLUMNS=1024 '
    SERVICE_SUFFIX = '.service'
    SYSTEMCTL_DEFAULT_OPTIONS = ' --no-legend --no-pager --no-ask-password '

    module Status
      ACTIVE = 'active'
      INACTIVE = 'inactive'

      ENABLED = 'enabled'
      DISABLED = 'disabled'

      SUPPORTED_STATES = [ENABLED, DISABLED]
    end

    def initialize
      textdomain 'services-manager'
      @services = nil
      clear_errors
      set_modified(false)
    end

    # TODO: move single-service creation and handling into a separate class
    def default_service
      {
        'enabled'     => false,
        'modified'    => false,
        'active'      => false,
        'load'        => '',
        'description' => '',
      }
    end

    def reset
      initialize
      true
    end

    def read
      (all.size > 0)
    end

    # Returns hash of all services read using systemctl
    #
    # @return Hash
    # @struct {
    #     'service_name'  => {
    #       'load'        => Reflects whether the unit definition was properly loaded
    #       'active'      => The high-level unit activation state, i.e. generalization of SUB
    #       'description' => English description of the service
    #       'enabled'     => (Boolean) whether the service has been enabled
    #       'modified'    => (Boolean) whether the service (enabled) has been changed
    #     }
    #   }
    def all
      return @services unless @services.nil?

      @services = {}

      SCR.Execute(
        path('.target.bash_output'),
        TERM_OPTIONS + 'systemctl list-unit-files --type service' + SYSTEMCTL_DEFAULT_OPTIONS
      )['stdout'].each_line {
        |line|
        service_def = line.split(/[\s]+/)
        # only enabled or disabled services can be handled
        # static and masked are ignored here
        if Status::SUPPORTED_STATES.include?(service_def[1])
          service_def[0].slice!(-8..-1) if (service_def[0].slice(-8..-1) == SERVICE_SUFFIX)
          @services[service_def[0]] = default_service
          @services[service_def[0]]['enabled'] = (service_def[1] == Status::ENABLED)
        end
      }

      SCR.Execute(
        path('.target.bash_output'),
        TERM_OPTIONS + 'systemctl --all --type service' + SYSTEMCTL_DEFAULT_OPTIONS
      )['stdout'].each_line {
        |line|
        service_def = line.split(/[\s]+/)
        service_def[0].slice!(-8..-1) if (service_def[0].slice(-8..-1) == SERVICE_SUFFIX)

        unless @services[service_def[0]].nil?
          @services[service_def[0]]['load']        = service_def[1]
          @services[service_def[0]]['active']      = (service_def[2] == Status::ACTIVE)
          @services[service_def[0]]['description'] = service_def[4..-1].join(" ")
        end
      }
      Builtins.y2debug('All services read: %1', @services)

      @services
    end

    def exists?(service)
      !all()[service].nil?
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

    def reset_modified(services)
      # Reset ('modified' of) all saved services
      services.each {
        |service|
        @services[service]['modified'] = false
      }
    end

    def enable_disable_services(force)
      enableddisabled = []

      all.each {
        |service, service_def|
        if service_def['modified'] || force
          if (SystemdService.is_enabled(service) ? Service::Enable(service) : Service::Disable(service))
            enableddisabled << service
          else
            error = {
              'message' => SystemdService.is_enabled(service) ?
                _('Could not enable service %{service}') % {:service => service}
                :
                _('Could not disable service %{service}') % {:service => service},
              'details' => full_info(service),
            }
            @errors << error
            Builtins.y2error("Runtime error: %1", error)
          end
        end
      }

      enableddisabled
    end

    def start_stop_services(force)
      all.each {
        |service, service_def|
        if service_def['modified'] || force
          unless (SystemdService.is_enabled(service) ? Service::Start(service) : Service::Stop(service))
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
      }
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
    def full_info(service)
      SCR.Execute(
        path('.target.bash_output'),
        TERM_OPTIONS + "systemctl status #{service}#{SERVICE_SUFFIX}" + " 2>&1"
      )['stdout']
    end

    # Sets that configuration has been modified
    def set_modified(new_status = true)
      @modified = new_status
    end

    # Returns whether configuration has been modified
    # @return (Boolean) whether modified
    def is_modified
      @modified
    end

    # Enables a given service (in memoery only, use save() later)
    #
    # @param String service name
    # @param Boolean new service status
    def set_enabled(service, new_status)
      @services[service]['enabled']  = new_status
      @services[service]['modified'] = true
      set_modified(true)
    end

    # Returns whether the given service has been enabled
    #
    # @param String service
    # @return Boolean enabled
    def is_enabled(service)
      @services[service]['enabled']
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
    def is_running(service)
      @services[service]['active']
    end

    # Return all errors that have happened since last errors cleanup
    #
    # @return list <map <string, string> > errors
    # @struct [
    #   { 'message' => error message, 'details' => some details },
    #   ...
    # ]
    def errors
      @errors
    end

    # Frees all stored errors
    def clear_errors
      @errors = []
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
