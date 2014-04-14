# Yast Services Manager

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

