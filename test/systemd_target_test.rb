require_relative "test_helper"

include TestHelpers::Targets

describe Yast::SystemdTarget do

  Yast::SystemdTargetClass::DEFAULT_TARGET_PATH = TEST_TARGET_PATH.join('default.target').to_s
  Yast::SystemdTargetClass::SYSTEMD_TARGETS_DIR = TEST_TARGETS_DIR.to_s

  attr_reader :system_target

  before do
    @system_target = Yast::SystemdTargetClass.new
  end

  it "can set and save the default target" do
    stub_system_target do
      TEST_TARGETS.each do |target|
        system_target.default_target = target
        system_target.modified.must_equal true
        system_target.default_target.must_equal target
        system_target.save.must_equal true
      end
    end
  end

  it "can reset the loaded and modified settings" do
    stub_system_target do
      TEST_TARGETS.each do |target|
        system_target.default_target = target
        system_target.modified.must_equal true
        system_target.reset
        system_target.modified.must_equal false
      end
    end
  end
end
