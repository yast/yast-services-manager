require_relative "test_helper"

describe Yast::SystemdTarget do
  it "can discover the default target" do
    skip "not done yet"
  end
end

__END__
class SystemdTargetTest

  def test_all_known_targets
    Yast::SCR.stubs(:Execute).returns(FIRST_SCR_CALL, SECOND_SCR_CALL)
    assert_equal(3, Yast::SystemdTarget.all.keys.count)
  end

  def test_current_default_target
    default_target = 'multi-user-with-cookies'
    default_target_path = File.join(
      Yast::SystemdTargetClass::SYSTEMD_TARGETS_DIR,
      default_target + Yast::SystemdTargetClass::TARGET_SUFFIX
    )
    Yast::SCR.stubs(:Read).returns(default_target_path)
    assert_equal(default_target, Yast::SystemdTarget.current_default)
  end

  def test_export
    default = 'target-2'
    Yast::SystemdTarget.stubs(:current_default).returns(default)
    assert_equal(default, Yast::SystemdTarget.export)
  end
end
