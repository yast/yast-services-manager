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

require "rspec"
require "yast"

module Yast
  module RSpec
    # RSpec extension to add YaST ServicesManager specific helpers
    module ServicesManagerHelpers

      # Stubs services defined from specs
      #
      # @example
      #
      #   services_specs = [
      #     {
      #       unit:            "sshd.service",
      #       start_mode:      :on_demand,
      #       start_modes:     [:on_boot, :on_demand, :manually],
      #       unit_file_state: "enabled",
      #       load:            "loaded",
      #       active:          "active",
      #       sub:             "running",
      #       description:     "running OpenSSH Daemon",
      #       search_terms:    ["sshd.service", "sshd.socket"]
      #     }
      #   ]
      #
      #   stub_services(services_specs)
      #
      # @param services_specs [Array<Hash>]
      def stub_services(services_specs)
        services = services_specs.map { |s| stub_service(s) }

        allow(Yast2::SystemService).to receive(:find_many) do |names|
          names.map do |name|
            services.find { |s| s.name == name }
          end
        end

        allow(Yast2::SystemService).to receive(:find) do |name|
          services.find { |s| s.name == name }
        end

        allow(Yast::ServicesManagerService).to receive(:find) do |name|
          Yast2::SystemService.find(name)
        end

        stub_list_unit_files(services_specs)
        stub_list_units(services_specs)
      end

      # Stubs a service
      #
      # @see #stubs_services
      #
      # @param serivces_specs [Hash]
      def stub_service(service_specs)
        start_mode = service_specs[:start_mode]

        if start_mode.nil?
          start_mode = service_specs[:unit_file_state] == "enabled" ? :boot : :manual
        end

        start_modes = service_specs[:start_modes] || [:on_boot, :manually]

        service = instance_double(Yast2::SystemService,
          name:         service_specs[:unit].split(".").first,
          start_mode:   start_mode,
          start_modes:  start_modes,
          active?:      service_specs[:active] == "active",
          state:        service_specs[:active],
          substate:     service_specs[:sub],
          description:  service_specs[:description],
          search_terms: service_specs[:search_terms]
        )

        allow(service).to receive(:start_mode=)

        service
      end

      # Stubs unit files
      #
      # @see #stubs_services
      #
      # @param services_specs [Array<Hash>]
      def stub_list_unit_files(services_specs)
        specs_with_unit_file_state = services_specs.select { |s| !s[:unit_file_state].nil? }

        lines = specs_with_unit_file_state.map do |specs|
          [specs[:unit], specs[:unit_file_state]].join(" ")
        end

        allow_any_instance_of(Y2ServicesManager::ServiceLoader)
          .to receive(:list_unit_files).and_return(lines)
      end

      # Stubs units
      #
      # @see #stubs_services
      #
      # @param services_specs [Array<Hash>]
      def stub_list_units(services_specs)
        specs_with_load = services_specs.select { |s| !s[:load].nil? }

        lines = specs_with_load.map do |specs|
          [specs[:unit], specs[:load], specs[:active], specs[:sub], specs[:description]].join(" ")
        end

        allow_any_instance_of(Y2ServicesManager::ServiceLoader).to receive(:list_units)
          .and_return(lines)
      end
    end
  end
end
