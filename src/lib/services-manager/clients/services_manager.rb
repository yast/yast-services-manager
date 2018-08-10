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
Yast.import "Mode"

module Y2ServicesManager
  module Clients
    # Services Manager client
    #
    # It basically runs the dialog to manage services, see {Dialogs::ServicesManager}.
    class ServicesManager < Yast::Client
      include Yast::I18n

      # Constructor
      #
      # Journal package (yast2-journal) is not an strong dependency (only suggested).
      # Here the journal is tried to be loaded, avoiding to fail when the package is
      # not installed (see {#load_journal}).
      def initialize
        textdomain "services-manager"

        load_journal
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

      # The log button only is included if YaST Journal is installed
      def run_dialog
        Dialogs::ServicesManager.new(
          show_logs_button: journal_loaded?,
          show_start_stop_button: !Yast::Mode.config,
          show_apply_button: !Yast::Mode.config
        ).run
      end

    private

      # Tries to load the journal package
      #
      # @return [Boolean] true if the package is correctly loaded; false otherwise.
      def load_journal
        require "y2journal"
      rescue LoadError
        false
      end

      # Checks whether the journal is loaded
      #
      # @return [Boolean]
      def journal_loaded?
        !defined?(::Y2Journal).nil?
      end
    end
  end
end
