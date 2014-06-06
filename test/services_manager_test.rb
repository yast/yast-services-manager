#!/usr/bin/env rspec

require_relative 'test_helper'

module Yast
  describe ServicesManager do
    context "Autoyast API" do
      it "exports systemd target and services" do
        services = {
          'a' => {:enabled=>true, :loaded=>true},
          'b' => {:enabled=>false, :loaded=>true}
        }
        ServicesManagerService.stub(:services).and_return(services)
        ServicesManagerTarget.stub(:default_target).and_return('some_target')

        data = Yast::ServicesManager.export
        expect(data['default_target']).to eq('some_target')
        expect(data['services']).to eq(['a'])

      end

      it "imports data for systemd target and services" do
        data = {
          'default_target' => 'multi-user',
          'services'       => ['x', 'y', 'z']
        }
        expect(ServicesManagerService).to receive(:import)
        expect(ServicesManagerTarget).to receive(:import)
        ServicesManager.import(data)
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
