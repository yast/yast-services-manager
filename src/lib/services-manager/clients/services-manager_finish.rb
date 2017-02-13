require "installation/finish_client"

module Servicesmanager
  module Clients
  Yast.import "ServicesManagerTarget"
  Yast.import "ServicesManagerService"

    class ServicesManagerFinish < ::Installation::FinishClient
      def title
        textdomain "installation"
        _("Setting default target and system services ...")
      end

      def write
        ServicesManagerTarget.save
        ServicesManagerService.save
      end
    end
  end
end
