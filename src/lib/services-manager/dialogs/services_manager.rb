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
require "services-manager/widgets/services_table"

Yast.import "Wizard"

module Y2ServicesManager
  module Dialogs
    class ServicesManager
      include Yast
      include Yast::I18n
      include Yast::UIShortcuts
      include Yast::Logger

      # Constructor
      #
      # Journal package (yast2-journal) is not an strong dependency (only suggested).
      # Here the journal is tried to be loaded, avoiding to fail when the package is
      # not installed (see {#load_journal}).
      def initialize(client)
        textdomain 'services-manager'
        load_journal

        @client = client
      end

      # Main dialog function
      #
      # @return :next or :abort
      def run
        show
        handle_input
      ensure
        close
      end

    private

      module Id
        SERVICE_BUTTONS = :services_buttons
        SERVICES_TABLE  = :services_table
        TOGGLE_RUNNING  = :start_stop
        TOGGLE_ENABLED  = :enable_disable
        DEFAULT_TARGET  = :default_target
        SHOW_DETAILS    = :show_details
        SHOW_LOGS       = :show_logs
      end

      attr_reader :client

      def title
        _('Services Manager')
      end

      def contents
        VBox(
          Left(
            HSquash(
              MinWidth(
                # Additional space for UI features
                display_width - 58,
                target_selector.widget
              )
            )
          ),
          VSpacing(1),
          services_table.widget,
          ReplacePoint(Id(Id::SERVICE_BUTTONS), Empty())
        )
      end

      def target_selector
        @target_selector ||= TargetSelector.new(Id::DEFAULT_TARGET, client)
      end

      # Table widget to show all services
      #
      # @return [Widgets::ServicesTable]
      def services_table
        @services_table ||= Widgets::ServicesTable.new(id: Id::SERVICES_TABLE)
      end

      def show
        Wizard.CreateDialog
        Wizard.SetContentsButtons(title, contents, "", Label.CancelButton, Label.OKButton)
        Wizard.HideBackButton
        Wizard.SetAbortButton(:abort, Label.CancelButton)

        services_names = read_services
        services_table.refresh(services_names: services_names)
        refresh_buttons(selected_service_name)
      end

      def close
        UI.CloseDialog
      end

      def handle_input
        input = nil

        loop do
          input = UI.UserInput
          log.info("User input: #{input}")

          case input
            when :abort, :cancel
              break if Popup::ReallyAbort(Yast::ServicesManager.modified?)
            when :next
              break if save || !continue?
            when Id::DEFAULT_TARGET
              set_default_target
            when Id::SERVICES_TABLE
              handle_table
            when Id::TOGGLE_ENABLED # Default for double-click in the table
              toggle_service
            when Id::TOGGLE_RUNNING
              switch_service
            when *client.all_start_modes
              set_start_mode(input)
            when Id::SHOW_DETAILS
              show_details
            when Id::SHOW_LOGS
              show_logs
            else
              log.error("Unknown user input: #{input}")
          end
        end

        input
      end

      def save
        UI.OpenDialog(Label(_('Writing configuration...')))
        client.save
        UI.CloseDialog
      end

      def continue?
        message =
          _("Writing the configuration failed:\n") +
          client.errors.join("\n") +
          _("\nWould you like to continue editing?")

        continue = Popup::ContinueCancel(message)
        client.reset if continue

        continue
      end

      def set_default_target
        client.default_target = target_selector.value
      end

      def handle_table
        if @prev_service == selected_service_name
          toggle_service
        else
          @prev_service = selected_service_name
          refresh_buttons(selected_service_name)
        end
      end

      # Toggles (enable/disable) whether the currently selected service should
      # be enabled or disabled while writing the configuration
      def toggle_service
        service = selected_service_name

        if client.can_be_enabled?(service)
          client.toggle_service(service)
        else
          message =_("This service cannot be enabled/disabled because " \
           "it has no \"install\" section in the description file")
          Popup.Error(message)
        end

        refresh_selected_service
      end

      # Switches (starts/stops) the currently selected service
      #
      # @return [Boolean] if successful
      def switch_service
        client.switch_service(selected_service_name)
        refresh_selected_service
      end

      # Sets the start mode to the selected service
      #
      # The table row of the selected service is refreshed.
      #
      # @param mode [Symbol] :on_boot, :on_demand, :manually
      def set_start_mode(mode)
        client.set_start_mode(selected_service_name, mode)
        refresh_selected_service
      end

      # Opens up a popup with details about the currently selected service
      def show_details
        service = selected_service_name
        full_info = client.service_status(service)

        x_size = full_info.lines.collect{|line| line.size}.sort.last
        y_size = full_info.lines.count

        Popup.LongText(
          _('Service %{service} Full Info') % {:service => service},
          RichText("<pre>#{full_info}</pre>"),
          # counted size plus dialog spacing
          x_size + 8, y_size + 6
        )

        services_table.focus
      end

      # Opens a dialog with the logs (from current boot) for the currently selected service
      #
      # In case the service is associated to a socket, the log entries for the socket unit
      # are also included, see {#selected_units_names}.
      def show_logs
        query = Y2Journal::Query.new(interval: "0", filters: { "unit" => selected_units_names })
        Y2Journal::EntriesDialog.new(query: query).run

        services_table.focus
      end

      # Buttons for actions over a selected service
      #
      # The log button only is included if YaST Journal is installed.
      #
      # @param service_name [String]
      # @return [YaST::Term]
      def service_buttons(service_name)
        start_stop_label = client.service_active?(service_name) ? _('&Stop') : _('&Start')
        start_mode_label = client.start_mode_to_human_for(service_name)
        buttons = [
          PushButton(Id(Id::TOGGLE_RUNNING), start_stop_label),
          HSpacing(1),
          MenuButton(Id(Id::TOGGLE_ENABLED), start_mode_label, start_options_for(service_name)),
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

      # Redraw all buttons according to the given service
      #
      # @param service_name [String]
      def refresh_buttons(service_name)
        UI.ReplaceWidget(Id(Id::SERVICE_BUTTONS), service_buttons(service_name))
      end

      # Redraws data of the selected service (table row and buttons)
      def refresh_selected_service
        refresh_buttons(selected_service_name)
        services_table.refresh_row(selected_service_name)
      end

      def read_services
        UI.OpenDialog(Label(_('Reading services status...')))
        services_names = client.services_names
        UI.CloseDialog

        services_names
      end

      # Names of the units associated to the currently selected service
      #
      # It includes the name of the socket unit when needed
      #
      # @return [Array<String>] e.g., ["tftp.service", "tftp.socket"]
      def selected_units_names
        if selected_service
          units = [selected_service.service.id]
          units << selected_service.socket.id if selected_service.socket?
          units
        else
          [selected_service_name]
        end
      end

      # Name of the currently selected service (taken from the table widget)
      #
      # @return [String]
      def selected_service_name
        services_table.selected_service_name
      end

      # Currently selected service
      #
      # @return [Yast2::Systemdervice, nil] nil if the service is not found
      def selected_service
        services_table.selected_service
      end

      # Possible start mode options to select for a sevice
      #
      # @param service_name [String]
      # @return [Array<Yast::Term>]
      def start_options_for(service_name)
        start_modes = client.service_start_modes(service_name)

        client.all_start_modes.each_with_object([]) do |mode, all|
          next unless start_modes.include?(mode)
          all << Item(Id(mode), client.start_mode_to_human(mode))
        end
      end

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

      def display_width
        UI.GetDisplayInfo["Width"] || 80
      end

      # Widget to select the systemd target
      class TargetSelector
        include Yast::I18n
        include Yast::UIShortcuts

        def initialize(id, client)
          @id = id
          @client = client
        end

        def widget
          ComboBox(
            Id(:default_target),
            Opt(:notify),
            _('Default System &Target'),
            items
          )
        end

        def value
          UI.QueryWidget(id, :Value)
        end

        def id
          Id(@id)
        end

      private

        attr_reader :client

        # All possible systemd targets
        #
        # @return [Array<YaST::Term>]
        def items
          client.all_targets.collect do |target, target_def|
            label = target_def[:description] || target
            Item(Id(target), label, (target == client.default_target))
          end
        end
      end
    end
  end
end
