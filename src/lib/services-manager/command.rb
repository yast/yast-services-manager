require 'yast'
require 'ostruct'

module Yast
  module SystemdCommand
    CONTROL         = "systemctl"
    COMMAND_OPTIONS = " --no-legend --no-pager --no-ask-password "
    ENV_VARS        = " LANG=C TERM=dumb COLUMNS=1024 "
    BASE_COMMAND    = ENV_VARS + CONTROL + COMMAND_OPTIONS

    def list_unit_files type: nil
      command = BASE_COMMAND + "list-unit-files"
      command += " --type=#{type} " unless type.nil?
      scr_execute(command)
    end

    def list_units type: nil, all: true
      command = BASE_COMMAND + "list-units"
      command += " --all " if all
      command += " --type=#{type} " unless type.nil?
      scr_execute(command)
    end

    def status unit_name
      command = BASE_COMMAND + "status" + " #{unit_name}  2>&1"
      scr_execute(command)
    end

    private

    def scr_execute command
      OpenStruct.new(SCR.Execute(Path.new('.target.bash_output'), command))
    end
  end
end
