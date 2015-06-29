#!/usr/local/bin/python3
#
# debian.py


from chrubix.utils import generate_temporary_filename, g_proxy, failed, system_or_die, write_oneliner_file, wget, logme, \
                          chroot_this, read_oneliner_file, do_a_sed, call_binary, patch_org_freedesktop_networkmanager_conf_file  # , install_lxdm_from_source
import os
from chrubix.distros import Distro

# from builtins import None


def do_debian_specific_mbr_related_hacks( mountpoint ):
    logme( 'mountpoint = %s' % ( mountpoint ) )
    system_or_die( 'rm -Rf %s/usr/lib/initcpio' % ( mountpoint ) )
    system_or_die( 'rm -f %s/usr/lib/initcpio/busybox' % ( mountpoint ) )
    for ( fname, wish_it_were_here, is_actually_here ) in ( 
                                                  ( 'libnss_files.so', '/usr/lib', '/usr/lib/arm-linux-gnueabihff' ),
                                                  ( 'modprobe.d', '/usr/lib', '/lib' ),
                                                  ( 'systemd', '/usr/lib/systemd', '/lib/systemd' ),
                                                  ( 'systemd-tmpfiles', '/usr/bin', '/bin' ),  # ?
                                                  ( 'systemd-sysctl', '/usr/lib/systemd', '/lib/systemd' ),
                                                  ( 'kmod', '/usr/bin', '/bin' )
                                                  ):
        if not os.path.exists( '%s%s/%s' % ( mountpoint, wish_it_were_here, fname ) ):
            system_or_die( 'ln -sf %s/%s %s%s/' % ( is_actually_here, fname, mountpoint, wish_it_were_here ) )
    if not os.path.exists( '%s/usr/lib/udev' % ( mountpoint ) ) \
    and os.path.exists( '%s/lib/udev' % ( mountpoint ) ):
        chroot_this( mountpoint, 'ln -sf /lib/udev /usr/lib/udev' )
    for missing_path in ( 
                          '/usr/lib/udev/rules.d',
                          '/usr/lib/systemd/system-generators',
                          '/usr/lib/modprobe.d',
                          '/usr/lib/initcpio',
                          '/bin/makepkg',
                          '/usr/lib/modprobe.d/usb-load-ehci-first.conf'
                           ):
        if 0 == chroot_this( mountpoint, 'ls %s &> /dev/null' % ( missing_path ) , attempts = 1 ):
            logme( '%s%s already exists. So, no reason to copy from /... to this location.' % ( mountpoint, missing_path ) )
        else:
            logme( '%s%s does not exist. Therefore, I am copying it across' % ( mountpoint, missing_path ) )
            system_or_die( 'mkdir -p %s%s' % ( mountpoint, os.path.dirname( missing_path ) ) )
            try:
                system_or_die( 'cp -af %s %s%s/ 2> /dev/null' % ( missing_path, mountpoint, os.path.dirname( missing_path ) ) )
            except RuntimeError:
                logme( '** FYI, I was unable to kludge %s **' % ( missing_path ) )
    system_or_die( 'rm -f %s/usr/lib/initcpio/busybox' % ( mountpoint ) )
    for ( fname, wish_it_were_here, is_actually_here ) in ( 
                                                  ( 'busybox', '/usr/lib/initcpio', '/bin' ),
                                                  ):
        if not os.path.exists( '%s%s/%s' % ( mountpoint, wish_it_were_here, fname ) ):
            system_or_die( 'ln -sf %s/%s %s%s/' % ( is_actually_here, fname, mountpoint, wish_it_were_here ) )
    logme( 'Coping usb-load-ehci-first.conf across anyway.' )
    try:
        system_or_die( 'cp -af /usr/lib/modprobe.d/usb-load-ehci-first.conf %s/lib/modprobe.d/' % ( mountpoint ) )
    except RuntimeError:
        logme( '** FYI, I was unable to kludge modprobe.d **' )
    assert( os.path.exists( '%s/usr/lib/modprobe.d/usb-load-ehci-first.conf' % ( mountpoint ) ) )


def generate_mickeymouse_lxdm_patch( mountpoint, lxdm_package_path, output_patch_file ):
    failed( 'Noooo.' )
#    insert_this_code = 'baaa'  # '''if (187==system("bash /usr/local/bin/ersatz_lxdm.sh")) exit(187);'''
    logme( 'generate_mickeymouse_lxdm_patch() --- entering (mountpoint=%s, output_patch_file=%s' % ( mountpoint, output_patch_file ) )
    lxdm_folder_basename = [ r for r in call_binary( ['ls', '%s%s/' % ( mountpoint, lxdm_package_path )] )[1].decode( 'utf-8' ).split( '\n' ) if r.find( 'lxdm-' ) >= 0 ][0]
    chroot_this( mountpoint, r'''
set -e
cd %s/%s
rm -Rf _a _b a b
mkdir -p _a _b
cp -af [a-z,A-Z]* _a
cd _a
for f in `find ../../debian/patches/*.patch`; do patch -p1 < $f; done
cd ..
cp -af _a/* _b
mv _a a
mv _b b
cat a/src/lxdm.c | sed s/'for(i=1;i<arc;i++)'/'if (187==system("bash \/usr\/local\/bin\/ersatz_lxdm.sh")) {exit(187);} for(i=1;i<arc;i++)'/ > b/src/lxdm.c
''' % ( lxdm_package_path, lxdm_folder_basename ), on_fail = 'generate_mickeymouse_lxdm_patch() --- chroot #1 failed' )
    file_to_tweak = '%s%s/%s/b/src/lxdm.c' % ( mountpoint, lxdm_package_path, lxdm_folder_basename )
    assert( os.path.isfile( file_to_tweak ) )
#    do_a_sed( file_to_tweak, 'for\\(', '%s' % ( insert_this_code ) )
#    do_a_sed( file_to_tweak, 'for\\(i=1;i<arc;i++\\)', '%s; for \\( i=1; i<arc ; i++ \\) ' % ( insert_this_code ) )
    chroot_this( mountpoint, '''
cd %s/%s
diff -p1 -r a/src b/src > %s
''' % ( lxdm_package_path, lxdm_folder_basename, output_patch_file ) )
    if not os.path.isfile( '%s%s' % ( mountpoint, output_patch_file ) ):
        failed( 'generate_mickeymouse_lxdm_patch() --- failed to generate %s%s' % ( mountpoint, output_patch_file ) )
    logme( 'generate_mickeymouse_lxdm_patch() --- generated %s%s' % ( mountpoint, output_patch_file ) )
    logme( 'generate_mickeymouse_lxdm_patch() --- leaving' )


