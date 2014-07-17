#!/usr/bin/env rspec

require_relative 'test_helper'

module Yast
  Yast.import 'ServicesManagerTarget'
  Yast.import 'ServicesManager'

  TARGETS = {
    "multi-user"=>{
      :enabled=>true, :loaded=>true, :active=>true, :description=>"Multi-User System"
    },
    "emergency"=>{
      :enabled=>false, :loaded=>true, :active=>false, :description=>"Emergency Mode"
    },
    "graphical"=>{
      :enabled=>false, :loaded=>true, :active=>false, :description=>"Graphical Interface"
    },
    "rescue"=>{
      :enabled=>false, :loaded=>true, :active=>false, :description=>"Rescue Mode"
    }
  }

  describe ServicesManager do
    before(:each) do
      log.info "--- test ---"
      allow(Yast::ServicesManagerService).to receive(:services).and_return({})
      allow(Yast::ServicesManagerTarget).to receive(:targets).and_return(TARGETS)
    end

    context "Autoyast API" do
      it "exports systemd target and services" do
        services = {
          'a' => { :enabled => true,  :loaded => true },
          'b' => { :enabled => false, :modified => true },
          'c' => { :enabled => true,  :loaded => true },
          # Service will not be exported: it's not modified
          'd' => { :enabled => false, :modified => false },
          # Service will not be exported: it's not loaded
          'e' => { :enabled => true,  :loaded => false },
        }

        allow(ServicesManagerService).to receive(:services).and_return(services)
        expect(ServicesManagerTarget).to receive(:default_target).and_return('some_target')

        data = Yast::ServicesManager.export
        expect(data['default_target']).to eq('some_target')
        expect(data['services']['enable'].sort).to eq(['a', 'c'].sort)
        expect(data['services']['disable'].sort).to eq(['b'].sort)
      end

      context "when using AutoYast profile written in SLE 11 format" do
        it "imports data for systemd target and services" do
          data = {
            'default' => '3',
            'services' => [
              {
                'service_name' => 'sa',
                'service_status' => 'enable',
                'service_start' => '3',
              },
              {
                'service_name' => 'sb',
                'service_status' => 'enable',
                'service_start' => '3',
              },
              {
                'service_name' => 'sc',
                'service_status' => 'disable',
                'service_start' => '3',
              },
            ]
          }

          expect(ServicesManagerService).to receive(:exists?).with(/^s[abc]$/).at_least(:once).and_return(true)
          expect(ServicesManagerService).to receive(:enable).with(/^s[ab]$/).twice.and_return(true)
          expect(ServicesManagerService).to receive(:disable).with(/^sc$/).once.and_return(true)

          expect(ServicesManagerService).to receive(:import).and_call_original
          expect(ServicesManagerTarget).to receive(:import).and_call_original
          expect(ServicesManager.import(data)).to be_true
        end
      end

      context "when using AutoYast profile written in pre-SLE 12 format" do
        it "imports data for systemd target and services" do
          data = {
            'default_target' => 'multi-user',
            'services'       => ['x', 'y', 'z']
          }

          expect(ServicesManagerService).to receive(:exists?).with(/^[xyz]$/).at_least(:once).and_return(true)

          expect(ServicesManagerService).to receive(:import).and_call_original
          expect(ServicesManagerTarget).to receive(:import).and_call_original
          expect(ServicesManager.import(data)).to be_true
        end
      end

      context "when using AutoYast profile in the current format" do
        it "imports data for systemd target and services" do
          data = {
            'default_target' => 'multi-user',
            'services' => {
              'enable'  => ['x', 'y', 'z'],
              'disable' => ['d', 'e', 'f'],
            },
          }
          expect(ServicesManagerService).to receive(:exists?).with(/^[xyzdef]$/).at_least(:once).and_return(true)
          expect(ServicesManagerService).to receive(:enable).with(/^[xyz]$/).exactly(3).times.and_return(true)
          expect(ServicesManagerService).to receive(:disable).with(/^[def]$/).exactly(3).times.and_return(true)

          expect(ServicesManagerService).to receive(:import).and_call_original
          expect(ServicesManagerTarget).to receive(:import).and_call_original
          expect(ServicesManager.import(data)).to be_true
        end
      end

      it "returns HTML-formatted autoyast summary with HTML-escaped values" do
        expect(ServicesManagerTarget).to receive(:export).and_return("multi-head-graphical-hydra")
        expect(ServicesManagerService).to receive(:export).and_return({
          "enable" => ["service-1", "service-<br>-2", "service-<b>name</b>-3"],
          "disable" => ["service-4", "service-<br>-5", "service-<b>name</b>-6"],
        })

        summary = ServicesManager.auto_summary
        ["multi-head-graphical-hydra", "service-[14]", "service-&lt;br&gt;-[25]", "service-&lt;b&gt;name&lt;/b&gt;-[36]"].each do |item|
          expect(summary).to match(/#{item}/)
        end
      end
    end

    context "Global public API" do
      it "has available methods for both target and services" do
        public_methods = [ :save, :read, :reset, :modified ]
        public_methods.each do |method|
          ServicesManagerService.stub(method)
          ServicesManagerTarget.stub(method)
          expect(ServicesManagerService).to receive(method)
          expect(ServicesManagerTarget).to  receive(method)
          ServicesManager.__send__(method)
        end

        ServicesManagerService.stub(:modified=)
        ServicesManagerTarget.stub(:modified=)
        expect(ServicesManagerService).to receive(:modified=).with(true)
        expect(ServicesManagerTarget).to receive(:modified=).with(true)
        ServicesManager.__send__(:modify)
      end
    end
  end
end
