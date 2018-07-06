# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

require "yast2/system_service"

module Y2ServicesManager
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

    LIST_UNIT_FILES_COMMAND = 'systemctl list-unit-files --type service'
    LIST_UNITS_COMMAND      = 'systemctl list-units --all --type service'
    STATUS_COMMAND          = 'systemctl status'
    # FIXME: duplicated in Yast::Systemctl
    COMMAND_OPTIONS         = ' --no-legend --no-pager --no-ask-password '
    TERM_OPTIONS            = ' LANG=C TERM=dumb COLUMNS=1024 '
    SERVICE_SUFFIX          = '.service'

    # @return [Settings]
    DEFAULT_SERVICE_SETTINGS = {
      :start_mode     => :manual,
      :start_modes    => [:boot, :manual],
      :can_be_enabled => true,
      :modified       => false,
      :active         => nil,
      :loaded         => false,
      :description    => nil
    }

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
      out = Yast::SCR.Execute(Yast::Path.new('.target.bash_output'), command)['stdout']
      out.lines
    end

    # @return [Array<String>] "dbus.service   loaded active running D-Bus System Message Bus\n"
    def list_units
      command = TERM_OPTIONS + LIST_UNITS_COMMAND + COMMAND_OPTIONS
      out = Yast::SCR.Execute(Yast::Path.new('.target.bash_output'), command)['stdout']
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
      ss = Yast2::SystemService.find_many(service_names)
      # Rest of settings
      services.clear # FIXME
      ss.each do |s|
        services[s.name] = s
      end
    end
  end
end
