require_relative "test_helper"

include TestHelpers::Targets

describe Yast::SystemdTarget do

  # replace /etc/systemd/system/default.target with test/tmp/targets/etc/default.target
  Yast::SystemdTargetClass::DEFAULT_TARGET_PATH = TEST_TARGET_PATH.join('default.target').to_s
  # replace /usr/lib/systemd/system with test/tmp/targets/lib
  Yast::SystemdTargetClass::SYSTEMD_TARGETS_DIR = TEST_TARGETS_DIR.to_s

  attr_reader :systemd_target

  before do
    @systemd_target = Yast::SystemdTargetClass.new
  end

  it "can set and save supported default target" do
    stub_systemd_target do
      systemd_target.default_target.must_be_empty
      supported_target = 'runlevel2'
      systemd_target.default_target = supported_target
      systemd_target.default_target.must_equal supported_target
      systemd_target.modified.must_equal true
      systemd_target.save.must_equal true
    end
  end

  it "fails when trying to set an unsupported target" do
    stub_systemd_target do
      unsupported_target = 'shutdown'
      proc { systemd_target.default_target = unsupported_target }.must_raise RuntimeError
    end
  end

  it "can reset the modified target" do
    stub_systemd_target do
      systemd_target.default_target.must_be_empty
      supported_target = 'multi-user'
      systemd_target.default_target = supported_target
      systemd_target.default_target.must_equal supported_target
      systemd_target.default_target.wont_equal nil
      systemd_target.modified.must_equal true
      systemd_target.reset
      systemd_target.modified.must_equal false
      systemd_target.default_target.must_be_empty
    end
  end

  it "includes supported targets" do
    stub_systemd_target do
      systemd_target.read
      systemd_target.targets.wont_be_empty
      %w(runlevel4 runlevel3).each do |target|
        systemd_target.targets.keys.must_include(target)
      end
    end
  end

  it "does not include unsupported targets" do
    stub_systemd_target do
      systemd_target.read
      %w(runlevel80 final).each do |target|
        systemd_target.targets.keys.wont_include(target)
      end
    end
  end
end
