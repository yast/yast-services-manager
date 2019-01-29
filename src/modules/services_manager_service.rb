# encoding: utf-8

# Copyright (c) [2014-2018] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "yast2/systemctl"
require "yast2/system_service"
require "services-manager/service_loader"

module Yast
  import "Mode"
  import "Service"
  import "ServicesProposal"
  import "Stage"

  class ServicesManagerServiceClass < Module
    include Yast::Logger
    extend Yast::I18n

    START_MODE = {
      on_boot:   N_('On Boot'),
      on_demand: N_('On Demand'),
      manual:    N_('Manually')
    }.freeze

    # @!attribute [w] modified
    #   @note Used by AutoYaST.
    #   @return [Boolean] Whether the module has been modified
    attr_writer :modified

    # @return [Hash{String => Yast2::SystemService}]
    def services
      read if @services.nil?
      @services
    end

    attr_reader :errors
    attr_writer :services

    alias_method :all, :services

    def initialize
      textdomain 'services-manager'
      @modified = false
      @errors = []
    end

    # Finds a service
    #
    # @param name [String] service name
    # @return [Yast2::SystemService, nil]
    def find(name)
      return services[name] unless Stage.initial || Mode.auto

      # In inst-sys we cannot check for installed services but generate entries for these
      # services if they do not exist yet. The same applies to AutoYaST when a service might be
      # installed as part of the software selection.
      services[name] = Yast2::SystemService.build(name)
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
      exists?(name) { |s| s.changed?(:active) }
    end

    # Returns whether the given service has been enabled
    #
    # @param name [String] service name
    # @return Boolean enabled
    def enabled(name)
      exists?(name) { |s| s.start_mode != :manual }
    end

    # Enables a given service (in memory only, use {#save} later)
    #
    # @param name [String] service name
    def enable(name)
      set_start_mode(name, :on_boot)
    end

    # Disables a given service (in memory only, use {#save} later)
    #
    # @param name [String] service name
    def disable(name)
      set_start_mode(name, :manual)
    end

    # Service state
    #
    # @param name [String] service name
    # @return [String, false] false if the service does not exist
    def state(name)
      exists?(name, &:state)
    end

    # Service substate
    #
    # @param name [String] service name
    # @return [String, false] false if the service does not exist
    def substate(name)
      exists?(name, &:substate)
    end

    # Service description
    #
    # @param name [String] service name
    # @return [String, false] false if the service does not exist
    def description(name)
      exists?(name, &:description)
    end

    # Returns services which have been modified (in memory)
    #
    # @return [Array<Yast2::SystemService>] List of modified services
    def modified_services
      services.values.select { |s| s.found? && s.changed? }
    end

    # Returns services which are not available in the underlying system
    #
    # @return [Array<Yast2::SystemService>] List of not found services
    def missing_services
      services.values.reject(&:found?)
    end

    # Reloads the service list
    #
    # @return [Hash{String => Yast2::SystemService}]
    # @see #read
    def reload
      @services = nil
      read
    end

    # Reads all services' data
    #
    # @note When running AutoYaST, system services will not be read as the relevant services
    # will be imported later.
    #
    # @return [Hash{String => Yast2::SystemService}]
    def read
      return @services if @services
      @services = Mode.auto ? {} : Y2ServicesManager::ServiceLoader.new.read
    end

    # Resets the global status of the object
    #
    # @return [Boolean]
    def reset
      services.values.each(&:reset)
      true
    end

    # Returns services to be exported to AutoYast profile
    #
    # FIXME: should be checked (and decided what to do if so) if service is marked to be exported as
    # both, enabled or disabled
    # @return [Hash{String => Array<String>}]
    def export
      on_boot_srvs = exportable_on_boot_services | ServicesProposal.enabled_services
      on_demand_srvs = exportable_on_demand_services
      disabled_srvs = exportable_disabled_services | ServicesProposal.disabled_services

      log.info "Exported services: on boot: #{on_boot_srvs}; on-demand: #{on_demand_srvs}; " \
        "disabled: #{disabled_srvs}"

      { "enable" => on_boot_srvs, "on_demand" => on_demand_srvs, "disable" => disabled_srvs }
    end

    # Import services from AutoYast profile
    #
    # Enabling or disabling them according to its declared status.
    # Unknown services only will be logged as error.
    #
    # @see #enable_or_disable
    #
    # @param profile [Yast::ServiceManagerProfile] a service manager profile
    #
    # @return [Boolean] true when all services were known; false if any services was unknown
    def import(profile)
      log.info "List of services from autoyast profile: #{profile.services.map(&:name)}"

      known_services, unknown_services = profile.services.partition { |service| exists?(service.name) }

      result = enable_or_disable(known_services)

      if unknown_services.empty? && result
        true
      else
        log.error("Services #{unknown_services.inspect} don't exist on this system")

        false
      end
    end

    # Saves the current configuration in memory
    #
    # @return [Boolean]
    def save
      log.info "Saving systemd services..."
      errors.clear
      refresh_services if Stage.initial || Mode.auto
      register_missing_services
      save_modified_services
      errors.empty?
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
    # @see Yast2::SystemService#start_modes
    def set_start_mode(name, mode)
      exists?(name) { |s| s.start_mode = mode }
    end

    # Returns the start_mode for the given service (from memory)
    #
    # @param name [String] service name
    # @return [Symbol] Start mode
    def start_mode(name)
      exists?(name, &:start_mode)
    end

    # Returns the list of supported start modes for the given service
    #
    # @param name [String] service name
    # @return [Array<Symbol>] Supported start modes
    def start_modes(name)
      exists?(name, &:start_modes)
    end

    # Returns full information from systemctl command about the service status
    #
    # @param service [Yast2::SystemService]
    #
    # @return [String] full unformatted information
    def status(service)
      output = service.keywords.map do |keyword|
        cmd = Yast2::Systemctl.execute("status #{keyword} 2>&1")
        cmd["stdout"]
      end

      output.join("\n")
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
      @modified || modified_services.any?
    end

    alias_method :modified?, :modified

    # Summary of changes in the services
    #
    # @return [String]
    def changes_summary
      started_services_summary +
        stopped_services_summary +
        changed_to_on_boot_services_summary +
        changed_to_on_demand_services_summary +
        changed_to_manual_services_summary
    end

  private

    # Registers errors for missing services
    #
    # @see #missing_services
    def register_missing_services
      missing_services.each do |service|
        self.errors << not_found_error_message_for(service)
      end
    end

    # Saves modified services
    def save_modified_services
      services = modified_services
      if services.empty?
        log.info "No service has been changed, nothing to do..."
        return
      end

      log.info "Modified services: #{services.map(&:name)}"

      services.each do |service|
        if !service.save(keep_state: Stage.initial)
          self.errors.concat(error_messages_for(service))
        end
      rescue Yast::SystemctlError
        # This exception is raised when the service cannot be refreshed
        next
      end
    end

    # Helper method to avoid if-else branching
    # When passed a block, this will be executed only if the service exists
    # Whitout block it returns the boolean value
    #
    # @param name [String] service name
    # @yieldreturn [Boolean]
    # @return [Boolean] false if the service does not exist,
    #   otherwise what the block returned
    def exists?(name)
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
      # TRANSLATORS: target action to perform over a service
      change = service.active? ? _("start") : _("stop")
      # TRANSLATORS: current service status
      status = service.running? ? _("running") : _("not running")

      format(
        # TRANSLATORS: Error message when a service cannot be activated/deactivated.
        # %{change} is replaced by the target action (i.e., "start" or "stop"),
        # %{service} is a service name (e.g., "cups"), and %{status} is the current
        # service status (i.e., "running" or "not running").
        _("Could not %{change} '%{service}' which is currently %{status}."),
        change:  change,
        service: service.name,
        status:  status
      )
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
      format(
        # TRANSLATORS: Error message when it was not possible to change the start
        # mode of a service. %{service} is replaced by a service name (e.g., "cups")
        # and %{change} is the target start mode (e.g., "on boot").
        _("Could not set '%{service}' to be started %{change}."),
        service: service.name,
        change:  _(START_MODE_TEXT[service.start_mode])
      )
    end

    # Returns a error message when the underlying service is not found
    #
    # @return [String] Error message
    def not_found_error_message_for(service)
      format(
        _("Service '%{service}' was not found."),
        service: service.name
      )
    end

    # Selects candidate services to be exported as enabled to AutoYast profile
    #
    # @return [Array<String>]
    def exportable_on_boot_services
      services.select { |n, _| start_mode(n) == :on_boot }.keys
    end

    # Selects candidate services to be exported as enabled on-demand to AutoYast profile
    #
    # @return [Array<String>]
    def exportable_on_demand_services
      services.select { |n, _| start_mode(n) == :on_demand }.keys
    end

    # Selects candidate services to be exported as disabled to AutoYast profile
    #
    # Untouched services are discarded; only services modified by the user to be disabled must be
    # exported to AutoYast profile.
    #
    # @return [Array<String>]
    def exportable_disabled_services
      services.select { |n, s| s.changed? && !enabled(n) }.keys
    end

    # Enable or disable given services according to its status
    #
    # An error will be logged for unknown statuses
    #
    # @see #import
    #
    # @param services [Array<Service>] services to be enabled or disabled
    def enable_or_disable(services)
      result = true
      services.each do |service|
        set_start_mode(service.name, service.start_mode)
      rescue ArgumentError
        result = false
        log.error("Invalid start mode '#{service.start_mode}' for service '#{service.name}'")
      end
      result
    end

    # Refresh the services information
    #
    # This is vitally important during 1st stage, where services information was read
    # too early (from the instsys and not from the installed system).
    def refresh_services
      services.values.each(&:refresh)
    end

    # Summary of services that have been started
    #
    # @return [String]
    def started_services_summary
      return "" unless started_services.any?

      format(
        _("The following services(%{amount}) will be started:<br />%{services}<br /><br />"),
        amount: started_services.size,
        services: services_names(started_services)
      )
    end

    # Summary of services that have been stopped
    #
    # @return [String]
    def stopped_services_summary
      return "" unless stopped_services.any?

      format(
        _("The following services(%{amount}) will be stopped:<br />%{services}<br /><br />"),
        amount:   stopped_services.size,
        services: services_names(stopped_services)
      )
    end

    # Summary of services that have been set to start on boot
    #
    # @return [String]
    def changed_to_on_boot_services_summary
      return "" unless changed_to_on_boot_services.any?

      format(
        _("The following services(%{amount}) will be configured to start after booting:<br />%{services}<br /><br />"),
        amount:   changed_to_on_boot_services.size,
        services: services_names(changed_to_on_boot_services)
      )
    end

    # Summary of services that have been set to start on demand
    #
    # @return [String]
    def changed_to_on_demand_services_summary
      return "" unless changed_to_on_demand_services.any?

      format(
        _("The following services(%{amount}) will be configured to start on demand:<br />%{services}<br /><br />"),
        amount:   changed_to_on_demand_services.size,
        services: services_names(changed_to_on_demand_services)
      )
    end

    # Summary of services that have been set to start manually
    #
    # @return [String]
    def changed_to_manual_services_summary
      return "" unless changed_to_manual_services.any?

      format(
        _("The following services(%{amount}) will be configured to start manually:<br />%{services}<br /><br />"),
        amount:   changed_to_manual_services.size,
        services: services_names(changed_to_manual_services)
      )
    end

    # Returns the name of the given services, joined by comma.
    #
    # @param services [Array<Yast2::SystemService>]
    # @return [String]
    def services_names(services)
      services.map(&:name).join(", ")
    end

    # Services that have been marked to start
    #
    # @return [Array<Yast2::SystemService>]
    def started_services
      modified_services.select { |s| s.action == :start }
    end

    # Services that have been market to stop
    #
    # @return [Array<Yast2::SystemService>]
    def stopped_services
      modified_services.select { |s| s.action == :stop }
    end

    # Services that have been configured to start on boot
    #
    # @return [Array<Yast2::SystemService>]
    def changed_to_on_boot_services
      modified_services.select { |s| s.changed?(:start_mode) && s.start_mode == :on_boot }
    end

    # Services that have been configured to start on demand
    #
    # @return [Array<Yast2::SystemService>]
    def changed_to_on_demand_services
      modified_services.select { |s| s.changed?(:start_mode) && s.start_mode == :on_demand }
    end

    # Services that have been configured to start manually
    #
    # @return [Array<Yast2::SystemService>]
    def changed_to_manual_services
      modified_services.select { |s| s.changed?(:start_mode) && s.start_mode == :manual }
    end

    publish({:function => :active,         :type => "boolean ()"              })
    publish({:function => :activate,       :type => "string (boolean)"        })
    publish({:function => :all,            :type => "map <string, map> ()"    })
    publish({:function => :disable,        :type => "string (boolean)"        })
    publish({:function => :enable,         :type => "string (boolean)"        })
    publish({:function => :enabled,        :type => "boolean ()"              })
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