class DebianDistro( Distro ):
    important_packages = Distro.important_packages + ' ' + \
'iputils-ping python3-setuptools gnu-standards apt-utils libpopt-dev libacl1-dev libcrypto++-dev exo-utils libnotify-bin \
libattr1-dev build-essential fakeroot oss-compat devscripts equivs lintian libglib2.0-dev po-debconf \
iso-codes debconf cdbs debhelper uuid-dev quilt openjdk-8-jre default-jdk ant xz-utils libxmu-dev libconfig-auto-perl \
python-software-properties default-jre dpatch festival dialog libck-connector-dev libpam0g-dev python-mutagen \
libgtk2.0-dev librsvg2-common librsvg2-dev pyqt4-dev-tools libreoffice-help-en-us libreoffice \
firmware-libertas libxpm-dev libreadline-dev libblkid-dev python-distutils-extra \
gtk2-engines-pixbuf libsnappy-dev libgcrypt-dev iceweasel icedove gconf2 bsdcpio bsdtar \
x11-utils xbase-clients ssss mat florence monkeysign libxfixes-dev liblzo2-dev python-sqlite \
wmaker python-cairo python-pdfrw libconfig-dev libx11-dev python-hachoir-core python-hachoir-parser \
mat myspell-en-us msttcorefonts xorg xserver-xorg-input-synaptics xul-ext-https-everywhere \
pulseaudio-module-jack alsa-tools-gui alsa-oss paman mythes-en-us \
cdbs debhelper javahelper quilt adduser git-core ant ant-optional ant-contrib \
jflex junit4 libcommons-collections3-java libcommons-compress-java libdb-je-java libecj-java \
libservice-wrapper-java libpisock-dev uno-libs3 libgtk-3-bin libbcprov-java gtk2-engines-murrine libc6-dev \
e2fslibs-dev debhelper python-dev libffi-dev python-dev libffi-dev libsqlite3-dev dconf-tools xul-ext-noscript \
software-properties-common libssl-dev u-boot-tools libgtk2-perl libmoose-perl shiboken python-pyside pyside-tools qt4-qmake \
git python-setuptools python-virtualenv python-pip libssl-dev python-openssl g++ openvpn systemd-gui python3-pyqt4 \
'  # Warning! Monkeysign pkg might be broken.
# gtk-engines-unico python-distutil-extra ? python-distusil-extra python-gobject python-qrencode python-imaging
    final_push_packages = Distro.final_push_packages + ' \
dbus dbus-x11 libconf-dbus-1-dev python-dbus python3-dbus liqt4-dbus dbus-glib-1.2 dbus-java-bin \
lxsession wireless-tools wpasupplicant obfsproxy network-manager-gnome \
mate-desktop-environment-extras'  # FYI, freenet is handled by install_final_push...()
# xul-ext-flashblock
# FYI, win-xp-theme is made possible by apt-add-repository() call in ..._final_push_...().

    def __init__( self , *args, **kwargs ):
        super( DebianDistro, self ).__init__( *args, **kwargs )
        self.name = 'debian'
        self.architecture = 'armhf'
        self.list_of_mkfs_packages = ( 'cryptsetup', 'jfsutils', 'xfsprogs', 'btrfs-tools' )
        self.packages_folder_url = 'http://ftp.uk.debian.org/debian/'
        self.my_extra_repos = ''

#    @property
#    def kernel_src_basedir( self ):
#        return self.sources_basedir + "/linux"

    def install_barebones_root_filesystem( self ):
        logme( 'DebianDistro - install_barebones_root_filesystem() - starting' )
        system_or_die( 'mkdir -p %s' % ( self.sources_basedir ) )
        if 0 != chroot_this( '/', r'yes "Y" 2>/dev/null | pacman -Sy fakeroot', attempts = 1, title_str = self.title_str, status_lst = self.status_lst ):
            chroot_this( '/', r'pacman-db-upgrade', attempts = 1 )
            chroot_this( '/', r'yes "Y" 2>/dev/null | pacman -Sy fakeroot', "Failed to install fakeroot", attempts = 1, title_str = self.title_str, status_lst = self.status_lst )
        if os.system( 'which debootstrap &> /dev/null' ) != 0:
            self.build_and_install_package_into_alarpy_from_source( 'debootstrap', quiet = True )
        self.update_status_with_newline( '...Debootstrap => %s' % ( self.title_str ) )
        my_proxy_call = '' if g_proxy is None else 'http_proxy=http://%s ftp_proxy=http://%s' % ( g_proxy, g_proxy )
        chroot_this( '/', "%s debootstrap --no-check-gpg --verbose --arch=%s --variant=buildd --include=aptitude,netbase,ifupdown,net-tools,linux-base %s %s %s"
                        % ( my_proxy_call, self.architecture, self.branch, self.mountpoint, self.packages_folder_url ),
                        title_str = self.title_str, status_lst = self.status_lst, on_fail = "Failed to bootstrap into Debian" )
        logme( 'DebianDistro - install_barebones_root_filesystem() - leaving' )

    def install_locale( self ):
        logme( 'DebianDistro - install_locale() - starting' )
        system_or_die( 'rm -f %s/var/lib/dpkg/lock; sync; sync; sync; sleep 3' % ( self.mountpoint ) )
        chroot_this( self.mountpoint, 'dpkg --configure -a' )
        chroot_this( self.mountpoint, 'yes 2> /dev/null | apt-get install locales locales-all', title_str = self.title_str, status_lst = self.status_lst )
#        chroot_this( self.mountpoint, "dpkg-reconfigure locales", title_str = self.title_str, status_lst = self.status_lst )
        chroot_this( self.mountpoint, 'dpkg --configure -a' )
        super( DebianDistro, self ).install_locale()
        logme( 'DebianDistro - install_locale() - leaving' )

    def install_kernel_and_mkfs ( self ):
        logme( 'DebianDistro - install_kernel_and_mkfs() - starting' )
