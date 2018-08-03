#!/usr/bin/env rspec

require_relative "test_helper"

require 'services-manager/services_manager_profile'

module Yast
  describe ServicesManagerProfile do
    attr_reader :profile, :autoyast_profile

    context "legacy runlevel autoyast profile" do
      before do
        @autoyast_profile = {
          'default'  => '3',
          'services' => [
            {
              'service_name'   => 'sshd',
              'service_status' => 'enable',
              'service_start'  => '3'
            },
            {
              'service_name'   => 'libvirt',
              'service_status' => 'disable',
              'service_start'  => '5'
            },
            {
              'service_name' => 'YaST2-Second-Stage',
              'service_status' => 'disable',
              'service_start'  => '5'
            },
            {
              'service_name' => 'YaST2-Firstboot',
              'service_status' => 'disable',
              'service_start'  => '5'
            },
          ]
        }
        @profile = ServicesManagerProfile.new(autoyast_profile)
      end

      it "returns profile object with services collection" do
        expect(profile.services).not_to be_empty
        expect(profile.services.size).to eq(2)
      end

      it "provides the original data from autoyast" do
        expect(profile.autoyast_profile).to equal(autoyast_profile)
      end

      it "provides collection of services to be started on boot" do
        service = profile.services.find {|s| s.name == 'sshd'}
        expect(service).not_to be_nil
        expect(service.start_mode).to eq(:on_boot)
      end

      it "provides collection of services to be disabled" do
        service = profile.services.find {|s| s.name == 'libvirt'}
        expect(service).not_to be_nil
        expect(service.start_mode).to eq(:manual)
      end

      YAST_SERVICES = ["YaST2-Firstboot", "YaST2-Second-Stage"]

      it "ignores YaST services" do
        service_names = profile.services.map(&:name)
        expect(service_names).to_not include(*YAST_SERVICES)
      end

      it "provides default target" do
        expect(profile.target).not_to be_empty
        expect(profile.target).to eq('multi-user')
      end
    end

    context "simplified services profile" do
      before do
        @autoyast_profile = {
          'default_target'=>'graphical',
          'services' => [ 'sshd', 'iscsi' ]
        }
        @profile = ServicesManagerProfile.new(autoyast_profile)
      end

      it "returns profile object that provides services collection" do
        expect(profile.services).not_to be_empty
        expect(profile.services.size).to eq(2)
      end

      it "provides the original data from autoyast" do
        expect(profile.autoyast_profile).to equal(autoyast_profile)
      end

      it "provides collection of services to be started on boot" do
        service = profile.services.find {|s| s.name == 'sshd'}
        expect(service).not_to be_nil
        expect(service.start_mode).to eq(:on_boot)
      end

      it "provides default target" do
        expect(profile.target).not_to be_empty
        expect(profile.target).to eq('graphical')
      end
    end

    context "extended services autoyast profile" do
      before do
        @autoyast_profile = {
          'default_target' => 'multi-user',
          'services' => {
            'enable'    => ['sshd',  'iscsi'  ],
            'disable'   => ['nginx', 'libvirt'],
            'on_demand' => ['cups']
          }
        }
        @profile = ServicesManagerProfile.new(autoyast_profile)
      end

      it "returns profile object that provides services collection" do
        expect(profile.services).not_to be_empty
        expect(profile.services.size).to eq(5)
      end

      it "provides the original data from autoyast" do
        expect(profile.autoyast_profile).to equal(autoyast_profile)
      end

      it "provides collection of services to be disabled" do
        service = profile.services.find {|s| s.name == 'nginx'}
        expect(service).not_to be_nil
        expect(service.start_mode).to eq(:manual)
      end

      it "provides collection of services to be started on boot" do
        service = profile.services.find {|s| s.name == 'sshd'}
        expect(service).not_to be_nil
        expect(service.start_mode).to eq(:on_boot)
      end

      it "provides collection of services to be started on demand" do
        service = profile.services.find {|s| s.name == 'cups'}
        expect(service).not_to be_nil
        expect(service.start_mode).to eq(:on_demand)
      end

      it "provides default target" do
        expect(profile.target).not_to be_empty
        expect(profile.target).to eq('multi-user')
      end
    end

    context "missing services and target entries in profile" do
      before do
        @autoyast_profile = {}
        @profile = ServicesManagerProfile.new(autoyast_profile)
      end

      it "provides not target information" do
        expect(profile.target).to be_nil
      end

      it "provides empty list of services" do
        expect(profile.services).to be_empty
      end
    end

    context "wrong services entries in profile" do
      before do
        @autoyast_profile = {
          'services' => {
            'wrong_entry' => ['wrong_entry']
          }
        }
        @profile = ServicesManagerProfile.new(autoyast_profile)
      end

      it "provides empty list of services" do
        expect(profile.services).to be_empty
      end
    end

  end
end
