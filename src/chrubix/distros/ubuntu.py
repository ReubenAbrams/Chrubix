#!/usr/local/bin/python3
#
# ubuntu.py
#


from chrubix.utils import logme, wget, system_or_die
from chrubix.distros.debian import JessieDebianDistro


class UbuntuDistro( JessieDebianDistro ):
    important_packages = JessieDebianDistro.important_packages  # + ' ' + '????'
    final_push_packages = JessieDebianDistro.final_push_packages + ' ' + 'lxdm wmsystemtray'
    def __init__( self , *args, **kwargs ):
        super( UbuntuDistro, self ).__init__( *args, **kwargs )
        self.name = 'ubuntu'

    def install_barebones_root_filesystem( self ):
        logme( 'Ubuntu - install_barebones_root_filesystem() - starting' )
        system_or_die( 'mv %s/dev %s/dev.real' % ( self.mountpoint, self.mountpoint ) )
        wget( url = 'https://dl.dropboxusercontent.com/u/59916027/chrubix/skeletons/ubuntu.tar.xz', extract_to_path = self.mountpoint, decompression_flag = 'J', title_str = self.title_str, status_lst = self.status_lst )
        system_or_die( 'mv %s/dev %s/.dev.wtf && mv %s/dev.real %s/dev' % ( self.mountpoint, self.mountpoint, self.mountpoint, self.mountpoint ) )
        return 0


class PangolinUbuntuDistro( UbuntuDistro ):
    def __init__( self , *args, **kwargs ):
        super( PangolinUbuntuDistro, self ).__init__( *args, **kwargs )
        self.branch = 'pangolin'

