# ubuntu.py
#


from chrubix.utils import logme, wget
from chrubix.distros.debian import WheezyDebianDistro


class UbuntuDistro( WheezyDebianDistro ):
    important_packages = WheezyDebianDistro.important_packages  # + ' ' + '????'
    final_push_packages = WheezyDebianDistro.final_push_packages + ' ' + 'lxdm wmsystemtray'
    def __init__( self , *args, **kwargs ):
        super( UbuntuDistro, self ).__init__( *args, **kwargs )
        self.name = 'ubuntu'

    def install_barebones_root_filesystem( self ):
        logme( 'Ubuntu - install_barebones_root_filesystem() - starting' )
        wget( url = 'https://dl.dropboxusercontent.com/u/59916027/chrubix/skeletons/ubuntu.tar.xz', extract_to_path = self.mountpoint, decompression_flag = 'J', title_str = self.title_str, status_lst = self.status_lst )
        return 0


class PangolinUbuntuDistro( UbuntuDistro ):
    def __init__( self , *args, **kwargs ):
        super( PangolinUbuntuDistro, self ).__init__( *args, **kwargs )
        self.branch = 'pangolin'

