require 'services-manager/systemctl'
require 'forwardable'

module Yast
  class SystemdSocketClass < Module
    UNIT_SUFFIX = ".socket"

    def find socket_name, properties={}
      socket_name += UNIT_SUFFIX unless socket_name.match(/#{UNIT_SUFFIX}$/)
      socket = Socket.new(socket_name, properties)
      return if socket.systemctl.properties.not_found?
      socket
    end

    def all
      #
    end

    class Socket
      extend  Forwardable

      def_delegators :@systemctl, :properties, :start, :stop, :enable, :disable

      attr_reader :systemctl

      def initialize socket_name, properties
        @systemctl = Systemctl.new(name: socket_name, type: :socket, properties: properties)
      end

      def active?
        properties.active?
      end

      def enabled?
        properties.enabled?
      end

      def description
        properties.description
      end

      def status
        properties.status
      end

      def listening?
        properties.sub_state == "listening"
      end
    end
  end
  SystemdSocket = SystemdSocketClass.new
end
