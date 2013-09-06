require_relative 'test_helper'

include TestHelpers::Services

describe Yast::SystemdService do
  attr_reader :systemd_service

  before do
    @systemd_service = Yast::SystemdServiceClass.new
  end

  it "returns a collection of services" do
    systemd_service.services.must_be_empty
    systemd_service.errors.must_be_empty
    systemd_service.modified.must_equal false
    stub_systemd_service do
      systemd_service.read
      systemd_service.all.wont_be_empty
      systemd_service.modified.must_equal false
      systemd_service.errors.must_be_empty
    end
  end

  it "does not include unsupported services" do
    stub_systemd_service do
      systemd_service.read
      unsupported_services.none? do |unsupported_service|
        systemd_service.services.keys.include? unsupported_service
      end.must_equal true
    end
  end

  it "does load all supported services" do
    stub_systemd_service do
      systemd_service.read
      supported_services.all? do |supported_service|
        systemd_service.services.keys.include? supported_service
      end.must_equal true
    end
  end

  it "can activate and deactivate services" do
    stub_systemd_service do
      stub_switch do
        systemd_service.read
        systemd_service.services.keys.each do |service|
          systemd_service.activate(service).must_equal true
          systemd_service.active?(service).must_equal true
          systemd_service.deactivate(service).must_equal true
          systemd_service.active?(service).must_equal false
        end
        systemd_service.modified.must_equal true
        systemd_service.activate('some_random_nonexisting_service').must_equal false
        systemd_service.activate('some_other_nonexisting_service').must_equal false
        systemd_service.save.must_equal true
        systemd_service.modified.must_equal false
      end
    end
  end

  it "can enable and disable services" do
    stub_systemd_service do
      stub_toggle do
        systemd_service.read
        systemd_service.services.keys.each do |service|
          systemd_service.enable(service).must_equal true
          systemd_service.enabled?(service).must_equal true
          systemd_service.disable(service).must_equal true
          systemd_service.enabled?(service).must_equal false
        end
        systemd_service.modified.must_equal true
        systemd_service.enable('nonexisting_service').must_equal false
        systemd_service.disable('nonexisting_service').must_equal false
        systemd_service.save.must_equal true
        systemd_service.modified.must_equal false
      end
    end
  end

  it "is able to reset the changes done" do
    stub_systemd_service do
      stub_toggle do
        systemd_service.read
        systemd_service.services.keys.each do |service|
          origin_enabled = systemd_service.enabled?(service)
          systemd_service.toggle(service).must_equal true
          systemd_service.enabled?(service).must_equal(!origin_enabled)
          systemd_service.modified.must_equal true
          systemd_service.reset
          systemd_service.modified.must_equal false
          systemd_service.enabled?(service).must_equal(origin_enabled)
        end
      end
      stub_switch do
        systemd_service.read
        systemd_service.services.keys.each do |service|
          origin_active = systemd_service.active?(service)
          systemd_service.switch(service).must_equal true
          systemd_service.active?(service).must_equal(!origin_active)
          systemd_service.modified.must_equal true
          systemd_service.reset
          systemd_service.modified.must_equal false
          systemd_service.active?(service).must_equal(origin_active)
        end
      end
    end
  end
end
