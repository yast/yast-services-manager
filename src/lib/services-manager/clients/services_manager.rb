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

require "yast"
require "services-manager/dialogs/services_manager"

Yast.import "ServicesManager"
Yast.import "Mode"
Yast.import "CommandLine"

module Y2ServicesManager
  module Clients
    class ServicesManager < Yast::Client
      include Yast::Logger

      def initialize
        textdomain 'services-manager'
      end

      def run
        cmdline = {
          "id"         => "services-manager",
          # translators: command line help text for services-manager module
          "help"       => _(
                            "Systemd target and services configuration module.\n" +
                            "Use systemctl for commandline services configuration."
                            ),
          "guihandler" => fun_ref(method(:gui_handler), "boolean ()")
        }

        CommandLine.Run(cmdline)
      end

      def gui_handler
        dialog.run == :next
      end

      def save
        log.info('Writing configuration...')

        Mode.config || Yast::ServicesManager.save
      end

      # Reads services and updates the table content
      #
      # It shows a temporary popup meanwhile the services are obtained.
      def services_names
        ServicesManagerService.all.keys
      end

      def errors
        Yast::ServicesManager.errors
      end

      def reset
        Yast::ServicesManager.reset
      end

      def all_targets
        ServicesManagerTarget.all
      end

      def default_target
        ServicesManagerTarget.default_target
      end

      def default_target=(target)
        log.info("Setting new default target '#{target}'")
        ServicesManagerTarget.default_target = target
      end

      # Switches (starts/stops) the currently selected service
      #
      # @return [Boolean] if successful
      def switch_service(service_name)
        new_status = ServicesManagerService.active(service_name) ? 'inactive' : 'active'
        log.info("Setting the service '#{service_name}' to #{new_status}")

        ServicesManagerService.switch(service_name)
      end

      # Sets the start mode to the selected service
      #
      # The table row of the selected service is refreshed.
      #
      # @param mode [Symbol] :on_boot, :on_demand, :manually
      def set_start_mode(service_name, mode)
        ServicesManagerService.set_start_mode(service_name, mode)
      end

      # Toggles (enable/disable) whether the currently selected service should
      # be enabled or disabled while writing the configuration
      def can_be_enabled?(service_name)
        ServicesManagerService.can_be_enabled(service_name)
      end

      def toggle_service(service_name)
        log.info("Toggling service state: #{service_name}")

        ServicesManagerService.toggle(service_name)
      end

      def service_active?(service_name)
        ServicesManagerService.active(service_name)
      end

      def service_status(service_name)
        ServicesManagerService.status(service_name)
      end

      def service_start_modes(service_name)
        ServicesManagerService.start_modes(service_name)
      end

      def all_start_modes
        ServicesManagerService.all_start_modes
      end

      def start_mode_to_human(mode)
        ServicesManagerService.start_mode_to_human(mode)
      end

      def start_mode_to_human_for(service_name)
        ServicesManagerService.start_mode_to_human_for(service_name)
      end

    private

      def dialog
        @dialog ||= Dialogs::ServicesManager.new(self)
      end
    end
  end
end
