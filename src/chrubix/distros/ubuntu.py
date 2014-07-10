#!/usr/local/bin/python3
#
# ubuntu.py
#

# FIXME - see http://marcin.juszkiewicz.com.pl/2013/02/14/how-to-install-ubuntu-13-04-on-chromebook/

from chrubix.utils import wget, system_or_die, unmount_sys_tmp_proc_n_dev, mount_sys_tmp_proc_n_dev, logme, chroot_this, g_proxy
from chrubix.distros.debian import JessieDebianDistro


class UbuntuDistro( JessieDebianDistro ):
    important_packages = JessieDebianDistro.important_packages + ' linux-chromebook'
    final_push_packages = JessieDebianDistro.final_push_packages + ' lxdm wmsystemtray'
    def __init__( self , *args, **kwargs ):
        super( UbuntuDistro, self ).__init__( *args, **kwargs )
        self.name = 'ubuntu'

    def install_aircrack_ng( self ):
        self.build_and_install_package_from_ubuntu_source( 'aircrack-ng' )
#        for stub in ('debian.tar', '.dsc', '.orig.tar'):
#            relevant_line = call_binary( ['curl','http://ubuntu2.cica.es/ubuntu/ubuntu/pool/universe/a/aircrack-ng/'] )[1].strip()
#            print('%s ==> %s' % (stub, relevant_line))

    def install_barebones_root_filesystem( self ):
        logme( 'Ubuntu - install_barebones_root_filesystem() - starting' )
        unmount_sys_tmp_proc_n_dev( self.mountpoint )
        wget( url = 'https://dl.dropboxusercontent.com/u/59916027/chrubix/skeletons/ubuntu.tar.xz', extract_to_path = self.mountpoint, decompression_flag = 'J', title_str = self.title_str, status_lst = self.status_lst )
        mount_sys_tmp_proc_n_dev( self.mountpoint )
        return 0

    def install_locale( self ):
        logme( 'UbuntuDistro - install_locale() - starting' )
        self.do_generic_locale_configuring()
        logme( 'UbuntuDistro - install_locale() - leaving' )

    def install_debianspecific_package_manager_tweaks( self, yes_add_ffmpeg_repo = False ):
        logme( 'UbuntuDistro - install_package_manager_tweaks() - starting' )
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
        logme( 'UbuntuDistro - install_package_manager_tweaks() - leaving' )

class PangolinUbuntuDistro( UbuntuDistro ):
    def __init__( self , *args, **kwargs ):
        super( PangolinUbuntuDistro, self ).__init__( *args, **kwargs )
        self.branch = 'pangolin liblzo2-2 liblzo2-dev dillo'
        for r in 'aircrack-ng gobby pv bc busybox rng-tools python-pip mpg123 pavucontrol mplayer claws-mail bluez-utils keepassx exo-utils'.split( ' ' ):
            self.important_packages = self.important_packages.replace( r + ' ', '' )


    def install_important_packages( self ):
        self.install_all_important_packages_other_than_systemd_sysv()
        self.install_aircrack_ng()

