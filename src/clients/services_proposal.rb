module Yast
  class ServicesProposal < Client

    Yast.import "SystemdServices"
    Yast.import "Progress"
    Yast.import "ProductControl"
    Yast.import "ProductFeatures"
    Yast.import "Service"
    Yast.import "Linuxrc"
    Yast.import "Report"
    Yast.import "Package"
    Yast.import "SuSEFirewall"

    def initialize
      textdomain "services-manager"
      args = WFM.Args
      function = args.shift.to_s
      case function
        when 'MakeProposal' then Proposal.new.create
        when 'AskUser'      then ask_user
        when 'Description'  then description
        when 'Write'        then write
        else  Builtins.y2error("Unknown function: %1", function)
      end
    end

    def description
      {
        'id'              => 'services',
        'menu_title'      => _("&Services"),
        'rich_text_title' => _('Services')
      }
    end

    def write
      # TODO
    end

    def ask_user
      # TODO
    end

    class Proposal < Client
      textdomain "services-manager"

      attr_reader :default_services

      def initialize
        @links    = []
        @settings = []
        @default_services = ProductFeatures.GetFeature('globals', 'services_proposal')
        @default_services = [] if default_services.to_s.empty?
        Builtins.y2error("Missing services_proposal") unless default_services.empty?
      end

      def create
        SuSEFirewall.Read
        default_services.each_with_index do |service, index|
          if !service['service_names']
            Builtins.y2error("Invalid service in %1, ignoring..", service)
            next
          end
          service_name = service['service_names']
          # TODO
          # finish creating the proposal
          # look into the #ReadCurrentConfiguration method in Runlevel#Client#services_proposal
        end
      end
    end
  end
end
