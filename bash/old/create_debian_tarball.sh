#!/bin/bash
#
# create_debian_tarball.sh
# - generates a Debian tarball from within ChromeOS
# - asks user to upload it to Dropbox etc.
# - terminates
#
# To run, type:-
# cd && wget bit.ly/1iBQSx9 -O xx && sudo bash xx
#################################################################################
#
# Here's my plan, re: the Ubuntu generator.
# 1. Install the alarm-rootfs.tar.xz filesystem in $kern
# 2. Use it to run Chrubix (Python).
# 3. Chrubix will detect that it's running within ChromeOS.
# 4.
# 1. Install the filesystem from ubuntu.tar.xz, which we've borrowed from Chrouton.
# 2. Install PKGBUILDs (folder of precompiled kernel & mk*fs).
# # 3. Somehow transform kernel & mk*fs into Ubuntu-friendly DEB Pkgs.
# # 4. Install them into the chroot.
# 5. Boot. Simply boot. Don't mess with encryption yet.
#
#
#
#
#
# ------------------------------------------------------------------


failed "THIS DEBIAN TARBALL GENERATOR HASN'T BEEN WRITTEN YET"
exit 0



