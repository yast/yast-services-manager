require 'yast'
require 'ostruct'

module Yast
  class Systemctl
    CONTROL         = "systemctl"
    COMMAND_OPTIONS = " --no-legend --no-pager --no-ask-password "
    ENV_VARS        = " LANG=C TERM=dumb COLUMNS=1024 "
    SYSTEMCTL       = ENV_VARS + CONTROL + COMMAND_OPTIONS

    SUPPORTED_TYPES  = [ :service, :socket, :target ]
    SUPPORTED_STATES = [ "enabled", "disabled" ]

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

    attr_reader :unit_name, :unit_type

    def initialize name: nil, type: nil
      raise "Unsupported unit: #{type}" unless SUPPORTED_TYPES.member?(type)

      @unit_name = name
      @unit_type = type
    end

    def show properties={}
      Properties.new(unit_name, properties)
    end

    def status unit_name
      scr_execute(SYSTEMCTL + "status " + unit_name + " 2&>1").stdout
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

    class Properties < OpenStruct

      DEFAULT_PROPERTIES = {
        id:           "Id",
        pid:          "MainPID",
        description:  "Description",
        load_state:   "LoadState",
        active_state: "ActiveState",
        sub_state:    "SubState",
        unit_file_state: "UnitFileState"
      }


      def initialize unit_name, properties
        properties.merge!(DEFAULT_PROPERTIES)
        self.scr = systemctl_show(unit_name, properties)
        properties.each {|name, property| self[name] = extract(property) }
        self.active    = active_state == 'active'
        self.running   = sub_state    == 'running'
        self.loaded    = load_state   == 'loaded'
        self.not_found = load_state   == 'not-found'
        self.enabled   = unit_file_state == 'enabled'
      end

      alias_method :active?,    :active
      alias_method :running?,   :running
      alias_method :loaded?,    :loaded
      alias_method :not_found?, :not_found
      alias_method :enabled?,   :enabled

      private

      def systemctl_show unit_name, properties
        command = SYSTEMCTL + "show " + unit_name
        command += properties.values.map {|p| command += " --property=#{p} "}.join
        Systemctl.scr_execute(command)
      end

      def extract property_name
        scr.stdout.scan(/#{property_name}=(.+)/).flatten.first
      end
    end
  end
end
