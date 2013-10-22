require 'erb'

module Yast
  import 'Wizard'
  import 'ServicesManager'

  class ServicesManagerAuto < Client
    textdomain 'services-manager'

    attr_reader :args

    def initialize
      @args = WFM.Args
      Builtins.y2milestone "Autoyast client called with args #{args}"
    end

    def call
      if args.size == 0
        Bultins.y2error("missing autoyast command")
        return
      end

      function = args.shift
      params   = args

      case function
        when 'Change'      then WFM.run_client('services-manager')
        when 'Summary'     then auto_summary
        when 'Import'      then ServicesManager.import(params)
        when 'Export'      then ServicesManager.export
        when 'Read'        then ServicesManager.read
        when 'Write'       then ServicesManager.save
        when 'Reset'       then ServicesManager.reset
        when 'Packages'    then {}
        else
          Builtins.y2error("Unknown Autoyast command: #{function}, params: #{params}")
      end
    end

    private

    def auto_summary
      ERB.new(summary_template).result(binding)
    end

    def summary_template
      <<-summary
<h2><%= _('Services Manager') %></h2>
<p><b><%= _('Default Target') %></b><%= SystemdTarget.export %></p>
<p><b><%= _('Enabled Services') %></b></p>
<ul>
<% SystemdService.export.each do |service| %>
  <li><%= service %></li>
<% end %>
</ul>
      summary
    end

  end
end

Yast::ServicesManagerAuto.new.call
