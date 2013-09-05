require_relative 'test_helper'

include TestHelpers::Services

describe Yast::SystemdService do
  attr_reader :systemd_service

  before do
    @systemd_service = Yast::SystemdServiceClass.new
  end

  it "returns all supported services" do
    systemd_service.services.must_be_empty
    systemd_service.errors.must_be_empty
    systemd_service.modified.must_equal false
    stub_systemd_service do
      systemd_service.read
      systemd_service.all.wont_be_empty
    end
  end

  it "does not include unsupported services" do
    puts get_services_units :accept => :unsupported
  end


end

__END__

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
