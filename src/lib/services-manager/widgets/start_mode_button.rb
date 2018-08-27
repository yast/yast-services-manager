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
    # Menu button to set the start mode of a service
    class StartModeButton < Base

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
        MenuButton(id, label, items)
      end

      # All possible start modes that the button can return
      #
      # @return [Array<Symbol>]
      def self.all_start_modes
        ServicesManagerService.all_start_modes
      end

      # Help text
      #
      # @return [String]
      def help
        # TRANSLATORS: help text for the 'Start Mode' button
        _(
          "<b>Start Mode</b> allows to change the start mode of the service (On Boot, On Demand or Manually). " \
          "The possible start modes depend on the service."
        )
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
        Id(:start_mode_button)
      end

      # Button label
      #
      # @return [String]
      def label
        _("Start Mode")
      end

      # Possible start mode options to select for the given service, see {service_name}
      #
      # @return [Array<Yast::Term>]
      def items
        start_modes = ServicesManagerService.start_modes(service_name)

        ServicesManagerService.all_start_modes.each_with_object([]) do |mode, all|
          next unless start_modes.include?(mode)
          all << Item(Id(mode), ServicesManagerService.start_mode_to_human(mode))
        end
      end
    end
  end
end
