class ServicesManagerProposal < Yast::Client
  Yast.import 'ServicesManager'
  Yast.import 'Arch'
  Yast.import 'Linuxrc'
  Yast.import 'Mode'
  Yast.import 'Pkg'

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
      when 'MakeProposal' then Proposal.new(args)
      when 'AskUser'      then ask_user
      when 'Description'  then DESCRIPTION
      when 'Write'        then write
    end
  end

  def ask_user
  end

  def write
  end

  class Proposal
    module Type
      GRAPHICAL = 'graphical'
      MULTIUSER = 'multi-user'
    end

    def initialize args
      set_default_target
      make_proposal
    end

    private

    #TODO
    # Add warnings to the last 2 setups, add logging
    # Create the proposal widget as in RunlevelEd
    def set_default_target
      if Mode.autoinst
        # Look at the RunlevelProposal, around line 118 where this stops
        # check if vnc is running
        # check if ssh is running
      else
        if Arch.x11_setup_needed && Pkg.IsSelected("xorg-x11") || Mode.live_installation
          default_target = Type::GRAPHICAL
        end
        if Linuxrc.serial_console
          default_target = Type::MULTIUSER
        elsif Linuxrc.vnc && Linuxrc.usessh
          if UI.GetDisplayInfo == 'TextMode'
            default_target = Type::MULTIUSER
          else
            default_target = Type::GRAPHICAL
          end
        elsif Linuxrc.vnc
          default_target = Type::GRAPHICAL
        elsif Linuxrc.usessh
          default_target = Type::MULTIUSER
        end
      end
      Yast::SystemdTarget.default_target = default_target
    end

    def

    def make_proposal
      installation_type =
    end
  end
end

ServicesManagerProposal.new
42
