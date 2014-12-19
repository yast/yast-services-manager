#
# spec file for package yast2-services-manager
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


######################################################################
#
# IMPORTANT: Please do not change spec file in build service directly
#            Use https://github.com/yast/yast-services-manager repo
#
######################################################################

Name:           yast2-services-manager
Version:        3.1.34.3

Release:        0
BuildArch:      noarch

BuildRoot:      %{_tmppath}/%{name}-build
Source0:        %{name}-%{version}.tar.bz2

Requires:       ruby
# ServicesManager library
Requires:       yast2 >= 3.1.86
Requires:       yast2-ruby-bindings >= 1.2.0
# need new enough installation for its inst clients
Conflicts:      yast2-installation < 3.1.32

Obsoletes:      yast2-runlevel
Conflicts:      yast2-runlevel

BuildRequires:  ruby
BuildRequires:  update-desktop-files
BuildRequires:  yast2-ruby-bindings >= 1.2.0
# ServicesManager library
BuildRequires:  yast2 >= 3.1.86
# Support for 'data' directory in rake install task
BuildRequires:  rubygem(yast-rake) >= 0.1.7
BuildRequires:  rubygem(rspec)

Summary:        YaST2 - Services Manager
Group:          System/YaST
License:        GPL-2.0+
Url:            https://github.com/yast/yast-services-manager

%description
Provides user interface and libraries to configure systemd
services and targets.

%prep
%setup -n %{name}-%{version}

%build

%check
# opensuse-13.1 does not contain rspec in default repositories
%if 0%{?suse_version} > 1310
rake test:unit
%endif

%install
rake install DESTDIR="%{buildroot}"
%suse_update_desktop_file services-manager

%define yast_dir %{_prefix}/share/YaST2

%files
%defattr(-,root,root)
%{yast_dir}/clients/*.rb
%{yast_dir}/modules/*.rb
%{yast_dir}/schema/autoyast/rnc/*.rnc
%dir %{yast_dir}/lib/services-manager/
%{yast_dir}/lib/services-manager/*.rb
%dir %{yast_dir}/data/services-manager/
%{yast_dir}/data/services-manager/*.erb
%{_prefix}/share/applications/YaST2/services-manager.desktop
# Needed for legacy support of runlevel autoyast profile
%{_prefix}/share/applications/YaST2/runlevel.desktop

%dir %_docdir/
%_docdir/%name/
%_docdir/%name/COPYING
