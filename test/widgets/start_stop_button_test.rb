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
require "services-manager/widgets/start_stop_button"

describe Y2ServicesManager::Widgets::StartStopButton do
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
      start_modes:     [:on_boot, :manual],
      load:            "loaded",
      active:          state,
      sub:             "running",
      description:     "OpenSSH Daemon"
    }
  end

  let(:service_name) { "sshd" }

  let(:state) { "active" }

  describe "#widget" do
    it "returns a Yast::Term" do
      expect(subject.widget).to be_a(Yast::Term)
    end

    context "when the service is active" do
      let(:state) { "active" }

      it "uses 'Stop' label" do
        expect(subject.widget.params.last).to match(/Stop/)
      end
    end

    context "when the service is not active" do
      let(:state) { "inactive" }

      it "uses 'Start' label" do
        expect(subject.widget.params.last).to match(/Start/)
      end
    end
  end
end
