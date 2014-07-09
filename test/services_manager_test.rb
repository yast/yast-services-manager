#!/usr/bin/env rspec

require_relative 'test_helper'

module Yast
  describe ServicesManager do
    context "Autoyast API" do
      it "exports systemd target and services" do
        services = {
          'a' => { :enabled => true,  :loaded => true },
          'b' => { :enabled => false, :loaded => true },
          'c' => { :enabled => true,  :loaded => true },
        }

        expect(ServicesManagerService).to receive(:services).and_return(services)
        expect(ServicesManagerTarget).to receive(:default_target).and_return('some_target')

        data = Yast::ServicesManager.export
        expect(data['default_target']).to eq('some_target')
        expect(data['services']['enable']).to eq(['a', 'c'])
        expect(data['services']['disable']).to eq(['b'])
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
            ]
          }
          expect(ServicesManagerService).to receive(:import)
          expect(ServicesManagerTarget).to receive(:import)
          ServicesManager.import(data)
        end
      end

      context "when using AutoYast profile written in pre-SLE 12 format" do
        it "imports data for systemd target and services" do
          data = {
            'default_target' => 'multi-user',
            'services'       => ['x', 'y', 'z']
          }
          expect(ServicesManagerService).to receive(:import)
          expect(ServicesManagerTarget).to receive(:import)
          ServicesManager.import(data)
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
          expect(ServicesManagerService).to receive(:import)
          expect(ServicesManagerTarget).to receive(:import)
          ServicesManager.import(data)
        end
      end

      it "returns HTML-formatted autoyast summary with HTML-escaped values" do
        expect(ServicesManagerTarget).to receive(:export).and_return("multi-head-graphical-hydra")
        expect(ServicesManagerService).to receive(:export).and_return(["service-1", "service-<br>-2", "service-<b>name</b>-3"])

        summary = ServicesManager.auto_summary
        ["multi-head-graphical-hydra", "service-1", "service-&lt;br&gt;-2", "service-&lt;b&gt;name&lt;/b&gt;-3"].each do |item|
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
