# encoding: utf-8

module Yast
  module Clients
    class ServicesManagerClient < Client
      Yast.import('Wizard')
      Yast.import('ServicesManager')

      def main
        Wizard.CreateDialog

        ret = false
        while(ret != true)
          if ServicesManager.main_dialog == :next
            ret = ServicesManager.save
          end
        end

        UI.CloseDialog
      end
    end
  end
end

Yast::Clients::ServicesManagerClient.new.main
