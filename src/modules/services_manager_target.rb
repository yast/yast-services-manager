require "yast"
require "yast2/systemd/target"

module Yast
  import 'Stage'

  class ServicesManagerTargetClass < Module
    include Yast::Logger

    module BaseTargets
      extend Yast::I18n

      textdomain 'services-manager'

      GRAPHICAL = 'graphical'
      MULTIUSER = 'multi-user'

      TRANSLATIONS = {
        # Default systemd target (previously: runlevel 5) option #1
        GRAPHICAL => N_("Graphical mode"),
        # Default systemd target (previously: runlevel 3) option #2
        MULTIUSER => N_("Text mode"),

        # Systemd targets, bnc#892366
        'emergency.target'          => N_("Emergency Mode"),
        'graphical.target'          => N_("Graphical Interface"),
        'initrd.target'             => N_("Initrd Default Target"),
        'initrd-switch-root.target' => N_("Switch Root"),
        'multi-user.target'         => N_("Multi-User System"),
        'rescue.target'             => N_("Rescue Mode"),
      }

      def self.localize(target_name)
        _(TRANSLATIONS[target_name] || target_name)
      end
    end

    # The targets listed below should not be displayed to the users in the drop down
    # menu on the services-manager UI.
    # More info at:
    # * https://bugzilla.novell.com/show_bug.cgi?id=869656
    # * http://www.freedesktop.org/software/systemd/man/bootup.html
    # * http://www.freedesktop.org/wiki/Software/systemd/SystemUpdates/
    BLACKLISTED_TARGETS = %w(
      halt
      kexec
      poweroff
      reboot
      system-update
    )

    # Used during installation workflow
    # @return [Boolean] Used by client default_target_proposal to override the default settings
    attr_accessor :force

    # Shown in client default_target_proposal during installation workflow
    # @return [String] Shows a reason why the default target has been selected;
    attr_accessor :proposal_reason

    def initialize
      textdomain 'services-manager'
    end

    # @return [Hash] Collection of available targets
    # @example {'rescue' => {:enabled=>false, :loaded=>true, :active=>false, :description=>'Rescue'}}
    def targets
      read if @targets.nil?
      @targets
    end

    # @return [String] Name of the default systemd target unit
    def default_target
      read if @default_target.nil?
      @default_target
    end

    alias_method :all, :targets

    def read
      @targets = {}
      @default_target = ""

      # Reads the data on a running system only
      return true if Stage.initial

      default_target = Yast2::Systemd::Target.get_default
      @initial_default_target = default_target ? default_target.name : ""
      @default_target = @initial_default_target

      Yast2::Systemd::Target.all.each do |target|
        next unless target.allow_isolate?
        next if BLACKLISTED_TARGETS.member?(target.name)

        @targets[target.name] = {
          :enabled => target.enabled?,
          :loaded  => target.loaded?,
          :active  => target.active?,
          :description => BaseTargets.localize("#{target.name}.target")
        }
      end

      !@targets.empty?
    end

    def default_target=(new_default)
      if !Stage.initial && !targets.keys.include?(new_default)
        raise "Target #{new_default} not found, available only #{targets.keys.join(', ')}"
      end

      @default_target = new_default
      log.info "New default target has been set: #{new_default}"
      new_default
    end

    def export
      default_target
    end

    def import profile
      if profile.target.nil? || profile.target.empty?
        # setting default_target due the defined environment
        self.default_target = (Installation.x11_setup_needed &&
          Arch.x11_setup_needed &&
          Pkg.IsSelected("xorg-x11-server")) ? BaseTargets::GRAPHICAL : BaseTargets::MULTIUSER
      else
        self.default_target = profile.target
      end
    end

    def inspect
      "#<#{self} @my_textdomain='#{@my_textdomain}', @default_target='#{default_target}', " +
      "@targets=#{targets.keys} >"
    end

    def save
      return true unless modified?
      log.info('Saving default target...')
      Yast2::Systemd::Target.set_default(default_target)
    end

    def reset
      read
    end

    # Whether the default target has been changed
    #
    # @return [Boolean]
    def modified?
      default_target != initial_default_target
    end

    alias_method :modified, :modified?

    # Summary of changes regarding the default target
    #
    # @return [String]
    def changes_summary
      return "" unless modified?

      target = @targets[default_target][:description]

      format(
        _("Default target will be changed to '%{target}'<br /><br />"),
        target: target
      )
    end

  private

    attr_reader :initial_default_target

    publish({:function => :all,            :type => "map <string, map> ()" })
    publish({:function => :default_target, :type => "string ()"            })
    publish({:function => :default_target=,:type => "string (string)"      })
    publish({:function => :export,         :type => "string ()"            })
    publish({:function => :import,         :type => "string ()"            })
    publish({:function => :modified,       :type => "boolean ()"           })
    publish({:function => :read,           :type => "boolean ()"           })
    publish({:function => :reset,          :type => "boolean ()"           })
    publish({:function => :save,           :type => "boolean ()"           })
  end

  ServicesManagerTarget = ServicesManagerTargetClass.new
end
