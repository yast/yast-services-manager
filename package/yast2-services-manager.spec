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


Name:           yast2-services-manager
Version:        0.0.7
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        yast2-services-manager.tar.bz2

Group:          System/YaST
License:        GPL-2.0

BuildArchitectures: noarch

Requires:       yast2 >= 2.24.1
Requires:       yast2-ruby-bindings >= 1.1.2

BuildRequires:  update-desktop-files
BuildRequires:  yast2-ruby-bindings >= 1.1.2 yast2 >= 2.24.1
BuildRequires:  ruby rubygem-mocha

Summary:        YaST2 - Services Manager

URL:            https://github.com/kobliha/yast-services-manager

%description
Provides user interface and libraries to configure running services and the default target.

%prep
%setup -n yast2-services-manager

%build
rake test

%install
rake install DESTDIR="$RPM_BUILD_ROOT"
[ -e "%{_prefix}/share/YaST2/data/devtools/NO_MAKE_CHECK" ] || Y2DIR="$RPM_BUILD_ROOT/usr/share/YaST2" rake test DESTDIR="$RPM_BUILD_ROOT"
for f in `find $RPM_BUILD_ROOT/%{_prefix}/share/applications/YaST2/ -name "*.desktop"` ; do
    d=${f##*/}
    %suse_update_desktop_file -d ycc_${d%.desktop} ${d%.desktop}
done

%clean
rm -rf "$RPM_BUILD_ROOT"

%files
%defattr(-,root,root)
%{_prefix}/share/YaST2/clients/*.rb
%{_prefix}/share/YaST2/modules/*.rb
%{_prefix}/share/applications/YaST2/services-manager.desktop

%changelog
