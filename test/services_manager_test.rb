require_relative 'test_helper'

include TestHelpers::Manager

describe Yast::ServicesManager do

  it "can manage exporting systemd target and services at once" do
    stub_manager_with :default_target => 'runlevel-8000', :services => ['a', 'b', 'c'] do
      data = Yast::ServicesManager.export

      data[Yast::ServicesManagerClass::TARGET].must_equal default_target
      data[Yast::ServicesManagerClass::SERVICES].must_equal services

      services.all? do |service|
        data[Yast::ServicesManagerClass::SERVICES].member?(service)
      end.must_equal(true)
    end
  end

  it "can manage importing of data for systemd target and services" do
  end

  it "shows summary with default target and registered services" do
    stub_manager_with :default_target => 'runlevel333', :services => ['sshd', 'cups'] do
      Yast::ServicesManager.summary.must_match default_target
      services.each {|s| Yast::ServicesManager.summary.must_match s }
    end
  end
end
