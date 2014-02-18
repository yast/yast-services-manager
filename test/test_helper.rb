require 'rspec'

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import 'ServicesManager'

module SystemctlStubs

  def socket_stubs
    stub_socket_unit_files
    stub_socket_units
    stub_unit_command
  end

  def stub_unit_command success: true
    Yast::Systemctl.stub(:scr_execute).and_return(
      OpenStruct.new \
      :stdout => 'success',
      :stderr => ( success ? '' : 'failure'),
      :exit   => ( success ? 0  : 1 )
    )
#   Yast::Systemctl.any_instance.stub(:unit_command).and_return(
#     OpenStruct.new :stdout=>'', :stderr=>'', :exit=>0
#   )
  end

  def stub_socket_unit_files
    Yast::Systemctl.stub(:list_unit_files).and_return(<<LIST
avahi-daemon.socket          enabled
cups.socket                  enabled
dbus.socket                  static
dm-event.socket              disabled
iscsid.socket                disabled
LIST
    )
  end

  def stub_socket_units
    Yast::Systemctl.stub(:list_units).and_return(<<LIST
avahi-daemon.socket          loaded active   running   Avahi mDNS/DNS-SD Stack Activation Socket
cups.socket                  loaded active   running   CUPS Printing Service Sockets
dbus.socket                  loaded active   running   D-Bus System Message Bus Socket
dm-event.socket              loaded inactive dead      Device-mapper event daemon FIFOs
iscsid.socket                loaded active   listening Open-iSCSI iscsid Socket
lvm2-lvmetad.socket          loaded inactive dead      LVM2 metadata daemon socket
pcscd.socket                 loaded active   listening PC/SC Smart Card Daemon Activation Socket
LIST
    )
  end

end

