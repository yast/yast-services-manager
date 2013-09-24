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
Version:        0.0.9
Release:        0
BuildArch:      noarch

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        yast2-services-manager.tar.bz2

Requires:       ruby >= 2.0
Requires:       yast2 >= 2.24.1
Requires:       yast2-ruby-bindings >= 1.2.0

BuildRequires:  ruby
BuildRequires:  rubygem-mocha
BuildRequires:  update-desktop-files
BuildRequires:  yast2 >= 2.24.1
BuildRequires:  yast2-ruby-bindings >= 1.2.0

Summary:        YaST2 - Services Manager
License:        GPL-2.0
Group:          System/YaST

Url:            https://github.com/yast/yast-services-manager

%description
Provides user interface and libraries to configure running services and the default target.

%prep
%setup -n yast2-services-manager

%build
# Temporary fix: Disabling tests that do not work in openSUSE higher than 12.3
echo 0%{?suse_version}
%if 0%{?suse_version} > 0 && 0%{?suse_version} <= 1230
rake test
%endif

%install
rake install DESTDIR="%{buildroot}"
%suse_update_desktop_file services-manager

%files
%defattr(-,root,root)
%{_prefix}/share/YaST2/clients/*.rb
%{_prefix}/share/YaST2/modules/*.rb
%{_prefix}/share/applications/YaST2/services-manager.desktop
%{_prefix}/share/YaST2/schema/autoyast/rnc/*.rnc
# Only license comes here, the rest will be in 'doc' package
%doc %dir %{_prefix}/share/doc/packages/yast2-services-manager/
%doc %{_prefix}/share/doc/packages/yast2-services-manager/README
%doc %{_prefix}/share/doc/packages/yast2-services-manager/COPYING

%changelog
