require 'services-manager/ui_elements'

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
      service_id = args['chosen_id'].to_s
      #TODO implement behaviour if force_reset parameter provided
      force_reset = !!args['force_reset']
      proposal = Proposal.new

      case function
        when 'MakeProposal' then proposal.read
        when 'AskUser'      then ask_user(service_id)
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

    def ask_user service_id
      Builtins.y2milestone "Services Proposal wanted to change with id %1", service_id
      if service_id.match /\Atoggle_service_\d+\z/
        Builtins.y2milestone "User requested #{service_id}"
        toggle_service(service_id)
      else
        Builtins.y2warning "Service id #{service_id} is unknown"
      end
      {'workflow_sequence' => :next}
    end

    private

    def toggle_service service_id
      id = service_id.match(/\Atoggle_service_(\d+)$/)[1]
      if !id
        Builtins.y2error "Failed to get id from #{service_id}"
        return false
      end

      id = id.to_i
      service = proposal.proposed_services[id]
      if !service
        Builtins.y2error "Proposed services have no entry at index #{id}; " +
          "Showing all of them: #{proposal.proposed_services}"
        return false
      end

      status = service['enabled']
      if status.nil?
        Builtins.y2error "Unknown status of service #{service}; " +
          "it's neither enabled not disabled"
        return false
      end
      service['enabled'] = !status
      true
    end

    class Proposal < Client
      include UIElements

      textdomain "services-manager"

      attr_reader :default_services, :proposed_services, :links

      def initialize
        @links = []
        @proposed_services = []
        @default_services = ProductFeatures.GetFeature('globals', 'services_proposal')
        @default_services = [] if default_services.to_s.empty?
        Builtins.y2error("Missing services_proposal") if default_services.empty?
        SuSEFirewall.Read
        load_services_details
        @proposal = {
          'preformatted_proposal' => proposal_summary,
          'warning_level'         => :warning,
          'warning'               => nil,
          'links'                 => links,
          'help'                  => help_text
        }
        Builtins.y2milestone "Created proposal: #{@proposal}"
      end

      def read
        @proposal
      end

      private

      def help_text
        if proposed_services.empty?
          _(
            "<p><big><b>Services</b></big><br>\nThe current setup does not provide " +
            "any functionality now.</p>"
        )
        else
          _(
            "<p><big><b>Services</b></big><br>\n" +
            "This installation proposal allows you to start and enable a service " +
            " from the \n list of services.</p>\n" +
            "<p>It may also open ports in the firewall for a service if firewall is " +
            "enabled\nand a particular service requires opening them.</p>\n"
          )
        end
      end

      def proposal_summary
        messages = []
        proposed_services.each_with_index do |service, index|
          if !service['firewall_plugins'].empty? && SuSEFirewall.IsEnabled
            if service['enabled']
              toggled  = bold('enabled')
              firewall = 'open'
              link     = ahref("toggle_service_#{index}", "(disable)")
            else
              toggled  = bold('disabled')
              firewall = 'closed'
              link     = ahref("toggle_service_#{index}", "(enable)")
            end
            message = _(
              "Service %service will be %toggled and port in firewall will be %switched %link" %
              :service => italic(service['label']),
              :toggled => toggled,
              :link    => link
            )
          else
            if service['enabled']
              toggled = bold('enabled')
              link    = ahref("toggle_service_#{index}", "(disable)")
            else
              toggled = bold('disabled')
              link    = ahref("toggled_service_#{index}", "(enable)")
            end
            message = _(
              "Service %service will be %toggled %link" %
              :service => service['label'],
              :toggled => toggled,
              :link    => link
            )
          end
          messages << message
        end
        list(*messages)
      end

      def load_services_details
        default_services.each_with_index do |service, index|

          if service['service_names'].to_s.empty?
            Builtins.y2error "Missing entry service_names in #{service}, ignoring.."
            next
          end

          services = service['service_names'].to_s.split
          if services.empty?
            Builtins.y2error "No services_names found in #{service}"
            next
          end

          firewall_plugins = service['firewall_plugins'].to_s.split
          if firewall_plugins.empty?
            Builtins.y2error "Empty entry for 'firewall_plugins' in service #{service}, ignoring.."
            next
          end

          enabled_by_default = service['enabled_by_default'].to_s == 'true'

          label = services.join(', ')
          label_id = service['label_id'].to_s
          if label_id.empty?
            Builtins.y2error "Missing label_id, using label '#{label}'"
          else
            tmp_label = ProductControl.GetTranslatedText(label_id).to_s
            if tmp_label.empty?
              Builtins.y2error "Unable to translate label_id in #{service}"
            else
              label = tmp_label
            end
          end

          packages = service['packages'].to_s.split

          service_specs = {
            'label'              => label,
            'services'           => services,
            'firewall_plugins'   => firewall_plugins,
            'enabled'            => enabled_by_default || detect_status(services),
            'enabled_by_default' => enabled_by_default,
            'packages'           => packages
          }

          self.proposed_services << service_specs
          self.links    << "toggle_service_#{index}"
        end
      end

      def detect_status services
        stopped_service = services.find do |service|
          !Service.Status(service).to_i.zero? || !Service.Enabled(service)
        end
        Builtins.y2milestone "Service #{service} is not running or it's disabled." if stopped_service
        return !stopped_service
      end
    end
  end
end
