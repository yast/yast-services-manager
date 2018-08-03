# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "services-manager/dialogs/services_manager"

Yast.import "CommandLine"

module Y2ServicesManager
  module Clients
    # Services Manager client
    #
    # It basically runs the dialog to manage services, see {Dialogs::ServicesManager}.
    class ServicesManager < Yast::Client
      include Yast::I18n

      def initialize
        textdomain "services-manager"
      end

      def run
        cmdline = {
          "id"         => "services-manager",
          # translators: command line help text for services-manager module
          "help"       => _(
                            "Systemd target and services configuration module.\n" +
                            "Use systemctl for commandline services configuration."
                            ),
          "guihandler" => fun_ref(method(:run_dialog), "boolean ()")
        }

        CommandLine.Run(cmdline)
      end

      def run_dialog
        Dialogs::ServicesManager.new.run
      end
    end
  end
end
