module Yast
  class ServicesManagerProfile
    include Yast::Logger

    ENABLE  = 'enable'
    DISABLE = 'disable'

    Service = Struct.new(:name, :status)

    attr_reader :autoyast_profile, :services, :target

    def initialize autoyast_profile
      @autoyast_profile = autoyast_profile
      @services = []
      extract_services
      extract_target
    end

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
        raise "Unknown autoyast services profile schema for data #{autoyast_profile}"
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
          end
      end
    end

    private

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
