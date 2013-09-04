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
      system_target.default_target.must_be_empty
      SUPPORTED_TEST_TARGETS.each do |target|
        system_target.default_target = target
        system_target.default_target.must_equal target
        system_target.modified.must_equal true
        system_target.save.must_equal true
      end

      UNSUPPORTED_TEST_TARGETS.each do |target|
        proc { system_target.default_target = target }.must_raise RuntimeError
      end
    end
  end

  it "can reset the loaded and modified settings" do
    stub_system_target do
      system_target.default_target.must_be_empty
      SUPPORTED_TEST_TARGETS.each do |target|
        system_target.default_target = target
        system_target.default_target.must_equal target
        system_target.default_target.wont_equal nil
        system_target.modified.must_equal true
        system_target.reset
        system_target.modified.must_equal false
        system_target.default_target.must_be_empty
      end
    end
  end

  it "cat list all supported targets" do
    stub_system_target do
      system_target.targets.must_be_empty
      system_target.read
      system_target.targets.wont_be_empty

      SUPPORTED_TEST_TARGETS.each do |target|
        system_target.targets.keys.must_include(target)
      end

      UNSUPPORTED_TEST_TARGETS.each do |target|
        system_target.targets.keys.wont_include(target)
      end
    end
  end
end
