require 'yast'
require 'ostruct'

module Yast
  class Systemctl
    CONTROL         = "systemctl"
    COMMAND_OPTIONS = " --no-legend --no-pager --no-ask-password "
    ENV_VARS        = " LANG=C TERM=dumb COLUMNS=1024 "
    SYSTEMCTL       = ENV_VARS + CONTROL + COMMAND_OPTIONS

    SUPPORTED_TYPES = [ :service, :socket, :target ]

    def self.list_unit_files type: nil
      command = SYSTEMCTL + "list-unit-files"
      command += " --type=#{type} " if type
      scr_execute(command)
    end

    def self.list_units type: nil, all: true
      command = SYSTEMCTL + "list-units"
      command += " --all " if all
      command += " --type=#{type} " if type
      scr_execute(command)
    end

    def self.list_sockets
    end

    def self.scr_execute command
      OpenStruct.new(SCR.Execute(Path.new('.target.bash_output'), command))
    end

    attr_reader :unit_name, :type

    def initialize name: nil, type: nil
      raise "Unsupported unit: #{type}" unless SUPPORTED_TYPES.member?(type)

      @unit_name = name
      @unit_type = type
    end

    def show unit_name
      Properties.new(scr_execute(SYSTEMCTL + "show " + unit_name))
    end

    def status unit_name
      Status.new(scr_execute(SYSTEMCTL + "status " + unit_name))
    end

    def start
    end

    def stop
    end

    def enable
    end

    def disable
    end

    private

    def scr_execute command
      self.class.scr_execute(command)
    end


    class Properties
      attr_reader :scr
      attr_reader :id, :description, :load_state, :active_state, :sub_state, :unit_path,
                  :unit_state, :pid, :config_file

      def initialize scr
        @scr = scr
        @id = extract_property('Id')
        @description = extract_property('Description')
        @load_state = extract_property('LoadState')
        @active_state = extract_property('ActiveState')
        @sub_state = extract_property('SubState')
      end

      private

      def extract_property property_name
        scr.stdout.scan(/#{property_name}=(.+)/).flatten.first
      end
    end

    class Status
      attr_reader :scr

      def initialize scr
        @scr = scr
      end
    end
  end
end
