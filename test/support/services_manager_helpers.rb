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
      #       keywords:        ["sshd.service", "sshd.socket"],
      #       changed:         false,
      #       errors:          []
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
      # @see #stub_services
      #
      # @param serivce_specs [Hash]
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
          keywords:     service_specs[:keywords],
          changed?:     service_specs[:changed] || false,
          errors:       service_specs[:errors] || []
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

      # Stubs targets defined from specs
      #
      # @example
      #
      #   targets_specs = [
      #     {
      #       name:           "multi-user",
      #       allow_isolate?: true,
      #       enabled?:       true,
      #       loaded?:        true,
      #       active?:        true
      #     }
      #   ]
      #
      #   stub_targets(targets_specs)
      #
      # @param targets_specs [Array<Hash>]
      def stub_targets(targets_specs)
        targets = targets_specs.map { |s| stub_target(s) }

        allow(Yast::SystemdTarget).to receive(:default_target).and_return(targets.first)
        allow(Yast::SystemdTarget).to receive(:all).and_return(targets)
      end

      # Stubs a target
      #
      # @see #stub_targets
      #
      # @param target_specs [Hash]
      def stub_target(target_specs)
        instance_double(Yast::SystemdTargetClass::Target, target_specs)
      end

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

        options.all? { |opt| contain_option?(widget, opt) }
      end

      # Checks whether a widget contains a specific option
      #
      # @param tree [Yast::Term]
      # @param option [Symbol, String]
      #
      # @return [Boolean]
      def contain_option?(widget, option)
        widget.params.last.any? { |opts| contain_widget?(opts, option) }
      end
    end
  end
end
