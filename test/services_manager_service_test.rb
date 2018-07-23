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

Yast.import "ServicesManagerService"

describe Yast::ServicesManagerServiceClass do
  subject { Yast::ServicesManagerServiceClass.new }

  let(:cups) do
    instance_double(
      Yast2::SystemService, name: "cups", description: "CUPS", start: true, stop: true,
      state: "active", substate: "running", changed?: false, start_mode: :on_boot,
      save: nil, errors: {}
    )
  end

  let(:dbus) do
    instance_double(
      Yast2::SystemService, name: "dbus", changed?: true, active?: true,
      running?: true, save: nil, errors: {}
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
    it "returns the list of services from ServiceLoader" do
      expect(subject.services).to eq(services)
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

  describe "#changed_value" do
    let(:changed_value?) { true }

    before do
      allow(cups).to receive(:changed_value?).and_return(changed_value?)
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

  describe "#can_be_enabled" do
    let(:static?) { false }

    before do
      allow(cups).to receive(:static?).and_return(static?)
    end

    context "when the service is not static" do
      it "returns true" do
        expect(subject.can_be_enabled("cups")).to eq(true)
      end
    end

    context "when the service is static" do
      let(:static?) { true }

      it "returns false" do
        expect(subject.can_be_enabled("cups")).to eq(false)
      end
    end

    context "when the service does not exist" do
      it "returns false" do
        expect(subject.can_be_enabled("unknown")).to eq(false)
      end
    end
  end

  describe "#modified_services" do
    it "returns modified services" do
      expect(subject.modified_services).to eq([dbus])
    end
  end

  describe "#reload"

  describe "#read"

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

      context "and is enabled" do
        before do
          allow(dbus).to receive(:start_mode).and_return(:on_boot)
        end

        it "exports the service as enabled" do
          expect(exported_services["enable"]).to include("dbus")
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

      context "and was enabled" do
        before do
          allow(cups).to receive(:start_mode).and_return(:on_boot)
        end

        it "exports the service as enable" do
          expect(exported_services["enable"]).to include("cups")
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
    let(:autoyast_profile) do
      {
        "default"  => "3",
        "services" => [
          {
            "service_name"   => "dbus",
            "service_status" => "enable",
            "service_start"  => "3"
          },
          {
            "service_name"   => "cups",
            "service_status" => "disable",
            "service_start"  => "5"
          }
        ]
      }
    end
    let(:profile) { Yast::ServicesManagerProfile.new(autoyast_profile) }

    before do
      allow(subject).to receive(:set_start_mode)
    end

    it "enables services with `enable` status" do
      expect(subject).to receive(:enable).with("dbus")

      subject.import(profile)
    end

    it "disables services with `disable` status" do
      expect(subject).to receive(:disable).with("cups")

      subject.import(profile)
    end

    context "there are unknown statuses" do
      let(:autoyast_profile) do
        {
          "default"  => "3",
          "services" => [
            {
              "service_name"   => "dbus",
              "service_status" => "wrong_status",
              "service_start"  => "3"
            },
            {
              "service_name"   => "cups",
              "service_status" => "disable",
              "service_start"  => "5"
            }
          ]
        }
      end

      it "logs an error for unkown statuses" do
        expect(subject.log).to receive(:error).with("Unknown status 'wrong_status' for service 'dbus'")

        subject.import(profile)
      end
    end

    context "when all services are present in the system" do
      it "returns true" do
        expect(subject.import(profile)).to be_truthy
      end
    end

    context "when any service is not present in the system" do
      let(:autoyast_profile) do
        {
          "default"  => "3",
          "services" => [
            {
              "service_name"   => "fake_service",
              "service_status" => "enable",
              "service_start"  => "3"
            },
            {
              "service_name"   => "cups",
              "service_status" => "disable",
              "service_start"  => "5"
            }
          ]
        }
      end

      it "logs an error" do
        expect(subject.log).to receive(:error).with(/don't exist on this system/)

        subject.import(profile)
      end

      it "returns false" do
        expect(subject.import(profile)).to be_falsey
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
      expect(dbus).to receive(:save).with(ignore_status: false)
      expect(cups).to_not receive(:save)
      subject.save
    end

    context "when a service registers an error" do
      before do
        allow(cups).to receive(:errors).and_return({activate: true})
      end

      it "returns false" do
        expect(subject.save).to eq(false)
      end
    end

    context "on 1st stage" do
      let(:initial) { true }

      it "saves all services not modifying the current status" do
        expect(dbus).to receive(:save).with(ignore_status: true)
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
      allow(dbus).to receive(:errors).and_return({:active => true})
      allow(cups).to receive(:errors).and_return({:start_mode => :manual})
    end

    it "returns the list of service errors" do
      expect(subject.errors).to eq([
        "Could not set cups to be started on boot.",
        "Could not start dbus which is currently running."
      ])
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
end
