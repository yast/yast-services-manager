require_relative "test_helper"


module Yast
  describe Yast::SystemdTarget do
    attr_reader :systemd_target

    before do
      @target = Yast::SystemdTargetClass.new
      target.stub(:list_target_units).and_return({
        'stdout' => "multi-user.target         enabled\n" +
                    "graphical.target          disabled",
        'stderr' => '',
        'exit'   => 0
      })

      target.stub(:list_target_details).and_return({
        'stdout' => "multi-user.target  loaded active   active Multi-User System\n" +
                    "graphical.target  loaded active   active Graphical Interface",
        'stderr' => '',
        'exit'   => 0
      })
      target.stub(:remove_default_target_symlink)
      target.stub(:create_default_target_symlink)
      target.stub(:get_default_target_filename)
      target.stub(:default_target_file)
    end

    it "can set supported target" do
      supported_target = 'graphical'
      systemd_target.default_target = supported_target
      systemd_target.default_target.must_equal supported_target
      systemd_target.modified.must_equal true
      systemd_target.save.must_equal true
    end

    it "fails when trying to set an unsupported target" do
      unsupported_target = 'shutdown'
      proc { systemd_target.default_target = unsupported_target }.must_raise RuntimeError
    end

    it "can reset the modified target" do
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

    it "includes supported targets" do
      systemd_target.read
      systemd_target.targets.wont_be_empty
      %w(runlevel4 runlevel3).each do |target|
        systemd_target.targets.keys.must_include(target)
      end
    end

    it "does not include unsupported targets" do
      systemd_target.read
      %w(runlevel80 final).each do |target|
        systemd_target.targets.keys.wont_include(target)
      end
    end
  end
end
