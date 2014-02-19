#!/usr/bin/env rspec

require_relative "test_helper"

module Yast
  describe SystemdSocket do
    include SystemdSocketStubs

    before do
      stub_sockets
    end

    describe ".find" do
      it "returns the unit object as specified in parameter" do
        socket = SystemdSocket.find "iscsid"
        expect(socket).to be_a(SystemdUnit)
        expect(socket.unit_type).to equal("socket")
        expect(socket.unit_name).to equal("iscsid.socket")
      end
    end

    desribe ".all" do
      it "returns all supported sockets found" do
        sockets = SystemdSocket.all
        expect(sockets).to be_a(Array)
        sockets.each {|s| expect(s).to be_a(SystemdSocket)}
      end
    end

    describe "#listening?" do
      socket = SystemdSocket.find "iscsid"
      expect(socket.listening?).to be_true
    end
  end
end
