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

      it "provides collection of services to be enabled" do
        service = profile.services.find {|s| s.name == 'sshd'}
        expect(service).not_to be_nil
        expect(service.status).to eq('enable')
      end

      it "provides collection of services to be disabled" do
        service = profile.services.find {|s| s.name == 'libvirt'}
        expect(service).not_to be_nil
        expect(service.status).to eq('disable')
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

      it "provides collection of services to be enabled" do
        service = profile.services.find {|s| s.name == 'sshd'}
        expect(service).not_to be_nil
        expect(service.status).to eq('enable')
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
            'enable'  => ['sshd',  'iscsi'  ],
            'disable' => ['nginx', 'libvirt']
          }
        }
        @profile = ServicesManagerProfile.new(autoyast_profile)
      end

      it "returns profile object that provides services collection" do
        expect(profile.services).not_to be_empty
        expect(profile.services.size).to eq(4)
      end

      it "provides the original data from autoyast" do
        expect(profile.autoyast_profile).to equal(autoyast_profile)
      end

      it "provides collection of services to be disabled" do
        service = profile.services.find {|s| s.name == 'nginx'}
        expect(service).not_to be_nil
        expect(service.status).to eq('disable')
      end

      it "provides collection of services to be enabled" do
        service = profile.services.find {|s| s.name == 'sshd'}
        expect(service).not_to be_nil
        expect(service.status).to eq('enable')
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
