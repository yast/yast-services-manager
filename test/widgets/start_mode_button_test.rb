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
require "services-manager/widgets/start_mode_button"

describe Y2ServicesManager::Widgets::StartModeButton do
  subject { described_class.new(service_name) }

  before do
    stub_services(services_specs)
  end

  let(:services_specs) { [sshd_specs] }

  let(:sshd_specs) do
    {
      unit:            "sshd.service",
      unit_file_state: "enabled",
      start_mode:      :manual,
      start_modes:     start_modes,
      load:            "loaded",
      active:          "active",
      sub:             "running",
      description:     "OpenSSH Daemon"
    }
  end

  let(:service_name) { "sshd" }

  let(:start_modes) { [:on_boot, :manual] }

  describe "#widget" do
    it "returns a Yast::Term" do
      expect(subject.widget).to be_a(Yast::Term)
    end

    it "allows to select a star mode" do
      widget = subject.widget

      expect(contain_option?(widget, :on_boot)).to eq(true)
      expect(contain_option?(widget, :manual)).to eq(true)
    end

    context "when the service does not support to start on demand" do
      let(:start_modes) { [:on_boot, :manual] }

      it "does not show 'On demand' option" do
        expect(contain_option?(subject.widget, :on_demand)).to eq(false)
      end
    end

    context "when the service supports to start on demand" do
      let(:start_modes) { [:on_boot, :on_demand, :manual] }

      it "shows 'On demand' option" do
        expect(contain_option?(subject.widget, :on_demand)).to eq(true)
      end
    end
  end

  describe ".all_start_modes" do
    it "returns all possible start modes" do
      expect(described_class.all_start_modes).to contain_exactly(:on_boot, :on_demand, :manual)
    end
  end
end
