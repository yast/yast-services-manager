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

module Yast
  extend Yast::I18n
  Yast::textdomain "services-manager"

  describe ServicesManagerService do
    attr_reader :service

    before do
      allow(Service).to receive(:Enable).and_return true
      allow(Service).to receive(:Disable).and_return true
      allow(Service).to receive(:Start).and_return true
      allow(Service).to receive(:Stop).and_return true

      @service = Yast::ServicesManagerServiceClass.new

      stub_services(services_specs)
    end

    let(:services_specs) do
      [
        {
          unit:            "sshd.service",
          unit_file_state: "enabled",
          load:            "loaded",
          active:          "active",
          sub:             "running",
          description:     "running OpenSSH Daemon"
        },
        {
          unit:            "postfix.service",
          unit_file_state: "disabled",
          load:            "loaded",
          active:          "inactive",
          sub:             "dead",
          description:     "Postfix Mail Agent"
        },
        {
          unit:            "swap.service",
          unit_file_state: "masked"
        },
        {
          unit:            "dbus.service",
          unit_file_state: "static",
          load:            "loaded",
          active:          "active",
          sub:             "running",
          description:     "D-Bus System Message Bus"
        },
        {
          unit:            "notloaded.service",
          unit_file_state: "static",
          load:            nil,
          active:          "active",
          sub:             "running",
          description:     "Stub notloaded"
        },
        {
          unit:            "lsb.service",
          unit_file_state: nil,
          load:            "loaded",
          active:          "active",
          sub:             "running",
          description:     "LSB service"
        },
        {
          unit:            "xbus.service",
          unit_file_state: "enabled",
          load:            "loaded",
          active:          "activating",
          sub:             "start",
          description:     "start YaST2 Second Stage (1)"
        },
        {
          unit:            "ybus.service",
          unit_file_state: "enabled",
          load:            "loaded",
          active:          "deactivating",
          sub:             "stop",
          description:     "start YaST2 Second Stage (2)"
        },
        {
          unit:            "zbus.service",
          unit_file_state: "enabled",
          load:            "loaded",
          active:          "reloading",
          sub:             "stop",
          description:     "start YaST2 Second Stage (3)"
        }
      ]
    end

    it "provides a collection of supported services" do
      expect(service.modified).to eq(false)
      expect(service.all).not_to be_empty
      expect(service.all.keys).to include('sshd', 'postfix', 'notloaded', 'lsb')
      expect(service.all).not_to include('swap')
    end

    it "cannot enable services which have the status -static-" do
      expect(service.can_be_enabled("dbus")).to eq(false)
    end

    it "can enable a service which is disabled" do
      postfix = service.all['postfix']
      expect(postfix[:start_mode]).to eq(:manual)
      expect(postfix[:modified]).to eq(false)
      service.set_start_mode('postfix', :boot)
      expect(postfix[:start_mode]).to eq(:boot)
      expect(postfix[:modified]).to eq(true)
      expect(service).to receive(:set_start_mode!).with("postfix").and_return(true)
      service.save
      expect(postfix[:modified]).to eq(false)
    end

    it "can disable a service which is enabled" do
      sshd = service.all['sshd']
      expect(sshd[:start_mode]).to eq(:boot)
      expect(sshd[:modified]).to eq(false)
      service.set_start_mode('sshd', :manual)
      expect(sshd[:start_mode]).to eq(:manual)
      expect(sshd[:modified]).to eq(true)
      expect(service).to receive(:set_start_mode!).with("sshd").and_return(true)
      service.save
      expect(sshd[:modified]).to eq(false)
    end

    it "can start an inactive service" do
      postfix = service.all['postfix']
      expect(postfix[:modified]).to be(false)
      service.activate 'postfix'
      expect(postfix[:active]).to be(true)
      expect(postfix[:modified]).to be(true)
      service.save
      expect(postfix[:active]).to be(true)
      expect(postfix[:modified]).to be(false)
    end

    it "can stop an active service" do
      sshd = service.all['sshd']
      expect(sshd[:active]).to be(true)
      expect(sshd[:modified]).to be(false)
      service.deactivate 'sshd'
      expect(sshd[:active]).to be(false)
      expect(sshd[:modified]).to be(true)
      service.save
      expect(sshd[:active]).to be(false)
      expect(sshd[:modified]).to be(false)
    end

    xit "can toggle a service" do
      sshd = service.all['sshd']
      status = sshd[:enabled]
      service.toggle 'sshd'
      expect(sshd[:enabled]).to be(!status)
      service.save
      expect(sshd[:enabled]).to be(!status)
    end

    it "can switch a service" do
      postfix = service.all['postfix']
      status  = postfix[:active]
      service.switch 'postfix'
      expect(postfix[:active]).to be(!status)
      service.save
      expect(postfix[:active]).to be(!status)
    end

    xit "can reset a toggled service" do
      sshd = service.all['sshd']
      status = sshd[:enabled]
      service.toggle 'sshd'
      expect(sshd[:enabled]).not_to eq(status)
      expect(sshd[:modified]).to eq(true)
      service.reset
      sshd = service.all['sshd']
      expect(sshd[:enabled]).to eq(status)
      expect(sshd[:modified]).to eq(false)
    end

    it "can reset a switched service" do
      sshd = service.all['sshd']
      status = sshd[:active]
      service.switch 'sshd'
      expect(sshd[:active]).to eq(!status)
      expect(sshd[:modified]).to eq(true)
      service.reset
      sshd = service.all['sshd']
      expect(sshd[:active]).to eq(status)
      expect(sshd[:modified]).to eq(false)
    end

    xcontext "when enabling is failing" do
      before do
        allow(Service).to receive(:Enable).and_return false
        allow(Service).to receive(:Disable).and_return false
        service.toggle 'postfix'
        service.save
      end

      it "reports errors" do
        expect(service.errors.first).to start_with Yast::_('Could not enable postfix')
      end

      it "cleans messages after reset" do
        expect(service.errors.size).to eq 1
        service.reset
        expect(service.errors.size).to eq 0
        # Let's fail again
        service.toggle 'postfix'
        service.save
        expect(service.errors.size).to eq 1
      end
    end

    # FIXME
    # Where is the code to mangage this case?
    # It was returning true because the service is mocked as #active? #=> true
    xcontext "when service is in state 'reloading'" do
      it "is considered to be active" do
        zbus_service = service.all['zbus']
        expect(zbus_service[:active]).to eq(true)
      end
    end

    context "when running in installation-system" do
      it "do not switch a service at all" do
        postfix = service.all['postfix']
        status  = postfix[:active]
        service.switch 'postfix' # locally only
        allow(Stage).to receive(:initial).and_return true
        expect(subject).to_not receive(:switch_services)
        service.save
      end

      xit "generates missing services entries" do
        allow(Stage).to receive(:initial).and_return true
        service.enable("new_service")
        expect(service.services["new_service"]).not_to be_nil
      end
    end

    describe "#state" do
      it "returns the service state" do
        expect(service.state("sshd")).to eq("active")
      end

      context "if the service is not found" do
        let(:service_name) { "unkown" }

        it "returns nil" do
          expect(service.state(service_name)).to be_nil
        end
      end
    end

    describe "#substate" do
      it "returns the service substate" do
        expect(service.substate("sshd")).to eq("running")
      end

      context "if the service is not found" do
        let(:service_name) { "unkown" }

        it "returns nil" do
          expect(service.substate(service_name)).to be_nil
        end
      end
    end

    describe "#description" do
      it "returns the service description" do
        expect(service.description("sshd")).to eq("running OpenSSH Daemon")
      end

      context "if the service is not found" do
        let(:service_name) { "unkown" }

        it "returns nil" do
          expect(service.description(service_name)).to be_nil
        end
      end
    end
  end
end
