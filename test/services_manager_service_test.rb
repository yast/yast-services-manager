#!/usr/bin/env rspec

require_relative "test_helper"

module Yast
  extend Yast::I18n
  Yast::textdomain "services-manager"

  describe ServicesManagerService do
    attr_reader :service

    def stub_services
      allow(Service).to receive(:Enable).and_return true
      allow(Service).to receive(:Disable).and_return true
      allow(Service).to receive(:Start).and_return true
      allow(Service).to receive(:Stop).and_return true
      allow(Service).to receive(:Enabled).with("sshd").and_return true
      allow(Service).to receive(:Enabled).with("postfix").and_return false
      allow(Service).to receive(:Enabled).with("swap").and_return false
      allow(Service).to receive(:Enabled).with("dbus").and_return false
      allow(Service).to receive(:Enabled).with("notloaded").and_return false
      allow(Service).to receive(:Enabled).with("xbus").and_return true
      allow(Service).to receive(:Enabled).with("ybus").and_return true
      allow(Service).to receive(:Enabled).with("zbus").and_return true
      allow(Service).to receive(:Enabled).with("lsb").and_return false
      allow(Service).to receive(:Enabled).with("").and_return true

    end

    before do
      allow_any_instance_of(ServicesManagerServiceClass::ServiceLoader).to receive(:list_unit_files)
        .and_return({
          'stdout'=> "sshd.service      enabled \n"  +
                     "postfix.service   disabled\n " +
                     "swap.service      masked  \n"  +
                     "dbus.service      static  \n"  +
                     "notloaded.service static  \n"  +
                     "xbus.service      enabled \n"  +
                     "ybus.service      enabled \n"  +
                     "zbus.service      enabled \n",
          'stderr' => '',
          'exit'   => 0
        })
      allow_any_instance_of(ServicesManagerServiceClass::ServiceLoader).to receive(:list_units)
        .and_return({
          'stdout'=>"sshd.service  loaded active   running OpenSSH Daemon\n" +
                    "postfix.service loaded inactive dead    Postfix Mail Agent\n" +
                    "dbus.service  loaded active   running D-Bus System Message Bus\n" +
                    "lsb.service  loaded active   running LSB service\n" +
                    "xbus.service loaded activating start start YaST2 Second Stage (1)\n" +
                    "ybus.service loaded deactivating stop start YaST2 Second Stage (2)\n" +
                    "zbus.service loaded reloading stop start YaST2 Second Stage (3)\n",
          'stderr' => '',
          'exit'   => 0
        })

      allow_any_instance_of(ServicesManagerServiceClass::ServiceLoader).to receive(:is_active?).and_return true

      @service = Yast::ServicesManagerServiceClass.new
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
      stub_services
      postfix = service.all['postfix']
      expect(postfix[:enabled]).to eq(false)
      expect(postfix[:modified]).to eq(false)
      service.enable 'postfix'
      expect(postfix[:enabled]).to eq(true)
      expect(postfix[:modified]).to eq(true)
      service.save
      expect(postfix[:enabled]).to eq(true)
      expect(postfix[:modified]).to eq(false)
    end

    it "can disable a service which is enabled" do
      stub_services
      sshd = service.all['sshd']
      expect(sshd[:enabled]).to eq(true)
      expect(sshd[:modified]).to eq(false)
      service.disable 'sshd'
      expect(sshd[:enabled]).to eq(false)
      expect(sshd[:modified]).to eq(true)
      service.save
      expect(sshd[:enabled]).to eq(false)
      expect(sshd[:modified]).to eq(false)
    end

    it "can start an inactive service" do
      stub_services
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
      stub_services
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

    it "can toggle a service" do
      stub_services
      sshd = service.all['sshd']
      status = sshd[:enabled]
      service.toggle 'sshd'
      expect(sshd[:enabled]).to be(!status)
      service.save
      expect(sshd[:enabled]).to be(!status)
    end

    it "can switch a service" do
      stub_services
      postfix = service.all['postfix']
      status  = postfix[:active]
      service.switch 'postfix'
      expect(postfix[:active]).to be(!status)
      service.save
      expect(postfix[:active]).to be(!status)
    end

    it "can reset a toggled service" do
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

    context "when enabling is failing" do
      before do
        stub_services
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

    context "when service is in state 'reloading'" do
      it "is considered to be active" do
        stub_services
        zbus_service = service.all['zbus']
        expect(zbus_service[:active]).to eq(true)
      end
    end
  end
end
