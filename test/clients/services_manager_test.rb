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

require "y2journal"

require "yast"
require "services-manager/clients/services_manager"

describe Y2ServicesManager::Clients::ServicesManager do
  include Yast::UIShortcuts

  # Checks whether a widgets tree contains the given id
  #
  # @param tree [Yast::Term]
  # @param id [Symbol]
  #
  # @return [Boolean]
  def contain_widget?(tree, id)
    !find_widget(tree, value: :id, param: id).nil?
  end

  # Finds a widget in the widgets tree
  #
  # @param tree [Yast::Term]
  # @param value [Symbol]
  # @param param [Object]
  #
  # @return [Yast::Term, nil]
  def find_widget(tree, value: nil, param: nil)
    return nil unless tree.is_a?(Yast::Term)

    tree.nested_find do |widget|
      widget.is_a?(Yast::Term) &&
        widget.value == value &&
        widget.params.any?(param)
      end
  end

  # Checks whether the widgets tree contains a button with a specific label
  #
  # @param tree [Yast::Term]
  # @param label [String]
  #
  # @return [Boolean]
  def contain_button?(tree, label)
    !find_widget(tree, value: :PushButton, param: label).nil?
  end

  # Checks whether the widgets tree contains a menu button with a specific label and
  # options (optional). The presence of given options is checked, but the menu button
  # could contain more options.
  #
  # @param tree [Yast::Term]
  # @param label [String]
  # @param options [Array<Symbol>]
  #
  # @return [Boolean]
  def contain_menu_button?(tree, label, options: [])
    widget = find_widget(tree, value: :MenuButton, param: label)

    return false if widget.nil?

    options.all? do |option|
      widget.params.last.any? { |opts| contain_widget?(opts, option) }
    end
  end

  # Helper for buttons expectations
  #
  # @param block [Proc]
  def expect_refresh_buttons(&block)
    expect(Yast::UI).to receive(:ReplaceWidget) do |_, content|
      expect(block.call(content)).to eq(true)
    end
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

      allow(Yast::Wizard).to receive(:SetContentsButtons)

      allow(Yast::SystemdTarget).to receive(:get_default).and_return(default_target)
      allow(Yast::SystemdTarget).to receive(:all).and_return(tagets)

      allow(Yast::UI).to receive(:QueryWidget).with(Id(:services_table), :CurrentItem)
        .and_return(selected_service_name)

      allow(Yast2::Feedback).to receive(:show).and_yield

      stub_services(services_specs)
    end

    after(:each) do
      # To generate new doubles in each test
      Yast::ServicesManagerService.services = nil
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

    let(:default_target) { multi_user_target }

    let(:tagets) { [multi_user_target] }

    let(:multi_user_target) do
      instance_double(Yast::SystemdTargetClass::Target,
        name:           "multi-user",
        allow_isolate?: true,
        enabled?:       true,
        loaded?:        true,
        active?:        true
      )
    end

    # Only to finish
    let(:user_input) { [:abort] }

    let(:selected_service_name) { "sshd" }

    context "when the selected service is running" do
      it "shows a 'stop' button" do
        expect_refresh_buttons { |buttons| contain_button?(buttons, "&Stop") }

        subject.run
      end
    end

    context "when the selected service is not running" do
      let(:selected_service_name) { "postfix" }

      it "shows a 'start' button" do
        expect_refresh_buttons { |buttons| contain_button?(buttons, "&Start") }

        subject.run
      end
    end

    context "when the selected service supports to start on demand" do
      let(:selected_service_name) { "postfix" }

      it "allows to select 'On demand' start mode" do
        expect_refresh_buttons do |buttons|
          contain_menu_button?(buttons, "Start Mode", options: [:on_boot, :on_demand, :manual])
        end

        subject.run
      end
    end

    context "when the selected service does not support to start on demand" do
      let(:selected_service_name) { "sshd" }

      it "does not allow to select 'On demand' start mode" do
        expect_refresh_buttons do |buttons|
          contain_menu_button?(buttons, "Start Mode", options: [:on_boot, :manual]) &&
            !contain_menu_button?(buttons, "Start Mode", options: [:on_demand])
        end

        subject.run
      end
    end

    context "when yast2-journal is installed" do
      before do
        allow(subject).to receive(:journal_loaded?).and_return(true)
      end

      it "offers a button to show the logs" do
        expect_refresh_buttons { |buttons| contain_button?(buttons, "Show &Log") }

        subject.run
      end
    end

    context "when yast2-journal is not installed" do
      before do
        allow(subject).to receive(:journal_loaded?).and_return(false)
      end

      it "does not offer a button to show the logs" do
        expect_refresh_buttons { |buttons| !contain_button?(buttons, "Show &Log") }

        subject.run
      end
    end

    context "when log button is used" do
      let(:user_input) { [:show_logs, :abort] }

      let(:entries_dialog) { instance_double(Y2Journal::EntriesDialog, run: nil) }

      let(:selected_service_name) { "sshd" }

      let(:services_specs) { [sshd_specs2, postfix_specs] }

      let(:sshd_specs2) { sshd_specs.merge(keywords: keywords) }

      let(:keywords) { ["sshd.service", "sshd.socket"] }

      it "shows the systemd journal entries for the selected service" do
        expect(Y2Journal::EntriesDialog).to receive(:new) do |params|
          filters = params[:query].filters["unit"]
          expect(filters).to contain_exactly(*keywords)
        end.and_return(entries_dialog)

        subject.run
      end
    end
  end
end
