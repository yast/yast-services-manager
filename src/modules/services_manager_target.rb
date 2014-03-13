require "yast"

module Yast
  import 'Mode'

  class ServicesManagerTargetClass < Module
    LIST_UNITS_COMMAND   = 'systemctl list-unit-files --type target'
    LIST_TARGETS_COMMAND = 'systemctl --all --type target'
    COMMAND_OPTIONS      = ' --no-legend --no-pager --no-ask-password '
    TERM_OPTIONS         = ' LANG=C TERM=dumb COLUMNS=1024 '
    TARGET_SUFFIX        = '.target'
    DEFAULT_TARGET       = 'default'
    SYSTEMD_TARGETS_DIR  = '/usr/lib/systemd/system'
    DEFAULT_TARGET_SYMLINK  = "/etc/systemd/system/#{DEFAULT_TARGET}#{TARGET_SUFFIX}"

    module Status
      ENABLED   = 'enabled'
      DISABLED  = 'disabled'
      SUPPORTED = [ENABLED, DISABLED]
      ACTIVE    = 'active'
      LOADED    = 'loaded'
    end

    module BaseTargets
      GRAPHICAL = 'graphical'
      MULTIUSER = 'multi-user'
    end

    attr_accessor :modified, :targets, :force, :proposal_reason
    attr_reader   :errors, :default_target

    alias_method :all, :targets

    def initialize
      textdomain 'services-manager'
      @errors  = []
      @targets = {}
      @default_target = ''
      read_targets if Mode.normal
    end

    def read_targets
      find_default_target
      load_supported_targets
      load_target_details
    end

    alias_method :read, :read_targets

    def valid?
      errors.empty?
    end

    def default_target= new_default
      if Mode.normal
        errors << _("Target #{new_default} not found") unless targets.keys.include?(new_default)
      end
      @default_target = new_default
      self.modified = true
      Builtins.y2milestone "New default target set: #{new_default}"
      new_default
    end

    def export
      default_target
    end

    def import new_target
      if new_target.to_s.empty?
        Builtins.y2error("New default target not provided")
        return
      end
      self.default_target = new_target
    end

    def inspect
      "#<#{self} @my_textdomain='#{@my_textdomain}', @default_target='#{default_target}', " +
      "@targets=#{targets.keys} >"
    end

    def save
      Builtins.y2milestone('Saving default target...')
      if !modified
        Builtins.y2milestone("Nothing to do, current default target already set to '#{default_target}'")
        return true
      end

      if !valid?
        errors.each {|e| Builtins.y2error(e) }
        Builtins.y2error("Invalid default target '#{default_target}'; aborting saving")
        return false
      end
      removed = remove_default_target_symlink
      created = create_default_target_symlink
      removed && created
    end

    def reset
      errors.clear
      read_targets
      self.modified = false
    end

    private

    def find_default_target
      @default_target = get_default_target_filename.chomp(TARGET_SUFFIX)
    end

    def remove_default_target_symlink
      Builtins.y2milestone("Removing default target symlink..")
      removed = SCR.Execute(path('.target.remove'), DEFAULT_TARGET_SYMLINK)
      if removed
        Builtins.y2milestone "#{DEFAULT_TARGET_SYMLINK} has been removed"
      else
        Builtins.y2error "Removing of #{DEFAULT_TARGET_SYMLINK} has failed"
      end
      removed
    end

    def create_default_target_symlink
      Builtins.y2milestone("Creating new default target symlink for #{default_target_file}")
      SCR.Execute(path('.target.symlink'), default_target_file, DEFAULT_TARGET_SYMLINK)
      created = SCR.Read(path('.target.size'), DEFAULT_TARGET_SYMLINK) > 0
      if created
        Builtins.y2milestone("Symlink has been created")
      else
        Builtins.y2error("Default target unit file '#{default_target}' is empty")
      end
      created
    end

    def get_default_target_filename
      File.basename(SCR.Read(path('.target.symlink'), DEFAULT_TARGET_SYMLINK).to_s)
    end

    def default_target_file
      File.join(SYSTEMD_TARGETS_DIR, "#{default_target}#{TARGET_SUFFIX}")
    end

    def list_target_units
      command = TERM_OPTIONS + LIST_UNITS_COMMAND + COMMAND_OPTIONS
      SCR.Execute(path('.target.bash_output'), command)
    end

    def list_targets_details
      command = TERM_OPTIONS + LIST_TARGETS_COMMAND + COMMAND_OPTIONS
      SCR.Execute(path('.target.bash_output'), command)
    end

    def load_supported_targets
      self.targets = {}
      output  = list_target_units
      stdout  = output.fetch 'stdout'
      stderr  = output.fetch 'stderr'
      exit_code = output.fetch 'exit'
      errors << stderr if exit_code.to_i != 0 && !stderr.to_s.empty?
      stdout.each_line do |line|
        target, status = line.split(/[\s]+/)
        if Status::SUPPORTED.include?(status)
          target.chomp! TARGET_SUFFIX
          next if target == DEFAULT_TARGET
          self.targets[target] = { :enabled  => status == Status::ENABLED }
        end
      end
      Builtins.y2milestone "Loaded supported target units: %1", targets.keys
    end

    def load_target_details
      output  = list_targets_details
      stdout  = output.fetch 'stdout'
      stderr  = output.fetch 'stderr'
      exit_code = output.fetch 'exit'
      errors << stderr if exit_code.to_i != 0 && !stderr.to_s.empty?
      unknown_targets = []
      stdout.each_line do |line|
        target, loaded, active, _, *description = line.split(/[\s]+/)
        target.chomp! TARGET_SUFFIX
        if targets[target]
          targets[target][:loaded] = loaded == Status::LOADED
          targets[target][:active] = active == Status::ACTIVE
          targets[target][:description] = description.join(' ')
        else
          unknown_targets << target
        end
      end

      Builtins.y2milestone 'Loaded target details: %1', targets

      if !unknown_targets.empty?
        Builtins.y2warning "No details loaded for these targets: #{unknown_targets.join(', ')} "
      end
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