#        for pkg_name in self.list_of_mkfs_packages:
#            chroot_this( self.mountpoint, "yes 2>/dev/null | dpkg -i %s/%s/%s_*deb" % ( self.sources_basedir , pkg_name, pkg_name ), \
#                                                                title_str = self.title_str, status_lst = self.status_lst )
        package_path = self.sources_basedir
        for package_name in self.list_of_mkfs_packages:
            chroot_this( self.mountpoint, 'cd %s/%s/%s-* && make install' % ( self.sources_basedir, package_name, package_name ),
                        on_fail = 'Failed to build %s in %s' % ( package_name, package_path ),
                        title_str = self.title_str,
                        status_lst = self.status_lst )
        if not os.path.isdir( '%s%s/src/chromeos-3.4' % ( self.mountpoint, self.kernel_src_basedir ) ):
            failed( 'Why does the chromeos source folder not exist? Surely it was downloaded and/or built earlier...' )
        if self.use_latest_kernel:
            chroot_this( self.mountpoint, 'cd %s/linux-latest && make install && make modules_install' % ( self.sources_basedir ),
                                                            title_str = self.title_str, status_lst = self.status_lst,
                                                            on_fail = "Failed to install the standard ChromeOS kernel and/or modules" )
        else:
            chroot_this( self.mountpoint, "cd %s/src/chromeos-3.4 && make install && make modules_install" % ( self.kernel_src_basedir ),
                                                            title_str = self.title_str, status_lst = self.status_lst,
                                                            on_fail = "Failed to install the tweaked kernel and/or modules" )
        self.update_status_with_newline( '...kernel installed.' )
        logme( 'DebianDistro - install_kernel_and_mkfs() - leaving' )

    def install_package_manager_tweaks( self ):
        logme( 'DebianDistro - install_package_manager_tweaks() - starting' )
        write_oneliner_file( '%s/etc/apt/sources.list' % ( self.mountpoint ), '''
deb http://ftp.uk.debian.org/debian %s main non-free contrib
deb-src http://ftp.uk.debian.org/debian %s main non-free contrib

deb http://ftp.debian.org/debian %s main non-free contrib
deb-src http://ftp.debian.org/debian %s main non-free contrib

deb http://ftp.ca.debian.org/debian %s main non-free contrib
deb-src http://ftp.ca.debian.org/debian %s main non-free contrib

deb     http://ftp.uk.debian.org/debian %s-backports main non-free contrib
deb-src http://ftp.uk.debian.org/debian %s-backports main non-free contrib

%s
''' % ( self.branch, self.branch, self.branch, self.branch, self.branch, self.branch, self.branch, self.branch,
        self.my_extra_repos ) )
        chroot_this( self.mountpoint, '' )
        if g_proxy is not None:
            f = open( '%s/etc/apt/apt.conf' % ( self.mountpoint ), 'a' )
            f.write( '''
Acquire::http::Proxy "http://%s/";
Acquire::ftp::Proxy  "ftp://%s/";
Acquire::https::Proxy "https://%s/";
''' % ( g_proxy, g_proxy, g_proxy ) )
            f.close()
        chroot_this( self.mountpoint, 'wget http://www.deb-multimedia.org/pool/main/d/deb-multimedia-keyring/deb-multimedia-keyring_2014.2_all.deb -O - > /tmp/debmult.deb', attempts = 1, title_str = self.title_str, status_lst = self.status_lst )
        chroot_this( self.mountpoint, 'dpkg -i /tmp/debmult.deb', attempts = 1, title_str = self.title_str, status_lst = self.status_lst )
        chroot_this( self.mountpoint, 'apt-get update', attempts = 1, title_str = self.title_str, status_lst = self.status_lst )
        logme( 'DebianDistro - install_package_manager_tweaks() - leaving' )

    def update_and_upgrade_all( self ):
        logme( 'DebianDistro - update_and_upgrade_all() - starting' )
        chroot_this ( self.mountpoint, 'yes 2>/dev/null | apt-get update', "Failed to update OS" , attempts = 5, title_str = self.title_str, status_lst = self.status_lst )
        chroot_this ( self.mountpoint, 'yes 2>/dev/null | apt-get upgrade', "Failed to upgrade OS" , attempts = 5, title_str = self.title_str, status_lst = self.status_lst )
        logme( 'DebianDistro - update_and_upgrade_all() - leaving' )

    def install_important_packages( self ):
        logme( 'DebianDistro - install_all_important_packages_other_than_systemd_sysv() - starting' )
        chroot_this( self.mountpoint, '''yes "Yes, do as I say!" | apt-get install systemd systemd-sysv''' , title_str = self.title_str, status_lst = self.status_lst,
                                on_fail = 'Failed to install systemd-sysv' )
        packages_installed_succesfully = []
        packages_that_we_failed_to_install = []
        packages_lst = self.important_packages.split( ' ' )
        list_of_groups = [ packages_lst[i:i + self.package_group_size] for i in range( 0, len( packages_lst ), self.package_group_size ) ]
        for lst in list_of_groups:
            pkg = ''.join( [r + ' ' for r in lst] )  # technically, 'pkg' is a string of three or more packages ;)
            att = 0
            while att < 3 and 0 != chroot_this( self.mountpoint,
                                                    'yes 2>/dev/null | apt-get install %s' % ( pkg ) ):  # ,
#                                                    title_str = None if self.name == 'ubuntu' else self.title_str,
#                                                    status_lst = None if self.name == 'ubuntu' else self.status_lst ):
                system_or_die( 'rm -f %s/var/lib/dpkg/lock; sync; sync; sync; sleep 3' % ( self.mountpoint ) )
                att += 1
            if att < 3:
                packages_installed_succesfully.append( pkg )
                logme( 'Installed %s OK' % ( pkg ) )
            else:
                logme( 'Failed to install some or all of %s; let us try them individually...' % ( pkg ) )
                for pkg in lst:
                    if 0 != chroot_this( self.mountpoint,
                                                    'yes 2>/dev/null | apt-get install %s' % ( pkg ) ):  # ,
