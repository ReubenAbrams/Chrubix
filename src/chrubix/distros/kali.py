#!/usr/local/bin/python3
#
# kali.py
#


# SEE https://github.com/offensive-security/kali-arm-build-scripts/blob/master/chromebook-arm-samsung.sh

from chrubix.distros.debian import JessieDebianDistro
from chrubix.utils import wget, system_or_die, unmount_sys_tmp_proc_n_dev, mount_sys_tmp_proc_n_dev


class KaliDistro( JessieDebianDistro ):
    important_packages = JessieDebianDistro.important_packages + ' kali-menu kali-defaults hydra john wireshark libnfc-bin'
    final_push_packages = JessieDebianDistro.final_push_packages + ' aircrack-ng passing-the-hash'

    def __init__( self , *args, **kwargs ):
        super( KaliDistro, self ).__init__( *args, **kwargs )
        self.name = 'kali'
        self.branch = None

    def install_barebones_root_filesystem( self ):
        unmount_sys_tmp_proc_n_dev( self.mountpoint )
        wget( url = 'https://dl.dropboxusercontent.com/u/59916027/chrubix/skeletons/kali-rootfs.tar.xz', extract_to_path = self.mountpoint, decompression_flag = 'J', title_str = self.title_str, status_lst = self.status_lst, attempts = 1 )
        mount_sys_tmp_proc_n_dev( self.mountpoint )
        return 0
