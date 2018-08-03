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
require "services-manager/widgets/base"

Yast.import "ServicesManager"

module Y2ServicesManager
  module Widgets
    # Button to start or stop a service
    class StartStopButton < Base

      # Constructor
      #
      # @param service_name [String] name of a service
      # @param id [Symbol] widget id
      def initialize(service_name, id: nil)
        textdomain "services-manager"

        super(id: id)
        @service_name = service_name
      end

      # Returns the plain libyui widget
      #
      # @return [Yast::Term]
      def widget
        PushButton(id, label)
      end

    private

      # @return [String] name of the service
      attr_reader :service_name

      # Default widget id
      #
      # @see Base#default_id
      #
      # @return [Yast::Term]
      def default_id
        Id(:start_stop_button)
      end

      # Label to show depending on the service state
      #
      # @return [String]
      def label
        ServicesManagerService.active(service_name) ? _("&Stop") : _("&Start")
      end
    end
  end
end
