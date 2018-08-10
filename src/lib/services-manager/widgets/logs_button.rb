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

module Y2ServicesManager
  module Widgets
    # Button to show logs of a service
    class LogsButton < Base

      # Constructor
      #
      # @param id [Symbol] widget id
      def initialize(id: nil)
        textdomain "services-manager"
        super
      end

      # Returns the plain libyui widget
      #
      # @return [Yast::Term]
      def widget
        PushButton(id, label)
      end

    private

      # Default widget id
      #
      # @see Base#default_id
      #
      # @return [Yast::Term]
      def default_id
        Id(:logs_button)
      end

      # Button label
      #
      # @return [String]
      def label
        _("Show &Log")
      end
    end
  end
end
