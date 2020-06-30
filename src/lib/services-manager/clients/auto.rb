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
require "installation/auto_client"
Yast.import "ServicesManager"

module Y2ServicesManager
  module Clients
    class Auto < ::Installation::AutoClient
      def initialize
        textdomain "services-manager"
      end

      # @see ::Installation::AutoClient#change
      def change
        WFM.CallFunction("services-manager")
      end

      # @see ::Installation::AutoClient#summary
      def summary
        Yast::ServicesManager.auto_summary
      end

      # @see ::Installation::AutoClient#import
      def import(param)
        Yast::ServicesManager.import(param)
      end

      # @see ::Installation::AutoClient#export
      def export(target: :default)
        Yast::ServicesManager.export(target: target)
      end

      # @see ::Installation::AutoClient#read
      def read
        Yast::ServicesManager.read
      end

      # @see ::Installation::AutoClient#write
      def write
        Yast::WFM.CallFunction("services-manager_finish", ["Write"])
      end

      # @see ::Installation::AutoClient#reset
      def reset
        Yast::ServicesManager.reset
      end

      # @see ::Installation::AutoClient#packages
      def packages
        {}
      end

      # @see ::Installation::AutoClient#modified?
      def modified?
        Yast::ServicesManager.modified?
      end

      # @see ::Installation::AutoClient#modified
      def modified
        Yast::ServicesManager.modify
      end
    end
  end
end
