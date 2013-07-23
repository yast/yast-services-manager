# encoding: utf-8

module Yast
  module Clients
    class ServicesManagerClient < Client
      Yast.import('Wizard')
      Yast.import('ServicesManager')

      def main
        Wizard.CreateDialog

        final_state = false
        while(true)
          if (ServicesManager.main_dialog == :next)
            final_state = ServicesManager.save
            break if final_state
          else
            break
          end
        end

        UI.CloseDialog
        final_state
      end
    end
  end
end

Yast::Clients::ServicesManagerClient.new.main
