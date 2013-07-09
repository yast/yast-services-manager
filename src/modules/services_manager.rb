# encoding: utf-8

require "ycp"

module Yast
  class ServicesManagerClass < Module
    Yast.import("UI")
    Yast.import("Wizard")
    Yast.import("Service")
    Yast.import("Label")
    Yast.import("Popup")
    Yast.import("Report")
    Yast.import("Message")
    Yast.import("SystemdTarget")
    Yast.import("SystemdService")

    module IDs
      SERVICES_TABLE = :services_table
      TOGGLE_RUNNING = :start_stop
      TOGGLE_ENABLED = :enable_disable
      DEFAULT_TARGET = :default_target
      SHOW_DETAILS   = :show_details
    end

    def initialize
      textdomain 'services-manager'
    end

    def summary
      list_of_services = SystemdService.export.collect do |service|
        '<li>' + service + '</li>'
      end

      '<h2>' + _('Services Manager') + '</h2>' +
        _('<p><b>Default Target:</b> %{default}</p>') % {:default => SystemdTarget.current_default} +
        _('<p><b>Enabled Services:</b><ul>%{services}</ul></p>') % {:services => list_of_services.join}
    end

    # Redraws the services dialog
    def redraw_services
      UI.OpenDialog(Label(_('Reading services status...')))

      table_items = SystemdService.all.collect {
        |service, service_def|
        Item(Id(service),
          service,
          service_def['enabled'] ? _('Enabled') : _('Disabled'),
          service_def['active'] ? _('Active') : _('Inactive'),
          service_def['description']
        )
      }
      UI.CloseDialog

      UI.ChangeWidget(Id(IDs::SERVICES_TABLE), :Items, table_items)
      UI.SetFocus(Id(IDs::SERVICES_TABLE))
    end

    def redraw_service(service)
      enabled = SystemdService.is_enabled(service)

      UI.ChangeWidget(
        Id(IDs::SERVICES_TABLE),
        Cell(service, 1),
        (enabled ? _('Enabled') : _('Disabled'))
      )

      running = SystemdService.is_running(service)

      # The current state matches the futural state
      if (enabled == running)
        UI.ChangeWidget(
          Id(IDs::SERVICES_TABLE),
          Cell(service, 2),
          (running ? _('Active') : _('Inactive'))
        )
      # The current state differs the the futural state
      else
        UI.ChangeWidget(
          Id(IDs::SERVICES_TABLE),
          Cell(service, 2),
          (running ? _('Active (will stop)') : _('Inactive (will start)'))
        )
      end
    end

    def redraw_system_targets
      items = SystemdTarget.all.collect {
        |target, target_def|
        label = target_def['description'] || target
        Item(Id(target), label, (target == SystemdTarget.current_default))
      }

      UI.ChangeWidget(Id(IDs::DEFAULT_TARGET), :Items, items)
    end

    # Fills the dialog contents
    def adjust_dialog
      contents = VBox(
        Left(ComboBox(
          Id(IDs::DEFAULT_TARGET),
          Opt(:notify),
          _('Default System &Target'),
          []
        )),
        VSpacing(1),
        Table(
          Id(IDs::SERVICES_TABLE),
          Opt(:notify),
          Header(
            _('Service'),
            _('Enabled'),
            _('Active'),
            _('Description')
          ),
          []
        ),
        HBox(
          PushButton(Id(IDs::TOGGLE_RUNNING), _('&Start/Stop')),
          HSpacing(1),
          PushButton(Id(IDs::TOGGLE_ENABLED), _('&Enable/Disable')),
          HStretch(),
          PushButton(Id(IDs::SHOW_DETAILS), _('Show &Details'))
        )
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
      service = UI.QueryWidget(Id(IDs::SERVICES_TABLE), :CurrentItem)
      Builtins.y2milestone('Toggling service running: %1', service)
      running = SystemdService.is_running(service)

      success = (running ? Service::Stop(service) : Service::Start(service))

      if success
        SystemdService.set_running(service, (! running))
        redraw_service(service)
      else
        Popup::ErrorDetails(
          (running ? Message::CannotStopService(service) : Message::CannotStartService(service)),
          SystemdService.full_info(service)
        )
      end

      UI.SetFocus(Id(IDs::SERVICES_TABLE))
      success
    end

    # Toggles (enable/disable) whether the currently selected service should
    # be enabled or disabled while writing the configuration
    def toggle_enabled
      service = UI.QueryWidget(Id(IDs::SERVICES_TABLE), :CurrentItem)
      Builtins.y2milestone('Toggling service status: %1', service)
      SystemdService.set_enabled(service, ! SystemdService.is_enabled(service))

      redraw_service(service)
      UI.SetFocus(Id(IDs::SERVICES_TABLE))
      true
    end

    # Opens up a popup with details about the currently selected service
    def show_details
      service = UI.QueryWidget(Id(IDs::SERVICES_TABLE), :CurrentItem)
      full_info = SystemdService.full_info(service)
      x_size = full_info.lines.collect{|line| line.size}.sort.last
      y_size = full_info.lines.count

      Popup.LongText(
        _('Service %{service} Full Info') % {:service => service},
        RichText("<pre>#{full_info}</pre>"),
        # counted size plus dialog spacing
        x_size + 8, y_size + 6
      )

      UI.SetFocus(Id(IDs::SERVICES_TABLE))
      true
    end

    def handle_dialog
      new_default_target = UI.QueryWidget(Id(IDs::DEFAULT_TARGET), :Value)
      Builtins.y2milestone("Setting new default target #{new_default_target}")
      SystemdTarget.set_default(new_default_target)
    end

    # Saves the current configuration
    #
    # @return Boolean if successful
    def save(params = {})
      Builtins.y2milestone('Writing configuration')
      UI.OpenDialog(Label(_('Writing configuration...')))

      ret = SystemdTarget.save(params) && SystemdService.save(params)
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
      SystemdTarget.is_modified || SystemdService.is_modified
    end

    # Main dialog function
    #
    # @return :next or :abort
    def main_dialog
      adjust_dialog

      while true
        returned = UI.UserInput
        Builtins.y2milestone('User returned %1', returned)

        case returned
          when :abort
            break if Popup::ReallyAbort(modified?)
          # Default for double-click in the table
          when IDs::TOGGLE_ENABLED, IDs::SERVICES_TABLE
            toggle_enabled
          when IDs::TOGGLE_RUNNING
            toggle_running
          when IDs::DEFAULT_TARGET
            handle_dialog
          when IDs::SHOW_DETAILS
            show_details
          when :next
            break
          else
            Builtins.y2error('Unknown user input: %1', returned)
        end
      end

      returned
    end

    publish({:function => :main_dialog, :type => "symbol"})
    publish({:function => :save, :type => "boolean"})
    publish({:function => :summary, :type => "string"})
    publish({:function => :modified?, :type => "boolean"})

  end

  ServicesManager = ServicesManagerClass.new
end
