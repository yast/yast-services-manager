require_relative 'test_helper'

require "systemd_service"

class SystemdServiceTest < Test::Unit::TestCase
  def teardown
    Yast::SCR.unstub
  end

  def test_all_known_services
    first_scr_call = {
      'exit'   => 0,
      'stderr' => '',
      'stdout' => "service-1     enabled\n" +
                  "service-2     enabled\n" +
                  "service-3     disabled\n",
    }
    second_scr_call = {
      'exit'   => 0,
      'stderr' => '',
      'stdout' => "service-1          loaded active   active     First service\n" +
                  "service-2          loaded active   active     Second service\n" +
                  "service-3          loaded inactive dead       Third service\n",
    }

    Yast::SCR.stubs(:Execute).returns(first_scr_call, second_scr_call)
    assert_equal(3, Yast::SystemdService.all.keys.count)
  end

  def test_export
    first_scr_call = {
      'exit'   => 0,
      'stderr' => '',
      'stdout' => "service-1     enabled\n" +
                  "service-2     enabled\n" +
                  "service-3     disabled\n",
    }
    second_scr_call = {
      'exit'   => 0,
      'stderr' => '',
      'stdout' => "service-1          loaded active   active     First service\n" +
                  "service-2          loaded active   active     Second service\n" +
                  "service-3          loaded inactive dead       Third service\n",
    }

    Yast::SCR.stubs(:Execute).returns(first_scr_call, second_scr_call)
    assert_equal(['service-1', 'service-2'], Yast::SystemdService.export.sort)
  end

end
