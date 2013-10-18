require_relative 'test_helper'

module Yast
  include TestHelpers::Manager

  describe Yast::ServicesManager do
    context "Autoyast API" do
      it "exports systemd target and services" do
        SystemdService.stub(:default_target).and_return('some_target')
        SystemdTarget.stub(:services).and_return(['a', 'b'])

        data = Yast::ServicesManager.export
        expect(data['default_target']).to eq('some_target')
        expect(data['services']).to eq(['a', 'b'])

      end

      it "can manage importing of data for systemd target and services" do
      end
    end

  it "shows summary with default target and registered services" do
    skip "this belongs to UI test suite"
    stub_manager_with :default_target => 'runlevel333', :services => ['sshd', 'cups'] do
      Yast::ServicesManager.summary.must_match default_target
      services.each {|s| Yast::ServicesManager.summary.must_match s }
    end
  end
end
