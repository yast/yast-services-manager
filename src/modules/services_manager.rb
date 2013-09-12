require 'yast'
require 'erb'

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

    module Id
      SERVICES_TABLE = :services_table
      TOGGLE_RUNNING = :start_stop
      TOGGLE_ENABLED = :enable_disable
      DEFAULT_TARGET = :default_target
      SHOW_DETAILS   = :show_details
    end

    TARGET   = 'default_target'
    SERVICES = 'services'

    def initialize
      textdomain 'services-manager'
    end

    def summary
      ERB.new(summary_template).result(binding)
    end

    private

    def summary_template
      <<-summary
<h2><%= _('Services Manager') %></h2>
<p><b><%= _('Default Target') %></b><%= SystemdTarget.export %></p>
<p><b><%= _('Enabled Services') %></b></p>
<ul>
  <% SystemdService.export.each do |service| %>
    <li><%= service %></li>
  <% end %>
</ul>
      summary
    end

    public

    def export
      {
        TARGET   => SystemdTarget.export,
        SERVICES => SystemdService.export
      }
    end

    def import(data)
      SystemdTarget.import  data[TARGET]
      SystemdService.import data[SERVICES]
    end

    def reset
      SystemdTarget.reset
      SystemdService.reset
    end

    def read
      SystemdTarget.read
      SystemdService.read
    end

    # Redraws the services dialog
    def redraw_services
      UI.OpenDialog(Label(_('Reading services status...')))
      services = SystemdService.all.collect do |service, attributes|
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
      enabled = SystemdService.enabled?(service)

      UI.ChangeWidget(
        Id(Id::SERVICES_TABLE),
        Cell(service, 1),
        (enabled ? _('Enabled') : _('Disabled'))
      )

      running = SystemdService.active?(service)

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
          (running ? _('Active (will stop)') : _('Inactive (will start)'))
        )
      end
    end

    def redraw_system_targets
      targets = SystemdTarget.all.collect do |target, target_def|
        label = target_def[:description] || target
        Item(Id(target), label, (target == SystemdTarget.default_target))
      end
      UI.ChangeWidget(Id(Id::DEFAULT_TARGET), :Items, targets)
    end

    # Fills the dialog contents
    def adjust_dialog
      contents = VBox(
        Left(ComboBox(
          Id(Id::DEFAULT_TARGET),
          Opt(:notify),
          _('Default System &Target'),
          []
        )),
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
      redraw_system_targets
    end

    # Toggles (starts/stops) the currently selected service
    #
    # @return Boolean if successful
    def toggle_running
      service = UI.QueryWidget(Id(Id::SERVICES_TABLE), :CurrentItem)
      Builtins.y2milestone('Toggling service running: %1', service)
      running = SystemdService.active?(service)

      success = (running ? Service.Stop(service) : Service.Start(service))

      if success
        SystemdService.switch(service)
        redraw_service(service)
      else
        Popup::ErrorDetails(
          (running ? Message::CannotStopService(service) : Message::CannotStartService(service)),
          SystemdService.status(service)
        )
      end

      UI.SetFocus(Id(Id::SERVICES_TABLE))
      success
    end

    # Toggles (enable/disable) whether the currently selected service should
    # be enabled or disabled while writing the configuration
    def toggle_enabled
      service = UI.QueryWidget(Id(Id::SERVICES_TABLE), :CurrentItem)
      Builtins.y2milestone('Toggling service status: %1', service)
      SystemdService.toggle(service)

      redraw_service(service)
      UI.SetFocus(Id(Id::SERVICES_TABLE))
      true
    end

    # Opens up a popup with details about the currently selected service
    def show_details
      service = UI.QueryWidget(Id(Id::SERVICES_TABLE), :CurrentItem)
      full_info = SystemdService.status(service)
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

    def handle_dialog
      new_default_target = UI.QueryWidget(Id(Id::DEFAULT_TARGET), :Value)
      Builtins.y2milestone("Setting new default target #{new_default_target}")
      SystemdTarget.default_target = new_default_target
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
      SystemdTarget.modified || SystemdService.modified
    end

    # Main dialog function
    #
    # @return :next or :abort
    def main_dialog
      ServicesManager.read
      adjust_dialog

      while true
        returned = UI.UserInput
        Builtins.y2milestone('User returned %1', returned)

        case returned
          when :abort
            break if Popup::ReallyAbort(modified?)
          # Default for double-click in the table
          when Id::TOGGLE_ENABLED, Id::SERVICES_TABLE
            toggle_enabled
          when Id::TOGGLE_RUNNING
            toggle_running
          when Id::DEFAULT_TARGET
            handle_dialog
          when Id::SHOW_DETAILS
            show_details
          when :next
            break
          else
            Builtins.y2error('Unknown user input: %1', returned)
        end
      end

      returned
    end

    publish({:function => :export,      :type => "map <string, any> ()"          })
    publish({:function => :import,      :type => "boolean ()"                    })
    publish({:function => :main_dialog, :type => "symbol ()"                     })
    publish({:function => :modified?,   :type => "boolean ()"                    })
    publish({:function => :modify!,     :type => "void ()"                       })
    publish({:function => :read,        :type => "void ()"                       })
    publish({:function => :save,        :type => "map <string, string> (boolean)"})
    publish({:function => :summary,     :type => "string ()"                     })

  end

  ServicesManager = ServicesManagerClass.new
end
