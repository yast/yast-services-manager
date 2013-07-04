# encoding: utf-8

module Yast
  module Clients
    class ServicesManagerAuto < Client
      require 'fileutils'
      $: << File.expand_path(File.join(File.dirname(__FILE__), '../includes/'))

      Yast.import('Wizard')

      require 'services-manager/dialogs.rb'

      def main
        function = ''
        params   = {}
        auto_ret = {}

        if WFM.Args.size > 0 && Ops.is(WFM.Args(0), 'string')
          function = WFM.Args(0)
          if WFM.Args.size > 1 && Ops.is(WFM.Args(0), 'map')
            params = Convert.to_map(WFM.Args(1))
          end
        end

        dialogs = Yast::Clients::ServicesManagerDialogs.new

        case function
          when 'Change'
            Wizard.CreateDialog
            auto_ret = (dialogs.main_dialog == :next)
            UI.CloseDialog
          when 'Summary'
            auto_ret = dialogs.summary
          when 'Import'
            # FIXME: TBD
          when 'Export'
            # FIXME: TBD
          when 'Read'
            # FIXME: TBD
          when 'Write'
            auto_ret = dialogs.save
          when 'Reset'
            # FIXME: TBD
          when 'Packages'
            auto_ret = {}
          when 'GetModified'
            auto_ret = dialogs.modified?
          when 'SetModified'
            # FIXME: TBD
          else
            Builtins.y2error("Unknown Autoyast command: #{function}, #{params.inspect}")
            auto_ret = nil
        end

        auto_ret
      end
    end
  end
end

Yast::Clients::ServicesManagerAuto.new.main
