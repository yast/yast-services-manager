require "yast"

module Yast

  ###  Supported profiles
  #
  # @example Extended profile with list of services to be enabled and disabled
  #
  # <services-manager>
  #   <default_target>multi-user</default_target>
  #   <services>
  #     <enable config:type="list">
  #       <service>at</service>
  #       <service>cron</service>
  #       <service>nscd</service>
  #       <service>openct</service>
  #       <service>postfix</service>
  #       <service>rsyslog</service>
  #       <service>sshd</service>
  #     </enable>
  #     <disable config:type="list">
  #       <service>libvirtd</service>
  #     </disable>
  #   </services>
  # </services-manager>
  #
  # @deprecated Legacy profile with incomplete support for services
  # @example Simple list of services
  #   Supported are only services to be enabled. This profile is missing
  #   services which are going to be disabled.
  #
  #  <services-manager>
  #   <default_target>multi-user</default_target>
  #   <services config:type="list">
  #     <service>cron</service>
  #     <service>postfix</service>
  #     <service>sshd</service>
  #   </services>
  #  </services-manager>
  #
  # @deprecated Legacy runlevel profile
  # @example Runlevel profle
  #
  #   <runlevel>
  #     <default>3</default>
  #     <services config:type="list">
  #       <service>
  #         <service_name>sshd</service_name>
  #         <service_status>enable</service_status>
  #         <service_start>3</service_start>
  #       </service>
  #     </services>
  #   </runlevel>
  #
  ###

  class ServicesManagerProfile
    include Yast::Logger
    include Yast::I18n
    Yast.import "Report"

    ENABLE  = 'enable'
    DISABLE = 'disable'
    ON_DEMAND = 'on_demand'

    YAST_SERVICES = ["YaST2-Firstboot", "YaST2-Second-Stage"]

    # Service object with two attributes:
    # @attr [String] name of the service unit. Suffix '.service' is optional.
    # @attr [String] start_mode on the target system. See Yast2::SystemService#start_mode.
    Service = Struct.new(:name, :start_mode)

    # Profile data passed from autoyast, a Hash expected
    # @return [Hash]
    attr_reader :autoyast_profile

    # List of Service structs
    # @return [Array<Service>]
    attr_reader :services

    # Name of the systemd default target unit. Suffix '.target' is optional.
    # @return [String] if the target has been specified in the profile. Can be nil.
    attr_reader :target

    def initialize autoyast_profile
      textdomain "services-manager"
      @autoyast_profile = autoyast_profile
      @services = []
      extract_services
      extract_target
    end

    private

    def simple_list?(list)
      list.all? { |s| s.is_a?(::String) }
    end

    def extended_list?(list)
      list.is_a?(Hash) && !(list.keys & LIST_NAMES_TO_START_MODE.keys).empty?
    end

    def runlevel_list?(list)
      list.all? { |s| s.is_a?(Hash) && (s.key?("service_name") || s.key?("service_status")) }
    end

    def extract_services
      services = autoyast_profile['services']
      return if services.nil? || services.empty?

      if simple_list?(services)
        load_from_simple_list(services)
      elsif extended_list?(services)
        load_from_extended_list(services)
      elsif runlevel_list?(services)
        load_from_runlevel_list(services)
      else
        Yast::Report.Error _("Unknown autoyast services profile schema for 'services-manager'")
        return
      end
      reject_yast_services
      log.info "Extracted services from autoyast profile: #{self.services}"
    end

    def extract_target
      if autoyast_profile.key?('default_target')
        @target = autoyast_profile['default_target']
      elsif autoyast_profile.key?('default')
        @target = case autoyast_profile['default']
          when "2", "3", "4"
            "multi-user"
          when "5"
            "graphical"
          when "0"
            log.error "You can't set the default target to 'poweroff' in autoyast profile"
            nil
          when "1"
            log.error "You can't set the default target to 'rescue' in autoyast profile"
            nil
          else
            log.error "Target '#{autoyast_profile['default']}' is not valid"
            nil
          end
      end
    end

    # Filter out all YaST services
    def reject_yast_services
       self.services.reject! {|s| YAST_SERVICES.include?(s.name)}
    end

    def load_from_simple_list services
      self.services.concat(
        services.map {|service_name| Service.new(service_name, :on_boot)}
      )
    end

    # @return [Hash<String, Symbol>] Map enable/disable to its corresponding start mode.
    STATUS_TO_START_MODE = {
      ENABLE => :on_boot,
      DISABLE => :manual,
    }.freeze

    def load_from_runlevel_list services
      self.services.concat(
        services.map do |service|
          Service.new(service['service_name'], STATUS_TO_START_MODE[service['service_status']])
        end
      )
    end

    # @return [Hash<String, Symbol>] Map the lists of services that are found in the profile
    #   with their corresponding start modes.
    LIST_NAMES_TO_START_MODE = {
      ENABLE => :on_boot,
      DISABLE => :manual,
      ON_DEMAND => :on_demand
    }.freeze

    def load_from_extended_list services
      LIST_NAMES_TO_START_MODE.each do |list, mode|
        next unless services.key?(list)
        services[list].each do |name|
          self.services << Service.new(name, mode)
        end
      end
    end
  end
end
