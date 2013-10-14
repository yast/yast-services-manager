module Yast
  import 'Arch'
  import 'Linuxrc'
  import 'Mode'
  import 'Pkg'
  import "Popup"
  import 'ProductFeatures'
  import 'ServicesManager'
  import 'Wizard'

  class TargetProposal < Client
    module Target
      GRAPHICAL = 'graphical'
      MULTIUSER = 'multi-user'
      SUPPORTED = [ GRAPHICAL, MULTIUSER ]
    end

    module Warnings
      attr_reader :warnings

      def detect_warnings selected_target
        @warnings = []
        if Linuxrc.vnc && selected_target != Target::GRAPHICAL
          warnings << _('VNC needs graphical system to be available')
        end
        warnings << _("\nDo you want to proceed?") unless warnings.empty?
      end
    end

    module Elements
      def item text
        "<li>#{text}</li>"
      end

      def list *items
        "<ul>#{items.map { |i| item(i) }}</ul>"
      end

      def para text
        "<p>#{text}</p>"
      end
    end

    def initialize
      textdomain 'services-manager'
      args = WFM.Args
      function = args.shift.to_s
      #TODO implement behaviour if force_reset parameter provided
      force_reset = !!args.shift.to_s
      case function
        when 'MakeProposal' then Proposal.new.create
        when 'AskUser'      then Dialog.new.show
        when 'Description'  then description
        when 'Write'        then write
        else  Builtins.y2error("Unknown function: %1", function)
      end
    end

    def description
      {
        'id'              => 'services-manager',
        'menu_title'      => _("&Default systemd target and services"),
        'rich_text_title' => _("Default systemd target and services")
      }
    end

    def write
      Builtins.y2milestone("Not writing yet, will be done in inst_finish")
    end

    class Dialog < Client
      include Warnings
      include Elements

      attr_accessor :dialog, :available_targets

      def initialize
        textdomain 'services-manager'
        self.available_targets = SystemdTarget.targets.keys.select do |target|
          Target::SUPPORTED.include?(target)
        end
      end

      def show
        create_dialog
        {'workflow_sequence' => show_dialog}
      end

      private

      def show_dialog
        case UI.UserInput
        when :next, :ok
          selected_target = UI.QueryWidget(Id(:selected_target), :CurrentButton).to_s
          Builtins.y2milestone "Target selected by user: #{selected_target}"
          detect_warnings(selected_target)
          if !warnings.empty?
            return show_dialog unless Popup.YesNo(warnings.join)
          end
          Builtins.y2milestone "Setting systemd default target to '#{selected_target}'"
          SystemdTarget.default_target = selected_target unless selected_target.empty?
          Wizard.CloseDialog
          :next
        when :cancel
          :cancel
        end
      end

      def generate_target_buttons
        Builtins.y2milestone "Available targets: #{available_targets}"
        radio_buttons = available_targets.map do |target_name|
          Left(RadioButton(Id(target_name), target_name))
        end
        VBox(*radio_buttons)
      end

      def create_dialog
        caption = _("Set Default Systemd Target")
        Wizard.CreateDialog
        Wizard.SetTitleIcon "yast-runlevel"
        Wizard.SetContentsButtons(
          caption,
          generate_content,
          help,
          Label.BackButton,
          Label.OKButton
        )
        Wizard.SetAbortButton(:cancel, Label.CancelButton)
        Wizard.HideBackButton
      end

      def help
        header = para _("Selecting the Default Systemd Target")

        intro = para _("Systemd is a system and service manager for Linux. " +
         "It consists of units whose job is to activate services and other units.")

        default = para _("Default target unit is activated on boot " +
          "by default. Usually it is a symlink located in path" +
          "/etc/systemd/system/default.target . See more on systemd man page.")

        multiuser = para _("Multi-User target is for setting up a non-graphical " +
          "multi-user system with network suitable for server (similar to runlevel 3).")

        graphical = para _("Graphical target for setting up a graphical login screen " +
          "with network which is typical for workstations (similar to runlevel 5).")

        recommendation = para _("When you are not sure what would be the best option " +
           "for you then go with graphical target.")

        header + intro + multiuser + graphical + recommendation
      end

      def generate_content
        VBox(
          RadioButtonGroup(
            Id(:selected_target),
            Frame(
              _('Available Targets'),
              HSquash(MarginBox(0.5, 0.5, generate_target_buttons))
            )
          )
        )
      end

    end

    class Proposal < Client
      include Warnings
      include Elements

      attr_accessor :default_target

      def initialize
        textdomain 'services-manager'
        self.default_target = ProductFeatures.GetFeature('globals', 'runlevel')
        change_default_target
        detect_warnings(default_target)
      end

      def create
        proposal = { 'preformatted_proposal' => list(default_target) }
        return proposal if warnings.empty?
        proposal.update 'warning_level' => :warning
        proposal.update 'warning'       => list(warnings)
      end

      private

      def change_default_target
        detect_target unless Mode.autoinst
        SystemdTarget.default_target = self.default_target
      end

      def detect_target
        if Arch.x11_setup_needed && Pkg.IsSelected("xorg-x11-server") || Mode.live_installation
          self.default_target = Target::GRAPHICAL
          return
        end

        if Linuxrc.serial_console
          self.default_target = Target::MULTIUSER
        elsif Linuxrc.vnc && Linuxrc.usessh
          self.default_target = UI.GetDisplayInfo == 'TextMode' ? Target::MULTIUSER : Target::GRAPHICAL
        elsif Linuxrc.vnc
          self.default_target = Target::GRAPHICAL
        elsif Linuxrc.usessh
          self.default_target = Target::MULTIUSER
        end
      end

    end
  end

  TargetProposal.new
end
42
