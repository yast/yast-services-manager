module Yast
  class ServicesManagerProfile
    include Yast::Logger

    Service = Struct.new(:name, :status)

    attr_reader :autoyast_data, :services

    def initialize services_data
      @autoyast_data = services_data
      @services = []
      if autoyast_data.all? {|item| item.is_a?(::String) }
        load_from_simple_list
      elsif autoyast_data.all? {|i| i.is_a?(Hash) && (i.key?('enable') || i.key?('disable')) }
        load_from_extended_list
      elsif autoyast_data.all? {|i| i.is_a?(Hash) && (i.key?('service_name') || i.key?('service_status')) }
        load_from_runlevel_list
      else
        log.error("Unknown autoyast service profile schema for data #{autoyast_data}")
      end
    end

    private

    def load_from_simple_list
      services.concat(extract_enabled(autoyast_data))
    end

    def load_from_runlevel_list
      services.concat(
        autoyast_data.map do |service|
          Service.new(service['service_name'], service['service_status'])
        end
      )
    end

    def load_from_extended_list
      autoyast_data.each do |service_group|
        services.concat(extract_enabled(service_group.fetch('enable', [] )))
        services.concat(extract_disabled(service_group.fetch('disable', [] )))
      end
    end

    def extract_enabled services
      services.map {|name| Service.new(name, 'enable')}
    end

    def extract_disabled services
      services.map {|name| Service.new(name, 'disable')}
    end
  end
end
