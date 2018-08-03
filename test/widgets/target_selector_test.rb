#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

require_relative '../test_helper'
require "services-manager/widgets/target_selector"

describe Y2ServicesManager::Widgets::TargetSelector do
  subject { described_class.new }

  before do
    stub_targets(targets)
  end

  let(:targets) { [multi_user_specs, graphical_specs] }

  let(:multi_user_specs) do
    {
      name:           "multi-user",
      allow_isolate?: true,
      enabled?:       true,
      loaded?:        true,
      active?:        true
    }
  end

  let(:graphical_specs) do
    {
      name:           "graphical",
      allow_isolate?: true,
      enabled?:       true,
      loaded?:        true,
      active?:        true
    }
  end

  describe "#widget" do
    it "returns a Yast::Term" do
      expect(subject.widget).to be_a(Yast::Term)
    end

    it "offers all possible targets" do
      widget = subject.widget

      expect(contain_option?(widget, "multi-user")).to eq(true)
      expect(contain_option?(widget, "graphical")).to eq(true)
    end
  end
end
