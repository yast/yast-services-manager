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
require "y2journal"
require "services-manager/clients/services_manager"

describe Y2ServicesManager::Clients::ServicesManager do
  subject { described_class.new }

  describe "#run" do
    before do
      allow(Y2ServicesManager::Dialogs::ServicesManager).to receive(:new).and_return(dialog)
    end

    let(:dialog) { instance_double(Y2ServicesManager::Dialogs::ServicesManager, run: true) }

    it "runs the Services Manager dialog" do
      expect(dialog).to receive(:run)

      subject.run
    end

    context "when yast2-journal is installed" do
      before do
        allow(subject).to receive(:journal_loaded?).and_return(true)
      end

      it "runs the dialog with a button to show the logs" do
        expect(Y2ServicesManager::Dialogs::ServicesManager).to receive(:new)
          .with(show_logs_button: true).and_return(dialog)

        subject.run
      end
    end

    context "when yast2-journal is not installed" do
      before do
        allow(subject).to receive(:journal_loaded?).and_return(false)
      end

      it "runs the dialog without a button to show the logs" do
        expect(Y2ServicesManager::Dialogs::ServicesManager).to receive(:new)
          .with(show_logs_button: false).and_return(dialog)

        subject.run
      end
    end
  end
end
