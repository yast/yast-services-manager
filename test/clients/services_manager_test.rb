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
require "services-manager/clients/services_manager"

describe Y2ServicesManager::Clients::ServicesManager do
  include Yast::UIShortcuts

  # Finds in the widgets tree a widget with the given id
  #
  # @param tree [Yast::Term]
  # @param id [Symbol]
  #
  # @return [Boolean]
  def exist_widget?(tree, id)
    !tree.nested_find { |w| w.is_a?(Yast::Term) && w.value == :id && w[0] == id }.nil?
  end

  subject { described_class.new }

  before do
    # Mock opening and closing the dialog
    allow(Yast::Wizard).to receive(:CreateDialog).and_return(true)
    allow(Yast::Wizard).to receive(:CloseDialog).and_return(true)

    allow(Yast::UI).to receive(:GetDisplayInfo).and_return({})
  end

  describe "#run" do
    before do
      allow(Yast::UI).to receive(:UserInput).and_return(*user_input)
      allow(Yast::Popup).to receive(:ReallyAbort).and_return(true)

      allow(Yast::SystemdTarget).to receive(:get_default).and_return(default_target)
      allow(Yast::SystemdTarget).to receive(:all).and_return(tagets)

      allow(Y2ServicesManager::ServiceLoader).to receive(:new).and_return(loader)

      allow(loader).to receive(:list_unit_files).and_return(units_files_output)
      allow(loader).to receive(:list_units).and_return(units_output)

      allow(Yast::SystemdService).to receive(:find_many)
        .with(services.map(&:name).sort).and_return(services)
    end

    let(:loader) { Y2ServicesManager::ServiceLoader.new }

    let(:default_target) { multi_user_target }

    let(:tagets) { [multi_user_target] }

    let(:multi_user_target) do
      double("target",
        name:           "multi-user",
        allow_isolate?: true,
        enabled?:       true,
        loaded?:        true,
        active?:        true
      )
    end

    let(:units_files_output) do
      [
        "sshd.service      enabled \n",
        "postfix.service   disabled\n"
      ]
    end

    let(:units_output) do
      [
        "sshd.service  loaded active   running OpenSSH Daemon\n",
        "postfix.service loaded inactive dead    Postfix Mail Agent\n"
      ]
    end

    let(:services) { [sshd_service, postfix_service] }

    let(:sshd_service) do
      double("service",
        name:     "sshd",
        enabled?: true,
        active?:  true
      )
    end

    let(:postfix_service) do
      double("service",
        name:     "postfix",
        enabled?: false,
        active?:  true
      )
    end

    let(:user_input) { [:abort] }

    context "when yast2-journal is installed" do
      it "offers a button to show the logs" do
        expect(Yast::Wizard).to receive(:SetContentsButtons) do |_, content, *|
          expect(exist_widget?(content, :show_logs)).to eq(true)
        end

        subject.run
      end
    end

    context "when yast2-journal is not installed" do
      before do
        allow(subject).to receive(:journal_loaded?).and_return(false)
      end

      it "does not offer a button to show the logs" do
        expect(Yast::Wizard).to receive(:SetContentsButtons) do |_, content, *|
          expect(exist_widget?(content, :show_logs)).to eq(false)
        end

        subject.run
      end
    end

    context "when log button is used" do
      let(:user_input) { [:show_logs, :abort] }

      before do
        allow(Yast::UI).to receive(:QueryWidget).with(table_id, :CurrentItem)
          .and_return(sshd_service.name)
        allow(Yast::SystemdService).to receive(:find).with(sshd_service.name)
          .and_return(sshd_service)

        allow(sshd_service).to receive(:id) { "sshd.service" }
        allow(sshd_service).to receive(:socket).and_return(socket)

        allow(Y2Journal::EntriesDialog).to receive(:new).and_return(entries_dialog)
      end

      let(:table_id) { Id(described_class::Id::SERVICES_TABLE) }

      let(:socket) { nil }

      let(:entries_dialog) { instance_double(Y2Journal::EntriesDialog, run: nil) }

      def expect_query_units(*units)
        expect(Y2Journal::Query).to receive(:new) do |params|
          filtered_units = params[:filters]["unit"]
          expect(filtered_units).to contain_exactly(*units)
        end
      end

      it "shows the systemd journal entries for the selected service" do
        expect_query_units("sshd.service")

        subject.run
      end

      context "and the service has an associated socked unit" do
        let(:socket) { double("socket", id: "sshd.socket") }

        it "also shows the systemd journal entries for the socked unit" do
          expect_query_units("sshd.service", "sshd.socket")

          subject.run
        end
      end
    end
  end
end
