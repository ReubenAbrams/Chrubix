# kali.py
#


# SEE https://github.com/offensive-security/kali-arm-build-scripts/blob/master/chromebook-arm-samsung.sh

from chrubix.distros.debian import WheezyDebianDistro
from chrubix.utils import wget


class KaliDistro( WheezyDebianDistro ):
    important_packages = WheezyDebianDistro.important_packages + ' kali-menu kali-defaults  hydra john wireshark libnfc-bin'
    final_push_packages = WheezyDebianDistro.final_push_packages + ' aircrack-ng passing-the-hash'

    def __init__( self , *args, **kwargs ):
        super( KaliDistro, self ).__init__( *args, **kwargs )
        self.name = 'kali'

    def install_barebones_root_filesystem( self ):
        wget( url = 'https://dl.dropboxusercontent.com/u/59916027/chrubix/skeletons/kali-rootfs.tar.xz', extract_to_path = self.mountpoint, decompression_flag = 'J', title_str = self.title_str, status_lst = self.status_lst )
        return 0
