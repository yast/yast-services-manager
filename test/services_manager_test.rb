require_relative 'test_helper'

require "systemd_target"
require "systemd_service"
require "services_manager"

class ServicesManagerTest < Test::Unit::TestCase
  def teardown
    Yast::SCR.unstub
  end

  def test_export
    default_target = 'runlevel-800'
    services_to_enable = ['a', 'b', 'c']
    Yast::SystemdTarget.stubs(:export).returns(default_target)
    Yast::SystemdService.stubs(:export).returns(services_to_enable)

    data = Yast::ServicesManager.export

    assert_equal(default_target, data[Yast::ServicesManagerClass::Data::TARGET])
    services_to_enable.each do |service|
      assert(data[Yast::ServicesManagerClass::Data::SERVICES].include?(service))
    end
  end

end
