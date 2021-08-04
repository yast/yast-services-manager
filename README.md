# Yast Services Manager

[![Workflow Status](https://github.com/yast/yast-services-manager/workflows/CI/badge.svg?branch=master)](
https://github.com/yast/yast-services-manager/actions?query=branch%3Amaster)
[![Jenkins Status](https://ci.opensuse.org/buildStatus/icon?job=yast-yast-services-manager-master)](
https://ci.opensuse.org/view/Yast/job/yast-yast-services-manager-master/)
[![Coverage Status](https://img.shields.io/coveralls/yast/yast-services-manager.svg)](https://coveralls.io/r/yast/yast-services-manager?branch=master)
[![inline docs](http://inch-ci.org/github/yast/yast-services-manager.svg?branch=master)](http://inch-ci.org/github/yast/yast-services-manager)

[Systemd status check](https://github.com/yast/yast-services-manager/tree/check_systemd_states):
[![Check](https://github.com/yast/yast-services-manager/actions/workflows/check.yml/badge.svg?branch=check_systemd_states)](
https://github.com/yast/yast-services-manager/actions/workflows/check.yml?query=branch%3Acheck_systemd_states)


Systemd target and services configuration library for Yast

## Autoyast profile

### Current profile for services and default target

```xml
<services-manager>
    <default_target>multi-user</default_target>
    <services>
      <enable config:type="list">
        <service>postfix</service>
        <service>rsyslog</service>
        <service>sshd</service>
      </enable>
      <disable config:type="list">
        <service>libvirtd</service>
      </disable>
    </services>
  </services-manager>
```
### Legacy runlevel profile [DEPRECATED]

```xml
<runlevel>
  <default>3</default>
  <services config:type="list">
    <service>
      <service_name>sshd</service_name>
      <service_status>enable</service_status>
      <service_start>3</service_start>
    </service>
  </services>
</runlevel>
```

### Legacy list of services [DEPRECATED]

```xml
  <services-manager>
    <default_target>multi-user</default_target>
    <services config:type="list">
      <service>cron</service>
      <service>postfix</service>
      <service>rsyslog</service>
      <service>sshd</service>
    </services>
  </services-manager>
```

## Running

`sudo yast services-manager`

or

`sudo yast services`

