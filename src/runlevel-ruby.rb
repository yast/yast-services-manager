# encoding: utf-8

module YCP
  module Clients
    class RunlevelRuby < Client
      YCP.import("UI")
      YCP.import("Wizard")
      YCP.import("Service")
      YCP.import("Label")
      YCP.import("Popup")

      TERM_OPTIONS = ' LANG=C TERM=dumb COLUMNS=1024 '
      SERVICE_SUFFIX = '.service'

      @modified = false

      module Status
        ACTIVE = 'active'
        INACTIVE = 'inactive'
      end

      # Belongs to Service module
      def services
        return @services if !@services.nil?

        @services = {}

        SCR.Execute(
          path(".target.bash_output"),
          TERM_OPTIONS + 'systemctl --all --type service --no-legend --no-pager --no-ask-password'
        )["stdout"].each_line {
          |line|
          service_def = line.split(/[\s]+/)
          service_def[0].slice!(-8..-1) if (service_def[0].slice(-8..-1) == SERVICE_SUFFIX)

          @services[service_def[0]] = {
            # Reflects whether the unit definition was properly loaded.
            'load'        => service_def[1],
            # The high-level unit activation state, i.e. generalization of SUB.
            'active'      => service_def[2],
            # The low-level unit activation state, values depend on unit type.
            'sub'         => service_def[3],
            'description' => service_def[4..-1].join(" "),
            'enabled'     => Service::Enabled(service_def[0]),
          }
        }
        Builtins.y2debug("All services read: %1", @services)

        @services
      end

      def modified!
        @modified = true
      end

      def modified?
        @modified
      end

      def redraw_services
        UI.OpenDialog(Label(_('Reading services status...')))
        table_items = self.services.sort.collect{
          |service, service_def|
          term(:item, term(:id, service),
            service,
            service_def['enabled'] ? _('Enabled') : _('Disabled'),
            service_def["active"] == Status::ACTIVE ? _('Active') : _('Inactive'),
            service_def["description"]
          )
        }
        UI.CloseDialog

        UI.ChangeWidget(term(:id, "services"), :Items, table_items)
        UI.SetFocus(term(:id, "services"))
      end

      def adjust_dialog
        contents = VBox(
          Table(
            term(:id, "services"),
            term(:header,
              _("Service"),
              _("Enabled"),
              _("Active"),
              _("Description")
            ),
            []),
            Left(HBox(
              PushButton(term(:id, :startstop), _("Start/Stop")),
              HSpacing(1),
              PushButton(term(:id, :enabledisable), _("Enable/Disable"))
            ))
        )
        caption = _("Services")

        Wizard.SetContentsButtons(caption, contents, "", Label.CancelButton, Label.OKButton)
        Wizard.HideBackButton
        Wizard.SetAbortButton(:abort, Label.CancelButton)

        self.redraw_services
      end

      def toggle_enabled
        service = UI.QueryWidget(term(:id, "services"), :CurrentItem)
        Builtins.y2milestone("Toggling (enabled) service: %1", service)
      end

      def main
        textdomain "runlevel-ruby"

        Wizard.CreateDialog
        self.adjust_dialog

        while true
          returned = UI.UserInput
          Builtins.y2milestone("User returned %1", returned)

          case returned
            when :abort
              break if Popup::ReallyAbort(self.modified?)
            when :enabledisable
              toggle_enabled
            else
              Builtins.y2error("Unknown user input: %1", returned)
          end
        end

        UI.CloseDialog
      end
    end
  end
end

YCP::Clients::RunlevelRuby.new.main
