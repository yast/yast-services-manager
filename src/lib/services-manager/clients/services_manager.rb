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

Yast.import "ServicesManager"
Yast.import "UI"
Yast.import "Wizard"
Yast.import "Service"
Yast.import "Label"
Yast.import "Popup"
Yast.import "Report"
Yast.import "Message"
Yast.import "Mode"
Yast.import "CommandLine"
Yast.import "SystemdService"
Yast.import "PackageSystem"

module Y2ServicesManager
  module Clients
    class ServicesManager < Yast::Client
      include Yast::Logger
      extend Yast::I18n

      module Id
        SERVICE_BUTTONS = :services_buttons
        SERVICES_TABLE  = :services_table
        TOGGLE_RUNNING  = :start_stop
        TOGGLE_ENABLED  = :enable_disable
        DEFAULT_TARGET  = :default_target
        SHOW_DETAILS    = :show_details
        SHOW_LOGS       = :show_logs
      end

      # Constructor
      #
      # Journal package (yast2-journal) is not an strong dependency (only suggested).
      # Here the journal is tried to be loaded, avoiding to fail when the package is
      # not installed (see {#load_journal}).
      def initialize
        load_journal
      end

      def run
        textdomain 'services-manager'

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
        Wizard.CreateDialog
        success = false
        while true
          if  main_dialog == :next
            success = Mode.config || save
            break if success
          else
            break
          end
        end
        UI.CloseDialog
        success
      end

    private

      # Tries to load the journal package
      #
      # @return [Boolean] true if the package is correctly loaded; false otherwise.
      def load_journal
        require "y2journal"
      rescue LoadError
        false
      end

      # Checks whether the journal is loaded
      #
      # @return [Boolean]
      def journal_loaded?
        !defined?(::Y2Journal).nil?
      end

      # Main dialog function
      #
      # @return :next or :abort
      def main_dialog
        adjust_dialog

        while true
          input = UI.UserInput
          Builtins.y2milestone('User returned %1', input)

          case input
            when :abort, :cancel
              break if Popup::ReallyAbort(Yast::ServicesManager.modified?)
            # Default for double-click in the table
            when Id::TOGGLE_ENABLED
              toggle_service
            when Id::SERVICES_TABLE
              handle_table
            when Id::TOGGLE_RUNNING
              switch_service
            when Id::DEFAULT_TARGET
              handle_dialog
            when Id::SHOW_LOGS
              show_logs
            when Id::SHOW_DETAILS
              show_details
            when *ServicesManagerService.all_start_modes
              set_start_mode(input)
            when :next
              break
            else
              Builtins.y2error('Unknown user input: %1', input)
          end
        end
        input
      end

      def save
        Builtins.y2milestone('Writing configuration...')
        UI.OpenDialog(Label(_('Writing configuration...')))
        success = Yast::ServicesManager.save
        UI.CloseDialog
        if !success
          success = ! Popup::ContinueCancel(
            _("Writing the configuration failed:\n" +
            Yast::ServicesManager.errors.join("\n")            +
            "\nWould you like to continue editing?")
          )
          Yast::ServicesManager.reset
        end
        success
      end

      def system_targets_items
        ServicesManagerTarget.all.collect do |target, target_def|
          label = target_def[:description] || target
          Item(Id(target), label, (target == ServicesManagerTarget.default_target))
        end
      end

      # Fills the dialog contents
      def adjust_dialog
        system_targets = system_targets_items
        # Translated target names are known in runtime only
        max_target_length = system_targets.collect{|i| i[1].length}.max

        # FIXME: Hotfix: For a yet unknown reason, max_target_length is sometimes nil
        unless max_target_length
          log.error "max_target_length is not defined, system targets: #{system_targets.inspect}"
          max_target_length = 20
        end

        contents = VBox(
          Left(
            HSquash(
              MinWidth(
                # Additional space for UI features
                max_service_name + 2,
                target_selector(system_targets)
              )
            )
          ),
          VSpacing(1),
          services_table,
          ReplacePoint(Id(Id::SERVICE_BUTTONS), Empty())
        )

        caption = _('Services Manager')

        Wizard.SetContentsButtons(caption, contents, "", Label.CancelButton, Label.OKButton)
        Wizard.HideBackButton
        Wizard.SetAbortButton(:abort, Label.CancelButton)

        redraw_services
      end

      def target_selector(targets_items)
        ComboBox(
          Id(Id::DEFAULT_TARGET),
          Opt(:notify),
          _('Default System &Target'),
          targets_items
        )
      end

      def services_table
        Table(
          Id(Id::SERVICES_TABLE),
          Opt(:immediate),
          Header(
            _('Service'),
            _('Start'),
            _('Active'),
            _('Description')
          ),
          []
        )
      end

      # Buttons for actions over a selected service
      #
      # The log button only is included if YaST Journal is installed.
      def service_buttons(service)
        start_stop_label = ServicesManagerService.active(service) ? _('&Stop') : _('&Start')
        start_mode_label = ServicesManagerService.start_mode_to_human_for(service)
        buttons = [
          PushButton(Id(Id::TOGGLE_RUNNING), start_stop_label),
          HSpacing(1),
          MenuButton(Id(Id::TOGGLE_ENABLED), start_mode_label, start_options_for(service)),
          HStretch(),
          PushButton(Id(Id::SHOW_DETAILS), _('Show &Details'))
        ]

        if journal_loaded?
          buttons += [
            HSpacing(1),
            PushButton(Id(Id::SHOW_LOGS), _("Show &Log"))
          ]
        end

        HBox(*buttons)
      end

      def start_options_for(service)
        start_modes = ServicesManagerService.start_modes(service)

        ServicesManagerService.all_start_modes.each_with_object([]) do |mode, all|
          next unless start_modes.include?(mode)
          all << Item(Id(mode), ServicesManagerService.start_mode_to_human(mode))
        end
      end

      # Redraws the services dialog
      def redraw_services
        UI.OpenDialog(Label(_('Reading services status...')))
        services = ServicesManagerService.all.collect do |service, attributes|
          Item(Id(service),
            shortened_service_name(service),
            ServicesManagerService.start_mode_to_human_for(service),
            attributes[:active] ? _('Active') : _('Inactive'),
            attributes[:description]
          )
        end
        UI.CloseDialog
        UI.ChangeWidget(Id(Id::SERVICES_TABLE), :Items, services)
        UI.SetFocus(Id(Id::SERVICES_TABLE))
        redraw_service_buttons
      end

      def redraw_service(service)
        UI.ChangeWidget(
          Id(Id::SERVICES_TABLE),
          Cell(service, 1),
          ServicesManagerService.start_mode_to_human_for(service)
        )

        enabled = ServicesManagerService.enabled(service)
        running = ServicesManagerService.active(service)

        # The current state matches the futural state
        if (enabled == running)
          UI.ChangeWidget(
            Id(Id::SERVICES_TABLE),
            Cell(service, 2),
            (running ? _('Active') : _('Inactive'))
          )
        # The current state differs the the futural state
        else
          UI.ChangeWidget(
            Id(Id::SERVICES_TABLE),
            Cell(service, 2),
            (running ? _('Active (will start)') : _('Inactive (will stop)'))
          )
        end

        redraw_service_buttons
      end

      def redraw_service_buttons
        UI.ReplaceWidget(Id(Id::SERVICE_BUTTONS), service_buttons(current_service))
      end

      def handle_dialog
        new_default_target = UI.QueryWidget(Id(Id::DEFAULT_TARGET), :Value)
        Builtins.y2milestone("Setting new default target '#{new_default_target}'")
        ServicesManagerTarget.default_target = new_default_target
      end

      def handle_table
        if @prev_service == current_service
          toggle_service
        else
          @prev_service = current_service
          redraw_service_buttons
        end
      end

      # Opens a dialog with the logs for the currently selected service (for current boot)
      #
      # In case the service is associated to a socket, the log entries for the socket unit
      # are also included, see {#selected_units_names}.
      def show_logs
        query = Y2Journal::Query.new(interval: "0", filters: { "unit" => selected_units_names })
        Y2Journal::EntriesDialog.new(query: query).run

        UI.SetFocus(Id(Id::SERVICES_TABLE))
        true
      end

      # Names of the units associated to the currently selected service
      #
      # It includes the name of the socket unit when needed
      #
      # @return [Array<String>] e.g., ["tftp.service", "tftp.socket"]
      def selected_units_names
        service = selected_service
        return [selected_sevice_name] unless service

        units_names = [service.id]
        units_names << service.socket.id if service.socket
        units_names
      end

      # Currently selected service
      #
      # @return [Yast::SystemdServiceClass::Service, nil] nil if the service is not found
      def selected_service
        SystemdService.find(selected_service_name)
      end

      # Name of the currently selected service (taken from the table widget)
      #
      # @return [String]
      def selected_service_name
        UI.QueryWidget(Id(Id::SERVICES_TABLE), :CurrentItem)
      end

      # Opens up a popup with details about the currently selected service
      def show_details
        service = selected_service_name
        full_info = ServicesManagerService.status(service)
        x_size = full_info.lines.collect{|line| line.size}.sort.last
        y_size = full_info.lines.count

        Popup.LongText(
          _('Service %{service} Full Info') % {:service => service},
          RichText("<pre>#{full_info}</pre>"),
          # counted size plus dialog spacing
          x_size + 8, y_size + 6
        )

        UI.SetFocus(Id(Id::SERVICES_TABLE))
        true
      end

      def set_start_mode(mode)
        ServicesManagerService.set_start_mode(current_service, mode)
        redraw_service(current_service)
        UI.SetFocus(Id(Id::SERVICES_TABLE))
      end

      # Switches (starts/stops) the currently selected service
      #
      # @return Boolean if successful
      def switch_service
        service = selected_service_name
        Builtins.y2milestone("Setting the service '#{service}' to " +
          "#{ServicesManagerService.services[service][:active] ? 'inactive' : 'active'}")

        success = ServicesManagerService.switch(service)
        redraw_service(service) if success

        UI.SetFocus(Id(Id::SERVICES_TABLE))
        success
      end

      # Toggles (enable/disable) whether the currently selected service should
      # be enabled or disabled while writing the configuration
      def toggle_service
        service = selected_service_name
        Builtins.y2milestone('Toggling service status: %1', service)
        if ServicesManagerService.can_be_enabled(service)
          ServicesManagerService.toggle(service)
        else
          Popup.Error(_("This service cannot be enabled/disabled because it has no \"install\" section in the description file"))
        end
        redraw_service(service)
        UI.SetFocus(Id(Id::SERVICES_TABLE))
        true
      end

      def display_width
        UI.GetDisplayInfo["Width"] || 80
      end

      def shortened_service_name(name)
        return name if name.size < max_service_name

        name[0..(max_service_name-3)] + "..."
      end

      def max_service_name
        # use 60 for other elements in table we want to display, see bsc#993826
        display_width - 60
      end

      def current_service
        UI.QueryWidget(Id(Id::SERVICES_TABLE), :CurrentItem)
      end
    end
  end
end
