#!/usr/local/bin/python3
#
# kali.py
#


# SEE https://github.com/offensive-security/kali-arm-build-scripts/blob/master/chromebook-arm-samsung.sh

from chrubix.distros.debian import JessieDebianDistro
from chrubix.utils import wget, chroot_this


class KaliDistro( JessieDebianDistro ):
    important_packages = JessieDebianDistro.important_packages + ' kali-menu kali-defaults hydra john wireshark libnfc-bin'
    final_push_packages = JessieDebianDistro.final_push_packages + ' aircrack-ng passing-the-hash'

    def __init__( self , *args, **kwargs ):
        super( KaliDistro, self ).__init__( *args, **kwargs )
        self.name = 'kali'
        self.branch = None

    def install_barebones_root_filesystem( self ):
        chroot_this( self.mountpoint, 'mv /dev /dev.real' )
        wget( url = 'https://dl.dropboxusercontent.com/u/59916027/chrubix/skeletons/kali-rootfs.tar.xz', extract_to_path = self.mountpoint, decompression_flag = 'J', title_str = self.title_str, status_lst = self.status_lst, attempts = 1 )
        chroot_this( self.mountpoint, 'mv /dev /.dev.wtf && mv /dev.real /dev', on_fail = 'Failed to fix /dev' )
        return 0
