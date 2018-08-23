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
require "yast2/popup"
require "yast2/feedback"
require "services-manager/widgets/base"
require "services-manager/widgets/target_selector"
require "services-manager/widgets/start_stop_button"
require "services-manager/widgets/start_mode_button"
require "services-manager/widgets/show_details_button"
require "services-manager/widgets/logs_button"
require "services-manager/widgets/services_table"

Yast.import "ServicesManager"
Yast.import "UI"
Yast.import "Wizard"
Yast.import "Label"
Yast.import "Popup"
Yast.import "Mode"

module Y2ServicesManager
  module Dialogs
    # Main dialog for Services Manager client
    #
    # The idea behind this dialog class is pretty similar to UI::Dialog.
    #
    # This dialog is exactly the same as the previously implemented by ServicesManager client,
    # which was using Wizard dialogs. Using UI::Dialog would require to manually define here the
    # used Wizard layout. For this reason, UI::Dialog was not used here. Anyway, this dialog (and
    # its widgets) should be replaced by CWM in future.
    class ServicesManager
      include Yast
      include Yast::Logger
      include Yast::I18n
      include Yast::UIShortcuts

      # @!method success
      #   Indicates whether the dialog was successful, that is, the changes were correctly applied
      #   @return [Boolean]
      attr_reader :success
      alias_method :success?, :success

      def initialize(show_logs_button: false, show_start_stop_button: true, show_apply_button: true)
        textdomain "services-manager"

        @show_logs_button = show_logs_button
        @show_start_stop_button = show_start_stop_button
        @show_apply_button = show_apply_button
      end

      # Runs the dialog and returns if it was successful
      #
      # @return [Boolean]
      def run
        show
        handle_events
        close

        success?
      end

    private

      # @return [Boolean] whether the logs button should be shown
      attr_reader :show_logs_button
      alias_method :show_logs_button?, :show_logs_button

      # @return [Boolean] whether the start/stop button should be shown
      attr_reader :show_start_stop_button
      alias_method :show_start_stop_button?, :show_start_stop_button

      # @return [Boolean] whether the apply button should be shown
      attr_reader :show_apply_button
      alias_method :show_apply_button?, :show_apply_button

      # @return [Boolean]
      attr_writer :success

      # @!method finish
      #   Indicates whether the dialog should be finished after handling some event
      #   @return [Boolean]
      attr_accessor :finish
      alias_method :finish?, :finish

      module WidgetsId
        SERVICE_BUTTONS     = :service_buttons
        START_STOP_BUTTON   = :start_stop_button
        START_MODE_BUTTON   = :start_mode_button
        SHOW_DETAILS_BUTTON = :show_details_button
        LOGS_BUTTON         = :logs_button
        SERVICES_TABLE      = :services_table
        TARGET_SELECTOR     = :target_selector
      end

      # Additional space for UI features
      FEATURES_WIDTH = 58

      private_constant :FEATURES_WIDTH

      # Shows the dialog
      def show
        dialog = Yast::Wizard.GenericDialog(buttons)
        Yast::Wizard.OpenDialog(dialog)

        Yast::Wizard.SetContents(title, contents, help, true, true)
        refresh
      end

      # Closes the dialog
      def close
        UI.CloseDialog
      end

      # Dialog title
      #
      # @return [String]
      def title
        _("Services Manager")
      end

      # Dialog help
      #
      # @return [String]
      def help
        services_table.help
      end

      # Dialog content
      #
      # @return [Yast::Term]
      def contents
        VBox(
          Left(
            HSquash(
              MinWidth(
                display_width - FEATURES_WIDTH,
                target_selector.widget
              )
            )
          ),
          VSpacing(1),
          services_table.widget,
          ReplacePoint(Id(WidgetsId::SERVICE_BUTTONS), Empty())
        )
      end

      # Dialog buttons
      #
      # @return [Yast::Term]
      def buttons
        HBox(
          HWeight(1, PushButton(Id(:help), Opt(:key_F1, :helpButton), Label.HelpButton)),
          HStretch(),
          PushButton(Id(:abort), Opt(:key_F9), Label.CancelButton),
          HSpacing(2),
          show_apply_button? ? PushButton(Id(:apply), _("&Apply")) : Empty(),
          PushButton(Id(:next), Opt(:key_F10, :default), Label.OKButton)
        )
      end

      def target_selector
        @target_selector ||= Widgets::TargetSelector.new(id: WidgetsId::TARGET_SELECTOR)
      end

      # Table widget to show all services
      #
      # @return [Widgets::ServicesTable]
      def services_table
        @services_table ||= Widgets::ServicesTable.new(id: WidgetsId::SERVICES_TABLE)
      end

      # Buttons for actions over a selected service
      #
      # @return [Yast::Term]
      def service_buttons
        buttons = [
          start_mode_button.widget,
          HStretch(),
          show_details_button.widget
        ]

        if show_start_stop_button?
          buttons.unshift(
            start_stop_button.widget,
            HSpacing(1),
          )
        end

        if show_logs_button?
          buttons += [
            HSpacing(1),
            logs_button.widget
          ]
        end

        HBox(*buttons)
      end

      # Button for starting/stopping a service
      #
      # @return [Widgets::StartStopButton]
      def start_stop_button
        @start_stop_button ||= Widgets::StartStopButton.new(selected_service_name, id: WidgetsId::START_STOP_BUTTON)
      end

      # Menu button to set the start mode of a service
      #
      # @return [Widgets::StartModeButton]
      def start_mode_button
        @start_mode_button ||= Widgets::StartModeButton.new(selected_service_name, id: WidgetsId::START_MODE_BUTTON)
      end

      # Button to show details about a service
      #
      # @return [Widgets::ShowDetailsButton]
      def show_details_button
        @show_details_button ||= Widgets::ShowDetailsButton.new(id: WidgetsId::SHOW_DETAILS_BUTTON)
      end

      # Button to show service logs
      #
      # @return [Widgets::LogsButton]
      def logs_button
        @logs_button ||= Widgets::LogsButton.new(id: WidgetsId::LOGS_BUTTON)
      end

      # Handle all events in the dialog
      #
      # @note The loop finishes when some event handler sets {#finish} to true.
      def handle_events
        loop do
          input = UI.UserInput
          log.info("User returned #{input}")

          handler = handler_name(input)

          if respond_to?(handler, true)
            case handler
            when "start_mode_button_handler"
              send(handler, input)
            else
              send(handler)
            end
          else
            log.error("Unknown user input: #{input}")
          end

          break if finish?
        end
      end

      # Name of the handler for the current event
      #
      # @return [String]
      def handler_name(input)
        handler = "#{input}_handler"

        if Widgets::StartModeButton.all_start_modes.include?(input)
          handler = "start_mode_button_handler"
        end

        handler
      end

      # Handler for help event (help button is used)
      #
      # A popup with help is shown
      def help_handler
        self.finish = false

        show_help
      end

      # Handler for abort event (abort button is used)
      #
      # A confirm popup is shown
      def abort_handler
        self.success ||= false
        self.finish = Popup::ReallyAbort(Yast::ServicesManager.modified?)
      end

      alias_method :cancel_handler, :abort_handler

      # Handler for next event (accept button is used)
      #
      # @note A confirmation popup is shown and it finishes the dialog if all
      #   changes were correctly applied.
      def next_handler
        return unless confirm_changes?

        self.success = save

        if !success && continue_editing?
          self.finish = false
          refresh
        else
          self.finish = true
        end
      end

      # Handler for apply event (apply button is used)
      #
      # @note A confirmation popup is shown and it does not finish the dialog when
      #   all changes were correctly applied.
      def apply_handler
        return unless confirm_changes?

        self.success = save

        if success || continue_editing?
          self.finish = false
          refresh
        else
          self.finish = true
        end
      end

      # Handler when a new service is selected on the table
      #
      # @note It refreshes the buttons according to the new selected service.
      def services_table_handler
        self.finish = false

        if @prev_service != selected_service_name
          @prev_service = selected_service_name
          refresh_service_buttons
        end
      end

      # Handler when a system target is selected
      def target_selector_handler
        self.finish = false

        log.info("Setting new default target '#{target_selector.value}'")
        ServicesManagerTarget.default_target = target_selector.value
        refresh_buttons
      end

      # Handler when a service is started/stopped
      def start_stop_button_handler
        self.finish = false

        service = selected_service_name

        log.info(
          "Setting the service 'service: #{service}' to " \
          "#{ServicesManagerService.active(service) ? 'inactive' : 'active'}"
        )

        ServicesManagerService.switch(service)
        refresh_selected_service
        refresh_buttons
      end

      # Handler when a start mode is selected
      #
      # @note The table row of the selected service is refreshed.
      def start_mode_button_handler(mode)
        self.finish = false

        ServicesManagerService.set_start_mode(selected_service_name, mode)
        refresh_selected_service
        refresh_buttons
      end

      # Handler when "Show Details" button is used
      #
      # @note It opens up a popup with details about the currently selected service
      def show_details_button_handler
        self.finish = false

        service = selected_service_name
        full_info = ServicesManagerService.status(service)
        x_size = full_info.lines.collect{|line| line.size}.sort.last
        y_size = full_info.lines.count

        Popup.LongText(
          format(_("Service %{service} Full Info"), service: service),
          RichText("<pre>#{full_info}</pre>"),
          # counted size plus dialog spacing
          x_size + 8,
          y_size + 6
        )

        services_table.focus
      end

      # Handler when "Show Log" button is used
      #
      # @note Opens a dialog with the logs (since current boot) for the currently selected service
      #
      # @see Yast2::SystemService#keywords
      def logs_button_handler
        query = Y2Journal::Query.new(interval: "0", filters: { "unit" => selected_service.keywords })
        Y2Journal::EntriesDialog.new(query: query).run

        services_table.focus
      end

      # When there are changes, it opens up a confirmation popup with a summary of all changes
      #
      # @return [Boolean]
      def confirm_changes?
        return true unless Yast::ServicesManager.modified?

        message = Yast::ServicesManager.changes_summary + _("Apply all changes?")

        Yast2::Popup.show(message, richtext: true, headline: _("Summary of changes"), buttons: :yes_no) == :yes
      end

      # Opens up a popup to ask the user whether to continue editing
      #
      # This popup is used when there is any problem applying the changes to the services,
      # see {#next_handler} and {#apply_handler}.
      #
      # @return [Boolean] true if user selects to continue editing; false otherwise.
      def continue_editing?
        message = format(
          _("Writing the configuration failed:\n%{errors}\nWould you like to continue editing?"),
          errors: Yast::ServicesManager.errors.join("\n")
        )

        Popup::ContinueCancel(message)
      end

      # Opens up a popup with the help text
      def show_help
        Yast2::Popup.show(help, richtext: true, headline: _("Help"), buttons: :ok)
      end

      # Applies all changes indicated for each service
      #
      # @return [Boolean] true if all changes were correctly applied; false otherwise.
      def save
        return true if Mode.config

        log.info("Writing configuration...")

        Yast2::Feedback.show(_("Writing configuration...")) { Yast::ServicesManager.save }
      end

      # Refreshes the widgets and the buttons of the dialog
      def refresh
        refresh_targets
        refresh_services
        refresh_buttons
      end

      # Refreshes the buttons of the dialog
      #
      # @note The 'Apply' button is disabled when there are no changes to apply.
      def refresh_buttons
        return unless show_apply_button?

        Yast::UI.ChangeWidget(Id(:apply), :Enabled, Yast::ServicesManager.modified?)
      end

      # Refreshes all service buttons according to the selected service
      def refresh_service_buttons
        @start_mode_button = nil
        @start_stop_button = nil
        @show_details_button = nil
        @logs_button = nil

        UI.ReplaceWidget(Id(WidgetsId::SERVICE_BUTTONS), service_buttons)
      end

      # Refreshes the target selector
      def refresh_targets
        ServicesManagerTarget.reset
        target_selector.refresh
      end

      # Reads services and updates the table content
      #
      # It shows a temporary popup meanwhile the services are obtained, see {#read_services}.
      def refresh_services
        services = read_services

        @prev_service = nil
        services_table.refresh(services_names: services)
        refresh_service_buttons
      end

      # Redraws data of the selected service (table row and buttons)
      def refresh_selected_service
        refresh_service_buttons
        services_table.refresh_row(selected_service_name)
      end

      # Read all services, showing a temporary popup meanwhile the services are obtained
      #
      # @return [Array<String>] name of all services
      def read_services
        Yast2::Feedback.show(_("Reading services status...")) do
          ServicesManagerService.reload
          ServicesManagerService.all.keys
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
      # @return [Yast2::SystemService]
      def selected_service
        ServicesManagerService.find(selected_service_name)
      end

      # @return [Integer]
      def display_width
        UI.GetDisplayInfo["Width"] || 80
      end
    end
  end
end
