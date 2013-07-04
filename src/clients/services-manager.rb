# encoding: utf-8

module Yast
  module Clients
    class ServicesManager < Client
      require 'fileutils'
      $: << File.expand_path(File.join(File.dirname(__FILE__), '../includes/'))

      Yast.import('Wizard')

      require 'services-manager/dialogs.rb'

      def main
        Wizard.CreateDialog

        dialogs = Yast::Clients::ServicesManagerDialogs.new
        ret = false
        while(ret != true)
          if dialogs.main_dialog == :next
            ret = dialogs.save
          end
        end

        UI.CloseDialog
      end
    end
  end
end

Yast::Clients::ServicesManager.new.main
