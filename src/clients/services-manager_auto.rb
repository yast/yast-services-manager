require 'erb'

module Yast
  import 'Wizard'
  import 'ServicesManager'

  class ServicesManagerAuto < Client

    def initialize
      textdomain 'services-manager'
    end

    def call args
      Builtins.y2milestone "Autoyast client called with args #{args}"
      if args.size == 0
        Bultins.y2error("missing autoyast command")
        return
      end

      function = args.shift
      params   = args.first

      case function
        when 'Change'      then WFM.CallFunction('services-manager')
        when 'Summary'     then auto_summary
        when 'Import'      then ServicesManager.import(params)
        when 'Export'      then ServicesManager.export
        when 'Read'        then ServicesManager.read
        when 'Write'       then ServicesManager.save
        when 'Reset'       then ServicesManager.reset
        when 'Packages'    then {}
        when 'GetModified' then ServicesManager.modified?
        when 'SetModified' then ServicesManager.modify
        else
          Builtins.y2error("Unknown Autoyast command: #{function}, params: #{params}")
      end
    end

    private

    def auto_summary
      result = ERB.new(summary_template).result(binding)
      Builtins.y2milestone "Returning summary: #{result}"
      result
    end

    def summary_template
      <<-summary
<h2><%= _('Services Manager') %></h2>
<p><b><%= _('Default Target') %></b></p>
<p><%= ERB::Util.html_escape SystemdTarget.export %></p>
<p><b><%= _('Enabled Services') %></b></p>
<ul>
<% SystemdService.export.each do |service| %>
  <li><%= ERB::Util.html_escape service %></li>
<% end %>
</ul>
      summary
    end

  end
  ServicesManagerAuto.new.call(WFM.Args)
end

