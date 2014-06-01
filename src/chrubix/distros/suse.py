#!/usr/local/bin/python3
#
# fedora.py
#


from chrubix.distros import Distro
from chrubix.utils import logme, wget, chroot_this, system_or_die


class SuseDistro( Distro ):
    important_packages = Distro.important_packages + ' ' + '\
xf86-video-fbdev cgpt xz mkinitcpio xf86-video-armsoc exo xf86-input-synaptics libxpm dtc xmlto xorg-server festival-us \
xorg-xmessage mesa pyqt gptfdisk xlockmore bluez-libs alsa-plugins acpi xorg-xinit sdl libcanberra icedtea-web-java7 \
libnotify talkfilters chromium xorg-server-utils java-runtime libxmu libxfixes apache-ant junit'
    final_push_packages = Distro.important_packages + ' ' + 'wmsystemtray lxdm network-manager-gnome'
    def __init__( self ):
        super( SuseDistro, self ).__init__()
        self.__distroname = 'fedora'
        self.typical_install_duration = 12445

    def install_barebones_root_filesystem( self ):
        logme( 'SuseDistro - install_barebones_root_filesystem() - starting' )
        wget( url = 'https://dl.dropboxusercontent.com/u/59916027/chrubix/skeletons/suse-rootfs.tar.xz', extract_to_path = self.mountpoint, decompression_flag = 'J', title_str = self.title_str, status_lst = self.status_lst )
        return 0

    def install_final_push_of_packages( self ):
        logme( 'Fedora - install_final_push_of_packages() - starting' )
#        self.build_and_install_software_from_archlinux_source( 'wmsystemtray' )
        self.status_lst.append( ['Installing %s' % ( self.final_push_packages.replace( '  ', ' ' ).replace( ' ', ', ' ) )] )
        res = 999
        attempts = 5
        while res != 0 and attempts > 0:
            attempts -= 1
            res = chroot_this( self.mountpoint, 'yes 2>/dev/null | yum install %s' % ( self.final_push_packages ), title_str = self.title_str, status_lst = self.status_lst )
            if res != 0:
                system_or_die( 'rm -f %s/var/lib/pacman/db.lck; sync; sync; sync; sleep 3' % ( self.mountpoint ) )
        assert( attempts > 0 )
#        self.status_lst[-1] += '...Done.'

