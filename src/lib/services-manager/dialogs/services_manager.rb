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
require "yast2/feedback"
require "services-manager/widgets/base"
require "services-manager/widgets/target_selector"
require "services-manager/widgets/start_stop_button"
require "services-manager/widgets/start_mode_button"
require "services-manager/widgets/show_details_button"
require "services-manager/widgets/services_table"

Yast.import "ServicesManager"
Yast.import "UI"
Yast.import "Wizard"
Yast.import "Label"
Yast.import "Popup"

module Y2ServicesManager
  module Dialogs
    # Main dialog for Services Manager client
    class ServicesManager
      include Yast
      include Yast::Logger
      include Yast::I18n
      include Yast::UIShortcuts

      # @!method success
      #   Indicates whether the dialog was successul, that is, the changes were correctly applied
      #   @return [Boolean]
      attr_reader :success
      alias_method :success?, :success

      def initialize
        textdomain "services-manager"
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
        SERVICES_TABLE      = :services_table
        TARGET_SELECTOR     = :target_selector
      end

      # Shows the dialog
      def show
        dialog = Yast::Wizard.GenericDialog(buttons)
        Yast::Wizard.OpenDialog(dialog)

        Yast::Wizard.SetContents(title, contents, help, true, true)
        refresh_services
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

      # TODO
      # Dialog help
      #
      # @return [String]
      def help
        ""
      end

      # Dialog content
      #
      # @return [Yast::Term]
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
          PushButton(Id(:apply), _("&Apply")),
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
        HBox(
          start_stop_button.widget,
          HSpacing(1),
          start_mode_button.widget,
          HStretch(),
          show_details_button.widget
        )
      end

      # Button for start/stop a service
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

      # Redraw all buttons according to the selected service
      def refresh_service_buttons
        @start_mode_button = nil
        @start_stop_button = nil
        @show_details_button = nil

        UI.ReplaceWidget(Id(WidgetsId::SERVICE_BUTTONS), service_buttons)
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
      # @note It finishes the dialog if all changes were correctly applied.
      def next_handler
        self.success = save

        if !success && continue_editing?
          self.finish = false
          refresh_services
        else
          self.finish = true
        end
      end

      # Handler for apply event (apply button is used)
      #
      # @note It does not finish the dialog when all changes were correctly applied.
      def apply_handler
        self.success = save

        if success || continue_editing?
          self.finish = false
          refresh_services
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
      end

      # Handler when a service is started/stopped
      def start_stop_button_handler
        self.finish = false

        service = selected_service_name

        log.info(
          "Setting the service 'service: #{service}' to " \
          "#{ServicesManagerService.active(service) ? 'inactive' : 'active'}"
        )

        success = ServicesManagerService.switch(service)

        refresh_selected_service if success
      end

      # Handler when a start mode is selected
      #
      # @note The table row of the selected service is refreshed.
      def start_mode_button_handler(mode)
        self.finish = false

        ServicesManagerService.set_start_mode(selected_service_name, mode)
        refresh_selected_service
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

      # Applies all changes indicated for each service
      #
      # @return [Boolean] true if all changes were correctly applied; false otherwise.
      def save
        return true if Mode.config

        log.info("Writing configuration...")

        Yast2::Feedback.show(_("Writing configuration...")) { Yast::ServicesManager.save }
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

      # @return [Integer]
      def display_width
        UI.GetDisplayInfo["Width"] || 80
      end
    end
  end
end