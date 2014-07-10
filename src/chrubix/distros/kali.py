#!/usr/local/bin/python3
#
# kali.py
#


# SEE https://github.com/offensive-security/kali-arm-build-scripts/blob/master/chromebook-arm-samsung.sh

from chrubix.distros.debian import JessieDebianDistro
from chrubix.utils import wget, system_or_die, unmount_sys_tmp_proc_n_dev, mount_sys_tmp_proc_n_dev, g_proxy, chroot_this


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

    def install_debianspecific_package_manager_tweaks( self, yes_add_ffmpeg_repo = False ):
#        f = open('%s/etc/apt/sources.list' % ( self.mountpoint ), 'a')
#        f.write(''' ''')
#        f.close()
        chroot_this( self.mountpoint, '' )
        if g_proxy is not None:
            f = open( '%s/etc/apt/apt.conf' % ( self.mountpoint ), 'a' )
            f.write( '''
Acquire::http::Proxy "http://%s/";
Acquire::ftp::Proxy  "ftp://%s/";
Acquire::https::Proxy "https://%s/";
''' % ( g_proxy, g_proxy, g_proxy ) )
            f.close()

