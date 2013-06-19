# encoding: utf-8

require "ycp"

module YCP
  class SystemdTargetClass < Module
    DEFAULT_TARGET_PATH = '/etc/systemd/system/default.target'
    SYSTEMD_TARGETS_DIR = '/usr/lib/systemd/system'
    TERM_OPTIONS = ' LANG=C TERM=dumb COLUMNS=1024 '
    TARGET_SUFFIX = '.target'
    DEFAULT_TARGET = 'default'

    module Status
      ENABLED  = 'enabled'
      DISABLED = 'disabled'
      SUPPORTED = [ENABLED, DISABLED]
    end

    def initialize
      YCP.import('FileUtils')
      textdomain 'runlevel-ruby'
      set_modified(false)
    end

    def is_modified
      @modified
    end

    def set_modified(modified)
      @modified = modified
    end

    def set_default(target)
      if (current_default != target)
        raise "Unknown target: #{target}" unless self.all.include?(target)

        @default_target = target
        set_modified(true)
      end

      current_default
    end

    def current_default
      read_current if @default_target.nil?
      @default_target
    end

    def save
      return true unless is_modified

      success = (FileUtils.Exists(DEFAULT_TARGET_PATH) ?
        SCR::Execute(path('.target.remove'), DEFAULT_TARGET_PATH) : true
      ) && SCR::Execute(path('.target.symlink'), default_target_path, DEFAULT_TARGET_PATH)

      set_modified(false)

      return success
    end

    def all
      return @all_targets unless @all_targets.nil?

      @all_targets = SCR.Execute(
        path('.target.bash_output'),
        TERM_OPTIONS + 'systemctl list-unit-files --type target --no-legend --no-pager --no-ask-password'
      )["stdout"].each_line.collect {
        |line|
        # Format: target_name#{target_suffix}      status
        target = line.split(/[\s]+/)
        if Status::SUPPORTED.include?(target[1])
          target[0].chomp! TARGET_SUFFIX
          target[0]
        end
      }

      @all_targets.compact!
      @all_targets.delete(DEFAULT_TARGET) if @all_targets.include?(DEFAULT_TARGET)
      @all_targets
    end

  private

    def read_current
      @default_target = File.basename(SCR::Read(path('.target.symlink'), DEFAULT_TARGET_PATH))
      @default_target.chomp! TARGET_SUFFIX
    end

    def default_target_path
      File.join(SYSTEMD_TARGETS_DIR, current_default + TARGET_SUFFIX)
    end

    publish({:function => :all, :type => "list <string>"})
    publish({:function => :save, :type => "boolean"})

    publish({:function => :current_default, :type => "string"})
    publish({:function => :set_default, :type => "boolean"})

    publish({:function => :set_modified, :type => "void"})
    publish({:function => :is_modified, :type => "boolean"})
  end

  SystemdTarget = SystemdTargetClass.new
end
