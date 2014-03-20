#!/usr/bin/env rspec

require_relative "test_helper"

require 'services-manager/services_manager_profile'

module Yast
  describe ServicesManagerProfile do
    attr_reader :profile, :autoyast_data

    context "legacy runlevel autoyast profile" do
      before do
        @autoyast_data =
          [
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
        @profile = ServicesManagerProfile.new(autoyast_data)
      end

      it "returns profile object with services collection" do
        expect(profile.services).not_to be_empty
        expect(profile.services.size).to eq(2)
      end

      it "provides the original data from autoyast" do
        expect(profile.autoyast_data).to equal(autoyast_data)
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
    end

    context "simplified services profile" do
      before do
        @autoyast_data = [ 'sshd', 'iscsi' ]
        @profile = ServicesManagerProfile.new(autoyast_data)
      end

      it "returns profile object that provides services collection" do
        expect(profile.services).not_to be_empty
        expect(profile.services.size).to eq(2)
      end

      it "provides the original data from autoyast" do
        expect(profile.autoyast_data).to equal(autoyast_data)
      end

      it "provides collection of services to be enabled" do
        service = profile.services.find {|s| s.name == 'sshd'}
        expect(service).not_to be_nil
        expect(service.status).to eq('enable')
      end

      it "provides collection of services to be disabled" do
        service = profile.services.find {|s| s.name == 'iscsi'}
        expect(service).not_to be_nil
        expect(service.status).to eq('enable')
      end
    end

    context "extended services autoyast profile" do
      before do
        @autoyast_data =
          [
            {'enable'  => ['sshd',  'iscsi'  ] },
            {'disable' => ['nginx', 'libvirt'] }
          ]
        @profile = ServicesManagerProfile.new(autoyast_data)
      end

      it "returns profile object that provides services collection" do
        expect(profile.services).not_to be_empty
        expect(profile.services.size).to eq(4)
      end

      it "provides the original data from autoyast" do
        expect(profile.autoyast_data).to equal(autoyast_data)
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
    end
  end
end
