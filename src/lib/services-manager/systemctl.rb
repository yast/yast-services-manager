require "ostruct"

module Yast
  class Systemctl
    CONTROL         = "systemctl"
    COMMAND_OPTIONS = " --no-legend --no-pager --no-ask-password "
    ENV_VARS        = " LANG=C TERM=dumb COLUMNS=1024 "
    SYSTEMCTL       = ENV_VARS + CONTROL + COMMAND_OPTIONS

    SUPPORTED_TYPES  = [ :service, :socket, :target ]
    SUPPORTED_STATES = [ "enabled", "disabled" ]

    DEFAULT_PROPERTIES = {
      id:              "Id",
      pid:             "MainPID",
      description:     "Description",
      load_state:      "LoadState",
      active_state:    "ActiveState",
      sub_state:       "SubState",
      unit_file_state: "UnitFileState"
    }

    def self.list_unit_files type: nil
      command = SYSTEMCTL + " list-unit-files "
      command += " --type=#{type} " if type
      scr_execute(command)
    end

    def self.list_units type: nil, all: true
      command = SYSTEMCTL + " list-units "
      command += " --all " if all
      command += " --type=#{type} " if type
      scr_execute(command)
    end

    def self.list_sockets
    end

    def self.scr_execute command
      OpenStruct.new(SCR.Execute(Path.new(".target.bash_output"), command))
    end

    attr_reader   :unit_name, :unit_type, :input_properties
    attr_accessor :properties

    def initialize name: nil, type: nil, properties: {}
      raise "Unsupported unit: #{type}" unless SUPPORTED_TYPES.member?(type)

      @unit_name = name
      @unit_type = type
      @input_properties = properties.merge!(DEFAULT_PROPERTIES)
      @properties = show
    end

    def show
      Properties.new(self)
    end

    def start
      unit_command("start").exit.zero?
    end

    def stop
      unit_command("stop").exit.zero?
    end

    def enable
      unit_command("enable").exit.zero?
    end

    def disable
      unit_command("disable").exit.zero?
    end

    def reload!
      self.properties = show
    end

    def unit_command command_name, options={}
      options.merge!(:reload=>true) if options[:reload].nil?
      result = scr_execute("#{SYSTEMCTL} #{command_name} #{unit_name} #{options[:options]}")
      reload! if options[:reload]
      result
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
        systemctl.unit_command("status", :reload=>false, :options=>"2>&1").stdout
      end

      def systemctl_show
        properties = systemctl.input_properties.map do |_, property_name|
          " --property=#{property_name} "
        end
        systemctl.unit_command("show", :reload=>false, :options=>properties.join)
      end
    end
  end
end
