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

module Y2ServicesManager
  # This class implements a placeholder for real system services. It is used during 1st stage to
  # hold configuration for those systems that will be available in the installed system (but are
  # unknown during 1st stage).
  class SystemServicePlaceholder
    # @return [String] Service name
    attr_reader :name

    # Constructor
    #
    # @param name [String] Service name
    def initialize(name)
      @name
    end

    # Returns the corresponding systemd service
    #
    # @return [Yast::SystemdServiceClass::Service,nil] Systemd service or nil when it is unknown
    def service
      @service ||= Yast::SystemdService.find(name)
    end

    # Returns the service socket if it exists
    #
    # @return [Yast::SystemdSocketClass::Socket] Systemd socket or nil when it does not exist
    def socket
      service.socket
    end

    def static?
      true
    end

    def start_mode
      [:boot, :manual]
    end

    def active
      false
    end

    alias_method :active?, :active

    def running?
      false
    end

    def description
      ""
    end
  end
end
