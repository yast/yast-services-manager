require_relative "test_helper"

include TestHelpers::Targets

describe Yast::SystemdTarget do

  Yast::SystemdTargetClass::DEFAULT_TARGET_PATH = TEST_TARGET_PATH.join('default.target').to_s
  Yast::SystemdTargetClass::SYSTEMD_TARGETS_DIR = TEST_TARGETS_DIR.to_s

  attr_reader :systemd_target

  before do
    @systemd_target = Yast::SystemdTargetClass.new
  end

  it "can set and save the default target" do
    stub_systemd_target do
      systemd_target.default_target.must_be_empty
      SUPPORTED_TEST_TARGETS.each do |target|
        systemd_target.default_target = target
        systemd_target.default_target.must_equal target
        systemd_target.modified.must_equal true
        systemd_target.save.must_equal true
      end

      UNSUPPORTED_TEST_TARGETS.each do |target|
        proc { systemd_target.default_target = target }.must_raise RuntimeError
      end
    end
  end

  it "can reset the loaded and modified settings" do
    stub_systemd_target do
      systemd_target.default_target.must_be_empty
      SUPPORTED_TEST_TARGETS.each do |target|
        systemd_target.default_target = target
        systemd_target.default_target.must_equal target
        systemd_target.default_target.wont_equal nil
        systemd_target.modified.must_equal true
        systemd_target.reset
        systemd_target.modified.must_equal false
        systemd_target.default_target.must_be_empty
      end
    end
  end

  it "cat list all supported targets" do
    stub_systemd_target do
      systemd_target.targets.must_be_empty
      systemd_target.read
      systemd_target.targets.wont_be_empty

      SUPPORTED_TEST_TARGETS.each do |target|
        systemd_target.targets.keys.must_include(target)
      end

      UNSUPPORTED_TEST_TARGETS.each do |target|
        systemd_target.targets.keys.wont_include(target)
      end
    end
  end
end
