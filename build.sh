#!/bin/bash
set -e

PACKAGE_NAME=blossomos-kinfocenter
VERSION=6.6.3
RELEASE=1
BUILDROOT=$(pwd)/rpmbuild
SPECS_DIR=$BUILDROOT/SPECS
SOURCES_DIR=$BUILDROOT/SOURCES
BUILD_DIR=$(pwd)/build
INSTALL_DIR=$BUILDROOT/INSTALL

# Clean and prepare build directories
rm -rf $BUILDROOT
mkdir -p $SPECS_DIR $SOURCES_DIR $INSTALL_DIR

# Build kinfocenter first
echo "Building kinfocenter..."
rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR
cd $BUILD_DIR
cmake .. -DCMAKE_INSTALL_PREFIX=/usr \
         -DCMAKE_BUILD_TYPE=Release \
         -DKDE_INSTALL_LIBDIR=lib64 \
         -DKDE_INSTALL_USE_QT_SYS_PATHS=ON
make -j$(nproc)

# Install to temporary location for packaging
echo "Installing to temporary directory..."
DESTDIR=$INSTALL_DIR make install
cd ..

SPECFILE=$SPECS_DIR/$PACKAGE_NAME.spec

# Write the specfile
cat > $SPECFILE <<EOF
Name:           $PACKAGE_NAME
Version:        $VERSION
Release:        $RELEASE%{?dist}
Summary:        BlossomOS customized KInfoCenter with Serial Numbers section
License:        GPL-2.0-or-later
BuildArch:      x86_64

Provides:       kinfocenter
Obsoletes:      kinfocenter

Requires:       kf6-kcoreaddons
Requires:       kf6-kconfig
Requires:       kf6-ki18n
Requires:       kf6-kcmutils
Requires:       kf6-kio
Requires:       kf6-solid
Requires:       kf6-kauth
Requires:       qt6-qtbase

%description
KInfoCenter provides a centralized and convenient overview of your
system and desktop environment.

This BlossomOS version includes:
- Serial Numbers section with Machine ID, Device ID, and Board Serial Number
- German translations for Serial Numbers section (Seriennummern)
- Uses PRETTY_NAME from /etc/os-release for distribution name

%prep
# nothing to prepare

%build
# already built

%install
cp -a $INSTALL_DIR/* %{buildroot}/

%files
%{_bindir}/kinfocenter
%{_libdir}/qt6/plugins/plasma/kcms/kcm_about-distro.so
%{_libdir}/qt6/plugins/plasma/kcms/kcm_energyinfo.so
%{_libdir}/qt6/plugins/plasma/kcms/kinfocenter/*.so
%{_libdir}/qt6/qml/org/kde/kinfocenter/
%{_libdir}/libexec/kinfocenter-opengl-helper
%{_libdir}/libexec/kinfocenter-vulkan-helper
%{_libdir}/libKInfoCenterInternal.so
%{_libexecdir}/kf6/kauth/kinfocenter-dmidecode-helper
%{_datadir}/applications/*.desktop
%{_datadir}/kinfocenter/
%{_datadir}/metainfo/org.kde.kinfocenter.appdata.xml
%{_datadir}/locale/*/LC_MESSAGES/*.mo
%{_datadir}/dbus-1/system.d/org.kde.kinfocenter.dmidecode.conf
%{_datadir}/dbus-1/system-services/org.kde.kinfocenter.dmidecode.service
%{_datadir}/polkit-1/actions/org.kde.kinfocenter.dmidecode.policy
%{_datadir}/doc/HTML/*/kinfocenter/

%changelog
* Sun Mar 15 2026 Leonie Ain <me@koyu.space> - 6.2.5-1
- Added Serial Numbers section with Machine ID, Device ID, and Board Serial Number
- Added German translations (Maschinennummer, Gerätenummer, Seriennummern)
- Changed to use PRETTY_NAME from /etc/os-release
- Hidden serial numbers by default with show/hide toggle buttons
EOF

# Build the RPM
echo "Building RPM..."
rpmbuild -bb $SPECFILE --define "_topdir $BUILDROOT"

echo ""
echo "RPM built successfully!"
echo "Location: $BUILDROOT/RPMS/x86_64/$PACKAGE_NAME-$VERSION-$RELEASE.*.rpm"
ls -lh $BUILDROOT/RPMS/x86_64/*.rpm
