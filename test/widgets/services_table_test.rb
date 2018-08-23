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

require "yast"
require "services-manager/widgets/services_table"

# TODO
#
# This table should be rewritten as a CWM::Table. For now, only some basic unit tests
# are added.
describe Y2ServicesManager::Widgets::ServicesTable do
  include Yast::UIShortcuts

  subject { described_class.new(id: :services_table, services_names: services_names) }

  before do
    allow(Yast::UI).to receive(:GetDisplayInfo).and_return({})

    stub_services(services_specs)
  end

  let(:services_names) { services_specs.map { |specs| specs[:unit].split(".").first } }

  let(:services_specs) { [sshd_specs, postfix_specs] }

  let(:sshd_specs) do
    {
      unit:            "sshd.service",
      unit_file_state: "enabled",
      start_mode:      :manual,
      start_modes:     [:on_boot, :manual],
      load:            "loaded",
      active:          "active",
      sub:             "running",
      description:     "running OpenSSH Daemon"
    }
  end

  let(:postfix_specs) do
    {
      unit:            "postfix.service",
      unit_file_state: "disabled",
      start_mode:      :on_boot,
      start_modes:     [:on_boot, :on_demand, :manual],
      load:            "loaded",
      active:          "inactive",
      sub:             "dead",
      description:     "Postfix Mail Agent"
    }
  end


  describe "#widget" do
    it "returns a Yast::Term" do
      expect(subject.widget).to be_a(Yast::Term)
    end
  end

  describe "#selected_service" do
    before do
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:services_table), :CurrentItem)
        .and_return(selected_service_name)
    end

    let(:selected_service_name) { "sshd" }

    it "returns the selected service object" do
      expect(subject.selected_service.name).to eq(selected_service_name)
    end
  end

  describe "#help" do
    it "returns the help text" do
      expect(subject.help).to be_a(String)
      expect(subject.help).to match(/shows the name/)
    end
  end
end
