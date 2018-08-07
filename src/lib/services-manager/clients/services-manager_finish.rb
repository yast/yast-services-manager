require "installation/finish_client"

module ServicesManager
  module Clients
    Yast.import "ServicesManagerTarget"
    Yast.import "ServicesManagerService"

    class ServicesManagerFinish < ::Installation::FinishClient
      def title
        textdomain "installation"
        _("Setting default target and system services ...")
      end

      def write
        WFM.CallFunction("services-manager_auto", ["Write"])
      end
    end
  end
end
