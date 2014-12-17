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

    # Service object with two attributes:
    # @attr [String] name of the service unit. Suffix '.service' is optional.
    # @attr [String] required status on the target system. Can be 'enable' or 'disable'.
    Service = Struct.new(:name, :status)

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

    def extract_services
      services = autoyast_profile['services']
      return if services.nil? || services.empty?

      if services.all? {|item| item.is_a?(::String) }
        load_from_simple_list(services)
      elsif services.is_a?(Hash) && ( services.key?(ENABLE) || services.key?(DISABLE))
        load_from_extended_list(services)
      elsif services.all? {|i| i.is_a?(Hash) && (i.key?('service_name') || i.key?('service_status')) }
        load_from_runlevel_list(services)
      else
        Yast::Report.Error _("Unknown autoyast services profile schema for 'services-manager'")
        return
      end
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

    def load_from_simple_list services
      self.services.concat(
        services.map {|service_name| Service.new(service_name, ENABLE)}
      )
    end

    def load_from_runlevel_list services
      self.services.concat(
        services.map do |service|
          Service.new(service['service_name'], service['service_status'])
        end
      )
    end

    def load_from_extended_list services
      self.services.concat(
        services.fetch(ENABLE, []).map do |service_name|
          Service.new(service_name, ENABLE)
        end
      )

      self.services.concat(
        services.fetch(DISABLE, []).map do |service_name|
          Service.new(service_name, DISABLE)
        end
      )
    end
  end
end
