require 'services-manager/systemctl'
require 'services-manager/defer_systemctl'
require 'forwardable'

module Yast
  class SystemdSocketClass < Module
    UNIT_SUFFIX = ".socket"

    def find socket_name
      socket_name += UNIT_SUFFIX unless socket_name.match(/#{UNIT_SUFFIX}$/)
      socket = Socket.new(socket_name)
      return if socket.properties.not_found?
      socket
    end

    def all
      #
    end

    class Socket
      include DeferredExecution
      extend  Forwardable

      def_delegators :@properties, :id, :pid, :description, :loaded?, :active?, :enabled?

      def_delegators :@systemctl, :status, :start, :stop, :enable, :disable

      def initialize socket_name
        @systemctl = Systemctl.new(name: socket_name, type: :socket)
        @properties = systemctl.properties(socket_name)
      end

      def listening?
        properties.sub_state == "listening"
      end

      def save
        execute_deferred
      end
    end
  end
  SystemdSocket = SystemdSocketClass.new
end