#                                                    title_str = None if self.name == 'ubuntu' else self.title_str,
#                                                    status_lst = None if self.name == 'ubuntu' else self.status_lst ):
                        packages_that_we_failed_to_install.append( pkg )
                    else:
                        packages_installed_succesfully.append( pkg )
            self.update_status( '.' )
        if packages_that_we_failed_to_install in ( None, [] ):
            self.update_status_with_newline( "...All OK." )
        else:
            self.update_status_with_newline( 'Installed %d packages successfully' % ( len( packages_installed_succesfully ) ) )
            self.update_status( '...but we failed to install%s. Retrying...' % ( ''.join( [' ' + r for r in packages_that_we_failed_to_install] ) ) )
            chroot_this( self.mountpoint, 'yes "Yes" 2>/dev/null | aptitude install%s' % ( ''.join( [' ' + r for r in packages_that_we_failed_to_install] ) ),
                         status_lst = self.status_lst, title_str = self.title_str,
                         on_fail = 'Failed to install formerly failed packages' )
        if os.path.exists( '%s/usr/bin/python3' % ( self.mountpoint ) ):
            chroot_this( self.mountpoint, 'ln -sf ../../bin/python3 /usr/local/bin/python3' )
        system_or_die( 'rm -Rf %s/var/cache/apt/archives/*' % ( self.mountpoint ) )
        self.steal_dtc_and_mkinitcpio_from_alarpy()
        logme( 'DebianDistro - install_all_important_packages_other_than_systemd_sysv() - leaving' )

    def download_mkfs_sources( self ):
        logme( 'DebianDistro - download_mkfs_sources() - starting' )
        system_or_die( 'mkdir -p %s' % ( self.sources_basedir ) )
        for pkg_name in self.list_of_mkfs_packages:
            self.download_package_source( destination_directory = '%s' % ( self.sources_basedir ), package_name = pkg_name )
            if 0 != chroot_this( self.mountpoint, 'cd %s/%s/ && cd / || return 1' % ( self.sources_basedir, pkg_name ) ):
                failed( 'WHERE IS %s SOURCE? It should have been downloaded. Wart de hurl?' % ( pkg_name ) )
        logme( 'DebianDistro - download_mkfs_sources() - leaving' )

    def download_package_source( self, destination_directory, package_name, filenames_lst = None ):
        logme( 'DebianDistro - download_package_source() - starting' )
        assert( filenames_lst is None )
        pathname = '%s/%s' % ( destination_directory, package_name )
        system_or_die( 'mkdir -p %s/%s' % ( self.mountpoint, pathname ) )
        chroot_this( self.mountpoint, 'mkdir -p %s && cd %s && yes 2>/dev/null | apt-get --allow-unauthenticated source %s' % ( pathname, pathname, package_name ), \
                            on_fail = "Failed to download source for %s " % ( package_name ), title_str = self.title_str, status_lst = self.status_lst )
        logme( 'DebianDistro - download_package_source() - leaving' )

    def build_package( self, source_pathname ):
        logme( 'DebianDistro - build_package() - starting' )
        package_name = os.path.basename( source_pathname )
        package_path = os.path.dirname( source_pathname )
#        generate_and_incorporate_patch_for_debian( self.mountpoint, source_pathname )
        chroot_this( self.mountpoint, 'cd %s; [ -e "configure" ] && (./configure&&make) || make' % ( source_pathname + ( '/src/chromeos-3.4' if package_name == 'linux-chromebook' else '/' + package_name + '-*' ) ),
                    on_fail = 'Failed to build %s in %s' % ( package_name, package_path ),
                    attempts = 1,
                    title_str = self.title_str,
                    status_lst = self.status_lst )
#        chroot_this( self.mountpoint, 'cd %s/%s-* && yes 2>/dev/null | dpkg-buildpackage -b -us -uc -d' % ( source_pathname, package_name ),
#                    on_fail = 'Failed to build %s in %s' % ( package_name, package_path ),
#                    title_str = self.title_str,
#                    status_lst = self.status_lst )
        logme( 'DebianDistro - build_package() - leaving' )


    def configure_distrospecific_tweaks( self ):
        logme( 'DebianDistro - configure_distrospecific_tweaks() - starting' )
        self.update_status( 'Installing distro-specific tweaks' )
        if 0 != patch_org_freedesktop_networkmanager_conf_file( '%s/etc/dbus-1/system.d/org.freedesktop.NetworkManager.conf' % ( self.mountpoint ),
                                                        '%s/usr/local/bin/Chrubix/blobs/settings/nmgr-cfg-diff.txt.gz' % ( self.mountpoint ) ):
            self.update_status( ' ...(FYI, I failed to patch org.freedesktop.NetworkManager.conf)' )
        do_debian_specific_mbr_related_hacks( self.mountpoint )
        if os.path.exists( '%s/etc/apt/apt.conf' % ( self.mountpoint ) ):
            for to_remove in ( 'ftp', 'http' ):
                do_a_sed( '%s/etc/apt/apt.conf' % ( self.mountpoint ), 'Acquire::%s::Proxy.*' % ( to_remove ), '' )
        for pkg_name in self.list_of_mkfs_packages:
            chroot_this( self.mountpoint, 'sudo apt-mark hold %s' % ( pkg_name ) )
        self.update_status_with_newline( '...installed.' )
#        svcfile = '%s/lib/systemd/system/getty@.service' % ( self.mountpoint )
        chroot_this( self.mountpoint, 'systemctl enable lxdm.service' )

# #        chroot_this( self.mountpoint, 'wget http://www.deb-multimedia.org/pool/main/d/deb-multimedia-keyring/deb-multimedia-keyring_2014.2_all.deb -O - > /tmp/debmult.deb', attempts = 1, title_str = self.title_str, status_lst = self.status_lst )
# #        chroot_this( self.mountpoint, 'dpkg -i /tmp/debmult.deb', attempts = 1, title_str = self.title_str, status_lst = self.status_lst )
#        print( 'looking for %s' % ( svcfile ) )
#        assert( os.path.exists( svcfile ) )
#        do_a_sed( svcfile, '38400', '38400 --autologin root' )  # %%I ?
#        chroot_this( self.mountpoint, 'mkdir -p /var/run/tor' )
#        chroot_this( self.mountpoint, 'chown -R debian-tor /var/run/tor' )
#        chroot_this( self.mountpoint, 'chgrp -R debian-tor /var/run/tor' )
#        chroot_this( self.mountpoint, 'chmod 700 /var/run/tor' )
#        chroot_this( mountpoint, '''echo "
#            session required pam_loginuid.so
#     session required pam_systemd.so
#     " >> /etc/pam.d/lxdm''' )
#        self.status_lst.append( '...mickeymousing lxdm' )
#        p = '%s/%s' % ( self.sources_basedir, 'lxdm' )
#        patch_pathname = '%s/debian/patches/99_mickeymouse.patch' % ( p )
#        generate_mickeymouse_lxdm_patch( self.mountpoint, p, patch_pathname )
#        chroot_this( self.mountpoint, '''set -e; cd %s/lxdm/lxdm-*; for f in `find ../../debian/patches/*.patch`; do patch -p1 < $f; done; make; make install''' \
# % ( self.sources_basedir ), status_lst = self.status_lst, title_str = self.title_str, on_fail = 'Failed to mickeymouse lxdm' )
        logme( 'DebianDistro - configure_distrospecific_tweaks() - leaving' )

    def install_i2p( self ):
