#!/bin/bash
sudo rpm-ostree usroverlay || true
./build.sh
RPM=$(ls build/rpmbuild/RPMS/*/kinfocenter-[0-9]*.rpm)
rpm2cpio $RPM | sudo cpio -fuidmv -D /
