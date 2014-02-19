#!/usr/bin/env rspec

require_relative 'test_helper'
require_relative '../src/lib/services-manager/systemctl'

module Yast
  describe Systemctl do
    include SystemctlStubs

    before do
      stub_systemctl
    end

    describe ".socket_units" do
      it "returns a list of socket unit ids registered with systemd" do
        socket_units = Systemctl.socket_units
        unit = socket_units.first
        expect(socket_units).to be_a(Array)
        expect(unit).to match(/.socket$/)
      end
    end
  end
end
