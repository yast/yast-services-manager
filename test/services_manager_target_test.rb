#!/usr/bin/env rspec

require_relative "test_helper"

module Yast
  module TestTarget
    class Template < Struct.new(
      :name, :allow_isolate?, :enabled?, :loaded?, :active?, :description
    )
    end

    GRAPHICAL  = Template.new('graphical', true)
    MULTI_USER = Template.new('multi-user', true)
    POWEROFF   = Template.new('poweroff', true)
    SLEEP      = Template.new('sleep', false)

    ALL = [ GRAPHICAL, MULTI_USER, POWEROFF, SLEEP ]
  end

  describe ServicesManagerTarget do
    context "reading targets" do
      it "reads default target name and other targets" do
        expect(SystemdTarget).to receive(:all).and_return(TestTarget::ALL)
        expect(SystemdTarget).to receive(:get_default).and_return(TestTarget::GRAPHICAL)
        target = ServicesManagerTargetClass.new
        expect(target.default_target).to eq('graphical')
        expect(target.targets).not_to be_empty
        expect(target.targets.keys).to include('multi-user')
        expect(target.targets.keys).to include('graphical')
        expect(target.targets.keys).not_to include('poweroff')
        expect(target.targets.keys).not_to include('sleep')
      end

      it "skips reading targets if Mode.normal is false" do
        Mode.SetMode('not-normal')
        expect(SystemdTarget).not_to receive(:all)
        expect(SystemdTarget).not_to receive(:get_default)
        target = ServicesManagerTargetClass.new
        expect(target.targets).to be_empty
        expect(target.default_target).to be_empty
        Mode.SetMode('normal')
      end
    end

    context "saving default target" do
      it "saves the modified default target name" do
        expect(SystemdTarget).to receive(:all).and_return(TestTarget::ALL)
        expect(SystemdTarget).to receive(:get_default).and_return(TestTarget::GRAPHICAL)
        expect(SystemdTarget).to receive(:set_default).and_return(true)
        target = ServicesManagerTargetClass.new
        expect(target.default_target).to eq('graphical')
        target.default_target = 'multi-user'
        expect(target.default_target).to eq('multi-user')
        expect(target.save).to eq(true)
      end

      it "skips setting the default target if not modified" do
        expect(SystemdTarget).to receive(:all).and_return(TestTarget::ALL)
        expect(SystemdTarget).to receive(:get_default).and_return(TestTarget::GRAPHICAL)
        target = ServicesManagerTargetClass.new
        expect(target.modified).to eq(false)
        expect(target.save).to eq(true)
      end
    end

    context "re-setting targets" do
      it "reloads the object properties" do
        expect(SystemdTarget).to receive(:all).and_return(TestTarget::ALL)
        expect(SystemdTarget).to receive(:get_default).and_return(TestTarget::GRAPHICAL)
        target = ServicesManagerTargetClass.new
        target.default_target = 'multi-user'
        expect(target.modified).to eq(true)
        expect(SystemdTarget).to receive(:all).and_return(TestTarget::ALL)
        expect(SystemdTarget).to receive(:get_default).and_return(TestTarget::GRAPHICAL)
        target.reset
        expect(target.modified).to eq(false)
        expect(target.default_target).to eq('graphical')
      end
    end
  end

  describe ServicesManagerTargetClass::BaseTargets do
    describe "#localize" do
      context "target is known" do
        it "localizes the target" do
          expect(ServicesManagerTargetClass::BaseTargets.localize(
            ServicesManagerTargetClass::BaseTargets::GRAPHICAL
          )).to eq("Graphical")
        end
      end

      context "target is unknown" do
        it "returns the given target unlocalized" do
          expect(ServicesManagerTargetClass::BaseTargets.localize(
            "unknown-target"
          )).to eq("unknown-target")
        end
      end
    end
  end
end
