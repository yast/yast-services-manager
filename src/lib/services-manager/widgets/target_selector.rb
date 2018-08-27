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
    # Widget to select a systemd target
    class TargetSelector < Base

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
        ComboBox(id, Opt(:notify), label, system_targets_items)
      end

      # Returns selected target
      #
      # @return [Symbol]
      def value
        UI.QueryWidget(id, :Value)
      end

      # Refreshes the widget content
      def refresh
        UI.ChangeWidget(id, :Items, system_targets_items)
      end

      # Help text
      #
      # @return [String]
      def help
        # TRANSLATORS: help text for the 'Default System Target' selectbox
        _("<b>Default System Target</b> Allows to select the Systemd defatult target.")
      end

    private

      # Default widget id
      #
      # @see Base#default_id
      #
      # @return [Yast::Term]
      def default_id
        Id(:target_selector)
      end

      # Widget label
      #
      # @return [String]
      def label
        _("Default System &Target")
      end

      # All possible systemd targets
      #
      # @return [Array<Yast::Term>]
      def system_targets_items
        ServicesManagerTarget.all.collect do |target, target_def|
          label = target_def[:description] || target
          Item(Id(target), label, (target == ServicesManagerTarget.default_target))
        end
      end
    end
  end
end
