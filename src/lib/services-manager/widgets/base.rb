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

Yast.import "UI"

module Y2ServicesManager
  module Widgets
    # Base class for widgets
    #
    # TODO: Currently this is not using CWM but plain libyui widgets. This should be
    # replaced by proper CWM widgets.
    class Base
      include Yast
      include Yast::I18n
      include Yast::UIShortcuts

      # @!method id
      #   Widget id
      #
      #   @return [Yast::Term]
      attr_reader :id

      # Constructor
      #
      # @param id [Symbol] widget id
      def initialize(id: nil)
        @id = id ? Id(id) : default_id
      end

    private

      # Default widget id
      #
      # @note Each class should redefine this method
      #
      # @return [Yast::Term]
      def default_id
        Id(:new_widget)
      end
    end
  end
end
