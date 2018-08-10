#!/usr/bin/env rspec

require_relative "test_helper"

require 'services-manager/services_manager_profile'

module Yast
  describe ServicesManagerProfile do
    let(:profile) { ServicesManagerProfile.new(autoyast_profile) }

    context "legacy runlevel autoyast profile" do
      let(:autoyast_profile) do
        {
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
      let(:autoyast_profile) do
        {
          'default_target'=>'graphical',
          'services' => [ 'sshd', 'iscsi' ]
        }
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
      let(:autoyast_profile) do
        {
          "default_target" => "multi-user",
          "services" => {
            "enable"    => ["sshd",  "iscsi"  ],
            "disable"   => ["nginx", "libvirt"],
            "on_demand" => ["cups"]
          }
        }
      end

      describe "#autoyast_profile" do
        it "returns the original data from autoyast" do
          expect(profile.autoyast_profile).to equal(autoyast_profile)
        end
      end

      describe "#services" do
        it "returns profile object that provides services collection" do
          expect(profile.services).not_to be_empty
          expect(profile.services.size).to eq(5)
        end

        context "when a list of services to disable is given" do
          let(:autoyast_profile) do
            { "services" => {"disable" => ["nginx"]} }
          end

          it "returns the list of services configured to be disabled" do
            expect(profile.services.size).to eq(1)
            nginx = profile.services.first
            expect(nginx.start_mode).to eq(:manual)
          end
        end

        context "when a list of services to be started on boot is given" do
          let(:autoyast_profile) do
            { "services" => {"enable" => ["sshd"]} }
          end

          it "returns the list of services configured to be started on boot" do
            expect(profile.services.size).to eq(1)
            sshd = profile.services.first
            expect(sshd.start_mode).to eq(:on_boot)
          end
        end

        context "when a list of services to be started on-demand is given" do
          let(:autoyast_profile) do
            { "services" => {"on_demand" => ["cups"]} }
          end

          it "returns the list of services configured to be started on-demand" do
            expect(profile.services.size).to eq(1)
            cups = profile.services.first
            expect(cups.start_mode).to eq(:on_demand)
          end
        end
      end

      describe "#target" do
        it "returns the default target" do
          expect(profile.target).not_to be_empty
          expect(profile.target).to eq("multi-user")
        end
      end
    end

    context "missing services and target entries in profile" do
      let(:autoyast_profile) { {} }

      it "provides not target information" do
        expect(profile.target).to be_nil
      end

      it "provides empty list of services" do
        expect(profile.services).to be_empty
      end
    end

    context "wrong services entries in profile" do
      let(:autoyast_profile) do
        {
          'services' => {
            'wrong_entry' => ['wrong_entry']
          }
        }
      end

      it "provides empty list of services" do
        expect(profile.services).to be_empty
      end
    end
  end
end
