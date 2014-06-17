#!/usr/local/bin/python3
#
# ubuntu.py
#


from chrubix.utils import wget, system_or_die, unmount_sys_tmp_proc_n_dev, mount_sys_tmp_proc_n_dev, logme
from chrubix.distros.debian import JessieDebianDistro


class UbuntuDistro( JessieDebianDistro ):
    important_packages = JessieDebianDistro.important_packages + ' uboot-mkimage'
    final_push_packages = JessieDebianDistro.final_push_packages + ' ' + 'lxdm wmsystemtray'
    def __init__( self , *args, **kwargs ):
        super( UbuntuDistro, self ).__init__( *args, **kwargs )
        self.name = 'ubuntu'

    def install_barebones_root_filesystem( self ):
        logme( 'Ubuntu - install_barebones_root_filesystem() - starting' )
        unmount_sys_tmp_proc_n_dev( self.mountpoint )
        wget( url = 'https://dl.dropboxusercontent.com/u/59916027/chrubix/skeletons/ubuntu.tar.xz', extract_to_path = self.mountpoint, decompression_flag = 'J', title_str = self.title_str, status_lst = self.status_lst )
        mount_sys_tmp_proc_n_dev( self.mountpoint )
        return 0


class PangolinUbuntuDistro( UbuntuDistro ):
    def __init__( self , *args, **kwargs ):
        super( PangolinUbuntuDistro, self ).__init__( *args, **kwargs )
        self.branch = 'pangolin'

