module Yast
  import "SystemdServices"
  import "Progress"
  import "ProductControl"
  import "ProductFeatures"
  import "Service"
  import "Linuxrc"
  import "Report"
  import "Package"
  import "SuSEFirewall"

  class ServicesProposal < Client

    def initialize
      textdomain "services-manager"
      args = WFM.Args
      function = args.shift.to_s
      #TODO implement behaviour if force_reset parameter provided
      force_reset = !!args.shift.to_s
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
        Builtins.y2error("Missing services_proposal") if default_services.empty?
      end

      def create
        SuSEFirewall.Read
        default_services.each_with_index do |service, index|

          if !service['service_names'] || service['service_names'].to_s.empty?
            Builtins.y2error "Invalid service in #{service}, ignoring.."
            next
          end

          services = service['service_names'].to_s.split(',').map(&:strip)
          if services.empty?
            Builtins.y2error "No services found in #{service}"
            next
          end

          if service['firewall_plugins'] && service['firewall_plugins'].to_s.empty?
            Builtins.y2error "Invalid item for 'firewall_plugins' in service #{service}, ignoring.."
            next
          end
          firewall_plugins = service['firewall_plugins'].to_s.split(',').map(&:strip)

          enabled_by_default = service['enabled_by_default'].to_s
          case enabled_by_default
            when 'false' then false
            when 'true'  then true
            else Builtins.y2error "Invalid entry in 'enabled_by_default': #{enabled_by_default}"
          end

          label = services.join(', ')
          label_id = service['label_id'].to_s
          if label_id.empty?
            Builtins.y2error "Missing label_id, using label '#{label}'"
          else
            tmp_label = ProductControl.GetTranslatedText(label_id)
            #TODO next is on line 246 in services_proposal Runlevel
          end
        end
        {
          'preformatted_proposal' => get_proposal_summary, #TODO
          'warning_level'         => :warning,
          'warning'               => nil,
          'links'                 => get_proposal_links, #TODO
          'help'                  => get_help_text #TODO
        }
      end
    end
  end
end
