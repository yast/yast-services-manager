require "ostruct"

module Yast
  class Systemctl
    CONTROL         = "systemctl"
    COMMAND_OPTIONS = " --no-legend --no-pager --no-ask-password "
    ENV_VARS        = " LANG=C TERM=dumb COLUMNS=1024 "
    SYSTEMCTL       = ENV_VARS + CONTROL + COMMAND_OPTIONS

    SUPPORTED_TYPES  = %w( service socket target )
    SUPPORTED_STATES = %w( enabled disabled )

    DEFAULT_PROPERTIES = {
      id:              "Id",
      pid:             "MainPID",
      description:     "Description",
      load_state:      "LoadState",
      active_state:    "ActiveState",
      sub_state:       "SubState",
      unit_file_state: "UnitFileState"
    }

    class << self

      def scr_execute command
        OpenStruct.new(SCR.Execute(Path.new(".target.bash_output"), command))
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

      def list_unit_files type: nil
        command = SYSTEMCTL + " list-unit-files "
        command += " --type=#{type} " if type
        scr_execute(command).stdout
      end

      def list_units type: nil, all: true
        command = SYSTEMCTL + " list-units "
        command += " --all " if all
        command += " --type=#{type} " if type
        scr_execute(command).stdout
      end

    end

    attr_reader   :unit_name, :unit_type, :input_properties, :errors
    attr_accessor :properties

    def initialize name, properties: {}
      @unit_name, @unit_type = name.split(".")
      raise "Missing unit type suffix" unless unit_type
      raise "Unsupported unit type '#{unit_type}'" unless SUPPORTED_TYPES.member?(unit_type)

      @input_properties = properties.merge!(DEFAULT_PROPERTIES)
      @properties = show
      @errors = ""
    end

    def show
      Properties.new(self)
    end

    def start
      result = unit_command("start")
      errors << result.stderr
      refresh!
      result.exit.zero?
    end

    def stop
      result = unit_command("stop")
      errors << result.stderr
      refresh!
      result.exit.zero?
    end

    def enable
      result = unit_command("enable")
      errors << result.stderr
      refresh!
      result.exit.zero?
    end

    def disable
      result = unit_command("disable")
      errors << result.stderr
      refresh!
      result.exit.zero?
    end

    def refresh!
      self.properties = show
    end

    def unit_command command_name, options={}
      scr_execute("#{SYSTEMCTL} #{command_name} #{unit_name} #{options[:options]}")
    end

    def scr_execute command
      self.class.scr_execute(command)
    end

    class Properties < OpenStruct

      attr_reader :systemctl

      def initialize systemctl
        super()
        @systemctl = systemctl
        extract_properties
        self[:active?]    = active_state    == "active"
        self[:running?]   = sub_state       == "running"
        self[:loaded?]    = load_state      == "loaded"
        self[:not_found?] = load_state      == "not-found"
        self[:enabled?]   = unit_file_state == "enabled"
        self[:supported?] = SUPPORTED_STATES.member?(unit_file_state)
        self[:status]     = systemctl_status
      end

      private

      def extract_properties
        systemctl.input_properties.each do |name, property|
          self[name] = systemctl_show.stdout.scan(/#{property}=(.+)/).flatten.first
        end
      end

      def systemctl_status
        systemctl.unit_command("status", :options => "2>&1").stdout
      end

      def systemctl_show
        properties = systemctl.input_properties.map do |_, property_name|
          " --property=#{property_name} "
        end
        systemctl.unit_command("show", :options => properties.join)
      end
    end
  end
end
