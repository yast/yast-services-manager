module Yast
  class ServicesManagerProposal < Client
    Yast.import 'ServicesManager'
    Yast.import 'Arch'
    Yast.import 'Linuxrc'
    Yast.import 'Mode'
    Yast.import 'Pkg'
    Yast.import 'ProductFeatures'

    extend FastGettext::Translation

    DESCRIPTION = {
      'id'              => 'services-manager',
      'menu_title'      => N_("&Default systemd target and services"),
      'rich_text_title' => N_("Default systemd target and services")
    }

    def initialize
      args = WFM.Args
      function = args.shift.to_s
      case function
        when 'MakeProposal' then Proposal.create
        when 'AskUser'      then ask_user
        when 'Description'  then DESCRIPTION
        when 'Write'        then write
        else Builtins.y2error("Unknown function: %1", function)
      end
    end

    def ask_user
    end

    def write
      Builtins.y2milestone("Not writing yet, will be done in inst_finish")
    end

    class Proposal

      def self.create
        new.proposal
      end

      module Type
        GRAPHICAL = 'graphical'
        MULTIUSER = 'multi-user'
      end

      attr_accessor :default_target
      attr_reader   :warnings, :featured_target

      def initialize
        @warnings = []
        @default_target = ProductFeatures.GetFeature('globals', 'runlevel')
        change_default_target
        update_warnings
      end

      def proposal
        { 'preformatted_proposal' => "<ul><li>#{default_target}</li></ul>" }
      end

      private

      def change_default_target
        detect_target unless Mode.autoinst
        SystemdTarget.default_target = self.default_target
      end

      def detect_target
        if Arch.x11_setup_needed && Pkg.IsSelected("xorg-x11-server") || Mode.live_installation
          self.default_target = Type::GRAPHICAL
          return
        end

        if Linuxrc.serial_console
          self.default_target = Type::MULTIUSER
        elsif Linuxrc.vnc && Linuxrc.usessh
          self.default_target = UI.GetDisplayInfo == 'TextMode' ? Type::MULTIUSER : Type::GRAPHICAL
        elsif Linuxrc.vnc
          self.default_target = Type::GRAPHICAL
        elsif Linuxrc.usessh
          self.default_target = Type::MULTIUSER
        end
      end

      def update_warnings
        if Linuxrc.vnc && default_target != Type::GRAPHICAL
          warnings << _('VNC needs graphical system to be available')
        end
      end

    end
  end

  ServicesManagerProposal.new
end
42
