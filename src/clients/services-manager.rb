# encoding: utf-8

module Yast
  module Clients
    class ServicesManagerClient < Client
      Yast.import('Wizard')
      Yast.import('ServicesManager')

      def main
        Wizard.CreateDialog

        final_state = (ServicesManager.main_dialog == :next)
        if final_state
          ret = ServicesManager.save
        end

        UI.CloseDialog
        final_state
      end
    end
  end
end

Yast::Clients::ServicesManagerClient.new.main
