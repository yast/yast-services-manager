#!/usr/bin/env rspec

require_relative 'test_helper'
require_relative '../src/lib/services-manager/systemctl'

module Yast
  describe Systemctl do
    include SystemctlStubs

    before do
      socket_stubs
    end

    describe ".socket_units" do
      it "returns a list of socket unit ids registered with systemd" do
        socket_units = Systemctl.socket_units
        unit = socket_units.first
        expect(socket_units).to be_a(Array)
        expect(unit).to match(/.socket$/)
      end
    end

    describe "#new" do
      it "expects a unit name with unit type suffix" do
        expect {Systemctl.new("random.socket") }.not_to raise_error
        expect {Systemctl.new("random.target") }.not_to raise_error
        expect {Systemctl.new("random.service")}.not_to raise_error
        expect {Systemctl.new("random.random") }.to raise_error
        expect {Systemctl.new("random")        }.to raise_error
      end
    end

    describe "#stop" do
      it "stops (deactivates) the unit" do
        unit = Systemctl.new("my.socket")
        expect(unit.stop).to be_true
      end

      it "fails to stop the unit" do
        stub_unit_command(:success=>false)
        unit = Systemctl.new("my.socket")
        expect(unit.stop).to be_false
        expect(unit.errors).not_to be_empty
      end

      it "triggers reloading of unit properties" do
        unit = Systemctl.new("my.socket")
        properties = unit.properties
        unit.stop
        expect(unit.properties.object_id).not_to eq(properties.object_id)
      end
    end

    describe "#start" do
      it "starts (activates) the unit" do
        unit = Systemctl.new("my.socket")
        expect(unit.start).to be_true
      end

      it "fails to start the unit" do
        stub_unit_command(:success=>false)
        unit = Systemctl.new("my.socket")
        expect(unit.start).to be_false
        expect(unit.errors).not_to be_empty
      end

      it "triggers reloading of unit properties" do
        unit = Systemctl.new("my.socket")
        properties = unit.properties
        unit.start
        expect(unit.properties.object_id).not_to eq(properties.object_id)
      end
    end

    describe "#enable" do
      it "enables the unit successfully" do
        unit = Systemctl.new("your.socket")
        expect(unit.enable).to be_true
      end

      it "fails to enable the unit" do
        stub_unit_command(:success=>false)
        unit = Systemctl.new("your.socket")
        expect(unit.enable).to be_false
        expect(unit.errors).not_to be_empty
      end

      it "triggers reloading of unit properties" do
        unit = Systemctl.new("your.socket")
        properties = unit.properties
        unit.enable
        expect(unit.properties.object_id).not_to eq(properties.object_id)
      end
    end

    describe "#show" do
      it "always returns new unit properties object" do
        unit = Systemctl.new("startrek.socket")
        expect(unit.show.object_id).not_to eq(unit.show.object_id)
      end
    end

    describe "#properties" do
      properties_sample = File.read(File.join(__dir__, 'files', 'socket_properties'))
      it "has default properties" do
        unit = Systemctl.new("iscsi.socket")
        Systemctl::DEFAULT_PROPERTIES.keys.each do |property|
          expect(unit.properties[property]).not_to be_nil
        end
      end

      it "can be extended on demand by other unit properties" do
      end
    end
  end
end
