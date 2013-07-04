# encoding: utf-8

require "ycp"

module Yast
  class SystemdTargetClass < Module
    DEFAULT_TARGET_PATH = '/etc/systemd/system/default.target'
    SYSTEMD_TARGETS_DIR = '/usr/lib/systemd/system'
    TERM_OPTIONS = ' LANG=C TERM=dumb COLUMNS=1024 '
    SYSTEMCTL_DEFAULT_OPTIONS = ' --no-legend --no-pager --no-ask-password '
    TARGET_SUFFIX = '.target'
    DEFAULT_TARGET = 'default'

    module Status
      ENABLED  = 'enabled'
      DISABLED = 'disabled'
      SUPPORTED = [ENABLED, DISABLED]

      ACTIVE = 'active'
      INACTIVE = 'inactive'
    end

    def initialize
      Yast.import('FileUtils')
      textdomain 'services-manager'
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
        raise "Unknown target: #{target}" unless self.all.keys.include?(target)

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

      success
    end

    def all
      return @targets if @targets

      @targets = {}

      SCR.Execute(
        path('.target.bash_output'),
        TERM_OPTIONS + 'systemctl list-unit-files --type target' + SYSTEMCTL_DEFAULT_OPTIONS
      )["stdout"].each_line {
        |line|
        # Format: target_name#{target_suffix}      status
        target = line.split(/[\s]+/)
        if Status::SUPPORTED.include?(target[1])
          target[0].chomp! TARGET_SUFFIX
          next if (target[0] == DEFAULT_TARGET)

          @targets[target[0]] = {
            'enabled'  => (target[1] == Status::ENABLED),
          }
        end
      }

      SCR.Execute(
        path('.target.bash_output'),
        TERM_OPTIONS + 'systemctl --all --type target' + SYSTEMCTL_DEFAULT_OPTIONS
      )["stdout"].each_line {
        |line|
        target = line.split(/[\s]+/)
        target[0].chomp! TARGET_SUFFIX

        unless @targets[target[0]].nil?
          @targets[target[0]]['load']        = target[1]
          @targets[target[0]]['active']      = (target[2] == Status::ACTIVE)
          @targets[target[0]]['description'] = target[4..-1].join(" ")
        end
      }

      Builtins.y2debug('All targets read: %1', @targets)
      @targets
    end

    def export
      { DEFAULT_TARGET => current_default }
    end

    def import(data)
      if data[DEFAULT_TARGET].nil?
        Builtins.y2warning("Cannot import, target definition '#{DEFAULT_TARGET}' not present in #{data.inspect}")
        return false
      else
        set_default(data[DEFAULT_TARGET])
      end

      # returns whether succesfully set
      (current_default == data[DEFAULT_TARGET])
    end

  private

    def read_current
      @default_target = File.basename(SCR::Read(path('.target.symlink'), DEFAULT_TARGET_PATH))
      @default_target.chomp! TARGET_SUFFIX
    end

    def default_target_path
      File.join(SYSTEMD_TARGETS_DIR, current_default + TARGET_SUFFIX)
    end

    publish({:function => :all, :type => "map <string, map>"})
    publish({:function => :save, :type => "boolean"})

    publish({:function => :current_default, :type => "string"})
    publish({:function => :set_default, :type => "boolean"})

    publish({:function => :set_modified, :type => "void"})
    publish({:function => :is_modified, :type => "boolean"})
  end

  SystemdTarget = SystemdTargetClass.new
end
