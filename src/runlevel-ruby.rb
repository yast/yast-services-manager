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
            # English description of the service
            'description' => service_def[4..-1].join(" "),
            'enabled'     => Service::Enabled(service_def[0]),
            'modified'    => false,
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

      def service_enabled!(service, new_status)
        @services[service]['enabled']  = new_status
        @services[service]['modified'] = true
        modified!
      end

      def service_enabled?(service)
        @services[service]['enabled']
      end

      def service_running!(service, new_running)
        @services[service]['active'] = new_running
      end

      def service_running?(service)
        @services[service]['active'] == Status::ACTIVE
      end

      def redraw_services
        UI.OpenDialog(Label(_('Reading services status...')))
        table_items = services.sort.collect{
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
              PushButton(term(:id, :startstop), _('&Start/Stop')),
              HSpacing(1),
              PushButton(term(:id, :enabledisable), _('&Enable/Disable'))
            ))
        )
        caption = _("Services")

        Wizard.SetContentsButtons(caption, contents, "", Label.CancelButton, Label.OKButton)
        Wizard.HideBackButton
        Wizard.SetAbortButton(:abort, Label.CancelButton)

        redraw_services
      end

      def toggle_running
        service = UI.QueryWidget(term(:id, "services"), :CurrentItem)
        Builtins.y2milestone("Toggling service running: %1", service)
        running = service_running?(service)

        success = (running ? Service::Stop(service) : Service::Start(service))

        if success
          service_running!(service, (running ? Status::INACTIVE : Status::ACTIVE))
          UI.ChangeWidget(
            term(:id, "services"),
            term(:Cell, service, 2),
            (service_running?(service) ? _('Active') : _('Inactive'))
          )
        else
          Popup::ErrorDetails(
            (running ? Message::CannotStopService(service) : Message::CannotStartService(service)),
            service_full_info(service)
          )
        end

        UI.SetFocus(term(:id, "services"))
        success
      end

      # Belongs to Service module
      def service_full_info(service)
        SCR.Execute(
          path(".target.bash_output"),
          TERM_OPTIONS + "systemctl status #{service}#{SERVICE_SUFFIX}" + " 2>&1"
        )["stdout"]
      end

      def toggle_enabled
        service = UI.QueryWidget(term(:id, "services"), :CurrentItem)
        Builtins.y2milestone("Toggling service status: %1", service)
        service_enabled!(service, !service_enabled?(service))

        UI.ChangeWidget(
          term(:id, "services"),
          term(:Cell, service, 1),
          (service_enabled?(service) ? _('Enabled') : _('Disabled'))
        )

        UI.SetFocus(term(:id, "services"))
        true
      end

      def save
        return true unless modified?

        UI.OpenDialog(Label(_('Writing configuration...')))

        ret = true
        services.each {
          |service, service_def|
          if service_def['modified']
            unless (service_enabled?(service) ? Service::Enable(service) : Service::Disable(service))
              ret = false

              Popup::ErrorDetails(
                (service_enabled?(service) ?
                  _("Could not enable service #{service}")
                  :
                  _("Could not disable service #{service}")
                ),
                service_full_info(service)
              )
            end
          end
        }

        UI.CloseDialog

        # Writing has failed, user can decide whether to continue or leave
        unless ret
          ret = ! Popup::ContinueCancel(
            _("Writing the configuration have failed.\nWould you like to continue editing?")
          )
        end

        ret
      end

      def main
        textdomain "runlevel-ruby"

        Wizard.CreateDialog
        adjust_dialog

        while true
          returned = UI.UserInput
          Builtins.y2milestone("User returned %1", returned)

          case returned
            when :abort
              break if Popup::ReallyAbort(modified?)
            when :enabledisable
              toggle_enabled
            when :startstop
              toggle_running
            when :next
              break if save
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
