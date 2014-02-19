require 'services-manager/systemd_unit'

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

    class Socket < SystemdUnit
      def listening?
        properties.sub_state == "listening"
      end
    end
  end
  SystemdSocket = SystemdSocketClass.new
end
