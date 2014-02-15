require 'services-manager/systemctl'
require 'services-manager/defer_systemctl'
require 'forwardable'

module Yast
  class SystemdSocketClass < Module
    UNIT_SUFFIX = ".socket"

    def find socket_name
      socket_name += UNIT_SUFFIX unless socket_name.match(/#{UNIT_SUFFIX}$/)
      @socket = Socket.new(socket_name)
    end

    class Socket
      include DeferSystemctl
      extend  Forwardable

      def_delegators :@properties, :id, :description, :load_state, :active_state

      def_delegators :@systemctl, :status, :start, :stop, :enable, :disable

      def initialize socket_name
        @systemctl = Systemctl.new(name: socket_name, type: :socket)
        @properties = systemctl.show(socket_name)
      end
    end
  end
  SystemdSocket = SystemdSocketClass.new
end
