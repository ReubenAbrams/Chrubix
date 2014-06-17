#!/usr/local/bin/python3
#
# debian.py

# TODO: aptitude --download-only ... Should I install it at end of important pkg func, or should I do it during final push?

from chrubix.utils import generate_temporary_filename, g_proxy, failed, system_or_die, write_oneliner_file, wget, logme, \
                          chroot_this, read_oneliner_file, do_a_sed
                          # , generate_and_incorporate_patch_for_debian
import os
from chrubix.distros import Distro

# FIXME: paman and padevchooser are deprecated
class DebianDistro( Distro ):
    important_packages = Distro.important_packages + ' ' + \
'iputils-ping python3-setuptools gnu-standards apt-utils libpopt-dev libacl1-dev libcrypto++-dev exo-utils libnotify-bin \
libattr1-dev build-essential fakeroot oss-compat devscripts equivs lintian libglib2.0-dev po-debconf \
iso-codes debconf cdbs debhelper uuid-dev quilt openjdk-7-jre ant xz-utils libxmu-dev libconfig-auto-perl \
python-software-properties default-jre dpatch festival dialog libck-connector-dev libpam0g-dev python-mutagen \
libgtk2.0-dev librsvg2-common librsvg2-dev pyqt4-dev-tools libreoffice-help-en-us libreoffice \
firmware-libertas libxpm-dev libreadline-dev libblkid-dev python-distutils-extra \
gtk2-engines-pixbuf libsnappy-dev libgcrypt-dev iceweasel icedove gconf2 bsdcpio bsdtar \
x11-utils xbase-clients ssss mat florence monkeysign libxfixes-dev liblzo2-dev \
wmaker python-cairo python-pdfrw libconfig-dev libx11-dev python-hachoir-core python-hachoir-parser \
mat myspell-en-us msttcorefonts xorg xserver-xorg-input-synaptics xul-ext-https-everywhere \
pulseaudio paprefs pulseaudio-module-jack pavucontrol paman alsa-tools-gui alsa-oss mythes-en-us \
libpisock-dev uno-libs3 libgtk-3-bin libbcprov-java gtk2-engines-murrine libc6-dev \
e2fslibs-dev debhelper python-dev libffi-dev python-dev libffi-dev libsqlite3-dev \
software-properties-common \
'  # Warning! Monkeysign pkg might be broken.
# gtk-engines-unico python-distutil-extra ? python-distusil-extra python-gobject python-qrencode python-imaging
    final_push_packages = Distro.final_push_packages + ' \
dbus dbus-x11 libconf-dbus-1-dev python-dbus python3-dbus liqt4-dbus dbus-glib-1.2 dbus-java-bin \
lxsession wireless-tools wpasupplicant obfsproxy network-manager-gnome \
mate-desktop-environment-extras i2p i2p-keyring'  # FYI, freenet is handled by install_final_push...()
# xul-ext-flashblock
# FYI, win-xp-theme is made possible by apt-add-repository() call in ..._final_push_...().

    def __init__( self , *args, **kwargs ):
        super( DebianDistro, self ).__init__( *args, **kwargs )
        self.name = 'debian'
        self.list_of_mkfs_packages = ( 'jfsutils', 'xfsprogs', 'btrfs-tools' )
        self.typical_install_duration = 16000

#    @property
#    def kernel_src_basedir( self ):
#        return self.sources_basedir + "/linux"

    def install_barebones_root_filesystem( self ):
        logme( 'DebianDistro - install_barebones_root_filesystem() - starting' )
        system_or_die( 'mkdir -p %s' % ( self.sources_basedir ) )
        if os.system( 'which debootstrap &> /dev/null' ) != 0:
            self.build_and_install_package_into_alarpy_from_source( 'debootstrap', quiet = True )
        self.status_lst.append( ['Running debootstrap, to generate Debian filesystem'] )
        my_proxy_call = '' if g_proxy is None else 'http_proxy=http://%s ftp_proxy=http://%s' % ( g_proxy, g_proxy )
        chroot_this( '/', "%s debootstrap --no-check-gpg --verbose --arch=%s --variant=buildd --include=aptitude,netbase,ifupdown,net-tools,linux-base %s %s http://ftp.uk.debian.org/debian/"
                        % ( my_proxy_call, self.architecture, self.branch, self.mountpoint ),
                        title_str = self.title_str, status_lst = self.status_lst, on_fail = "Failed to bootstrap into Debian" )
        logme( 'DebianDistro - install_barebones_root_filesystem() - leaving' )

    def install_locale( self ):
        logme( 'DebianDistro - install_locale() - starting' )
        system_or_die( 'rm -f %s/var/lib/dpkg/lock; sync; sync; sync; sleep 3' % ( self.mountpoint ) )
        chroot_this( self.mountpoint, 'dpkg --configure -a' )
        chroot_this( self.mountpoint, 'yes 2> /dev/null | apt-get install locales locales-all', title_str = self.title_str, status_lst = self.status_lst )
