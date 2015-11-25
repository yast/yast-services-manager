class ServicesManagerClient < Yast::Client
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

  include Yast::Logger

  module Id
    SERVICES_TABLE = :services_table
    TOGGLE_RUNNING = :start_stop
    TOGGLE_ENABLED = :enable_disable
    DEFAULT_TARGET = :default_target
    SHOW_DETAILS   = :show_details
  end

  def main
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
          break if Popup::ReallyAbort(ServicesManager.modified?)
        # Default for double-click in the table
        when Id::TOGGLE_ENABLED, Id::SERVICES_TABLE
          toggle_service
        when Id::TOGGLE_RUNNING
          switch_service
        when Id::DEFAULT_TARGET
          handle_dialog
        when Id::SHOW_DETAILS
          show_details
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
    success = ServicesManager.save
    UI.CloseDialog
    if !success
      success = ! Popup::ContinueCancel(
        _("Writing the configuration failed:\n" +
        ServicesManager.errors.join("\n")            +
        "\nWould you like to continue editing?")
      )
      ServicesManager.reset
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
            max_target_length + 2,
            ComboBox(
              Id(Id::DEFAULT_TARGET),
              Opt(:notify),
              _('Default System &Target'),
              system_targets
            )
          )
        )
      ),
      VSpacing(1),
      Table(
        Id(Id::SERVICES_TABLE),
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
        PushButton(Id(Id::TOGGLE_RUNNING), _('&Start/Stop')),
        HSpacing(1),
        PushButton(Id(Id::TOGGLE_ENABLED), _('&Enable/Disable')),
        HStretch(),
        PushButton(Id(Id::SHOW_DETAILS), _('Show &Details'))
      )
    )
    caption = _('Services Manager')

    Wizard.SetContentsButtons(caption, contents, "", Label.CancelButton, Label.OKButton)
    Wizard.HideBackButton
    Wizard.SetAbortButton(:abort, Label.CancelButton)

    redraw_services
  end

  # Redraws the services dialog
  def redraw_services
    UI.OpenDialog(Label(_('Reading services status...')))
    services = ServicesManagerService.all.collect do |service, attributes|
      Item(Id(service),
        service,
        attributes[:enabled] ? _('Enabled') : _('Disabled'),
        attributes[:active] ? _('Active') : _('Inactive'),
        attributes[:description]
      )
    end
    UI.CloseDialog
    UI.ChangeWidget(Id(Id::SERVICES_TABLE), :Items, services)
    UI.SetFocus(Id(Id::SERVICES_TABLE))
  end

  def redraw_service(service)
    enabled = ServicesManagerService.enabled(service)

    UI.ChangeWidget(
      Id(Id::SERVICES_TABLE),
      Cell(service, 1),
      (enabled ? _('Enabled') : _('Disabled'))
    )

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
  end



  def handle_dialog
    new_default_target = UI.QueryWidget(Id(Id::DEFAULT_TARGET), :Value)
    Builtins.y2milestone("Setting new default target '#{new_default_target}'")
    ServicesManagerTarget.default_target = new_default_target
  end

  # Opens up a popup with details about the currently selected service
  def show_details
    service = UI.QueryWidget(Id(Id::SERVICES_TABLE), :CurrentItem)
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

  # Switches (starts/stops) the currently selected service
  #
  # @return Boolean if successful
  def switch_service
    service = UI.QueryWidget(Id(Id::SERVICES_TABLE), :CurrentItem)
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
    service = UI.QueryWidget(Id(Id::SERVICES_TABLE), :CurrentItem)
    Builtins.y2milestone('Toggling service status: %1', service)
    ServicesManagerService.toggle(service)

    redraw_service(service)
    UI.SetFocus(Id(Id::SERVICES_TABLE))
    true
  end
end

ServicesManagerClient.new.main
