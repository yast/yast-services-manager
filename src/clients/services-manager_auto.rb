# encoding: utf-8

module Yast
  module Clients
    class ServicesManagerAuto < Client
      Yast.import('Wizard')
      Yast.import('ServicesManagerDialogs')

      def configure_manually
        Wizard.CreateDialog
        ret = (ServicesManagerDialogs.main_dialog == :next)
        UI.CloseDialog
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
          when 'Change' then configure_manually
          when 'Summary' then ServicesManagerDialogs.summary
          when 'Import'
            # FIXME: TBD
          when 'Export'
            # FIXME: TBD
          when 'Read'
            # FIXME: TBD
          when 'Write' then ServicesManagerDialogs.save(:force => true, :startstop => false)
          when 'Reset'
            # FIXME: TBD
          when 'Packages'
            auto_ret = {}
          when 'GetModified' then ServicesManagerDialogs.modified?
          when 'SetModified'
            # FIXME: TBD
          else
            Builtins.y2error("Unknown Autoyast command: #{function}, #{params.inspect}")
            nil
        end
      end

    end
  end
end

Yast::Clients::ServicesManagerAuto.new.main