#        chroot_this( self.mountpoint, "dpkg-reconfigure locales", title_str = self.title_str, status_lst = self.status_lst )
        chroot_this( self.mountpoint, 'dpkg --configure -a' )
        self.do_generic_locale_configuring()
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
        self.status_lst[-1] += '...kernel installed.'
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
''' % ( self.branch, self.branch, self.branch, self.branch, self.branch, self.branch, self.branch, self.branch ) )
        chroot_this( self.mountpoint, '' )
        if g_proxy is not None:
            f = open( '%s/etc/apt/apt.conf' % ( self.mountpoint ), 'a' )
            f.write( '''
Acquire::http::Proxy "http://%s/";
Acquire::ftp::Proxy  "ftp://%s/";
Acquire::https::Proxy "https://%s/";
''' % ( g_proxy, g_proxy, g_proxy ) )
            f.close()
        logme( 'DebianDistro - install_package_manager_tweaks() - leaving' )

    def update_and_upgrade_all( self ):
        logme( 'DebianDistro - update_and_upgrade_all() - starting' )
        chroot_this ( self.mountpoint, 'yes 2>/dev/null | apt-get update', "Failed to update OS" , attempts = 5, title_str = self.title_str, status_lst = self.status_lst )
        chroot_this ( self.mountpoint, 'yes 2>/dev/null | apt-get upgrade', "Failed to upgrade OS" , attempts = 5, title_str = self.title_str, status_lst = self.status_lst )
        logme( 'DebianDistro - update_and_upgrade_all() - leaving' )

    def install_important_packages( self ):
        logme( 'DebianDistro - install_important_packages() - starting' )
        packages_installed_succesfully = []
        packages_that_we_failed_to_install = []
        packages_lst = self.important_packages.split( ' ' )
        list_of_groups = [ packages_lst[i:i + self.package_group_size] for i in range( 0, len( packages_lst ), self.package_group_size ) ]
        for lst in list_of_groups:
            pkg = ''.join( [r + ' ' for r in lst] )  # technically, 'pkg' is a string of three or more packages ;)
            att = 0
            while att < 3 and 0 != chroot_this( self.mountpoint,
                                                    'yes 2>/dev/null | apt-get install %s' % ( pkg ),
                                                    title_str = self.title_str, status_lst = self.status_lst ):
                system_or_die( 'rm -f %s/var/lib/dpkg/lock; sync; sync; sync; sleep 3' % ( self.mountpoint ) )
                att += 1
            if att < 3:
                packages_installed_succesfully.append( pkg )
                logme( 'Installed %s OK' % ( pkg ) )
            else:
                logme( 'Failed to install some or all of %s; let us try them individually...' % ( pkg ) )
                for pkg in lst:
                    if 0 != chroot_this( self.mountpoint,
                                                    'yes 2>/dev/null | apt-get install %s' % ( pkg ),
                                                    title_str = self.title_str, status_lst = self.status_lst ):
                        packages_that_we_failed_to_install.append( pkg )
                    else:
                        packages_installed_succesfully.append( pkg )
            self.status_lst[-1] += '.'
        if packages_that_we_failed_to_install in ( None, [] ):
            self.status_lst[-1] += "All OK."
        else:
            self.status_lst.append( ['Installed %d packages successfully' % ( len( packages_installed_succesfully ) )] )
            self.status_lst[-1] += '...but we failed to install%s. Retrying...' % ( ''.join( [' ' + r for r in packages_that_we_failed_to_install] ) )
            chroot_this( self.mountpoint, 'yes 2>/dev/null | aptitude install%s' % ( ''.join( [' ' + r for r in packages_that_we_failed_to_install] ) ),
                         status_lst = self.status_lst, title_str = self.title_str,
                         on_fail = 'Failed to install formerly failed packages' )
        if os.path.exists( '%s/usr/bin/python3' % ( self.mountpoint ) ):
            chroot_this( self.mountpoint, 'ln -sf ../../bin/python3 /usr/local/bin/python3' )
        system_or_die( 'rm -Rf %s/var/cache/apt/archives/*' % ( self.mountpoint ) )
        self.steal_dtc_and_mkinitcpio_from_alarpy()
        logme( 'DebianDistro - install_important_packages() - leaving' )

#        for pkg_name in 'python2-pyptlib xul-ext-torbutton'.split( ' ' ):
#            self.build_and_install_package_from_debian_source( pkg_name )

#    def download_kernel_source( self ):
#        self.download_package_source( destination_directory = os.path.dirname( self.kernel_src_basedir ),
#                                      package_name = os.path.basename( self.kernel_src_basedir ) )

    def download_mkfs_sources( self ):
        logme( 'DebianDistro - download_mkfs_sources() - starting' )
        system_or_die( 'mkdir -p %s' % ( self.sources_basedir ) )
        for pkg_name in self.list_of_mkfs_packages:
            self.download_package_source( destination_directory = '%s' % ( self.sources_basedir ), package_name = pkg_name )
        logme( 'DebianDistro - download_mkfs_sources() - leaving' )

    def download_package_source( self, destination_directory, package_name, filenames_lst = None ):
        logme( 'DebianDistro - download_package_source() - starting' )
        assert( filenames_lst is None )
        pathname = '%s/%s' % ( destination_directory, package_name )
        system_or_die( 'mkdir -p %s/%s' % ( self.mountpoint, pathname ) )
        chroot_this( self.mountpoint, 'mkdir -p %s && cd %s && yes 2>/dev/null | apt-get source %s' % ( pathname, pathname, package_name ), \
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
        self.status_lst.append( ['Installing distro-specific tweaks'] )
        if os.path.exists( '%s/etc/apt/apt.conf' % ( self.mountpoint ) ):
            for to_remove in ( 'ftp', 'http' ):
                do_a_sed( '%s/etc/apt/apt.conf' % ( self.mountpoint ), 'Acquire::%s::Proxy.*' % ( to_remove ), '' )
        for pkg_name in self.list_of_mkfs_packages:
            chroot_this( self.mountpoint, 'sudo apt-mark hold %s' % ( pkg_name ) )
        self.status_lst[-1] += '...installed.'
        write_oneliner_file( '/etc/X11/default-display-manager', '/usr/local/bin/greeter.sh' )
        logme( 'DebianDistro - configure_distrospecific_tweaks() - leaving' )

    def install_final_push_of_packages( self ):
        logme( 'DebianDistro - install_final_push_of_packages() - starting' )
        chroot_this( self.mountpoint, 'which ping && echo "Ping installed OK" || yes 2>/dev/null | apt-get install iputils-ping', on_fail = 'Failed to install ping' )
#        chroot_this( self.mountpoint, 'pip install leap.bitmask', status_lst = self.status_lst, title_str = self.title_str,
#                     on_fail = 'Failed to install leap.bitmask' )
        self.install_win_xp_theme()
        for cmd in ( 
                    'yes 2>/dev/null | apt-get install u-boot-tools || echo -en ""',
                    'yes 2>/dev/null | add-apt-repository "deb http://deb.i2p2.no/ %s main"' % ( 'stable' ),  # 'unstable' if self.branch == 'jessie' else 'stable' ),
                    'yes "" 2>/dev/null | curl https://geti2p.net/_static/debian-repo.pub | apt-key add -',
                    'yes 2>/dev/null | apt-get update'
                   ):
            chroot_this( self.mountpoint, cmd, title_str = self.title_str, status_lst = self.status_lst,
                         on_fail = "Failed to run %s successfully" % ( cmd ) )
#        self.status_lst.append( [ 'Go to https://wiki.freenetproject.org/Installing/POSIX and learn how to install Freenet'] )
        if self.final_push_packages.find( 'wmsystemtray' ) < 0:
            self.install_expatriate_software_into_a_debianish_OS( package_name = 'wmsystemtray', method = 'debian' )
        if self.final_push_packages.find( 'lxdm' ) < 0:
            self.install_expatriate_software_into_a_debianish_OS( package_name = 'lxdm', method = 'ubuntu' )
        self.status_lst.append( ['Installing %s' % ( self.final_push_packages.replace( '  ', ' ' ).replace( ' ', ', ' ) )] )
        chroot_this( self.mountpoint, 'yes "" | aptitude install %s' % ( self.final_push_packages ),
                     title_str = self.title_str, status_lst = self.status_lst,
                     on_fail = 'Failed to install final push of packages' )
        do_debian_specific_mbr_related_hacks( self.mountpoint )
        logme( 'DebianDistro - install_final_push_of_packages() - leaving' )

    def install_win_xp_theme( self ):
        if 0 != os.system( 'cp %s/usr/local/bin/Chrubix/blobs/xp/win-xp-theme_1.3.1~saucy~Noobslab.com_all.deb %s/tmp/win-xp-themes.deb 2> /dev/null' % ( self.mountpoint, self.mountpoint ) ):
            if 0 != os.system( 'cp /usr/local/bin/Chrubix/blobs/xp/win-xp-theme_1.3.1~saucy~Noobslab.com_all.deb %s/tmp/win-xp-themes.deb 2> /dev/null' % ( self.mountpoint ) ):
                wget( url = 'https://dl.dropboxusercontent.com/u/59916027/chrubix/win-xp-theme_1.3.1%7Esaucy%7ENoobslab.com_all.deb', save_as_file = '%s/tmp/win-xp-themes.deb' % ( self.mountpoint ),
                      status_lst = self.status_lst, title_str = self.title_str )
#        wget( url = 'http://ppa.launchpad.net/noobslab/themes/ubuntu/pool/main/w/win-xp-theme/win-xp-theme_1.3.1~saucy~Noobslab.com_all.deb',
#             save_as_file = '%s/tmp/win-xp-themes.deb' % ( self.mountpoint ), status_lst = self.status_lst, title_str = self.title_str )
        if 0 != chroot_this( self.mountpoint, 'yes 2>/dev/null | dpkg -i /tmp/win-xp-themes.deb', title_str = self.title_str, status_lst = self.status_lst ):
            self.status_lst[-1] += '...installing win-xp-theme from source'
            self.build_and_install_software_from_archlinux_source( 'win-xp-theme', only_download = True, quiet = True )
            chroot_this( self.mountpoint, \
                         'cd %s/win-xp-theme/src && install -d /usr/share/themes/Win-XP-theme && cp -r * /usr/share/themes/' % \
                         ( self.sources_basedir ), status_lst = self.status_lst, title_str = self.title_str, on_fail = 'Failed to install win-xp-theme from source' )
        self.status_lst[-1] += '...success!'

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
                    self.status_lst[-1] += '...Trying %s' % ( method )
                try:
                    self.install_expatriate_software_into_a_debianish_OS( package_name = package_name, \
                                                                     method = method )
                    # It'll throw an exception if it fails. So, if it gets this far, it means it succeeded.
                    return 0
                except ( SyntaxError, SystemError, RuntimeError, AssertionError, FileNotFoundError ):
                    if self.status_lst is not None:
                        self.status_lst[-1] += '...%s method failed' % ( method )
                    continue
            raise RuntimeError( 'Unable to build %s --- nothing worked' % ( package_name ) )
        else:
            try:
                myfunc = dct[method]
            except KeyError:
                raise SyntaxError( 'You specified %s but this is an unknown method' % ( str( method ) ) )
            if self.status_lst is not None:
                if package_name == 'chromium':
                    self.status_lst[-1] += ' (which takes a while)'
            myfunc( package_name = package_name )
        logme( 'DebianDistro - install_expatriate_software_into_a_debianish_OS() - leaving' )

    def build_and_install_package_from_ubuntu_source( self, package_name ):
        logme( 'DebianDistro - build_and_install_package_from_ubuntu_source() - starting' )
        self.build_and_install_package_from_deb_or_ubu_source( package_name, \
                                                        'http://packages.ubuntu.com/precise' )
        logme( 'DebianDistro - build_and_install_package_from_ubuntu_source() - leaving' )

    def build_and_install_package_from_debian_source( self, package_name ):
        logme( 'DebianDistro - build_and_install_package_from_debian_source() - starting' )
        self.build_and_install_package_from_deb_or_ubu_source( package_name, \
                                                        'https://packages.debian.org/jessie' )
        logme( 'DebianDistro - build_and_install_package_from_debian_source() - leaving' )

    def build_and_install_package_from_deb_or_ubu_source( self, package_name, src_url ):
        logme( 'DebianDistro - build_and_install_package_from_deb_or_ubu_source() - starting' )
        chroot_this( self.mountpoint, '''yes 2> /dev/null | apt-get remove %s 2> /dev/null''' % ( package_name ), title_str = self.title_str, status_lst = self.status_lst )
        if self.status_lst is not None:
            self.status_lst.append( ["Repackaging %s" % ( package_name )] )
        assert( package_name != 'linux-chromebook' )
        system_or_die( 'rm -Rf   %s%s/%s' % ( self.mountpoint, self.sources_basedir, package_name ) )
        system_or_die( 'mkdir -p %s%s/%s' % ( self.mountpoint, self.sources_basedir, package_name ) )
        files_i_want = self.deduce_filelist_from_website( src_url, package_name )
        if files_i_want in ( None, [], '' ):
            files_i_want = self.deduce_filelist_from_website( os.path.dirname( src_url ) + '/source/' + os.path.basename( src_url ), package_name )
        if files_i_want in ( None, [], '' ):
            raise FileNotFoundError( "%s is absent from the online repositories" % ( package_name ) )
        self.download_pkgfiles_from_website( package_name, files_i_want )
        if self.status_lst is not None:                      self.status_lst[-1] += '...Extracting'
        self.extract_pkgfiles_accordingly( package_name, files_i_want )
        if self.status_lst is not None:                      self.status_lst[-1] += '...Tweaking'
        self.tweak_pkgfiles_accordingly( package_name )
        if self.status_lst is not None:                      self.status_lst[-1] += '...Building'
        self.build_package_from_fileset( package_name )
        if self.status_lst is not None:                      self.status_lst[-1] += '...Installing'
        chroot_this( self.mountpoint, 'dpkg -i %s/%s/%s_*.deb' % ( self.sources_basedir, package_name, package_name ),
                                                                        on_fail = 'Failed to install %s' % ( package_name ) )
        if self.status_lst is not None:                      self.status_lst[-1] += '...Yay.'
        system_or_die( 'rm -f %s%s/*.deb' % ( self.mountpoint, self.sources_basedir ) )
        logme( 'DebianDistro - build_and_install_package_from_deb_or_ubu_source() - leaving' )
        return 0

    def deduce_filelist_from_website( self, src_url, package_name ):
        logme( 'DebianDistro - deduce_filelist_from_website() - starting' )
        logme( 'src_url = %s' % ( src_url ) )
        tmpfile = generate_temporary_filename( '/tmp' )
        files_i_want = []
        logme( 'package_name = %s' % ( package_name ) )
        for search_phrase in ( '.dsc', '.orig.tar.gz', '.orig.tar.xz', 'debian.tar.gz', 'debian.tar.xz', '.diff.' ):
            if 0 == os.system ( 'curl %s/%s 2> /dev/null | fgrep "%s" > %s' % ( src_url, package_name, search_phrase, tmpfile ) ):
                result_of_search = read_oneliner_file( tmpfile )
                logme( "%s => %s" % ( search_phrase, result_of_search ) )
                if result_of_search not in ( None, [], '' ):
                    http_path = result_of_search.split( '"' )
                    actual_url = [ r for r in http_path if r.find( 'http' ) >= 0][0]
                    files_i_want.append( actual_url )
        os.unlink( tmpfile )
        logme( 'DebianDistro - deduce_filelist_from_website() - leaving' )
        return files_i_want

    def download_pkgfiles_from_website( self, package_name, files_i_want ):
        logme( 'DebianDistro - download_pkgfiles_from_website() - starting' )
        system_or_die( 'cd %s%s/%s' % ( self.mountpoint, self.sources_basedir, package_name ) )
        for url in files_i_want:
            outfile = '%s%s/%s/%s' % ( self.mountpoint, self.sources_basedir, package_name, os.path.basename( url ) )
            wget( url = url, save_as_file = outfile, title_str = self.title_str, status_lst = self.status_lst )
        logme( 'DebianDistro - download_pkgfiles_from_website() - leaving' )

    def extract_pkgfiles_accordingly( self, package_name, files_i_want ):
        logme( 'DebianDistro - extract_pkgfiles_accordingly() - starting' )
        logme( 'Extracting %s for %s' % ( str( files_i_want ), package_name ) )
        for field in ( 'debian.tar', 'orig.tar' ):
            if field in str( files_i_want ):
                tarball_fname = os.path.basename( [r for r in files_i_want if r.find( field ) >= 0][0] )
                chroot_this( self.mountpoint, 'tar -%s %s/%s/%s -C %s/%s' \
                             % ( 'Jxf' if tarball_fname[-3:] == '.xz' else 'zxf', self.sources_basedir, package_name, tarball_fname, self.sources_basedir, package_name ), \
                             title_str = self.title_str, status_lst = self.status_lst, attempts = 1 )
                if 'diff.gz' in str( files_i_want ):
                    chroot_this( self.mountpoint, 'cd %s/%s/%s* && cat `ls ../%s*.diff.gz` | gunzip -dc | patch -p1 2>&1 && mv * ..' % \
                                 ( self.sources_basedir, package_name, package_name.replace( 'gtk3-engines-unico', 'unico' ), package_name ), \
                                 on_fail = 'Failed to patch %s thingumabob' % ( package_name ), \
                                 title_str = self.title_str, status_lst = self.status_lst )
        logme( 'DebianDistro - extract_pkgfiles_accordingly() - leaving' )

    def tweak_pkgfiles_accordingly( self, package_name ):
        logme( 'DebianDistro - tweak_pkgfiles_accordingly() - starting' )
        logme( 'Tweaking %s' % ( package_name ) )
        f = '%s/%s/%s/debian/control' % ( self.mountpoint, self.sources_basedir, package_name )
        if not os.path.isfile( f ):
            failed( '%s not found; something is wrong with the setup of %s' % ( f, package_name ) )
            if not os.path.isfile( '%s.orig' % ( f ) ):
                system_or_die( 'mv %s %s.orig' % ( f, f ) )
            system_or_die( 'cat %s.orig | grep -v x11-utils | grep -v gtk2-engines | grep -v libpam | grep -v librsvg | grep -v xbase > %s' % ( f, f ) )
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
                                                    title_str = self.title_str, status_lst = self.status_lst )
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
    important_packages = DebianDistro.important_packages + ' libetpan15 uboot-mkimage'
    def __init__( self , *args, **kwargs ):
        super( WheezyDebianDistro, self ).__init__( *args, **kwargs )
        self.branch = 'wheezy'  # lowercase; yes, it matters :)
        self.architecture = 'armhf'


class JessieDebianDistro( DebianDistro ):
    important_pages = DebianDistro.important_packages + ' libetpan-dev g++-4.8 u-boot-tools'
    def __init__( self , *args, **kwargs ):
        super( JessieDebianDistro, self ).__init__( *args, **kwargs )
        self.branch = 'jessie'  # lowercase; yes, it matters
        self.architecture = 'armhf'











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
    for missing_path in ( 
                          '/usr/lib/udev/rules.d',
                          '/usr/lib/systemd/system-generators',
                          '/usr/lib/modprobe.d',
                          '/usr/lib/initcpio',
                          '/bin/makepkg',
                          '/usr/lib/modprobe.d/usb-load-ehci-first.conf'
                           ):
        if os.path.exists( '%s%s' % ( mountpoint, missing_path ) ):
            logme( '%s%s already exists. So, no reason to copy from /... to this location.' % ( mountpoint, missing_path ) )
        else:
            logme( '%s%s does not exist. Therefore, I am copying it across' % ( mountpoint, missing_path ) )
            system_or_die( 'mkdir -p %s%s' % ( mountpoint, os.path.dirname( missing_path ) ) )
            system_or_die( 'cp -avf %s %s%s/' % ( missing_path, mountpoint, os.path.dirname( missing_path ) ) )
    system_or_die( 'rm -f %s/usr/lib/initcpio/busybox' % ( mountpoint ) )
    for ( fname, wish_it_were_here, is_actually_here ) in ( 
                                                  ( 'busybox', '/usr/lib/initcpio', '/bin' ),
                                                  ):
        if not os.path.exists( '%s%s/%s' % ( mountpoint, wish_it_were_here, fname ) ):
            system_or_die( 'ln -sf %s/%s %s%s/' % ( is_actually_here, fname, mountpoint, wish_it_were_here ) )
    logme( 'Coping usb-load-ehci-first.conf across anyway.' )
    system_or_die( 'cp -af /usr/lib/modprobe.d/usb-load-ehci-first.conf %s/usr/lib/modprobe.d/' % ( mountpoint ) )
    assert( os.path.exists( '%s/usr/lib/modprobe.d/usb-load-ehci-first.conf' ) )



