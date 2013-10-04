module Yast
  class TargetProposal < Client
    Yast.import 'Arch'
    Yast.import 'Linuxrc'
    Yast.import 'Mode'
    Yast.import 'Pkg'
    Yast.import "Popup"
    Yast.import 'ProductFeatures'
    Yast.import 'ServicesManager'
    Yast.import 'Wizard'

    extend FastGettext::Translation

    textdomain 'services-manager'

    DESCRIPTION = {
      'id'              => 'services-manager',
      'menu_title'      => N_("&Default systemd target and services"),
      'rich_text_title' => N_("Default systemd target and services")
    }

    module Target
      GRAPHICAL = 'graphical'
      MULTIUSER = 'multi-user'
      SUPPORTED = [ GRAPHICAL, MULTIUSER ]
    end

    module Warnings
      attr_accessor :warnings

      def inspect_warnings selected_target
        self.warnings = []
        if Linuxrc.vnc && selected_target != Target::GRAPHICAL
          warnings << _('VNC needs graphical system to be available')
        end
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
        "<p>" + _(text) + "</p>"
      end
    end

    def initialize
      args = WFM.Args
      function = args.shift.to_s
      case function
        when 'MakeProposal' then Proposal.new.create
        when 'AskUser'      then Dialog.new.show
        when 'Description'  then DESCRIPTION
        when 'Write'        then write
        else  Builtins.y2error("Unknown function: %1", function)
      end
    end

    def write
      Builtins.y2milestone("Not writing yet, will be done in inst_finish")
    end

    class Dialog < Client
      include Warnings
      include Elements

      textdomain 'services-manager'

      attr_accessor :dialog, :available_targets

      def initialize
        self.available_targets = SystemdTarget.targets.keys.reject do |target|
          !Target::SUPPORTED.include?(target)
        end
      end

      def show
        create_dialog
        {'workflow_sequence' => show_dialog}
      end

      private

      def show_dialog
        while true do
          case UI.UserInput
          when :next, :ok
            selected_target = UI.QueryWidget(Id(:selected_target), :CurrentButton).to_s
            Builtins.y2milestone "Target selected by user: #{selected_target}"
            inspect_warnings(selected_target)
            if !warnings.empty?
              next unless Popup.YesNo(warnings.join)
            end
            SystemdTarget.default_target = selected_target unless selected_target.empty?
            Wizard.CloseDialog
            break :next
          when :cancel
            break :cancel
          end
        end
      end

      def generate_target_buttons
        available_targets.inject(VBox()) do |vbox, target_name|
          vbox.params << Left(RadioButton(Id(target_name), target_name))
          vbox
        end
      end

      def create_dialog
        caption = _("Set Default Systemd Target")
        Wizard.CreateDialog
        Wizard.SetTitleIcon "yast-services-manager"
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
        header = para "Selecting the Default Systemd Target"

        intro = para "Systemd is a system and service manager for Linux. " +
         "It consists of units whose job is to activate services and other units."

        default = para "Default target unit is activated on boot " +
          "by default. Usually it is a symlink located in path" +
          "/etc/systemd/system/default.target . See more on systemd man page."

      # FIXME is rescue target needed for installation proposal?
      # rescuee = para "Rescue target is a special target unit for setting up " +
      #   "the base system and a rescue shell (similar to runlevel 1)"

        multiuser = para "Multi-User target is for setting up a non-graphical " +
          "multi-user system with network suitable for server (similar to runlevel 3)."

        graphical = para "Graphical target for setting up a graphical login screen " +
          "with network which is typical for workstations (similar to runlevel 5)."

        recommendation = para "When you are not sure what would be the best option " +
           "for you then go with graphical target."

        header + intro + multiuser + graphical + recommendation
      end

      def generate_content
        VBox(RadioButtonGroup(Id(:selected_target), Frame(_('Available Targets'),
          HSquash(MarginBox(0.5, 0.5, generate_target_buttons)))))
      end

    end

    class Proposal < Client
      include Warnings
      include Elements

      textdomain 'services-manager'

      attr_accessor :default_target

      def initialize
        self.default_target = ProductFeatures.GetFeature('globals', 'runlevel')
        change_default_target
        inspect_warnings(default_target)
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

  ServicesManagerProposal.new
end
42
