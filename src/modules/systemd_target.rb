require "yast"

module Yast
  class SystemdTargetClass < Module
    SYSTEMCTL_DEFAULT_OPTIONS = ' --no-legend --no-pager --no-ask-password '
    TERM_OPTIONS              = ' LANG=C TERM=dumb COLUMNS=1024 '
    TARGET_SUFFIX             = '.target'
    DEFAULT_TARGET            = 'default'
    DEFAULT_TARGET_PATH       = "/etc/systemd/system/#{DEFAULT_TARGET}#{TARGET_SUFFIX}"
    SYSTEMD_TARGETS_DIR       = '/usr/lib/systemd/system'
    LIST_UNITS_COMMAND        = 'systemctl list-unit-files --type target'
    LIST_TARGETS_COMMAND      = 'systemctl --all --type target'

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

    def all
      targets ? targets : load_targets
    end

    def default_target
      return @default_target if @default_target
      @default_target = get_default_target
      @default_target.chomp! TARGET_SUFFIX
    end

    def default_target= new_default
      raise "Unknown target: #{new_default}" unless all.keys.include?(new_default)
      if default_target != new_default
        @default_target = new_default
        self.modified = true
      end
      @default_target
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

    def inspect
      "#<#{self} @my_textdomain='#{@my_textdomain}', @default_target='#{default_target}', " +
      "@targets=#{targets.keys} >"
    end

    def save params={}
      return true unless (modified || params[:force])
      if File.exists?(default_target_file)
        SCR.Execute(path('.target.remove'), DEFAULT_TARGET_PATH)
        success = !!(SCR.Execute(path('.target.symlink'), default_target_file, DEFAULT_TARGET_PATH))
        self.modified = false
      else
        success = false
      end
      success
    end

    def reset
      @targets        = nil
      @default_target = nil
      self.modified = false
      true
    end

    def read
      default_target
      load_supported_targets && load_target_details
    end

    private

    def get_default_target
      File.basename(SCR.Read(path('.target.symlink'), DEFAULT_TARGET_PATH).to_s)
    end

    def default_target_file
      File.join(SYSTEMD_TARGETS_DIR, "#{default_target}#{TARGET_SUFFIX}")
    end

    def list_target_units
      command = TERM_OPTIONS + LIST_UNITS_COMMAND + SYSTEMCTL_DEFAULT_OPTIONS
      SCR.Execute(path('.target.bash_output'), command)
    end

    def list_targets_details
      command = TERM_OPTIONS + LIST_TARGETS_COMMAND + SYSTEMCTL_DEFAULT_OPTIONS
      SCR.Execute(path('.target.bash_output'), command)
    end

    #TODO
    # Check for stderr and exit code
    def load_supported_targets
      self.targets = {}
      output  = list_target_units
      stdout  = output.fetch 'stdout'
      stderr  = output.fetch 'stderr'
      exit_code = output.fetch 'exit'
      stdout.each_line do |line|
        target, status = line.split(/[\s]+/)
        if Status::SUPPORTED.include?(status)
          target.chomp! TARGET_SUFFIX
          next if target == DEFAULT_TARGET
          self.targets[target] = { :enabled  => status == Status::ENABLED }
        end
      end
      Builtins.y2milestone "Loaded supported targets: %1", targets.keys
      stderr.empty? && exit_code == 0
    end

    #TODO
    # Check for stderr and exit code
    def load_target_details
      output  = list_targets_details
      stdout  = output.fetch 'stdout'
      stderr  = output.fetch 'stderr'
      exit_code = output.fetch 'exit'
      stdout.each_line do |line|
        target, loaded, active, _, *description = line.split(/[\s]+/)
        target.chomp! TARGET_SUFFIX
        if targets[target]
          targets[target][:loaded] = loaded == Status::LOADED
          targets[target][:active] = active == Status::ACTIVE
          targets[target][:description] = description.join(' ')
        end
      end
      Builtins.y2milestone 'All targets loaded: %1', targets
      stderr.empty? && exit_code == 0
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
