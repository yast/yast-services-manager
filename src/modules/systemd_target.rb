require "yast"

module Yast
  class SystemdTargetClass < Module
    SYSTEMCTL_DEFAULT_OPTIONS = ' --no-legend --no-pager --no-ask-password '
    TERM_OPTIONS              = ' LANG=C TERM=dumb COLUMNS=1024 '
    TARGET_SUFFIX             = '.target'
    DEFAULT_TARGET            = 'default'
    DEFAULT_TARGET_PATH       = "/etc/systemd/system/#{DEFAULT_TARGET}#{TARGET_SUFFIX}"
    SYSTEMD_TARGETS_DIR       = '/usr/lib/systemd/system'

    module Status
      ENABLED   = 'enabled'
      DISABLED  = 'disabled'
      SUPPORTED = [ENABLED, DISABLED]
      ACTIVE    = 'active'
      LOADED    = 'loaded'
    end

    attr_accessor :modified, :targets

    def initialize
      textdomain 'services-manager'
    end

    def default_target
      return @default_target if @default_target
      @default_target = File.basename(SCR::Read(path('.target.symlink'), DEFAULT_TARGET_PATH).to_s)
      @default_target.chomp! TARGET_SUFFIX
    end

    def default_target= new_default
      raise "Unknown target: #{new_default}" unless all.keys.include?(new_default)
      unless default_target == new_default
        @default_target = new_default
        self.modified = true
      end
      @default_target
    end

    def save params={}
      return true unless (modified || params[:force])
      if File.exists?(default_target_file)
        SCR::Execute(path('.target.remove'), DEFAULT_TARGET_PATH)
        success = !!SCR::Execute(path('.target.symlink'), default_target_file, DEFAULT_TARGET_PATH)
        self.modified = false
      else
        success = false
      end
      success
    end

    private

    def load_targets
      @targets = {}

      SCR.Execute(
        path('.target.bash_output'),
        TERM_OPTIONS                              +
        'systemctl list-unit-files --type target' +
        SYSTEMCTL_DEFAULT_OPTIONS
      )["stdout"].each_line do |line|
        target = line.split(/[\s]+/)
        if Status::SUPPORTED.include?(target[1])
          target[0].chomp!(TARGET_SUFFIX)
          next if (target[0] == DEFAULT_TARGET)
          @targets[target[0]] = { :enabled  => (target[1] == Status::ENABLED) }
        end
      end

      SCR.Execute(
        path('.target.bash_output'),
        TERM_OPTIONS                    +
        'systemctl --all --type target' +
        SYSTEMCTL_DEFAULT_OPTIONS
      )["stdout"].each_line do |line|
        target = line.split(/[\s]+/)
        target[0].chomp! TARGET_SUFFIX
        unless @targets[target[0]].nil?
          @targets[target[0]][:loaded]      = target[1]  == Status::LOADED
          @targets[target[0]][:active]      = (target[2] == Status::ACTIVE)
          @targets[target[0]][:description] = target[4..-1].join(" ")
        end
      end
      Builtins.y2debug('All targets read: %1', @targets)
      @targets
    end

    public

    def all
      targets ? targets : load_targets
    end

    def reset
      @targets        = nil
      @default_target = nil
      self.modified = false
      true
    end

    def export
      default_target
    end

    def import new_target
      if new_target.to_s.empty?
        Builtins.y2error("New default target must not be empty string")
        return nil
      end
      self.default_target = new_target
    end

    def read
      default_target
      load_targets
      true
    end

    private

    def default_target_file
      File.join(SYSTEMD_TARGETS_DIR, "#{default_target}#{TARGET_SUFFIX}")
    end

    publish({:function => :all,             :type => "map <string, map>" })
    publish({:function => :default_target,  :type => "string ()"         })
    publish({:function => :export,          :type => "string ()"         })
    publish({:function => :import,          :type => "string ()"         })
    publish({:function => :modified,        :type => "boolean ()"        })
    publish({:function => :modified=,       :type => "boolean (boolean)" })
    publish({:function => :read,            :type => "boolean ()"        })
    publish({:function => :reset,           :type => "boolean ()"        })
    publish({:function => :save,            :type => "boolean ()"        })
  end

  SystemdTarget = SystemdTargetClass.new
end
