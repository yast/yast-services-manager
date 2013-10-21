#!/usr/bin/env rspec

require_relative 'test_helper'

module Yast

  describe ServicesManager do
    context "Autoyast API" do
      it "exports systemd target and services" do
        SystemdService.stub(:default_target).and_return('some_target')
        SystemdTarget.stub(:services).and_return(['a', 'b'])

        data = Yast::ServicesManager.export
        expect(data['default_target']).to eq('some_target')
        expect(data['services']).to eq(['a', 'b'])

      end

      it "imports data for systemd target and services" do
        data = {
          'default_target' => 'multi-user',
          'services'       => ['x', 'y', 'z']
        }
        expect(SystemdService).to receive(:import)
        expect(SystemdTarget).to receive(:import)
        ServicesManager.import(data)
      end
    end

    context "Global public API" do
      public_methods = [ :save, :read, :modified?, :reset ]
      public_methods.each do |method|
        expect(SystemdService).to receive(method)
        expect(SystemdTarget).to receive(method)
        ServicesManager.send :method
      end
    end
  end
end
