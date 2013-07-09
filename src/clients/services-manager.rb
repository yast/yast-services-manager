# encoding: utf-8

module Yast
  module Clients
    class ServicesManager < Client
      Yast.import('Wizard')
      Yast.import('ServicesManagerDialogs')

      def main
        Wizard.CreateDialog

        ret = false
        while(ret != true)
          if ServicesManagerDialogs.main_dialog == :next
            ret = ServicesManagerDialogs.save
          end
        end

        UI.CloseDialog
      end
    end
  end
end

Yast::Clients::ServicesManager.new.main
