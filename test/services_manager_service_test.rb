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

      all_services = {}
      declare_service = lambda do |name, enabled|
        d = double(description: "Stub #{name}", enabled?: enabled, active?: true, socket: nil)
        all_services[name] = d
      end

      declare_service.call("sshd", true)
      declare_service.call("postfix", false)
      declare_service.call("dbus", false)
      declare_service.call("notloaded", false)
      declare_service.call("xbus", true)
      declare_service.call("ybus", true)
      declare_service.call("zbus", true)
      declare_service.call("lsb", false)

      keys = all_services.sort.map(&:first)
      values = all_services.sort.map(&:last)
      allow(SystemdService)
        .to receive(:find_many).with(keys)
              .and_return(values)
    end

    before do
      stub_services

      allow_any_instance_of(ServicesManagerServiceClass::ServiceLoader).to receive(:list_unit_files)
        .and_return(
          [
                     "sshd.service      enabled \n",
                     "postfix.service   disabled\n",
                     "swap.service      masked  \n",
                     "dbus.service      static  \n",
                     "notloaded.service static  \n",
                     "xbus.service      enabled \n",
                     "ybus.service      enabled \n",
                     "zbus.service      enabled \n"
          ]
        )
      allow_any_instance_of(ServicesManagerServiceClass::ServiceLoader).to receive(:list_units)
        .and_return(
          [
            "sshd.service  loaded active   running OpenSSH Daemon\n",
            "postfix.service loaded inactive dead    Postfix Mail Agent\n",
            "dbus.service  loaded active   running D-Bus System Message Bus\n",
            "lsb.service  loaded active   running LSB service\n",
            "xbus.service loaded activating start start YaST2 Second Stage (1)\n",
            "ybus.service loaded deactivating stop start YaST2 Second Stage (2)\n",
            "zbus.service loaded reloading stop start YaST2 Second Stage (3)\n"
          ]
        )

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

    it "can toggle a service" do
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
      it "generates missing services entries" do
        allow(Stage).to receive(:initial).and_return true
        service.enable("new_service")
        expect(service.services["new_service"]).not_to be_nil
      end
    end

    context "when a service is disabled" do
      let(:dbus) do
        double("dbus", enabled?: false, active?: true, description: "CUPS", socket: socket)
      end

      before do
        allow(SystemdService).to receive(:find_many).and_return([dbus])
      end

      context "but its socket is enabled" do
        let(:socket) { double("dbus_socket", enabled?: true) }

        it "considers the system as enabled" do
          expect(service.all["dbus"][:enabled]).to eq(true)
        end
      end

      context "and its socket is disabled" do
        let(:socket) { double("dbus_socket", enabled?: false) }

        it "considers the system as enabled" do
          expect(service.all["dbus"][:enabled]).to eq(false)
        end
      end
    end
  end
end
