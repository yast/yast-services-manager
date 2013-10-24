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
Source0:        %{name}-%{version}.tar.bz2

Requires:       ruby >= 2.0.0
Requires:       yast2 >= 3.0.5
Requires:       yast2-ruby-bindings >= 1.2.0

BuildRequires:  ruby
BuildRequires:  update-desktop-files
BuildRequires:  yast2-ruby-bindings >= 1.2.0
BuildRequires:  yast2 >= 3.0.5

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
%yast_build

%install
rake install
%suse_update_desktop_file services-manager

%files
%defattr(-,root,root)
%{yast_clientdir}/*.rb
%{yast_moduledir}/*.rb
%{yast_desktopdir}/*.desktop
%{yast_schemadir}/autoyast/rnc/services-manager.rnc
%dir %{_datadir}/YaST2/lib/
%{_datadir}/YaST2/lib/services-manager/

%dir %{yast_docdir}
%doc %{yast_docdir}/COPYING

%changelog
