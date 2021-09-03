# YaST Services Manager

[![Check](https://github.com/yast/yast-services-manager/actions/workflows/check.yml/badge.svg?branch=check_systemd_states)](https://github.com/yast/yast-services-manager/actions/workflows/check.yml?query=branch%3Acheck_systemd_states)

This branch contains a script which regularly scans for the systemd
states in openSUSE Tumbleweed.

The goal is to find the changes in systemd early and adapt YaST for the changes
as fast as possible.

## When the Check Fails

- Update the state names and their translations in
  [`Y2ServicesManager::Widgets::ServicesTable::TRANSLATIONS`][TRANS].

[TRANS]: https://github.com/yast/yast-services-manager/blob/master/src/lib/services-manager/widgets/services_table.rb

- The important changes are in Unit Active States (ActiveState
  property). That's because our Service Manager has a button that does either
  **Start** or **Stop**, depending on whether we judge the service as active
  or not.  [`Yast2::Systemd::UnitProperties::ACTIVE_STATES` (yast2.rpm)][AS]
  is the list to be adjusted.

[AS]: https://github.com/yast/yast-yast2/blob/master/library/systemd/src/lib/yast2/systemd/unit_properties.rb

- Changes in Service Unit Substates (SubState property) seem not to be
  important for our behavior, just keep their names translated.

  For the curious, to see which ActiveState a SubState corresponds to, see
  `state_translation_table` and `state_translation_table_idle`
  in [upstream src/core/service.c][service_c].

[service_c]: https://github.com/systemd/systemd/blob/main/src/core/service.c

- To see what the new states mean, look in
  [Systemd GitHub repository](https://github.com/systemd/systemd), search for
  the new state name, press `b` for *git blame*, find the commit and the
  corresponding Pull Request.

- Update `expected_states.yml` in this branch.
