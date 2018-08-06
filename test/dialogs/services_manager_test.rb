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
require "services-manager/dialogs/services_manager"

describe Y2ServicesManager::Dialogs::ServicesManager do
  include Yast::UIShortcuts

  subject { described_class.new }

  before do
    # Mock opening and closing the dialog
    allow(Yast::Wizard).to receive(:GenericDialog).and_return(true)
    allow(Yast::Wizard).to receive(:OpenDialog).and_return(true)
    allow(Yast::Wizard).to receive(:SetContents).and_return(true)
    allow(Yast::Wizard).to receive(:CloseDialog).and_return(true)

    allow(Yast::UI).to receive(:GetDisplayInfo).and_return({})
  end

  describe "#run" do
    before do
      allow(Yast::UI).to receive(:UserInput).and_return(*user_input)
      allow(Yast::Popup).to receive(:ReallyAbort).and_return(true)

      allow(Yast::UI).to receive(:QueryWidget).with(Id(:services_table), :CurrentItem)
        .and_return(selected_service_name)

      allow(Yast2::Feedback).to receive(:show).and_yield

      allow(Yast::Popup).to receive(:ReallyAbort).and_return(true)

      stub_targets(targets_specs)
      stub_services(services_specs)
    end

    after(:each) do
      # To generate new doubles in each test
      Yast::ServicesManagerService.services = nil
    end

    let(:targets_specs) { [multi_user_specs] }

    let(:multi_user_specs) do
      {
        name:           "multi-user",
        allow_isolate?: true,
        enabled?:       true,
        loaded?:        true,
        active?:        true
      }
    end

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

    let(:selected_service_name) { "sshd" }

    context "when user selects 'Cancel' button" do
      let(:user_input) { [:cancel] }

      it "shows a confirmation popup" do
        expect(Yast::Popup).to receive(:ReallyAbort)

        subject.run
      end

      it "closes the dialog" do
        expect(Yast::UI).to receive(:CloseDialog)

        subject.run
      end

      it "returns false" do
        expect(subject.run).to eq(false)
      end
    end

    context "when user selects 'OK' button" do
      let(:user_input) { [:next] }

      before do
        allow(Yast::ServicesManager).to receive(:save).and_return(success)
      end

      let(:success) { true }

      it "tries to apply all changes" do
        expect(Yast::ServicesManager).to receive(:save)

        subject.run
      end

      context "and all changes are correctly applied" do
        let(:success) { true }

        it "closes the dialog" do
          expect(Yast::UI).to receive(:CloseDialog)

          subject.run
        end

        it "returns true" do
          expect(subject.run).to eq(true)
        end
      end

      context "and some changes cannot be applied" do
        let(:success) { false }

        it "asks whether to continue editing" do
          expect(Yast::Popup).to receive(:ContinueCancel)

          subject.run
        end

        context "and user wants to continue editing" do
          before do
            allow(Yast::Popup).to receive(:ContinueCancel).and_return(true)
          end

          let(:user_input) { [:next, :cancel] }

          it "refreshes the services list" do
            expect(subject).to receive(:refresh_services).twice

            subject.run
          end
        end

        context "and user does not want to continue editing" do
          before do
            allow(Yast::Popup).to receive(:ContinueCancel).and_return(false)
          end

          it "returns false" do
            expect(subject.run).to eq(false)
          end
        end
      end
    end

    context "when user selects 'Apply' button" do
      let(:user_input) { [:apply, :cancel] }

      before do
        allow(Yast::ServicesManager).to receive(:save).and_return(success)
      end

      let(:success) { true }

      it "tries to apply all changes" do
        expect(Yast::ServicesManager).to receive(:save)

        subject.run
      end

      context "and all changes are correctly applied" do
        let(:success) { true }

        it "refreshes the services list" do
          expect(subject).to receive(:refresh_services).twice

          subject.run
        end
      end

      context "and some changes cannot be applied" do
        let(:success) { false }

        it "asks whether to continue editing" do
          expect(Yast::Popup).to receive(:ContinueCancel)

          subject.run
        end

        context "and user wants to continue editing" do
          before do
            allow(Yast::Popup).to receive(:ContinueCancel).and_return(true)
          end

          it "refreshes the services list" do
            expect(subject).to receive(:refresh_services).twice

            subject.run
          end
        end

        context "and user does not want to continue editing" do
          before do
            allow(Yast::Popup).to receive(:ContinueCancel).and_return(false)
          end

          it "closes the dialog" do
            expect(Yast::UI).to receive(:CloseDialog)

            subject.run
          end

          it "returns false" do
            expect(subject.run).to eq(false)
          end
        end
      end
    end
  end
end
