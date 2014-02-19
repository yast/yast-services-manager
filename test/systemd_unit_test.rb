#!/usr/bin/env rspec

require_relative 'test_helper'
require_relative '../src/lib/services-manager/systemd_unit'

module Yast
  describe SystemdUnit do
    include SystemdSocketStubs

    before do
      stub_sockets
    end

    describe "#new" do
      it "creates a new systemd unit name from full unit name" do
        expect { SystemdUnit.new("random.socket") }.not_to raise_error
        expect { SystemdUnit.new("random")        }.to raise_error
      end

      it "allows to create only supported units" do
        expect { SystemdUnit.new("my.socket")      }.not_to raise_error
        expect { SystemdUnit.new("default.target") }.not_to raise_error
        expect { SystemdUnit.new("sshd.service")   }.not_to raise_error
        expect { SystemdUnit.new("random.unit")    }.to raise_error
      end
    end

    describe "#stop" do
      it "stops (deactivates) the unit and reloads its properties" do
        stub_unit_command
        unit = SystemdUnit.new("my.socket")
        properties = unit.properties
        expect(unit.stop).to be_true
        expect(unit.properties).not_to equal(properties)
      end

      it "fails to stop the unit due to an error" do
        stub_unit_command(:success=>false)
        unit = SystemdUnit.new("my.socket")
        expect(unit.stop).to be_false
        expect(unit.errors).not_to be_empty
      end

    end

    describe "#start" do
      it "starts (activates) the unit and reloads its properties" do
        stub_unit_command(:success=>true)
        unit = SystemdUnit.new("my.socket")
        properties = unit.properties
        expect(unit.start).to be_true
        expect(unit.properties).not_to equal(properties)
      end

      it "fails to start the unit" do
        stub_unit_command(:success=>false)
        unit = SystemdUnit.new("my.socket")
        expect(unit.start).to be_false
        expect(unit.errors).not_to be_empty
      end
    end

    describe "#enable" do
      it "enables the unit successfully" do
        stub_unit_command(:success=>true)
        unit = SystemdUnit.new("your.socket")
        expect(unit.enable).to be_true
      end

      it "fails to enable the unit" do
        stub_unit_command(:success=>false)
        unit = SystemdUnit.new("your.socket")
        expect(unit.enable).to be_false
        expect(unit.errors).not_to be_empty
      end

      it "triggers reloading of unit properties" do
        stub_unit_command(:success=>true)
        unit = SystemdUnit.new("your.socket")
        properties = unit.properties
        unit.enable
        expect(unit.properties).not_to equal(properties)
      end
    end

    describe "#show" do
      it "always returns new unit properties object" do
        unit = SystemdUnit.new("startrek.socket")
        expect(unit.show).not_to equal(unit.show)
      end
    end

    describe "#properties" do

      it "has default basic properties" do
        unit = SystemdUnit.new("iscsi.socket")
        SystemdUnit::DEFAULT_PROPERTIES.keys.each do |property|
          expect(unit.properties.to_h.keys).to include(property)
        end
      end

      it "provides status properties" do
        unit = SystemdUnit.new("something.service")
        expect(unit).to respond_to(:enabled?)
        expect(unit).to respond_to(:active?)
        expect(unit).to respond_to(:running?)
        expect(unit).to respond_to(:loaded?)
        expect(unit).to respond_to(:supported?)
        expect(unit).to respond_to(:not_found?)
        expect(unit).to respond_to(:path)
      end

      it "accepts properties parameter to extend the unit properties" do
        unit = SystemdUnit.new("sshd.service", :requires => "Requires", :wants => "Wants")
        expect(unit.properties.requires).not_to be_nil
        expect(unit.properties.wants).not_to be_nil
      end
    end
  end
end
