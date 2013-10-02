module Yast
  class ServicesManagerProposal < Client
    Yast.import 'Arch'
    Yast.import 'Linuxrc'
    Yast.import 'Mode'
    Yast.import 'Pkg'
    Yast.import 'ProductFeatures'
    Yast.import 'ServicesManager'
    Yast.import 'Wizard'

    extend FastGettext::Translation

    DESCRIPTION = {
      'id'              => 'services-manager',
      'menu_title'      => N_("&Default systemd target and services"),
      'rich_text_title' => N_("Default systemd target and services")
    }

    module Target
      GRAPHICAL = 'graphical'
      MULTIUSER = 'multi-user'
      RESCUE    = 'rescue'
    end

    def initialize
      args = WFM.Args
      function = args.shift.to_s
      case function
        when 'MakeProposal' then Proposal.create
        when 'AskUser'      then Dialog.show
        when 'Description'  then DESCRIPTION
        when 'Write'        then write
        else  unknown_function
      end
    end

    def unknown_function
      Builtins.y2error("Unknown function: %1", function)
    end

    def write
      Builtins.y2milestone("Not writing yet, will be done in inst_finish")
    end

    class Dialog
      def self.show
        new.show
      end

      attr_reader   :original_target, :available_targets
      attr_accessor :dialog

      def initialize
        @original_target = SystemdTarget.default_target
        @available_targets = SystemdTarget.targets.keys.sort
      end

      def show
        create_dialog
        show_dialog
      end

      private

      def show_dialog
        while true do
          case UI.UserInput
          when :next, :ok
            UI.QueryWidget(Id(:selected_target), :CurrentButton)
          when :cancel
            break
          end
        end
        result = :ok
        { 'workflow_sequence' => result }
      end

      def generate_target_buttons
        available_targets.inject(VBox()) do |vbox, target_name|
          vbox.params << Left(RadioButton(Id(target_name), target_name))
        end
      end

      def create_dialog
        caption = _("Set Default Systemd Target")
        Wizard.CreateDialog
        Wizard.SetTitleIcon "yast-services-manager"
        Wizard.SetContentsButtons(
          caption, generate_target_buttons, help, Label.BackButton, Label.OkButton
        )
        Wizard.SetAbortButton :cancel, Label.CancelButton
        Wizard.HideBackButton
      end

      def help
      end

      def generate_content
        VBox(RadioButtonGroup(Id(:selected_target),Frame(_('Available Targets'),
          HSquash(MarginBox(0.5, 0.5, generate_target_buttons))))
      end

    end

    class Proposal
      def self.create
        new.proposal
      end

      attr_accessor :default_target
      attr_reader   :warnings

      def initialize
        @warnings = []
        @default_target = ProductFeatures.GetFeature('globals', 'runlevel')
        change_default_target
        update_warnings
      end

      def proposal
        proposal = { 'preformatted_proposal' => list(default_target) }
        return proposal if warnings.empty?
        proposal.update 'warning_level' => :warning
        proposal.update 'warning'       => list(warnings)
      end

      private

      def item text
        "<li>#{text}</li>"
      end

      def list *items
        "<ul>#{items.map { |i| item(i) }}</ul>"
      end

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

      def update_warnings
        if Linuxrc.vnc && default_target != Target::GRAPHICAL
          warnings << _('VNC needs graphical system to be available')
        end
      end

    end
  end

  ServicesManagerProposal.new
end
# TODO
# How to set the default target after detection has not been successful and target is nil?
# Is this still usefule and where is it being set? ProductFeatures.GetFeature('globals', 'runlevel')
42