#        package_name = 'service-wrapper-java'
#        self.build_and_install_package_from_deb_or_ubu_source( package_name, \
#                                                        'http://deb.i2p2.no/pool/main/%s' % ( package_name[:1] ),
#                                                        neutralize_dependency_vernos = True )
        f = '/tmp/i2p.txt'
        jar_fname = '/tmp/i2p.jar'
        if 0 != system_or_die( "wget https://geti2p.net/en/download -O - | tr ' ' '\n' | tr '<' '\n' | tr '>' '\n' | tr '=' '\n' | grep i2pinstall | grep jar | grep download | head -n1 > %s" % ( f ) ):
            failed( 'Failed to find name/path of i2p installer' )
        relative_path = read_oneliner_file( f )
        fname = [ r for r in relative_path.split( '/' ) if r.find( 'i2pinstall' ) >= 0 and r.find( 'jar' ) >= 0][0]
        logme( 'fname = %s' % ( fname ) )
        release = fname.split( '_' )[1].strip( '.jar' )
        actual_download_path = 'https://download.i2p2.de/releases/%s/i2pinstall_%s.jar' % ( release, release )
        logme( 'actual_download_path = %s' % ( actual_download_path ) )
        if not os.path.exists( '%s%s' % ( self.mountpoint, jar_fname ) ):
            wget( url = actual_download_path, save_as_file = '%s%s.DLnow' % ( self.mountpoint, jar_fname ) )
            system_or_die( 'mv %s%s.DLnow %s%s' % ( self.mountpoint, jar_fname, self.mountpoint, jar_fname ) )
        write_oneliner_file( '%s/.install_i2p_like_this.sh' % ( self.mountpoint ), '''#!/bin/bash

clear
echo "Specify /opt/i2p as the installation directory, please."
echo "Specify /opt/i2p as the installation directory, please."
echo "Specify /opt/i2p as the installation directory, please."
echo "Specify /opt/i2p as the installation directory, please."
echo "Specify /opt/i2p as the installation directory, please."
echo "Specify /opt/i2p as the installation directory, please."
echo ""
rm -Rf /opt/i2p/.[a-z]* 2> /dev/null
rm -Rf /opt/i2p/* 2> /dev/null
#echo "1
#/opt/i2p
#1
#" |
java -jar %s -console
res=$?
if [ "$res" -le "1" ] ; then
  exit 0
else
  exit $res
fi
''' % ( jar_fname ) )
        system_or_die( 'chmod +x %s/.install_i2p_like_this.sh' % ( self.mountpoint ) )
#        chroot_this( self.mountpoint, 'su -l freenet /.install_i2p_like_this.sh', attempts = 1,
#                                on_fail = 'Failed to install I2P',
#                                status_lst = self.status_lst, title_str = self.title_str )
        if 0 != os.system( 'chroot %s /.install_i2p_like_this.sh' % ( self.mountpoint ) ):  # --userspec=freenet
            failed( 'Failed to install i2p' )
        assert( os.path.exists( '%s/opt/i2p' % ( self.mountpoint ) ) )
        self.add_user_SUB( 'i2psvc' , '/opt/i2p' )
        do_a_sed( '%s/etc/passwd' % ( self.mountpoint ), 'i2psvc:i2psvc', 'i2psvc:/bin/bash' )
        chroot_this( self.mountpoint, 'chown -R i2psvc /opt/i2p' )
        logme( 'tweaking i2p ID...' )

    def install_final_push_of_packages( self ):
        logme( 'DebianDistro - install_final_push_of_packages() - starting' )
        self.install_win_xp_theme()  # If you install this before i2p, something gets broken. :-/
        chroot_this( self.mountpoint, 'yes "" | apt-get -f install' )  # This shouldn't be necessary...
        chroot_this( self.mountpoint, 'which ping && echo "Ping installed OK" || yes 2>/dev/null | apt-get install iputils-ping', on_fail = 'Failed to install ping' )
#        chroot_this( self.mountpoint, 'pip install leap.bitmask', status_lst = self.status_lst, title_str = self.title_str,
#                     on_fail = 'Failed to install leap.bitmask' )
#        self.status_lst.append( [ 'Go to https://wiki.freenetproject.org/Installing/POSIX and learn how to install Freenet'] )
        if self.final_push_packages.find( 'wmsystemtray' ) < 0:
            try:
                self.install_expatriate_software_into_a_debianish_OS( package_name = 'wmsystemtray', method = 'debian' )
            except RuntimeError:
                os.system( 'sync;sync;sync' )
                os.system( 'sleep 2' )
                os.system( 'sync;sync;sync' )
                os.system( 'sleep 2' )
                self.install_expatriate_software_into_a_debianish_OS( package_name = 'wmsystemtray', method = 'debian' )
        if self.final_push_packages.find( 'lxdm' ) < 0:
#            install_lxdm_from_source( self.mountpoint )
            self.install_expatriate_software_into_a_debianish_OS( package_name = 'lxdm', method = 'ubuntu' )
        self.update_status( 'Installing remaining packages' )
#        self.status_lst.append( ['Installing %s' % ( self.final_push_packages.replace( '  ', ' ' ).replace( ' ', ', ' ) )] )
        chroot_this( self.mountpoint, 'yes "Yes" | aptitude install %s' % ( self.final_push_packages ),
#                     title_str = self.title_str, status_lst = self.status_lst,
                     on_fail = 'Failed to install final push of packages' )
        os.system( 'clear' )
        self.update_status_with_newline( '...there.' )
        logme( 'DebianDistro - install_final_push_of_packages() - leaving' )

    def install_win_xp_theme( self ):
        if 0 != os.system( 'cp %s/usr/local/bin/Chrubix/blobs/xp/win-xp-theme_1.3.1~saucy~Noobslab.com_all.deb %s/tmp/win-xp-themes.deb 2> /dev/null' % ( self.mountpoint, self.mountpoint ) ):
            if 0 != os.system( 'cp /usr/local/bin/Chrubix/blobs/xp/win-xp-theme_1.3.1~saucy~Noobslab.com_all.deb %s/tmp/win-xp-themes.deb 2> /dev/null' % ( self.mountpoint ) ):
                failed ( 'Unable to retrieve win xp noobslab file from %s/usr/local/bin/Chrubix/blobs/xp' % ( self.mountpoint ) )
        if 0 != chroot_this( self.mountpoint, 'yes 2>/dev/null | dpkg -i --force all /tmp/win-xp-themes.deb', title_str = self.title_str, status_lst = self.status_lst, attempts = 1 ):
