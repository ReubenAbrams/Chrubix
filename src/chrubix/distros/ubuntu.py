#!/usr/local/bin/python3
#
# ubuntu.py
#
# FIXME - (1)try DebianDistro instead...? (2)see http://marcin.juszkiewicz.com.pl/2013/02/14/how-to-install-ubuntu-13-04-on-chromebook/


from chrubix.utils import logme, chroot_this, g_proxy, failed, \
                          write_oneliner_file, do_a_sed
from chrubix.distros.debian import JessieDebianDistro


class UbuntuDistro( JessieDebianDistro ):
    def __init__( self , *args, **kwargs ):
        super( UbuntuDistro, self ).__init__( *args, **kwargs )
        self.name = 'ubuntu'
        self.branch = 'UNKNOWN_BRANCH'
        self.packages_folder_url = 'http://ports.ubuntu.com/ubuntu-ports/'
        assert( self.important_packages not in ( '', None ) )
        self.important_packages += ' linux-chromebook'
        self.final_push_packages += ' lxdm wmsystemtray'

    def install_aircrack_ng( self ):
        logme( 'FYI, I am not installing aircrack' )
#        self.build_and_install_package_from_ubuntu_source( 'aircrack-ng' )
#        for stub in ('debian.tar', '.dsc', '.orig.tar'):
#            relevant_line = call_binary( ['curl','http://ubuntu2.cica.es/ubuntu/ubuntu/pool/universe/a/aircrack-ng/'] )[1].strip()
#            print('%s ==> %s' % (stub, relevant_line))

    def install_debianspecific_package_manager_tweaks( self, yes_add_ffmpeg_repo = False ):
        assert( not yes_add_ffmpeg_repo )
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

class VividUbuntuDistro( UbuntuDistro ):
    def __init__( self , *args, **kwargs ):
        super( VividUbuntuDistro, self ).__init__( *args, **kwargs )
        self.branch = 'vivid'  # '15.04'  # vivid, a.k.a. latest
        self.important_packages = 'x11-server-utils x11-kb-utils x11-apps ' + self.important_packages + ' liblzo2-2 liblzo2-dev dillo'
        for r in 'libreoffice openjdk-8-jre ttf-dejavu ttf-liberation firmware-libertas liferea aircrack-ng bc busybox rng-tools python-pip mpg123 python-software-properties openjdk-8-jre pavucontrol mplayer claws-mail bluez-utils keepassx exo-utils'.split( ' ' ):
            self.important_packages = self.important_packages.replace( r + ' ', '' )


    def install_important_packages( self ):
        # https://wiki.ubuntu.com/DebootstrapChroot
        for cmd in ( 
                    'apt-get update',
                    'apt-get --no-install-recommends install wget debconf devscripts gnupg nano',
                    'apt-get update',
                    'apt-get install locales dialog',
                    'locale-gen en_US.UTF-8',
                    'add-apt-repository ppa:ubuntuhandbook1/apps',
                    'apt-get update',
                    'apt-get install liferea' ):
            chroot_this( self.mountpoint, 'yes "" | ' + cmd, title_str = self.title_str, status_lst = self.status_lst )
#        failed( 'Aborting for test porpoises' )
#        'tzselect; TZ='Continent/Country'; export TZ
        super( VividUbuntuDistro, self ).install_important_packages()  # FIXME yes_add_ffmpeg_repo = True )
        self.install_aircrack_ng()

    def install_i2p( self ):
        failed( 'https://launchpad.net/~i2p-maintainers/+archive/ubuntu/i2p' )
#        chroot_this( self.mountpoint, 'wget http://www.deb-multimedia.org/pool/main/d/deb-multimedia-keyring/deb-multimedia-keyring_2014.2_all.deb -O - > /tmp/debmult.deb', attempts = 1, title_str = self.title_str, status_lst = self.status_lst )
#        chroot_this( self.mountpoint, 'dpkg -i /tmp/debmult.deb', attempts = 1, title_str = self.title_str, status_lst = self.status_lst )
        assert( self.branch in ( 'wheezy', 'jessie' ) )
        write_oneliner_file( '%s/etc/apt/sources.list.d/i2p.list' % ( self.mountpoint ), '''
deb http://deb.i2p2.no/ %s main
deb-src http://deb.i2p2.no/ %s main
''' % ( self.branch, self.branch ) )
        for cmd in ( 
                        'yes 2>/dev/null | add-apt-repository "deb http://deb.i2p2.no/ %s main"' % ( self.branch ),
                        'yes "" 2>/dev/null | curl https://geti2p.net/_static/i2p-debian-repo.key.asc | apt-key add -',
                        'yes 2>/dev/null | apt-get update'
                   ):
            chroot_this( self.mountpoint, cmd, title_str = self.title_str, status_lst = self.status_lst,
                             on_fail = "Failed to run %s successfully" % ( cmd ) )
        chroot_this( self.mountpoint, 'yes | apt-get install i2p i2p-keyring', on_fail = 'Failed to install i2p' )
        logme( 'tweaking i2p ID...' )
        do_a_sed( '%s/etc/passwd' % ( self.mountpoint ), 'i2p:/bin/false', 'i2p:/bin/bash' )



