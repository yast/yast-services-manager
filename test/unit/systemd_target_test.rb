require "fileutils"

require File.join(File.dirname(__FILE__), "../test_helper")

require "test/unit"
require "mocha/setup"
require "ycp"

require "systemd_target"

class SystemdTargetTest < Test::Unit::TestCase
  def teardown
    Yast::SCR.unstub
  end

  def test_all_known_targets
    first_scr_call = {
      'exit'   => 0,
      'stderr' => '',
      'stdout' => "target-1     enabled\n" +
                  "target-2     disabled\n" +
                  "target-3     disabled\n",
    }
    second_scr_call = {
      'exit'   => 0,
      'stderr' => '',
      'stdout' => "target-1          loaded active   active     Basic target\n" +
                  "target-2          loaded active   active     Enhanced target\n" +
                  "target-3          loaded inactive dead       Super-enhanced target\n",
    }

    Yast::SCR.stubs(:Execute).returns(first_scr_call, second_scr_call)
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
end
