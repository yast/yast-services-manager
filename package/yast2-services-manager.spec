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
Version:        0.0.4
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        yast2-services-manager.tar.bz2


Group:          System/YaST
License:        GPL-2.0
Requires:       yast2 >= 2.21.22

BuildArchitectures: noarch

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:        YaST2 - Services Manager

%description
Provides user interface and libraries to configure running services and the default target.

%prep
%setup -n yast2-services-manager

%build

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
/usr/share/YaST2/clients/services-manager.rb
/usr/share/YaST2/modules/*.rb
%{_prefix}/share/applications/YaST2/services-manager.desktop
