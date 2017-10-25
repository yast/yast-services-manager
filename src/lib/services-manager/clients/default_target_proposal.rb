require 'services-manager/ui_elements'

module Yast
  import 'Arch'
  import 'Linuxrc'
  import 'Mode'
  import 'Pkg'
  import 'Popup'
  import 'ProductFeatures'
  import 'ServicesManagerTarget'
  import 'Wizard'

  class TargetProposal < Client

    module Target
      include ServicesManagerTargetClass::BaseTargets

      SUPPORTED = [ GRAPHICAL, MULTIUSER ]
    end

    module Warnings
      attr_reader :warnings

      def detect_warnings selected_target
        if Linuxrc.vnc && selected_target != Target::GRAPHICAL
          warnings << _('VNC needs graphical system to be available')
        end
      end
    end

    def initialize
      textdomain 'services-manager'
    end

    def call args
      function = args.shift.to_s
      #TODO implement behaviour if force_reset parameter provided
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
        'menu_title'      => _("&Default systemd target"),
        'rich_text_title' => _("Default systemd target")
      }
    end

    def write
      Builtins.y2milestone("Not writing yet, will be done in inst_finish")
    end

    class Dialog < Client
      include Warnings
      include UIElements

      attr_accessor :dialog
      attr_reader   :available_targets

      def initialize
        textdomain 'services-manager'
        @warnings = []
        @available_targets = Target::SUPPORTED
      end

      def show
        # create the proposal dialog and get the sequence symbol from block
        sequence = create_dialog { handle_dialog }
        {'workflow_sequence' => sequence}
      end

      private

      def handle_dialog
        case UI.UserInput
        when :next, :ok
          selected_target = UI.QueryWidget(Id(:selected_target), :CurrentButton)
          detect_warnings(selected_target)
          if !warnings.empty?
            return handle_dialog unless Popup.ContinueCancel(warnings.join "\n")
          end
          Builtins.y2milestone "User selected target '#{selected_target}'"
          ServicesManagerTarget.default_target = selected_target
          ServicesManagerTarget.force = true
          :next
        when :cancel
          :cancel
        end
      end

      def generate_target_buttons
        Builtins.y2milestone "Available targets: #{available_targets}"

        radio_buttons = available_targets.map do |target_name|
          selected = target_name == ServicesManagerTarget.default_target
          Left(
            RadioButton(
              Id(target_name),
              ServicesManagerTargetClass::BaseTargets.localize(target_name),
              selected
            )
          )
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
        yield
      ensure
        Wizard.CloseDialog
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

        header + intro + default + multiuser + graphical + recommendation
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
      include UIElements
      include Yast::Logger

      attr_accessor :default_target

      def initialize
        textdomain 'services-manager'
        @warnings = []
        if ServicesManagerTarget.force
          Builtins.y2milestone(
            "Default target has been changed before by user manually to '#{ServicesManagerTarget.default_target}'"
          )
        end

        # While autoyast installation default target will be set by autoyast (file inst_autosetup.rb).
        # (bnc#889055)
        if Mode.autoinst || Mode.autoupgrade
          self.default_target = ServicesManagerTarget.default_target
        else
          change_default_target
        end

        detect_warnings(default_target)
        Builtins.y2milestone("Systemd default target is set to '#{ServicesManagerTarget.default_target}'")
      end

      def create
        proposal = {
          'preformatted_proposal' => list(
            ServicesManagerTargetClass::BaseTargets.localize(default_target)
          )
        }

        return proposal if warnings.empty?

        proposal.update 'warning_level' => :warning
        proposal.update 'warning'       => list(*warnings)
        proposal
      end

      private

      def change_default_target
        self.default_target = ProductFeatures.GetStringFeature('globals', 'default_target').strip
        if default_target.nil? || default_target.empty?
          detect_target
        elsif Target::SUPPORTED.include?(default_target)
          log.info "Using target '#{default_target}' from control file."
        else
          raise "Invalid value in control file for default_target: '#{default_target}'"
        end
        # Check if the user forced a particular target before; if he did and the
        # autodetection recommends a different one now, warn the user about this
        # and keep the default target unchanged.
        if ServicesManagerTarget.force && default_target != ServicesManagerTarget.default_target
          localized_target = ServicesManagerTargetClass::BaseTargets.localize(default_target)
          warnings << _("The installer is recommending you the default target '%s' ") % localized_target
          warnings << ServicesManagerTarget.proposal_reason
          self.default_target = ServicesManagerTarget.default_target
          return
        end
        Builtins.y2milestone("Setting systemd default target to #{default_target}")
        ServicesManagerTarget.default_target = default_target
      end

      def detect_target
        self.default_target =
          if Arch.x11_setup_needed && Pkg.IsSelected("xorg-x11-server")
            give_reason _("X11 packages have been selected for installation")
            Target::GRAPHICAL
          elsif Mode.live_installation
            give_reason _("Live Installation is typically used for full GUI in target system")
            Target::GRAPHICAL
          elsif Linuxrc.serial_console
            give_reason _("Serial connection does typically not support GUI")
            Target::MULTIUSER
          elsif Linuxrc.vnc && Linuxrc.usessh
            if UI.GetDisplayInfo == 'TextMode'
              give_reason _("Text mode installation assumes no GUI on the target system")
              Target::MULTIUSER
            else
              give_reason _("Using VNC assumes a GUI on the target system")
              Target::GRAPHICAL
            end
          elsif Linuxrc.vnc
            give_reason _("Using VNC assumes a GUI on the target system")
            Target::GRAPHICAL
          elsif Linuxrc.usessh
            give_reason _("SSH installation mode assumes no GUI on the target system")
            Target::MULTIUSER
          elsif !(Arch.x11_setup_needed && Pkg.IsSelected("xorg-x11-server"))
            give_reason _("X11 packages have not been selected for installation")
            Target::MULTIUSER
          else
            give_reason _("This recommendation is based on the analysis of other installation settings")
            Target::MULTIUSER
          end

        Builtins.y2milestone("Detected target proposal '#{default_target}'")
      end

      def give_reason message
        ServicesManagerTarget.proposal_reason = message
        Builtins.y2milestone("Systemd target detection says: #{message}")
      end
    end
  end
end

