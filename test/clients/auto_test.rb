#!/usr/bin/env rspec

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

require_relative "../test_helper"
require "services-manager/clients/auto"

describe Y2ServicesManager::Clients::Auto do
  subject(:client) { Y2ServicesManager::Clients::Auto.new }

  describe "#change" do
    before do
      allow(Yast::WFM).to receive(:CallFunction).with("services-manager")
        .and_return(true)
    end

    it "runs services-manager client" do
      expect(Yast::WFM).to receive(:CallFunction).with("services-manager")
      client.change
    end

    it "returns :accept if changes are confirmed" do
      expect(client.change).to eq(:accept)
    end
  end

  describe "#summary" do
    before do
      allow(Yast::ServicesManager).to receive(:auto_summary)
        .and_return("Services List")
    end

    it "returns the AutoYaST summary" do
      expect(client.summary).to eq("Services List")
    end
  end

  describe "#import" do
    let(:profile) { { "default-target" => "graphical" } }

    it "imports the profile" do
      expect(Yast::ServicesManager).to receive(:import).with(profile)
      client.import(profile)
    end
  end

  describe "#export" do
    let(:profile) { { "default-target" => "graphical" } }

    before do
      allow(Yast::ServicesManager).to receive(:export).and_return(profile)
    end

    it "exports the services information for the AutoYaST profile" do
      expect(client.export).to eq(profile)
    end
  end

  describe "#read" do
    it "runs system services information" do
      expect(Yast::ServicesManager).to receive(:read)
      client.read
    end
  end

  describe "#write" do
    before do
      allow(Yast::WFM).to receive(:CallFunction).and_return(true)
    end

    it "runs services manager finish client" do
      expect(Yast::WFM).to receive(:CallFunction).with("services-manager_finish", ["Write"])
      client.write
    end

    it "returns the value from the finish client" do
      expect(client.write).to eq(true)
    end
  end

  describe "#reset" do
    it "resets the services information" do
      expect(Yast::ServicesManager).to receive(:reset)
      client.reset
    end
  end

  describe "#packages" do
    it "returns an empty hash (no packages to install)" do
      expect(client.packages).to eq({})
    end
  end

  describe "#modified?" do
    before do
      allow(Yast::ServicesManager).to receive(:modified?).and_return(modified?)
    end

    context "when the services information was modified" do
      let(:modified?) { true }

      it "returns true" do
        expect(client.modified?).to eq(true)
      end
    end

    context "when the services information was modified" do
      let(:modified?) { false }

      it "returns false" do
        expect(client.modified?).to eq(false)
      end
    end
  end
end
