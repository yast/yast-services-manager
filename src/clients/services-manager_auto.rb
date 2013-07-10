# encoding: utf-8

module Yast
  module Clients
    class ServicesManagerAuto < Client
      Yast.import('Wizard')
      Yast.import('ServicesManager')

      def configure_manually
        Wizard.CreateDialog
        ret = (ServicesManager.main_dialog == :next)
        UI.CloseDialog
        ret
      end

      def main
        args = WFM.Args
        Builtins.y2milestone("Client #{__FILE__} called with args #{args.inspect}")

        if args.size == 0
          Bultins.y2error("missing autoyast command")
          return
        end

        function = args[0] || ''
        params   = args[1] || {}

        case function
          when 'Change'      then configure_manually
          when 'Summary'     then ServicesManager.summary
          when 'Import'      then ServicesManager.import(params)
          when 'Export'      then ServicesManager.export
          when 'Read'        then ServicesManager.read
          when 'Write'       then ServicesManager.save(:force => true, :startstop => false)
          when 'Reset'       then ServicesManager.reset
          when 'Packages'    then {}
          when 'GetModified' then ServicesManager.modified?
          when 'SetModified' then ServicesManager.modified!
          else
            Builtins.y2error("Unknown Autoyast command: #{function}, #{params.inspect}")
            nil
        end
      end

    end
  end
end

Yast::Clients::ServicesManagerAuto.new.main
