# encoding: utf-8

module Yast
  module Clients
    class ServicesManager < Client
      require 'fileutils'
      $: << File.expand_path(File.join(File.dirname(__FILE__), '../include/'))

      Yast.import('Wizard')

      require 'services-manager/shared.rb'

      def main
        Wizard.CreateDialog

        sm = Yast::Clients::ServicesManagerShared.new
        ret = false
        while(ret != true)
          if sm.main_dialog == :next
            ret = sm.save
          end
        end

        UI.CloseDialog
      end
    end
  end
end

Yast::Clients::ServicesManager.new.main