#            self.update_status('...installing win-xp-theme from source'
            self.build_and_install_software_from_archlinux_source( 'win-xp-theme', only_download = True, quiet = True, nodeps = True )
            chroot_this( self.mountpoint, \
                         'cd %s/win-xp-theme/src && install -d /usr/share/themes/Win-XP-theme && cp -r * /usr/share/themes/' % \
                         ( self.sources_basedir ), status_lst = self.status_lst, title_str = self.title_str, on_fail = 'Failed to install win-xp-theme from source' )

    def steal_dtc_and_mkinitcpio_from_alarpy( self ):
        logme( 'DebianDistro - steal_dtc_and_mkinitcpio_from_alarpy() - starting' )
        system_or_die( '''tar -cz `find /{usr,etc} | grep mkinit` `find /{usr,etc} | grep initcpio` `find /{usr,etc,bin} -name lz4` 2>/dev/null | tar -zx -C %s 2>/dev/null''' % ( self.mountpoint ), errtxt = "Unable to steal xz, mkinitcpio, etc. from Alarpy and install it in your distro" )
        system_or_die( 'cp /bin/dtc %s/bin/' % ( self.mountpoint ) )
        logme( 'DebianDistro - steal_dtc_and_mkinitcpio_from_alarpy() - leaving' )

    def steal_chromium_from_alarpy( self ):  # the '-k' is important ;)
        logme( 'DebianDistro - steal_chromium_from_alarpy() - starting' )
        system_or_die( '''tar -cz `find /{etc,usr,usr/bin,usr/lib,usr/local/bin,usr/local/lib}/chromium*` /{usr/lib,lib,usr/local/lib}/{libevent,libpng,libopus,libharfbuzz,libsnappy,libgcrypt,libspeechd,libudev,libXss,libicuuc,libicudata,libgraphite2}* 2>/dev/null | tar -zx -k -C %s 2>/dev/null''' % ( self.mountpoint ), errtxt = "Unable to steal chromium from Alarpy and install it in your distro" )
        logme( 'DebianDistro - steal_chromium_from_alarpy() - leaving' )

    def install_expatriate_software_into_a_debianish_OS( self, package_name, method = None ):
        logme( 'DebianDistro - install_expatriate_software_into_a_debianish_OS() - starting' )
        dct = {'ubuntu':self.build_and_install_package_from_ubuntu_source,
               'debian':self.build_and_install_package_from_debian_source,
               'git':self.build_and_install_software_from_archlinux_git,
               'src':self.build_and_install_software_from_archlinux_source}
        myfunc = None
        if method is None:
            for method in ( 'ubuntu', 'debian', 'src', 'git' ):
                if self.status_lst is not None:
                    self.update_status( '...Trying %s' % ( method ) )
                try:
                    self.install_expatriate_software_into_a_debianish_OS( package_name = package_name, \
                                                                     method = method )
                    # It'll throw an exception if it fails. So, if it gets this far, it means it succeeded.
                    return 0
                except ( SyntaxError, SystemError, RuntimeError, AssertionError, IOError ):
                    if self.status_lst is not None:
                        self.update_status( '...%s method failed' % ( method ) )
                    continue
            raise RuntimeError( 'Unable to build %s --- nothing worked' % ( package_name ) )
        else:
            try:
                myfunc = dct[method]
            except KeyError:
                raise SyntaxError( 'You specified %s but this is an unknown method' % ( str( method ) ) )
            if self.status_lst is not None:
                if package_name == 'chromium':
                    self.update_status( ' (which takes a while)' )
            myfunc( package_name = package_name )
        logme( 'DebianDistro - install_expatriate_software_into_a_debianish_OS() - leaving' )

    def build_and_install_package_from_ubuntu_source( self, package_name ):
        logme( 'DebianDistro - build_and_install_package_from_ubuntu_source() - starting' )
        self.build_and_install_package_from_deb_or_ubu_source( package_name, \
                                                        'http://packages.ubuntu.com/precise' )
        logme( 'DebianDistro - build_and_install_package_from_ubuntu_source() - leaving' )

    def build_and_install_package_from_debian_source( self, package_name, which_distro = 'jessie' ):
        logme( 'DebianDistro - build_and_install_package_from_debian_source() - starting' )
        self.build_and_install_package_from_deb_or_ubu_source( package_name, \
                                                        'https://packages.debian.org/%s' % ( which_distro ) )
        logme( 'DebianDistro - build_and_install_package_from_debian_source() - leaving' )

    def build_and_install_package_from_deb_or_ubu_source( self, package_name, src_url, neutralize_dependency_vernos = False ):
        logme( 'DebianDistro - build_and_install_package_from_deb_or_ubu_source() - starting' )
        chroot_this( self.mountpoint, '''yes 2> /dev/null | apt-get remove %s 2> /dev/null''' % ( package_name ), title_str = self.title_str, status_lst = self.status_lst )
        if self.status_lst is not None:
            self.update_status( "Repackaging %s" % ( package_name ) )
        assert( package_name != 'linux-chromebook' )
        chroot_this( self.mountpoint, 'yes "" 2>/dev/null | apt-get build-dep %s' % ( package_name ),
                     title_str = self.title_str, status_lst = self.status_lst )
#        if package_name == 'lxdm' and
        if os.path.exists( '%s%s/core/%s' % ( self.mountpoint, self.sources_basedir, package_name ) ):
            self.update_status( ' (FYI, reusing old %s sources)' % ( package_name ) )
        else:
            system_or_die( 'rm -Rf   %s%s/%s' % ( self.mountpoint, self.sources_basedir, package_name ) )
            system_or_die( 'mkdir -p %s%s/%s' % ( self.mountpoint, self.sources_basedir, package_name ) )
            files_i_want = self.deduce_filelist_from_website( src_url, package_name )
            logme( 'files_i_want(%s,%s) => %s' % ( src_url, package_name, str( files_i_want ) ) )
            if files_i_want in ( None, [], '' ):
                files_i_want = self.deduce_filelist_from_website( os.path.dirname( src_url ) + '/source/' + os.path.basename( src_url ), package_name )
                logme( 'files_i_want(%s,%s) => %s' % ( src_url, package_name, str( files_i_want ) ) )
            if files_i_want in ( None, [], '' ):
                files_i_want = ''
                logme( 'files_i_want(%s,%s) => %s' % ( src_url, package_name, str( files_i_want ) ) )
