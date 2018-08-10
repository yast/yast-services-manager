require "installation/finish_client"

Yast.import "ServicesManager"
Yast.import "Report"
Yast.import "HTML"

module ServicesManager
  module Clients
    class ServicesManagerFinish < ::Installation::FinishClient
      def title
        textdomain "installation"
        _("Setting default target and system services ...")
      end

      # Writes services configuration changes
      #
      # It displays a warning when some error occurs.
      #
      # @return [Boolean] Returns true if the operation was successful; false otherwise.
      def write
        return true if ServicesManager.save
        errors = ServicesManager.errors
        Yast::Report.LongWarning(Yast::HTML.List(errors)) unless errors.empty?
        false
      end
    end
  end
end
