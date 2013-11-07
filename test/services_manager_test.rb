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
        SystemdService.stub(:services).and_return(services)
        SystemdTarget.stub(:default_target).and_return('some_target')

        data = Yast::ServicesManager.export
        expect(data['default_target']).to eq('some_target')
        expect(data['services']).to eq(['a'])

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
      it "has available methods for both target and services" do
        public_methods = [ :save, :read, :reset, :modified, :modified= ]
        public_methods.each do |method|
          SystemdService.stub(method)
          SystemdTarget.stub(method)
          expect(SystemdService).to receive(method)
          expect(SystemdTarget).to  receive(method)
          method == :modified= ? ServicesManager.__send__(method, true) : ServicesManager.__send__(method)
        end
      end
    end
  end
end