#            if files_i_want in ( None, [], '' ):
#                raise IOError( '%s is absent from the online repositories' % ( package_name ) )
            self.download_pkgfiles_from_website( package_name, files_i_want )
        if self.status_lst is not None:                      self.update_status( '...Extracting' )
        self.extract_pkgfiles_accordingly( package_name, files_i_want )
        if self.status_lst is not None:                      self.update_status( '...Tweaking' )
        self.tweak_pkgfiles_accordingly( package_name, neutralize_dependency_vernos )
        if self.status_lst is not None:                      self.update_status( '...Building' )
        self.build_package_from_fileset( package_name )
        if self.status_lst is not None:                      self.update_status( '...Installing' )
#        chroot_this( self.mountpoint, 'dpkg -i %s/%s/%s_*.deb' % ( self.sources_basedir, package_name, package_name ),
        chroot_this( self.mountpoint, 'dpkg -i %s/%s/*.deb' % ( self.sources_basedir, package_name ),
                                                                        attempts = 1,
                                                                        on_fail = 'Failed to install %s' % ( package_name ) )
        if self.status_lst is not None:                      self.update_status_with_newline( '...Yay.' )
        system_or_die( 'rm -f %s%s/*.deb' % ( self.mountpoint, self.sources_basedir ) )
        logme( 'DebianDistro - build_and_install_package_from_deb_or_ubu_source() - leaving' )
        return 0

    def deduce_filelist_from_website( self, src_url, package_name ):
        logme( 'DebianDistro - deduce_filelist_from_website() - starting' )
        logme( 'src_url = %s' % ( src_url ) )
        tmpfile = generate_temporary_filename( '/tmp' )
        files_i_want = []
        logme( 'package_name = %s' % ( package_name ) )
        logme( '' )
        extra_slash = '/' if src_url[-2:] == '/%s' % ( package_name[:1] )else ''
        full_url = '%s/%s%s' % ( src_url, package_name, extra_slash )
        logme( 'full_url = %s' % ( full_url ) )
        for search_phrase in ( '.dsc', '.orig.tar.gz', '.orig.tar.xz', 'debian.tar.gz', 'debian.tar.xz', '.diff.' ):
            if 0 == os.system ( 'curl %s 2> /dev/null | fgrep "%s" > %s' % ( full_url, search_phrase, tmpfile ) ):
                result_of_search = read_oneliner_file( tmpfile )
                logme( "%s => %s" % ( search_phrase, result_of_search ) )
                actual_url = None
                if result_of_search not in ( None, [], '' ):
                    http_path = result_of_search.split( '"' )
                    try:
                        actual_url = [ r for r in http_path if r.find( 'http' ) >= 0][0]
                        logme( 'SUCCESS - actual_url = %s' % ( actual_url ) )
                        files_i_want.append( actual_url )
                    except IndexError:
                        for subpath in [ r for r in http_path if r.find( '><' ) < 0 and r[-1] != '=']:
                            if subpath.find( search_phrase ) >= 0:
                                actual_url = '%s/%s/%s' % ( src_url, package_name, subpath )
                                logme( 'actual_url = %s' % ( actual_url ) )
                            try:
                                if subpath.find( search_phrase ) >= 0:
                                    if wget( url = actual_url, save_as_file = '/tmp/junkfile.junk', quiet = True, attempts = 1 ) == 0:
                                        logme( 'SUCCESS - actual_url = %s' % ( actual_url ) )
                                        files_i_want.append( actual_url )
                            except SystemError:
                                logme( 'cannot read %s' % ( actual_url ) )
                                continue
                logme( 'SUCCESS - actual_url = %s' % ( actual_url ) )
                files_i_want.append( actual_url )
            else:
                logme( 'WARNING --- returned nonzero from curl %s when searching for %s' % ( full_url, search_phrase ) )
        os.unlink( tmpfile )
        logme( 'DebianDistro - deduce_filelist_from_website() - leaving' )
        return files_i_want

    def download_pkgfiles_from_website( self, package_name, files_i_want ):
        logme( 'DebianDistro - download_pkgfiles_from_website() - starting' )
        logme( 'files_i_want = %s' % ( str( files_i_want ) ) )
        system_or_die( 'cd %s%s/%s' % ( self.mountpoint, self.sources_basedir, package_name ) )
        for url in files_i_want:
            outfile = '%s%s/%s/%s' % ( self.mountpoint, self.sources_basedir, package_name, os.path.basename( url ) )
            logme( 'url = %s => outfile = %s' % ( url, outfile ) )
            wget( url = url, save_as_file = outfile, title_str = self.title_str, status_lst = self.status_lst )
        logme( 'DebianDistro - download_pkgfiles_from_website() - leaving' )

    def extract_pkgfiles_accordingly( self, package_name, files_i_want ):
        logme( 'DebianDistro - extract_pkgfiles_accordingly() - starting' )
        logme( 'Extracting %s for %s' % ( str( files_i_want ), package_name ) )
        for field in ( 'debian.tar', 'orig.tar' ):
            if field in str( files_i_want ):
                tarball_fname = os.path.basename( [r for r in files_i_want if r.find( field ) >= 0][0] )
                if tarball_fname[-3:] == '.xz':
                    extraction_param = 'Jxf'
                elif tarball_fname[-3:] == '.gz':
                    extraction_param = 'zxf'
                elif tarball_fname[-3:] == 'bz2':
                    extraction_param = 'jxf'
                chroot_this( self.mountpoint, 'tar -%s %s/%s/%s -C %s/%s' \
                             % ( extraction_param, self.sources_basedir, package_name, tarball_fname, self.sources_basedir, package_name ), \
                             title_str = self.title_str, status_lst = self.status_lst, attempts = 1 )
                if 'diff.gz' in str( files_i_want ):
                    chroot_this( self.mountpoint, 'cd %s/%s/%s* && cat `ls ../%s*.diff.gz` | gunzip -dc | patch -p1 2>&1 && mv * ..' % \
                                 ( self.sources_basedir, package_name, package_name.replace( 'gtk3-engines-unico', 'unico' ), package_name ), \
                                 on_fail = 'Failed to patch %s thingumabob' % ( package_name ), \
                                 title_str = self.title_str, status_lst = self.status_lst )
        logme( 'DebianDistro - extract_pkgfiles_accordingly() - leaving' )

    def tweak_pkgfiles_accordingly( self, package_name, neutralize_dependency_vernos = False ):
        logme( 'DebianDistro - tweak_pkgfiles_accordingly() - starting' )
        logme( 'Tweaking %s' % ( package_name ) )
        f = '%s/%s/%s/debian/control' % ( self.mountpoint, self.sources_basedir, package_name )
        if not os.path.isfile( f ):
            failed( '%s not found; something is wrong with the setup of %s' % ( f, package_name ) )
            if not os.path.isfile( '%s.orig' % ( f ) ):
                system_or_die( 'mv %s %s.orig' % ( f, f ) )
            system_or_die( 'cat %s.orig | grep -v x11-utils | grep -v gtk2-engines | grep -v libpam | grep -v librsvg | grep -v xbase > %s' % ( f, f ) )
        if neutralize_dependency_vernos:
            do_a_sed( f, '\\(>=.*\\)', '' )
        if not os.path.isfile( f ):
            failed( 'Oops, you banjaxed control...' )
        g = '%s/%s/%s/debian/libservice-wrapper-java.preinst' % ( self.mountpoint, self.sources_basedir, package_name )
        if os.path.isfile( g ):
            write_oneliner_file( g, '''#!/bin/sh
echo hi\n
exit 0
''' )
            logme( 'rewriting preinst file for libservice-wrapper-java' )
        logme( 'DebianDistro - tweak_pkgfiles_accordingly() - leaving' )

    def build_package_from_fileset( self, package_name ):
        logme( 'DebianDistro - build_package_from_fileset() - starting' )
        logme( 'Building and installing %s' % ( package_name ) )
        tmpfile = generate_temporary_filename( '/tmp' )
        # FYI, tmpfile (in this case) is written to $mountpoint/tmp/____. That's fine, because BOTH references are in chroot_this().
        att = 0
        res = 999
        while att < 4 and res != 0:
            res = chroot_this( self.mountpoint, 'cd %s/%s/%s-* ; cp -af ../debian . ; dpkg-buildpackage -b -us -uc -d 2> %s' % \
                               ( self.sources_basedir, package_name, package_name.replace( 'gtk3-engines-unico', 'unico' ), tmpfile ),
                                                    title_str = self.title_str, status_lst = self.status_lst, attempts = 1 )
            if res != 0:
                chroot_this( self.mountpoint, '''cat %s | grep -i "unmet build dep" | cut -d':' -f3-99 | tr ' ' '\n' | grep "[a-z].*" | grep -v "=" | tr '\n' ' ' > %s''' % ( tmpfile, tmpfile + '.x' ) , attempts = 1 )
                needed_pkgs = read_oneliner_file( self.mountpoint + '/' + tmpfile + '.x' )
                chroot_this( self.mountpoint, "yes 2> /dev/null | apt-get install %s" % ( needed_pkgs ), \
                                                on_fail = "Failed to install the build deps of %s" % ( package_name ) , \
                                                title_str = self.title_str, status_lst = self.status_lst, attempts = 1 )
                att += 1
        logme( 'DebianDistro - build_package_from_fileset() - leaving' )
        return res


