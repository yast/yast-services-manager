require "ostruct"

module Yast
  module Systemctl
    CONTROL         = "systemctl"
    COMMAND_OPTIONS = " --no-legend --no-pager --no-ask-password "
    ENV_VARS        = " LANG=C TERM=dumb COLUMNS=1024 "
    SYSTEMCTL       = ENV_VARS + CONTROL + COMMAND_OPTIONS

    class << self

      def execute command
        OpenStruct.new(SCR.Execute(Path.new(".target.bash_output"), SYSTEMCTL + command))
      end

      def socket_units
        sockets_from_files = list_unit_files(:type=>:socket).lines.map do |line|
          line.split(/[\s]+/).first
        end
        sockets_from_units = list_units(:type=>:socket).lines.map do |line|
          socket_unit, _, _, _ = line.split(/[\s]+/)
          socket_unit
        end
        sockets_from_files | sockets_from_units
      end

      private

      def list_unit_files type: nil
        command = SYSTEMCTL + " list-unit-files "
        command += " --type=#{type} " if type
        execute(command).stdout
      end

      def list_units type: nil, all: true
        command = SYSTEMCTL + " list-units "
        command += " --all " if all
        command += " --type=#{type} " if type
        execute(command).stdout
      end
    end
  end
end
