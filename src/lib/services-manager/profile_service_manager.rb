module Yast
  class ServicesManagerProfile
    def initialize services_profile
      @autoyast_profile = services_profile
      @profile =
        case services_profile
        when Array
          ListProfile.new(autoyast_profile)
        when Hash
          if services_profile.any? {|k| ['enable', 'disable'].member?(k) }
            ExtendedProfile.new(autoyast_profile)
          elsif services_profile.any? {|k| ['service_name', 'service_status'].member?(k) }
            RunlevelProfile.new(autoyast_profile)
          else
            raise "Invalid autoyast profile"
          end
        end
    end

    Service = Struct.new(:name, :status)

    class RunlevelProfile
      attr_reader :services

      def initialize services
        @services = services.map do |service|
          Service.new(service['service_name'], service['service_status'])
        end
      end
    end

    class ListProfile
      attr_reader :services

      def initialize services
        @services = services.map {|service| Service.new(service, :enable) }
      end
    end

    class ExtendedProfile
      attr_reader :services

      def initialize services
        @services = services.map do |status|
          if status['enable']
            status.values.each {|s| Service.new(s, 'enable') }
          elsif status['disable']
            status.values.each {|name| Service.new(name, 'disable') }
          else
            log.error("Unknown status '#{status}' for services in autoyast profile")
          end
        end
      end
    end
  end
end
