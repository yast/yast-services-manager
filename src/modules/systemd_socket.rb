require 'services-manager/systemctl'
require 'forwardable'

module Yast
  class SystemdSocketClass < Module
    UNIT_SUFFIX = ".socket"

    def find socket_name, properties: {}
      socket_name += UNIT_SUFFIX unless socket_name.match(/#{UNIT_SUFFIX}$/)
      socket = Socket.new(socket_name, properties)
      return if socket.properties.not_found?
      socket
    end

    def all properties: {}
      sockets = Systemctl.socket_units.map do |socket_unit|
        Socket.new(socket_unit, properties)
      end
      sockets.select {|s| s.properties.supported?}
    end

    class Socket
      extend  Forwardable

      def_delegators :@systemctl, :properties, :start, :stop, :enable, :disable

      attr_reader :systemctl

      def initialize socket_name, properties
        @systemctl = Systemctl.new(name: socket_name, type: :socket, properties: properties)
      end

      def name
        properties.id
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
