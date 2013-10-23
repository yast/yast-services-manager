#!/usr/bin/env rspec

require_relative "test_helper"

module Yast
  describe Yast::SystemdTarget do
    attr_reader :target

    before do
      SystemdTargetClass.any_instance
        .stub(:get_default_target_filename)
        .and_return('multi-user.target')
      SystemdTargetClass.any_instance
        .stub(:list_target_units)
        .and_return({
          'stdout' => "multi-user.target         enabled\n" +
                      "graphical.target          disabled",
          'stderr' => '',
          'exit'   => 0
        })

      SystemdTargetClass.any_instance
        .stub(:list_targets_details)
        .and_return({
          'stdout' => "multi-user.target  loaded active   active Multi-User System\n" +
                      "graphical.target  loaded active   active Graphical Interface",
          'stderr' => '',
          'exit'   => 0
        })
      SystemdTargetClass.any_instance.stub(:remove_default_target_symlink).and_return(true)
      SystemdTargetClass.any_instance.stub(:create_default_target_symlink).and_return(true)
      SystemdTargetClass.any_instance.stub(:default_target_file)
      @target = SystemdTargetClass.new
    end

    it "can set supported target" do
      supported_target = 'graphical'
      target.default_target = supported_target
      expect(target.default_target).to eq(supported_target)
      expect(target.modified).to eq(true)
      expect(target.errors).to be_empty
      expect(target.valid?).to be(true)
      expect(target.save).to eq(true)
    end

    it "can set but not save unsupported target" do
      unsupported = 'suse'
      target.default_target = unsupported
      expect(target.default_target).to eq(unsupported)
      expect(target.errors).not_to be_empty
      expect(target.valid?).to be(false)
      expect(target.save).to be(false)
    end

    it "can reset the modified target" do
      original_target = target.default_target
      new_target = 'test'
      target.default_target = new_target
      expect(target.default_target).to eq(new_target)
      expect(target.modified).to eq(true)
      target.reset
      expect(target.modified).to eq(false)
      expect(target.default_target).not_to eq(new_target)
      expect(target.default_target).to eq(original_target)
    end

  end
end
