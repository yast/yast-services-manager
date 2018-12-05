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

require_relative 'test_helper'

require "yast"
require "services-manager/service_loader"

describe Y2ServicesManager::ServiceLoader do

  subject { described_class.new }

  let(:alsasound) do
    instance_double(
      Yast2::SystemService, name: "alsasound", description: "alsasound", start: true, stop: true,
      state: "active", substate: "running", changed?: false, start_mode: :on_boot,
      save: nil, refresh: nil, errors: {}
    )
  end

  let(:apparmor) do
    instance_double(
      Yast2::SystemService, name: "apparmor", changed?: true, active?: true,
      running?: false, refresh: nil, save: nil, errors: {}
    )
  end
  
  let(:services) do
    [alsasound, apparmor]
  end  

  describe "#read" do
    before do
      allow_any_instance_of(Y2ServicesManager::ServiceLoader)
        .to receive(:list_unit_files).
        and_return(["apparmor.service enabled\n",
                    "alsasound.service static\n"])
      allow_any_instance_of(Y2ServicesManager::ServiceLoader)
        .to receive(:list_units).
        and_return(["alsasound.service loaded inactive dead Sound Card\n",
                    "apparmor.service loaded active exited AppArmor profiles\n"])      
    end

    context "when services can be evalutated by systemd/sockets" do
      it "returns services with correct name" do
        expect(Yast2::SystemService).to receive(:find_many).
          with(services.map {|service| service.name}.sort).
          and_return(services)
        read_services = subject.read.map {|key, service| service.name}
        expect(read_services).to eq( services.map {|service| service.name})
      end
    end

    context "when services cannot be evalutated by systemd/sockets" do
      it "returns none services" do
        expect(Yast2::SystemService).to receive(:find_many).
          with(services.map {|service| service.name}.sort).          
          and_return([nil,nil])
        expect(subject.read).to be_empty
      end
    end
    
  end
end

