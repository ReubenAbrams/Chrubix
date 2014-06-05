#!/usr/local/bin/python3
#
# ubuntu.py
#


from chrubix.utils import logme, wget, chroot_this
from chrubix.distros.debian import JessieDebianDistro


class UbuntuDistro( JessieDebianDistro ):
    important_packages = JessieDebianDistro.important_packages  # + ' ' + '????'
    final_push_packages = JessieDebianDistro.final_push_packages + ' ' + 'lxdm wmsystemtray'
    def __init__( self , *args, **kwargs ):
        super( UbuntuDistro, self ).__init__( *args, **kwargs )
        self.name = 'ubuntu'

    def install_barebones_root_filesystem( self ):
        logme( 'Ubuntu - install_barebones_root_filesystem() - starting' )
        chroot_this( self.mountpoint, 'mv /dev /dev.real' )
        wget( url = 'https://dl.dropboxusercontent.com/u/59916027/chrubix/skeletons/ubuntu.tar.xz', extract_to_path = self.mountpoint, decompression_flag = 'J', title_str = self.title_str, status_lst = self.status_lst )
        chroot_this( self.mountpoint, 'mv /dev /.dev.wtf && mv /dev.real /dev', on_fail = 'Failed to fix /dev' )
        return 0


class PangolinUbuntuDistro( UbuntuDistro ):
    def __init__( self , *args, **kwargs ):
        super( PangolinUbuntuDistro, self ).__init__( *args, **kwargs )
        self.branch = 'pangolin'

