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

require "yast"
require "services-manager/widgets/base"

Yast.import "ServicesManager"

module Y2ServicesManager
  module Widgets
    class ServicesTable < Base
      extend Yast::I18n

      # Systemd states and substates might change. Use the following script to check
      # whether new states are not considered yet:
      #
      # https://github.com/yast/yast-services-manager/blob/systemd_states_check/devel/systemd_status_check.rb
      TRANSLATIONS = {
        service_state: {
          "activating"   => N_("Activating"),
          "active"       => N_("Active"),
          "deactivating" => N_("Deactivating"),
          "failed"       => N_("Failed"),
          "inactive"     => N_("Inactive"),
          "reloading"    => N_("Reloading")
        },
        service_substate: {
          "auto-restart"  => N_("Auto-restart"),
          "dead"          => N_("Dead"),
          "exited"        => N_("Exited"),
          "failed"        => N_("Failed"),
          "final-sigkill" => N_("Final-sigkill"),
          "final-sigterm" => N_("Final-sigterm"),
          "reload"        => N_("Reload"),
          "running"       => N_("Running"),
          "start"         => N_("Start"),
          "start-post"    => N_("Start-post"),
          "start-pre"     => N_("Start-pre"),
          "stop"          => N_("Stop"),
          "stop-post"     => N_("Stop-post"),
          "stop-sigabrt"  => N_("Stop-sigabrt"),
          "stop-sigkill"  => N_("Stop-sigkill"),
          "stop-sigterm"  => N_("Stop-sigterm")
        }
      }
      private_constant :TRANSLATIONS

      # Constructor
      #
      # @example
      #   ServicesTable.new(services_names: ["tftp", "cups"])
      #
      # @param id [Symbol] widget id
      # @param services_names [Array<String>] name of services to show
      def initialize(id: nil, services_names: [])
        textdomain "services-manager"

        super(id: id)
        @services_names = services_names
      end

      # @return [Yast::Term]
      def widget
        @table ||= Table(id, Opt(:immediate), header, items)
      end

      # Sets focus on the table
      def focus
        UI.SetFocus(id)
      end

      # Refreshes the content of the table
      #
      # The table will refresh its content with the given services names. In case that
      # no services names are given, it will show the same services again.
      #
      # @param services_names [Array<String>, nil]
      def refresh(services_names: nil)
        @services_names = services_names if services_names

        UI.ChangeWidget(id, :Items, items)
        focus
      end

      # Refreshes the row of a specific service
      #
      # @param service_name [String]
      def refresh_row(service_name)
        refresh_start_mode_value(service_name)
        refresh_state_value(service_name)
        focus
      end

      # Name of the service of the currently selected row
      #
      # @return [String]
      def selected_service_name
        UI.QueryWidget(id, :CurrentItem)
      end

      # Service object of the currently selected row
      #
      # @return [Yast2::SystemService, nil] nil if the service is not found
      def selected_service
        service(selected_service_name)
      end

      # Help text
      #
      # @return [String]
      def help
        # TRANSLATORS: help text to explain the columns of the services table
        _(
          "<h2>The table contains the following information:</h2>" \
          "<b>Service</b> shows the name of the service." \
          "<br />" \
          "<b>Start</b> shows the start mode of the service:" \
          "<ul>" \
            "<li>On Boot: the service will be automatically started after booting the system.</li>" \
            "<li>On Demand: the service will be automatically started when needed.</li>" \
            "<li>Manually: the service will not be automatically started.</li>" \
          "</ul>" \
          "<b>State</b> shows the state and substate of the service." \
          "<br />" \
          "<b>Description</b> shows the description of the service." \
          "<br />" \
          "<br />" \
          "Note: edited values are marked with '(*)'."
        )
      end

    private

      # @return [Array<String>] services shown in the table
      attr_reader :services_names

      # Default widget id
      #
      # @see Base#default_id
      #
      # @return [Yast::Term]
      def default_id
        Id(:services_table)
      end

      # Table header
      #
      # @return [Yast::Term]
      def header
        Header(
          *columns.map { |c| send("#{c}_title") }
        )
      end

      # Content of the table
      #
      # @return [Array<Yast::Term>]
      def items
        services_names.sort_by { |s| s.downcase }.map { |s| Item(*values_for(s)) }
      end

      # Values to show in the table for a specific service
      #
      # @param service_name [String]
      # @return [Array<Yast::Term, String>]
      def values_for(service_name)
        [row_id(service_name)] + columns.map { |c| send("#{c}_value", service_name) }
      end

      # Columns to show in the table
      #
      # @return [Array<Symbol>]
      def columns
        [:name, :start_mode, :state, :description]
      end

      # Title for name column
      #
      # @return [String]
      def name_title
        _("Service")
      end

      # Title for start_mode column
      #
      # @return [String]
      def start_mode_title
        _("Start")
      end

      # Title for state column
      #
      # @return [String]
      def state_title
        _("State")
      end

      # Title for description column
      #
      # @return [String]
      def description_title
        _("Description")
      end

      # Id for a table row of a service
      #
      # @param service_name [String]
      # @return [Yast::Term]
      def row_id(service_name)
        Id(service_name)
      end

      # Value for the name column of a service
      #
      # @param service_name [String]
      # @return [String]
      def name_value(service_name)
        max_width = max_column_width(:name)
        return service_name if service_name.size < max_width

        service_name[0..(max_width - 3)] + "..."
      end

      # Value for the start_mode column of a service
      #
      # @note The value contains a special mark when it has been edited by the user,
      #   see {#highlight_value}.
      #
      # @param service_name [String]
      # @return [String]
      def start_mode_value(service_name)
        value = ServicesManagerService.start_mode_to_human_for(service_name)

        value = highlight_value(value) if service(service_name).changed?(:start_mode)

        value
      end

      # Value for the state column of a service
      #
      # By default it shows the current service status, but if the user starts or stops
      # the service, then it shows the fixed text "Active" or "Inactive", see {#current_state_value}
      # and {#future_state_value}.
      #
      # @note The value contains a special mark when it has been edited by the user,
      #   see {#highlight_value}.
      #
      # @param service_name [String]
      # @return [String]
      def state_value(service_name)
        service = service(service_name)

        return current_state_value(service) unless service.changed?(:active)

        future_state_value(service)
      end

      # Value for the description column of a service
      #
      # @param service_name [String]
      # @return [String]
      def description_value(service_name)
        ServicesManagerService.description(service_name) || ""
      end

      # Text for the current state of the service
      #
      # @param service [Yast2::SystemService]
      # @return [String]
      def current_state_value(service)
        state = TRANSLATIONS[:service_state][service.state]
        substate = TRANSLATIONS[:service_substate][service.substate]

        return _(state) unless substate

        # TRANSLATORS: state of a service, as showed by systemctl (e.g., "Active (Running)").
        # %{state} is replaced by the service state (e.g. "Active", "Inactive", etc) and
        # %{substate} is replaced by the service substate (e.g., "Start", "Stop", "Exited", etc).
        format(_("%{state} (%{substate})"), state: _(state), substate: _(substate))
      end

      # Text for the future state of the service
      #
      # @note It contains a special mark, see {#highlight_value}.
      #
      # @param service [Yast2::SystemService]
      # @return [String]
      def future_state_value(service)
        value = service.active? ? _("Active") : _("Inactive")
        highlight_value(value)
      end

      # Adds a special mark to highlight the value (e.g., when the value has been edited)
      #
      # @param value [String]
      # @return [String]
      def highlight_value(value)
        "(*) " + value
      end

      # Service object
      #
      # @param service_name [String]
      # @return [Yast2::SystemService, nil] nil if the service is not found
      def service(service_name)
        ServicesManagerService.find(service_name)
      end

      # Updates the value for the start_mode column of a service
      #
      # @param service_name [String]
      def refresh_start_mode_value(service_name)
        UI.ChangeWidget(id, Cell(service_name, 1), start_mode_value(service_name))
      end

      # Updates the value for the state column of a service
      #
      # @param service_name [String]
      def refresh_state_value(service_name)
        UI.ChangeWidget(id, Cell(service_name, 2), state_value(service_name))
      end

      # Max width of a column
      #
      # In general there is no limitation for any column. Only name column has
      # a limited width.
      #
      # @param column [Symbol]
      # @return [Integer]
      def max_column_width(column)
        return nil if column != :name

        # use 60 for other elements in table we want to display, see bsc#993826
        display_width - 60
      end

      # @return [Integer]
      def display_width
        UI.GetDisplayInfo["Width"] || 80
      end
    end
  end
end
