# encoding: utf-8

module YCP
  module Clients
    class RunlevelRuby < Client
      YCP.import("UI")
      YCP.import("Wizard")
      YCP.import("Service")
      YCP.import("Label")
      YCP.import("Popup")
      YCP.import("Report")
      YCP.import("Message")
      YCP.import("SystemdTarget")
      YCP.import("ServiceV2")

      module IDs
        SERVICES_TABLE = :services_table
        TOGGLE_RUNNING = :start_stop
        TOGGLE_ENABLED = :enable_disable
        DEFAULT_TARGET = :default_target
      end

      # Redraws the services dialog
      def redraw_services
        UI.OpenDialog(Label(_('Reading services status...')))

        table_items = ServiceV2.all.collect {
          |service, service_def|
          term(:item, term(:id, service),
            service,
            service_def['enabled'] ? _('Enabled') : _('Disabled'),
            service_def['active'] ? _('Active') : _('Inactive'),
            service_def['description']
          )
        }
        UI.CloseDialog

        UI.ChangeWidget(term(:id, IDs::SERVICES_TABLE), :Items, table_items)
        UI.SetFocus(term(:id, IDs::SERVICES_TABLE))
      end

      def redraw_service(service)
        enabled = ServiceV2.is_enabled(service)

        UI.ChangeWidget(
          term(:id, IDs::SERVICES_TABLE),
          term(:Cell, service, 1),
          (enabled ? _('Enabled') : _('Disabled'))
        )

        running = ServiceV2.is_running(service)

        # The current state matches the futural state
        if (enabled == running)
          UI.ChangeWidget(
            term(:id, IDs::SERVICES_TABLE),
            term(:Cell, service, 2),
            (running ? _('Active') : _('Inactive'))
          )
        # The current state differs the the futural state
        else
          UI.ChangeWidget(
            term(:id, IDs::SERVICES_TABLE),
            term(:Cell, service, 2),
            (running ? _('Active (will stop)') : _('Inactive (will start)'))
          )
        end
      end

      def redraw_system_targets
        UI.ChangeWidget(term(:id, IDs::DEFAULT_TARGET), :Items, SystemdTarget.all)
        UI.ChangeWidget(term(:id, IDs::DEFAULT_TARGET), :Value, SystemdTarget.current_default)
      end

      # Fills the dialog contents
      def adjust_dialog
        contents = VBox(
          Left(ComboBox(
            term(:id, IDs::DEFAULT_TARGET),
            term(:opt, :notify),
            _('Default System &Target'),
            []
          )),
          VSpacing(1),
          Table(
            term(:id, IDs::SERVICES_TABLE),
            term(:header,
              _('Service'),
              _('Enabled'),
              _('Active'),
              _('Description')
            ),
            []),
            Left(HBox(
              PushButton(term(:id, IDs::TOGGLE_RUNNING), _('&Start/Stop')),
              HSpacing(1),
              PushButton(term(:id, IDs::TOGGLE_ENABLED), _('&Enable/Disable'))
            ))
        )
        caption = _('Services Manager')

        Wizard.SetContentsButtons(caption, contents, "", Label.CancelButton, Label.OKButton)
        Wizard.HideBackButton
        Wizard.SetAbortButton(:abort, Label.CancelButton)

        redraw_services
        redraw_system_targets
      end

      # Toggles (starts/stops) the currently selected service
      #
      # @return Boolean if successful
      def toggle_running
        service = UI.QueryWidget(term(:id, IDs::SERVICES_TABLE), :CurrentItem)
        Builtins.y2milestone('Toggling service running: %1', service)
        running = ServiceV2.is_running(service)

        success = (running ? Service::Stop(service) : Service::Start(service))

        if success
          ServiceV2.set_running(service, (! running))
          redraw_service(service)
        else
          Popup::ErrorDetails(
            (running ? Message::CannotStopService(service) : Message::CannotStartService(service)),
            ServiceV2.full_info(service)
          )
        end

        UI.SetFocus(term(:id, IDs::SERVICES_TABLE))
        success
      end

      # Toggles (enable/disable) whether the currently selected service should
      # be enabled or disabled while writing the configuration
      def toggle_enabled
        service = UI.QueryWidget(term(:id, IDs::SERVICES_TABLE), :CurrentItem)
        Builtins.y2milestone('Toggling service status: %1', service)
        ServiceV2.set_enabled(service, ! ServiceV2.is_enabled(service))

        redraw_service(service)
        UI.SetFocus(term(:id, IDs::SERVICES_TABLE))
        true
      end

      def handle_dialog
        new_default_target = UI.QueryWidget(term(:id, IDs::DEFAULT_TARGET), :Value)
        Builtins.y2milestone("Setting new default target #{new_default_target}")
        SystemdTarget.set_default(new_default_target)
      end

      # Saves the current configuration
      #
      # @return Boolean if successful
      def save
        Builtins.y2milestone('Writing configuration')
        UI.OpenDialog(Label(_('Writing configuration...')))

        ret = SystemdTarget.save && ServiceV2.save
        # TODO: report errors

        UI.CloseDialog

        # Writing has failed, user can decide whether to continue or leave
        unless ret
          ret = ! Popup::ContinueCancel(
            _("Writing the configuration have failed.\nWould you like to continue editing?")
          )
        end

        ret
      end

      # Are there any unsaved changes?
      def modified?
        SystemdTarget.modified || ServiceV2.modified
      end

      # Main function
      def main
        textdomain "runlevel-ruby"

        Wizard.CreateDialog
        adjust_dialog

        while true
          returned = UI.UserInput
          Builtins.y2milestone('User returned %1', returned)

          case returned
            when :abort
              break if Popup::ReallyAbort(modified?)
            when IDs::TOGGLE_ENABLED
              toggle_enabled
            when IDs::TOGGLE_RUNNING
              toggle_running
            when IDs::DEFAULT_TARGET
              handle_dialog
            when :next
              break if save
            else
              Builtins.y2error('Unknown user input: %1', returned)
          end
        end

        UI.CloseDialog
      end
    end
  end
end

YCP::Clients::RunlevelRuby.new.main
