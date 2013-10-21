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
        when 'Write'        then Writer.new(proposal).write
        else  Builtins.y2error("Unknown function: %1", function)
      end
    end

    def ask_user service_id
      Builtins.y2milestone "Services proposal wanted to change with id %1", service_id
      if service_id.match /\Atoggle_service_\d+\z/
        Builtins.y2milestone "User requested #{service_id}"
        toggle_service(service_id)
      else
        Builtins.y2warning "Service id #{service_id} is unknown"
      end
      {'workflow_sequence' => :next}
    end

    def description
      {
        'id'              => 'services',
        'menu_title'      => _("&Services"),
        'rich_text_title' => _('Services')
      }
    end

    private

    def toggle_service service_id
      id = service_id.match(/\Atoggle_service_(\d+)\z/)[1]
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

          service_names = service['service_names'].to_s.split
          if service_names.empty?
            Builtins.y2error "No entry in service_names in #{service}, ignoring.."
            next
          end

          firewall_plugins = service['firewall_plugins'].to_s.split
          if service['firewall_plugins'] && firewall_plugins.empty?
            Builtins.y2warning "No entries for 'firewall_plugins' in service #{service}"
          end

          enabled_by_default = service['enabled_by_default'].to_s == 'true'
          label_id = service['label_id'].to_s
          label = ProductControl.GetTranslatedText(label_id).to_s

          if label_id.empty?
            label = service_names.join(', ')
            Builtins.y2error "Missing label_id, using label '#{label}'"
          end

          if label.empty?
            label = service_names.join(', ')
            Builtins.y2error "Unable to translate label_id in #{service}"
          end

          packages = service['packages'].to_s.split

          service_specs = {
            'label'              => label,
            'services'           => service_names,
            'firewall_plugins'   => firewall_plugins,
            'enabled'            => enabled_by_default || detect_status(service_names),
            'enabled_by_default' => enabled_by_default,
            'packages'           => packages
          }

          self.proposed_services << service_specs
          self.links << "toggle_service_#{index}"
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

    class Writer < Client
      textdomain "services-manager"

      attr_reader :proposal

      def initialize proposal
        @proposal = proposal
      end

      def write
        success = true
        proposal.proposed_services.each do |proposed_service|
          service_names = proposed_service['services']

          if proposed_service['enabled']
            Builtins.y2milestone "Service #{proposed_service} should not be enabled"
            stop_and_disable_services(service_names)
            next
          end

          handle_missing_packages(proposed_service)
          success = manage_service(proposed_service)
        end
        SuSEFirewall.Write
        success
      end

      private

      def handle_missing_packages service
        missing_packages = service['packages'].select do |package|
          installed = Package.Installed(package)
          available = Package.Available(package)
          Report.Error _("Package %1 is not available" % package) if !installed && !available
          !installed
        end

        if !missing_packages.empty?
          Builtins.y2milestone "Packages to be installed: #{missing_packages}"
          installed = Package.DoInstall(missing_packages)
          if installed
            Builtins.y2milestone "Required packages for #{service} have been installed"
          else
            Report.Error _("Installation of required packages has failed; \n" +
                           "enabling and starting the services may also fail")
          end
        end
      end

      def manage_service proposed_service
        success = true
        proposed_service['services'].each do |service|
          Builtins.y2milestone "Enabling service #{service}"

          enabled = Service.Enable(service)
          if enabled
            Builtins.y2milestone "Service #{service} has been enabled"
          else
            Report.Error _("Cannot enable service %1" % service)
            success = false
            next
          end

          started = Service.Start(service)
          if started
            Builtins.y2milestone "Service #{service} has been started"
          else
            success = false
            next
          end

          firewall_plugins = service['firewall_plugins']
          if SuSEFirewall.IsEnabled && !firewall_plugins.empty?
            Builtins.y2milestone "Firewall plugins: #{firewall_plugins}"
            open_firewall_ports(firewall_plugins)
          end
        end
        success
      end

      def stop_and_disable_services services
        services.each do |service|
          Builtins.y2warning "#{service} must not be stopped now" if protected_service?(service)
          if Service.Status(service).to_i.zero? || Service.Enabled(service)
            Builtins.y2milestone "Stopping and disabling service #{service}"
            Service.RunInitScriptWithTimeOut(service, 'stop')
            Service.Disable(service)
          end
        end
      end

      def open_firewall_ports plugins
        plugins = plugins.map { |p| "service:#{p}" }
        interfaces = SuSEFirewall.GetAllKnowInterfaces.map do |interface|
          interface['id'] unless interface['id'].to_s.empty?
        end.compact
        Builtins.y2milestone "Available firewall interfaces: #{interfaces}"
        zones = if interfaces.empty?
          SuSEFirewall.GetKnownFirewallZones
        else
          SuSEFirewall.GetZonesOfInterfacesWithAnyFeatureSupported(interfaces)
        end
        Builtins.y2milestone "Found firewall zones #{zones}"
        SuSEFirewall.SetServicesForZones(plugins, zones, true)
      end

      def protected_service? service_name
        return true if Linuxrc.vnc    && service_name == "xinetd"
        return true if Linuxrc.usessh && service_name == "sshd"
        false
      end
    end
  end
end
Yast::ServicesProposal.new
