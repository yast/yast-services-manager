require "yast"

module Yast
  import 'Mode'
  import 'SystemdTarget'

  class ServicesManagerTargetClass < Module
    include Yast::Logger

    module BaseTargets
      GRAPHICAL = 'graphical'
      MULTIUSER = 'multi-user'
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

    # @return [Boolean] True if properties of the ServicesManagerTarget has been modified
    attr_accessor :modified

    # Used during installation workflow
    # @return [Boolean] Used by client default_target_proposal to override the default settings
    attr_accessor :force

    # Shown in client default_target_proposal during installation workflow
    # @return [String] Shows a reason why the default target has been selected;
    attr_accessor :proposal_reason

    # @return [String] Name of the default systemd target unit
    attr_reader :default_target

    # @return [Hash] Collection of available targets
    # @example {'rescue' => {:enabled=>false, :loaded=>true, :active=>false, :description=>'Rescue'}}
    attr_reader :targets

    alias_method :all, :targets

    def initialize
      textdomain 'services-manager'
      @targets = {}
      @modified = false
      @default_target = ''
      read_targets
    end

    def read_targets
      return unless Mode.normal

      default_target = SystemdTarget.get_default
      @default_target = default_target ? default_target.name : ''

      SystemdTarget.all.each do |target|
        next unless target.allow_isolate?
        next if BLACKLISTED_TARGETS.member?(target.name)

        targets[target.name] = {
          :enabled => target.enabled?,
          :loaded  => target.loaded?,
          :active  => target.active?,
          :description => target.description
        }
      end
    end

    alias_method :read, :read_targets

    def default_target= new_default
      if Mode.normal && !targets.keys.include?(new_default)
        raise "Target #{new_default} not found, available only #{targets.keys.join(', ')}"
      end

      @default_target = new_default
      self.modified = true
      log.info "New default target has been set: #{new_default}"
      new_default
    end

    def export
      default_target
    end

    def import profile
      return false if profile.target.nil? || profile.target.empty?
      self.default_target = profile.target
    end

    def inspect
      "#<#{self} @my_textdomain='#{@my_textdomain}', @default_target='#{default_target}', " +
      "@targets=#{targets.keys} >"
    end

    def save
      return true if !modified
      log.info('Saving default target...')
      SystemdTarget.set_default(default_target)
    end

    def reset
      targets.clear
      read_targets
      self.modified = false
    end

    publish({:function => :all,            :type => "map <string, map> ()" })
    publish({:function => :default_target, :type => "string ()"            })
    publish({:function => :default_target=,:type => "string (string)"      })
    publish({:function => :export,         :type => "string ()"            })
    publish({:function => :import,         :type => "string ()"            })
    publish({:function => :modified,       :type => "boolean ()"           })
    publish({:function => :modified=,      :type => "boolean (boolean)"    })
    publish({:function => :read,           :type => "boolean ()"           })
    publish({:function => :reset,          :type => "boolean ()"           })
    publish({:function => :save,           :type => "boolean ()"           })
  end

  ServicesManagerTarget = ServicesManagerTargetClass.new
end
