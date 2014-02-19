#!/usr/bin/env rspec

require_relative "test_helper"

module Yast
  import 'SystemdSocket'

  describe SystemdSocket do
    include SystemdSocketStubs

    before do
      stub_sockets
    end

    describe ".find" do
      it "returns the unit object as specified in parameter" do
        socket = SystemdSocket.find "iscsid"
        expect(socket).to be_a(SystemdUnit)
        expect(socket.unit_type).to eq("socket")
        expect(socket.unit_name).to eq("iscsid")
      end
    end

    describe ".all" do
      it "returns all supported sockets found" do
        sockets = SystemdSocket.all
        expect(sockets).to be_a(Array)
        sockets.each {|s| expect(s.unit_type).to eq('socket')}
      end
    end

    describe "#listening?" do
      it "returns true if the socket is accpeting connections" do
        socket = SystemdSocket.find "iscsid"
        expect(socket.listening?).to be_true
      end
    end
  end
end
