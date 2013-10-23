#!/usr/bin/env rspec

require_relative "test_helper"

module Yast
  describe SystemdService do
    attr_reader :service

    def stub_services
      Service.stub(:Enable).and_return(true)
      Service.stub(:Disable).and_return(true)
      Service.stub(:Start).and_return(true)
      Service.stub(:Stop).and_return(true)
    end

    before do
      SystemdServiceClass.any_instance
        .stub(:list_services_units)
        .and_return({
          'stdout'=> "sshd.service     enabled \n"  +
                     "postfix.service  disabled\n " +
                     "swap.service     masked  \n"  +
                     "dbus.service     static  \n",
          'stderr' => '',
          'exit'   => 0
        })
      SystemdServiceClass.any_instance
        .stub(:list_services_details)
        .and_return({
          'stdout'=>"sshd.service  loaded active   running OpenSSH Daemon\n" +
                    "postfix.service loaded inactive dead    Postfix Mail Agent\n" +
                    "dbus.service  loaded active   running D-Bus System Message Bus",
          'stderr' => '',
          'exit'   => 0
        })

      @service = Yast::SystemdServiceClass.new
    end

    it "provides a collection of supported services" do
      expect(service.modified).to eq(false)
      expect(service.all).not_to be_empty
      expect(service.all.keys).to include('sshd', 'postfix')
      expect(service.all).not_to include('swap', 'dbus')
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
      expect(postfix[:active]).to be(false)
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
      expect(sshd[:enabled]).to eq(!status)
      expect(sshd[:modified]).to eq(true)
      service.reset
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
      expect(sshd[:active]).to eq(status)
      expect(sshd[:modified]).to eq(false)
    end
  end
end
