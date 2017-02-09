require "installation/finish_client"

module Installation
  module Clients
  import "ServicesManagerTarget"
  import "ServicesManagerService"

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
