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
        ENABLED = 'enabled'
        DISABLED = 'disabled'
      end

      # Belongs to Service module (after it's converted to Ruby) #

      # Returns hash of all services read using systemctl
      #
      # @return Hash
      # @struct {
      #     'service_name'  => {
      #       'load'        => Reflects whether the unit definition was properly loaded
      #       'active'      => The high-level unit activation state, i.e. generalization of SUB
      #       'description' => English description of the service
      #       'enabled'     => (Boolean) whether the service has been enabled
      #       'modified'    => (Boolean) whether the service (enabled) has been changed
      #     }
      #   }
      def services
        return @services if !@services.nil?

        @services = {}

        SCR.Execute(
          path(".target.bash_output"),
          TERM_OPTIONS + 'systemctl list-unit-files --type service --no-legend --no-pager --no-ask-password'
        )["stdout"].each_line {
          |line|
          service_def = line.split(/[\s]+/)
          # only enabled or disabled services can be handled
          # static and masked are ignored here
          if service_def[1] == Status::ENABLED || service_def[1] == Status::DISABLED
            service_def[0].slice!(-8..-1) if (service_def[0].slice(-8..-1) == SERVICE_SUFFIX)
            @services[service_def[0]] = {
              'enabled'  => (service_def[1] == Status::ENABLED),
              'modified' => false,
            }
          end
        }

        SCR.Execute(
          path(".target.bash_output"),
          TERM_OPTIONS + 'systemctl --all --type service --no-legend --no-pager --no-ask-password'
        )["stdout"].each_line {
          |line|
          service_def = line.split(/[\s]+/)
          service_def[0].slice!(-8..-1) if (service_def[0].slice(-8..-1) == SERVICE_SUFFIX)

          unless @services[service_def[0]].nil?
            @services[service_def[0]]['load']        = service_def[1]
            @services[service_def[0]]['active']      = service_def[2]
            @services[service_def[0]]['description'] = service_def[4..-1].join(" ")
          end
        }
        Builtins.y2debug("All services read: %1", @services)

        @services
      end

      # Belongs to Service module (after it's converted to Ruby) #

      # Returns full information about the service
      #
      # @param String service name
      # @return String full unformatted information
      def service_full_info(service)
        SCR.Execute(
          path(".target.bash_output"),
          TERM_OPTIONS + "systemctl status #{service}#{SERVICE_SUFFIX}" + " 2>&1"
        )["stdout"]
      end

      # Sets that configuration has been modified
      def modified!
        @modified = true
      end

      # Returns whether configuration has been modified
      # @return (Boolean) whether modified
      def modified?
        @modified
      end

      # Enables a given service (in memoery only, use save() later)
      #
      # @param String service name
      # @param Boolean new service status
      def service_enabled!(service, new_status)
        @services[service]['enabled']  = new_status
        @services[service]['modified'] = true
        modified!
      end

      # Returns whether the given service has been enabled
      #
      # @param String service
      # @return Boolean enabled
      def service_enabled?(service)
        @services[service]['enabled']
      end

      # Sets whether service should be running after writing the configuration
      #
      # @param String service name
      # @param Boolean running
      def service_running!(service, new_running)
        @services[service]['active'] = new_running
      end

      # Returns the current setting whether service should be running
      #
      # @param String service name
      # @return Boolean running
      def service_running?(service)
        @services[service]['active'] == Status::ACTIVE
      end

      # Redraws the services dialog
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

      # Fills the dialog contents
      def adjust_dialog
        contents = VBox(
          Table(
            term(:id, "services"),
            term(:header,
              _('Service'),
              _('Enabled'),
              _('Active'),
              _('Description')
            ),
            []),
            Left(HBox(
              PushButton(term(:id, :startstop), _('&Start/Stop')),
              HSpacing(1),
              PushButton(term(:id, :enabledisable), _('&Enable/Disable'))
            ))
        )
        caption = _('Services')

        Wizard.SetContentsButtons(caption, contents, "", Label.CancelButton, Label.OKButton)
        Wizard.HideBackButton
        Wizard.SetAbortButton(:abort, Label.CancelButton)

        redraw_services
      end

      # Toggles (starts/stops) the currently selected service
      #
      # @return Boolean if successful
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

      # Toggles (enable/disable) whether the currently selected service should
      # be enabled or disabled while writing the configuration
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

      # Saves the current configuration
      #
      # @return Boolean if successful
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

      # Main function
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
