#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2014-2018] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "test_helper"

Yast.import "ServicesManager"
require "services-manager/services_manager_profile"

describe Yast::ServicesManagerServiceClass do
  subject { Yast::ServicesManagerServiceClass.new }

  let(:cups) do
    instance_double(
      Yast2::SystemService, name: "cups", description: "CUPS", start: true, stop: true,
      state: "active", substate: "running", changed?: false, start_mode: :on_boot,
      save: nil, refresh: nil, errors: {}, found?: true
    )
  end

  let(:dbus) do
    instance_double(
      Yast2::SystemService, name: "dbus", changed?: true, active?: true,
      running?: true, refresh: nil, save: nil, errors: {}, found?: true
    )
  end

  let(:services) do
    { "cups" => cups, "dbus" => dbus }
  end

  let(:loader) do
    instance_double(Y2ServicesManager::ServiceLoader, read: services)
  end

  before do
    allow(Y2ServicesManager::ServiceLoader).to receive(:new)
      .and_return(loader)
  end

  describe "#services" do
    it "returns the list of services" do
      expect(subject.services).to eq(services)
    end

    context "during autoinstallation or autoupgrade" do
      before do
        allow(Yast::Mode).to receive(:auto).and_return(true)
      end

      it "returns an empty hash" do
        expect(subject.services).to eq({})
      end

      context "after importing a list of services" do
        let(:profile) { Yast::ServicesManagerProfile.new("services" => {"enable" => ["cups"]}) }

        before do
          subject.import(profile)
        end

        it "returns the imported services" do
          expect(subject.services.size).to eq(1)
          service = subject.services.values.first
          expect(service.name).to eq("cups")
        end
      end
    end
  end

  describe "#find" do
    context "when the service exists" do
      it "returns the service" do
        expect(subject.find("cups")).to eq(cups)
      end
    end

    context "when the service does not exist" do
      it "returns nil" do
        expect(subject.find("unknown")).to be_nil
      end
    end
  end

  describe "#activate" do
    it "sets the service to be started" do
      expect(cups).to receive(:start)
      subject.activate("cups")
    end

    it "returns true" do
      expect(subject.activate("cups")).to eq(true)
    end

    context "when the service does not exist" do
      it "returns false" do
        expect(subject.activate("unknown")).to eq(false)
      end
    end
  end

  describe "#deactivate" do
    it "sets the service to be stopped" do
      expect(cups).to receive(:stop)
      subject.deactivate("cups")
    end

    it "returns true" do
      expect(subject.deactivate("cups")).to eq(true)
    end

    context "when the service does not exist" do
      it "returns false" do
        expect(subject.deactivate("unknown")).to eq(false)
      end
    end
  end

  describe "#active" do
    let(:active?) { true }

    before do
      allow(cups).to receive(:active?).and_return(active?)
    end

    context "when the service is active" do
      it "returns true" do
        expect(subject.active("cups")).to eq(true)
      end
    end

    context "when the service is inactive" do
      let(:active?) { false }

      it "returns false" do
        expect(subject.active("cups")).to eq(false)
      end
    end

    context "when the service does not exist" do
      it "returns false" do
        expect(subject.active("unknown")).to eq(false)
      end
    end
  end

  describe "#changed_value?" do
    let(:changed_value?) { true }

    before do
      allow(cups).to receive(:changed?).and_return(changed_value?)
    end

    context "when the given value has been changed" do
      it "returns true" do
        expect(subject.changed_value?("cups", :active)).to eq(true)
      end
    end

    context "when the given value has not been changed" do
      let(:changed_value?) { false }

      it "returns false" do
        expect(subject.changed_value?("cups", :active)).to eq(false)
      end
    end

    context "when the service does not exist" do
      it "returns false" do
        expect(subject.changed_value?("unknown", :active)).to eq(false)
      end
    end
  end

  describe "#enabled" do
    let(:start_mode) { :on_boot }

    before do
      allow(cups).to receive(:start_mode).and_return(start_mode)
    end

    context "when the start mode is set to a value different from :manual" do
      it "returns true" do
        expect(subject.enabled("cups")).to eq(true)
      end
    end

    context "when start mode is set to :manual" do
      let(:start_mode) { :manual }

      it "returns false" do
        expect(subject.enabled("cups")).to eq(false)
      end
    end

    context "when the service does not exist" do
      it "returns false" do
        expect(subject.enabled("unknown")).to eq(false)
      end
    end
  end

  describe "#state" do
    it "returns service's active state" do
      expect(subject.state("cups")).to eq(cups.state)
    end

    context "when the service does not exist" do
      it "returns false" do
        expect(subject.state("unknown")).to eq(false)
      end
    end
  end

  describe "#substate" do
    it "returns service's sub-state" do
      expect(subject.substate("cups")).to eq(cups.substate)
    end

    context "when the service does not exist" do
      it "returns false" do
        expect(subject.substate("unknown")).to eq(false)
      end
    end
  end

  describe "#modified_services" do
    it "returns modified services" do
      expect(subject.modified_services).to eq([dbus])
    end
  end

  describe "#read" do
    it "loads the list of services from ServiceLoader" do
      expect(loader).to receive(:read)
      subject.read
    end

    context "when services are already read" do
      before do
        subject.read
      end

      it "does not try to read them again" do
        expect(loader).to_not receive(:read)
        subject.read
      end
    end
  end

  describe "#reload" do
    it "loads the list of services from ServiceLoader" do
      expect(loader).to receive(:read)
      subject.reload
    end

    context "when services are already read" do
      before do
        subject.reload
      end

      it "reads them again" do
        expect(loader).to receive(:read)
        subject.reload
      end
    end
  end

  describe "#reset" do
    it "resets all services" do
      services.values.each { |s| expect(s).to receive(:reset) }
      subject.reset
    end
  end

  describe "#export" do
    before do
      allow(cups).to receive(:static?)
      allow(cups).to receive(:start_mode)
      allow(dbus).to receive(:static?)
      allow(dbus).to receive(:start_mode)
    end

    let(:exported_services) { subject.export }

    context "when service is proposed to be enabled" do
      before do
        allow(Yast::ServicesProposal).to receive(:enabled_services).and_return(["sshd"])
      end

      it "exports the services as enabled" do
        expect(exported_services["enable"]).to include("sshd")
      end
    end

    context "when service is proposed to be disabled" do
      before do
        allow(Yast::ServicesProposal).to receive(:disabled_services).and_return(["httpd"])
      end

      it "exports the service as disabled" do
        expect(exported_services["disable"]).to include("httpd")
      end
    end

    context "when is a static service (user cannot enable or disable it)" do
      before do
        allow(dbus).to receive(:static?).and_return(true)
      end

      context "and is enabled" do
        before do
          allow(dbus).to receive(:start_mode).and_return(:on_boot)
        end

        it "does not export the service as enabled" do
          expect(exported_services["enable"]).to_not include("dbus")
        end

        it "does not export the service as disabled" do
          expect(exported_services["disable"]).to_not include("dbus")
        end
      end

      context "and is disabled" do
        before do
          allow(dbus).to receive(:start_mode).and_return(:manual)
        end

        it "does not export the service as enabled" do
          expect(exported_services["enable"]).to_not include("dbus")
        end

        it "exports the service as disabled" do
          expect(exported_services["disable"]).to include("dbus")
        end
      end
    end

    context "when is not a static sevice (user can enable/disable it)" do
      before do
        allow(dbus).to receive(:static?).and_return(false)
      end

      context "and is set to be started on boot" do
        before do
          allow(dbus).to receive(:start_mode).and_return(:on_boot)
        end

        it "exports the service as enabled" do
          expect(exported_services["enable"]).to include("dbus")
        end
      end

      context "and is set to be started on demand" do
        before do
          allow(dbus).to receive(:start_mode).and_return(:on_demand)
        end

        it "exports the services to be started on demand" do
          exported = subject.export
          expect(exported["on_demand"]).to include("dbus")
          expect(exported["enable"]).to_not include("dbus")
          expect(exported["disable"]).to_not include("dbus")
        end
      end

      context "and is disabled" do
        before do
          allow(dbus).to receive(:start_mode).and_return(:manual)
        end

        it "does not export the service as enabled" do
          expect(exported_services["enable"]).to_not include("dbus")
        end
      end
    end

    context "when service has changes (modified by user)" do
      before do
        allow(cups).to receive(:changed?).and_return(true)
      end

      context "and was disabled" do
        before do
          allow(cups).to receive(:start_mode).and_return(:manual)
        end

        it "exports the service as disabled" do
          expect(exported_services["enable"]).to_not include("cups")
          expect(exported_services["disable"]).to include("cups")
        end
      end

      context "and was set to be started on boot" do
        before do
          allow(cups).to receive(:start_mode).and_return(:on_boot)
        end

        it "exports the service as enable" do
          expect(exported_services["enable"]).to include("cups")
          expect(exported_services["disable"]).to_not include("cups")
        end
      end

      context "and was set to be started on demand" do
        before do
          allow(cups).to receive(:start_mode).and_return(:on_demand)
        end

        it "exports the service to be started on demand" do
          expect(exported_services["on_demand"]).to include("cups")
          expect(exported_services["enable"]).to_not include("cups")
          expect(exported_services["disable"]).to_not include("cups")
        end
      end

      # FIXME this scenario should be fixed, see {Yast::ServicesManagerServiceClass#export} method
      context "and was disabled by user but also proposed to be enabled" do
        before do
          allow(cups).to receive(:start_mode).and_return(:manual)
          allow(Yast::ServicesProposal).to receive(:enabled_services).and_return(["cups"])
        end

        it "exports the service as both, enabled and disabled" do
          expect(exported_services["enable"]).to include("cups")
          expect(exported_services["disable"]).to include("cups")
        end
      end
    end
  end

  describe "#enable" do
    it "sets the service as enabled" do
      expect(dbus).to receive(:start_mode=).with(:on_boot)

      subject.enable("dbus")
    end
  end

  describe "#disable" do
    it "sets the service as disable" do
      expect(dbus).to receive(:start_mode=).with(:manual)

      subject.disable("dbus")
    end
  end

  describe "#import" do
    let(:profile_services) do
      [
        Yast::ServicesManagerProfile::Service.new("dbus", :on_boot),
        Yast::ServicesManagerProfile::Service.new("cups", :on_demand),
        Yast::ServicesManagerProfile::Service.new("libvirtd", :manual),
      ]
    end

    let(:libvirtd) do
      instance_double(Yast2::SystemService, name: "libvirtd")
    end

    let(:services) do
      { "cups" => cups, "dbus" => dbus, "libvirtd" => libvirtd }
    end

    let(:profile) do
      instance_double(Yast::ServicesManagerProfile, services: profile_services)
    end

    before do
      allow(subject).to receive(:set_start_mode)
    end

    it "sets the start mode for the given services" do
      expect(subject).to receive(:set_start_mode).with("dbus", :on_boot)
      expect(subject).to receive(:set_start_mode).with("cups", :on_demand)
      expect(subject).to receive(:set_start_mode).with("libvirtd", :manual)
      subject.import(profile)
    end

    it "returns true" do
      expect(subject.import(profile)).to eq(true)
    end

    context "when an unknown service is specified" do
      let(:profile_services) do
        [Yast::ServicesManagerProfile::Service.new("unknown", :on_boot)]
      end

      it "logs an error" do
        expect(subject.log).to receive(:error).with(/don't exist on this system/)
        subject.import(profile)
      end

      it "returns false" do
        expect(subject.import(profile)).to eq(false)
      end
    end

    context "when an invalid start mode is specified" do
      let(:profile_services) do
        [Yast::ServicesManagerProfile::Service.new("cups", :fail)]
      end

      before do
        allow(subject).to receive(:set_start_mode).with("cups", :fail).and_raise(ArgumentError)
      end

      it "logs an error" do
        allow(subject.log).to receive(:error)
        expect(subject.log).to receive(:error).with(/Invalid/)
        subject.import(profile)
      end

      it "returns false" do
        expect(subject.import(profile)).to eq(false)
      end
    end
  end

  describe "#save" do
    let(:initial) { false }

    before do
      allow(Yast::Stage).to receive(:initial).and_return(initial)
      allow(dbus).to receive(:changed?).and_return(true)
    end

    it "saves and resets changed services" do
      expect(dbus).to receive(:save).with(keep_state: false)
      expect(cups).to_not receive(:save)
      subject.save
    end

    it "does not refresh services" do
      expect(dbus).to_not receive(:refresh)
      expect(cups).to_not receive(:refresh)
      subject.save
    end

    context "when a service registers an error" do
      before do
        allow(dbus).to receive(:errors).and_return({active: true})
        allow(dbus).to receive(:save).and_return(false)
      end

      it "returns false" do
        expect(subject.save).to eq(false)
      end
    end

    context "on 1st stage" do
      let(:initial) { true }

      it "refresh services before saving them" do
        expect(dbus).to receive(:refresh).ordered
        expect(dbus).to receive(:save).ordered
        subject.save
      end

      it "saves all services not modifying the current status" do
        expect(dbus).to receive(:save).with(keep_state: true)
        subject.save
      end
    end

    context "on autoinstallation or autoupgrade" do
      before do
        allow(Yast::Mode).to receive(:auto).and_return(true)
        allow(subject).to receive(:services).and_return({"dbus" => dbus})
      end

      it "refresh services before saving them" do
        expect(dbus).to receive(:refresh).ordered
        expect(dbus).to receive(:save).ordered
        subject.save
      end
    end

    context "when no service is changed" do
      it "returns true" do
        expect(subject.save).to eq(true)
      end
    end
  end

  describe "#errors" do
    before do
      allow(dbus).to receive(:errors).and_return({active: true, start_mode: :on_boot})
      allow(dbus).to receive(:start_mode).and_return(:on_boot)
      allow(cups).to receive(:found?).and_return(false)
    end

    it "returns the list of service errors" do
      subject.save
      expect(subject.errors).to contain_exactly(
        "Service 'cups' was not found.",
        "Could not start 'dbus' which is currently running.",
        "Could not set 'dbus' to be started on boot."
      )
    end

    context "when save has not been called" do
      it "returns an empty array" do
        expect(subject.errors).to be_empty
      end
    end
  end

  describe "#switch" do
    let(:active?) { true }

    before do
      allow(cups).to receive(:active?).and_return(active?)
    end

    context "when the service is active" do
      it "deactivates the service" do
        expect(cups).to receive(:stop)
        subject.switch("cups")
      end

      it "returns true" do
        expect(subject.switch("cups")).to eq(true)
      end
    end

    context "when the service is inactive" do
      let(:active?) { false }

      it "activates the service" do
        expect(cups).to receive(:start)
        subject.switch("cups")
      end

      it "returns true" do
        expect(subject.switch("cups")).to eq(true)
      end
    end

    context "when the service does not exist" do
      it "returns false" do
        expect(subject.switch("unknown")).to eq(false)
      end
    end
  end

  describe "#start_mode" do
    let(:start_mode) { :on_boot }

    before do
      allow(cups).to receive(:start_mode).and_return(start_mode)
    end

    it "returns service start mode" do
      expect(subject.start_mode("cups")).to eq(:on_boot)
    end

    context "when the service does not exist" do
      it "returns false" do
        expect(subject.start_mode("unknown")).to eq(false)
      end
    end
  end

  describe "#set_start_mode" do
    it "sets service start mode" do
      expect(cups).to receive(:start_mode=).with(:on_boot)
      subject.set_start_mode("cups", :on_boot)
    end

    context "when the service does not exist" do
      it "returns false" do
        expect(subject.set_start_mode("unknown", :on_boot)).to eq(false)
      end
    end
  end

  describe "#state" do
    it "returns the service state" do
      expect(subject.state("cups")).to eq("active")
    end

    context "if the service is not found" do
      it "returns false" do
        expect(subject.state("unknown")).to eq(false)
      end
    end
  end

  describe "#substate" do
    it "returns the service substate" do
      expect(subject.substate("cups")).to eq("running")
    end

    context "if the service is not found" do
      it "returns false" do
        expect(subject.substate("unknown")).to eq(false)
      end
    end
  end

  describe "#description" do
    it "returns the service description" do
      expect(subject.description("cups")).to eq("CUPS")
    end

    context "if the service is not found" do
      it "returns false" do
        expect(subject.description("unknown")).to eq(false)
      end
    end
  end

  describe "#modified" do
    let(:services) { { "cups" => cups } }

    context "when it has been marked as modified" do
      before do
        subject.modified = true
      end

      it "returns true" do
        expect(subject.modified).to eq(true)
      end
    end

    context "when a service has been changed" do
      let(:services) { { "dbus" => dbus } }

      it "returns true" do
        expect(subject.modified).to eq(true)
      end
    end

    context "when it has not been marked as modified or no service has been changed" do
      it "returns false" do
        expect(subject.modified).to eq(false)
      end
    end
  end
end
