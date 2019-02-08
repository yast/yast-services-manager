#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2014-2018] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "test_helper"

Yast.import "Mode"
Yast.import "ServicesManagerTarget"

module Yast
  module TestTarget
    class Template < Struct.new(
      :name, :allow_isolate?, :enabled?, :loaded?, :active?, :description
    )
    end

    GRAPHICAL  = Template.new("graphical", true)
    MULTI_USER = Template.new("multi-user", true)
    POWEROFF   = Template.new("poweroff", true)
    SLEEP      = Template.new("sleep", false)
    MDMONITOR  = Template.new("mdmonitor", true)

    ALL = [ GRAPHICAL, MULTI_USER, POWEROFF, SLEEP, MDMONITOR ]
  end

  extend Yast::I18n
  Yast::textdomain "services-manager"

  describe ServicesManagerTargetClass do
    subject { described_class.new }

    before do
      allow(Yast::Mode).to receive(:mode).and_return("normal")

      allow(Yast2::Systemd::Target).to receive(:all).and_return(TestTarget::ALL)
      allow(Yast2::Systemd::Target).to receive(:get_default).and_return(TestTarget::MULTI_USER)
    end

    describe "#default_target" do
      context "when the default target has not been set yet" do
        it "returns the default target in the system" do
          expect(subject.default_target).to eq("multi-user")
        end
      end

      context "when the default target has been set" do
        before do
          subject.default_target = "multi-user"
        end

        it "returns the new default target" do
          expect(subject.default_target).to eq("multi-user")
        end
      end
    end

    describe "#targets" do
      it "returns the list of all possible targets" do
        expect(subject.targets.keys).to contain_exactly("multi-user", "graphical", "mdmonitor")
      end

      it "does not include targets that does not allow isolate" do
        expect(subject.targets.keys).to_not include("sleep")
      end

      it "does not include targets that belongs to the black list" do
        expect(subject.targets.keys).to_not include("poweroff")
      end

      context "when running in 'initial' stage" do
        before do
          allow(Yast::Stage).to receive(:stage).and_return("initial")
        end

        it "returns an empty list" do
          expect(subject.targets).to be_empty
        end
      end
    end

    describe "#save" do
      before do
        subject.default_target = target
      end

      context "default target is available" do
        before do
          allow(Yast2::Systemd::Target).to receive(:find).and_return(TestTarget::GRAPHICAL)
        end

        context "when the default target has not been changed" do
          let(:target) { "multi-user" }

          it "does not perform changes in the underlying system" do
            expect(Yast2::Systemd::Target).to_not receive(:set_default)

            subject.save
          end
        end

        context "when the default target has been changed" do
          let(:target) { "graphical" }

          it "saves the changes in the underlying system" do
            expect(Yast2::Systemd::Target).to receive(:set_default).with("graphical")

            subject.save
          end
        end
      end

      context "when default target is not available" do
        let(:target) { "graphical" }

        it "reports an error and set to multi-user" do
          expect(Yast2::Systemd::Target).to receive(:find).and_return(nil)
          expect(Yast::Report).to receive(:Warning)
          expect(Yast2::Systemd::Target).to receive(:set_default).with("multi-user")
          subject.save
        end
      end
    end

    describe "#reset" do
      it "sets the default target according to value in the system" do
        subject.default_target = "mdmonitor"

        subject.reset

        expect(subject.default_target).to eq("multi-user")
      end
    end

    describe "#modified?" do
      before do
        subject.default_target = target
      end

      context "when the default target has been changed" do
        let(:target) { "graphical" }

        it "returns false" do
          expect(subject.modified?).to eq(true)
        end
      end

      context "when the default target has not been changed" do
        let(:target) { "multi-user" }

        it "returns true" do
          expect(subject.modified?).to eq(false)
        end
      end
    end

    describe "#modified=" do
      context "when is set to true" do
        it "sets the module as modified" do
          subject.modified = true
          expect(subject.modified?).to eq(true)
        end
      end

      context "when is set to false" do
        it "sets the module as 'not modified'" do
          subject.modified = false
          expect(subject.modified?).to eq(false)
        end

        context "but the default target has been changed" do
          let(:target) { "multi-user" }

          before do
            subject.default_target = "graphical"
          end

          it "does not set the module as 'not modified'" do
            subject.modified = false
            expect(subject.modified?).to eq(true)
          end
        end
      end
    end

    describe "#changes_summary" do
      context "when the default target has not been changed" do
        it "returns an empty text" do
          expect(subject.changes_summary).to be_empty
        end
      end

      context "when the default target has been changed" do
        before do
          subject.default_target = "graphical"
        end

        it "returns a summary describing the change" do
          expect(subject.changes_summary).to include("Default target will be changed")
        end
      end
    end
  end

  describe ServicesManagerTargetClass::BaseTargets do
    describe "#localize" do
      context "when target is known" do
        it "localizes the target" do
          expect(ServicesManagerTargetClass::BaseTargets.localize(
            ServicesManagerTargetClass::BaseTargets::GRAPHICAL
          )).to eq(Yast::_("Graphical mode"))
        end
      end

      context "when target is unknown" do
        it "returns the given target unlocalized" do
          expect(ServicesManagerTargetClass::BaseTargets.localize(
            "unknown-target"
          )).to eq("unknown-target")
        end
      end
    end
  end
end
