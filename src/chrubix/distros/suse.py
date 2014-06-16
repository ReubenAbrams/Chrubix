#!/usr/local/bin/python3
#
# fedora.py
#


from chrubix.distros import Distro
from chrubix.utils import wget, system_or_die, unmount_sys_tmp_proc_n_dev, mount_sys_tmp_proc_n_dev, logme, chroot_this


class SuseDistro( Distro ):
    important_packages = Distro.important_packages + ' ' + '\
 cgpt xz mkinitcpio libxpm dtc xmlto festival-us \
mesa gptfdisk bluez-libs alsa-plugins acpisdl libcanberra icedtea-web-java7 \
libnotify talkfilters chromium xorg-server-utils java-runtime libxmu libxfixes apache-ant junit'
    final_push_packages = Distro.important_packages + '\
xorg-server xf86-input-synaptics xf86-video-armsoc xorg-xmessage xlockmore pyqt \
xorg-xinit xf86-video-fbdev wmsystemtray lxdm network-manager-gnome'
    def __init__( self ):
        super( SuseDistro, self ).__init__()
        self.__distroname = 'fedora'
        self.typical_install_duration = 12445

    def install_barebones_root_filesystem( self ):
        logme( 'SuseDistro - install_barebones_root_filesystem() - starting' )
        unmount_sys_tmp_proc_n_dev( self.mountpoint )
        wget( url = 'https://dl.dropboxusercontent.com/u/59916027/chrubix/skeletons/suse-rootfs.tar.xz', extract_to_path = self.mountpoint, decompression_flag = 'J', title_str = self.title_str, status_lst = self.status_lst )
        mount_sys_tmp_proc_n_dev( self.mountpoint )
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