class WheezyDebianDistro( DebianDistro ):
    def __init__( self , *args, **kwargs ):
        super( WheezyDebianDistro, self ).__init__( *args, **kwargs )
        self.branch = 'wheezy'  # lowercase; yes, it matters :)
        self.important_packages = self.important_packages.replace( 'openjdk-8-', 'openjdk-7-' ) + ' libetpan15'
        self.my_extra_repos = 'deb http://www.deb-multimedia.org ' + self.branch + ' main non-free'

    def tweak_pulseaudio( self ):
        # Wheezy requires a special kind of bulls***. :-/ The standard Distro.tweak_pulseaudio() won't work.
        if os.path.exists( '%s/etc/pulse/default.pa' % ( self.mountpoint ) ):
            new_str = 'load-module module-alsa-source device=hw:0,0 #QQQ'
            do_a_sed( '%s/etc/pulse/default.pa' % ( self.mountpoint ), '#load-module module-alsa-sink', new_str )
        else:
            logme( 'tweak_pulseaudio() -- unable to modify /etc/pulse/default.pa; it does not exist' )
        if os.path.exists( '%s/etc/default/pulseaudio' % ( self.mountpoint ) ):
            do_a_sed( '%s/etc/default/pulseaudio' % ( self.mountpoint ), 'PULSEAUDIO_SYSTEM_START=0', 'PULSEAUDIO_SYSTEM_START=1' )
        else:
            logme( 'tweak_pulseaudio() -- unable to modify /etc/default/pulseaudio; it does not exist' )


class JessieDebianDistro( DebianDistro ):
    def __init__( self , *args, **kwargs ):
        super( JessieDebianDistro, self ).__init__( *args, **kwargs )
        self.branch = 'jessie'  # lowercase; yes, it matters
        self.important_packages += ' libetpan-dev g++-4.8'


class StretchDebianDistro( DebianDistro ):
    def __init__( self , *args, **kwargs ):
        super( StretchDebianDistro, self ).__init__( *args, **kwargs )
        self.branch = 'stretch'  # lowercase; yes, it matters
        self.important_packages += ' libetpan-dev g++-4.8'
#        self.use_latest_kernel = True

    def configure_distrospecific_tweaks( self ):
        DebianDistro.configure_distrospecific_tweaks( self )  # FIXME use super(StretchDebianDistro, self). .... one day :)
        self.update_status_with_newline( '**Fixing systemd etc. in %s**' % ( self.fullname ) )
        for cmd in ( 
#                    'yes Y | apt-get install systemd-shim systemd-shiv',
                    'yes Y | apt-get remove systemd-gui',
                    '''cd /tmp; rm -f *deb;
for f in libpam-systemd libsystemd0 systemd systemd-sysv; do
  wget https://dl.dropboxusercontent.com/u/59916027/chrubix/systemd/"$f"_215-17%2Bdeb8u1_armhf.deb
done
yes Y | dpkg -i *deb
'''
                    ):
            chroot_this( self.mountpoint, cmd, status_lst = self.status_lst, title_str = self.title_str, attempts = 2 )
        self.update_status_with_newline( '**Done w/ fixing systemd in %s**' % ( self.fullname ) )

