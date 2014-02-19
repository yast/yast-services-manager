require 'services-manager/systemctl'

require 'ostruct'
require 'forwardable'

module Yast
  class SystemdUnit

    SUPPORTED_TYPES  = %w( service socket target )
    SUPPORTED_STATES = %w( enabled disabled )

    DEFAULT_PROPERTIES = {
      id:              "Id",
      pid:             "MainPID",
      description:     "Description",
      load_state:      "LoadState",
      active_state:    "ActiveState",
      sub_state:       "SubState",
      unit_file_state: "UnitFileState",
      path:            "FragmentPath"
    }

    extend Forwardable

    def_delegators :@properties,
                   :active?, :enabled?, :running?, :not_found?, :loaded?, :supported?, :path

    attr_reader   :unit_name, :unit_type, :input_properties, :errors
    attr_accessor :properties

    def initialize full_unit_name, properties: {}
      @unit_name, @unit_type = full_unit_name.split(".")
      raise "Missing unit type suffix" unless unit_type
      raise "Unsupported unit type '#{unit_type}'" unless SUPPORTED_TYPES.member?(unit_type)

      @input_properties = properties.merge!(DEFAULT_PROPERTIES)
      @properties = show
      @errors = ""
    end

    def show
      Properties.new(self)
    end

    def status
      command("status", :options => "2>&1").stdout
    end

    def start
      result = command("start")
      errors << result.stderr
      refresh!
      result.exit.zero?
    end

    def stop
      result = command("stop")
      errors << result.stderr
      refresh!
      result.exit.zero?
    end

    def enable
      result = command("enable")
      errors << result.stderr
      refresh!
      result.exit.zero?
    end

    def disable
      result = command("disable")
      errors << result.stderr
      refresh!
      result.exit.zero?
    end

    def command command_name, options={}
      errors.clear
      Systemctl.execute("#{command_name} #{unit_name} #{options[:options]}")
    end

    private

    def refresh!
      self.properties = show
    end

    class Properties < OpenStruct

      attr_reader :systemd_unit, :systemd_properties

      def initialize systemd_unit
        super()
        @systemd_unit = systemd_unit
        @systemd_properties = show_systemd_properties
        extract_properties
        self[:active?]    = active_state    == "active"
        self[:running?]   = sub_state       == "running"
        self[:loaded?]    = load_state      == "loaded"
        self[:not_found?] = load_state      == "not-found"
        self[:enabled?]   = unit_file_state == "enabled"
        self[:supported?] = SUPPORTED_STATES.member?(unit_file_state)
      end

      private

      def extract_properties
        systemd_unit.input_properties.each do |name, property|
          self[name] = systemd_properties.scan(/#{property}=(.+)/).flatten.first
        end
      end

      def show_systemd_properties
        properties = systemd_unit.input_properties.map do |_, property_name|
          " --property=#{property_name} "
        end
        systemd_unit.command("show", :options => properties.join)
      end
    end
  end
end
