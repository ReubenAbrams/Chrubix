#!/usr/local/bin/python3
#
# archlinux.py


from chrubix.distros import Distro
from chrubix.utils import failed, system_or_die, chroot_this, wget, logme, do_a_sed
import os


# FIXME: paman and padevchooser are deprecated
class ArchlinuxDistro( Distro ):
    important_packages = Distro.important_packages + ' \
cgpt xz mkinitcpio mutagen libconfig festival-us libxpm uboot-mkimage dtc mythes-en \
mesa pyqt gptfdisk bluez-libs alsa-plugins acpi sdl libcanberra perl-xml-parser \
libnotify talkfilters java-runtime libxmu apache-ant junit zbar python2-setuptools python2-pip \
twisted python2-yaml python2-distutils-extra python2-gobject python2-cairo python2-poppler python2-pdfrw \
bcprov gtk-engine-unico gtk-engine-murrine gtk-engines xorg-fonts xorg-font-utils xorg-fonts-encodings \
libreoffice-en-US libreoffice-common libreoffice-gnome libxfixes python2-pysqlite \
xorg-server xorg-xinit xf86-input-synaptics xf86-video-fbdev xf86-video-armsoc xlockmore \
mate mate-themes-extras mate-nettool mate-mplayer mate-accountsdialog python2-pysqlite gtk2-perl \
xorg-server-utils xorg-xmessage librsvg icedtea-web-java7 gconf hunspell-en chromium thunderbird windowmaker \
'
    install_from_AUR = 'ttf-ms-fonts gtk-theme-adwaita-x win-xp-theme wmsystemtray python2-pyptlib hachoir-core hachoir-parser mat obfsproxy java-service-wrapper i2p'  # pulseaudio-ctl pasystray-git ssss florence
    final_push_packages = Distro.final_push_packages + ' lxdm network-manager-applet'

    def __init__( self , *args, **kwargs ):
        super( ArchlinuxDistro, self ).__init__( *args, **kwargs )
        self.name = 'archlinux'
        self.architecture = 'armv7h'
        self.list_of_mkfs_packages = ( 'btrfs-progs', 'jfsutils', 'xfsprogs' )
        self.typical_install_duration = 14000

    def install_barebones_root_filesystem( self ):
        logme( 'ArchlinuxDistro - install_barebones_root_filesystem() - starting' )
#        wget( url = 'http://us.mirror.archlinuxarm.org/os/ArchLinuxARM-chromebook-latest.tar.gz', \
        os.system( 'umount %s/dev &>/dev/null' % ( self.mountpoint ) )
        wget( url = 'https://dl.dropboxusercontent.com/u/59916027/chrubix/skeletons/ArchLinuxARM-chromebook-latest.tar.gz', \
                                                extract_to_path = self.mountpoint, decompression_flag = 'z', \
                                                title_str = self.title_str, status_lst = self.status_lst )
        return 0

    def install_locale( self ):
        logme( 'ArchlinuxDistro - install_locale() - starting' )
#       chroot_this( self.mountpoint, 'yes 2> /dev/null | pacman -S locales locales-all', title_str = self.title_str, status_lst = self.status_lst ):
        self.do_generic_locale_configuring()

    def install_kernel_and_mkfs ( self ):
        # Technically, this won't install Linux-latest, which wasn't built with makepkg's help anyway. However, it WILL install
        # 3.4.0-ARCH (built w/ makepkg). Two kernels wait in PKGBUILDs/ore: one in linux-latest, the other in linux-chromebook.
        logme( 'ArchlinuxDistro - install_kernel_and_mkfs() - starting' )
        chroot_this( self.mountpoint, r'yes "" 2>/dev/null | pacman -U `find %s | grep -x ".*\.tar\.xz"`' % ( self.sources_basedir ), title_str = self.title_str, status_lst = self.status_lst )
        if self.use_latest_kernel:
            chroot_this( self.mountpoint, 'cd %s/linux-latest && make install && make modules_install' % ( self.sources_basedir ),
                         title_str = self.title_str, status_lst = self.status_lst,
                         on_fail = "Failed to install the standard ChromeOS kernel and/or modules" )
        self.status_lst[-1] += '...kernel installed.'


    def install_package_manager_tweaks( self ):
        logme( 'ArchlinuxDistro - install_package_manager_tweaks() - starting' )
        do_a_sed( '%s/etc/pacman.d/mirrorlist' % ( self.mountpoint ), '#.*Server =', 'Server =' )

    def update_and_upgrade_all( self ):
        logme( 'ArchlinuxDistro - update_and_upgrade_all() - starting' )
        system_or_die( 'rm -f %s/var/lib/pacman/db.lck; sync; sync; sync' % ( self.mountpoint ) )
        chroot_this( self.mountpoint, r'yes "" 2>/dev/null | pacman -Sy', "Failed to update OS" , attempts = 5, title_str = self.title_str, status_lst = self.status_lst )
        chroot_this( self.mountpoint, r'yes "" 2>/dev/null | pacman -Syu', "Failed to upgrade OS", attempts = 5, title_str = self.title_str, status_lst = self.status_lst )

    def install_important_packages( self ):
        logme( 'ArchlinuxDistro - install_important_packages() - starting' )
        packages_lst = [ r for r in self.important_packages.split( ' ' ) if r != '']
        failed_packages = ''
        list_of_groups = [ packages_lst[i:i + self.package_group_size] for i in range( 0, len( packages_lst ), self.package_group_size ) ]
        for lst in list_of_groups:
            s = ''.join( [r + ' ' for r in lst] )
            attempts = 0
            while attempts < 2 and 0 != chroot_this( self.mountpoint, 'yes "" 2>/dev/null | pacman -S --needed ' + s, title_str = self.title_str, status_lst = self.status_lst ):
                system_or_die( 'rm -f %s/var/lib/pacman/db.lck; sync; sync; sync; sleep 1' % ( self.mountpoint ) )
                self.update_and_upgrade_all()
                system_or_die( 'sync; sync; sync; sleep 1' )
                attempts += 1
            if attempts == 2:
                for pkg in lst:
                    if 0 != chroot_this( self.mountpoint, 'yes "" 2>/dev/null | pacman -S --needed ' + pkg, title_str = self.title_str, status_lst = self.status_lst ):
                        failed_packages += ' ' + pkg
            logme( 'Installed%s OK' % ( ''.join( [' ' + r for r in lst] ) ) )
            self.status_lst[-1] += '.'
#            self.status_lst[-1] += ' %d%%' % ( progress * 100 // len( packages_lst ) )
        self.status_lst[-1] += 'installed.'
        if failed_packages != '':
            self.status_lst[-1] += [ ' I failed to install%s, however.' % ( failed_packages )]
        system_or_die( 'rm -Rf %s/var/cache/apt/archives/*' % ( self.mountpoint ) )

#    def download_kernel_source( self ):  # This also downloads all the other PKGBUILDs (for btrfs-progs, jfsutils, etc.)
#        logme( 'ArchlinuxDistro - download_kernel_source() - starting' )
#        chroot_this( self.mountpoint, 'cd %s && git clone git://github.com/archlinuxarm/PKGBUILDs.git' % ( self.ryo_tempdir ), \
#                             on_fail = "Failed to git clone kernel source", title_str = self.title_str, status_lst = self.status_lst )
#        self.download_package_source( os.path.basename( self.kernel_src_basedir ), ( 'PKGBUILD', ) )

    def download_mkfs_sources( self ):
        logme( 'ArchlinuxDistro - download_mkfs_sources() - starting' )
        assert( self.list_of_mkfs_packages[0].find( 'btrfs' ) >= 0 )
        assert( self.list_of_mkfs_packages[1].find( 'jfs' ) >= 0 )
        assert( self.list_of_mkfs_packages[2].find( 'xfs' ) >= 0 )
        self.download_package_source( self.list_of_mkfs_packages[0], ( 'PKGBUILD', 'btrfs-progs.install', 'initcpio-hook-btrfs', 'initcpio-install-btrfs', '01-fix-manpages.patch' ) )
        self.download_package_source( self.list_of_mkfs_packages[1], ( 'PKGBUILD', 'inttypes.patch' ) )
        self.download_package_source( self.list_of_mkfs_packages[2], ( 'PKGBUILD', ) )

    def download_package_source( self, package_name, filenames_lst = None ):
        logme( 'ArchlinuxDistro - download_package_source() - starting' )
#        self.status_lst.append( [ "Downloading %s package into %s OS" % ( package_name, self.name ) ] )
        system_or_die( 'mkdir -p %s/%s/%s' % ( self.mountpoint, self.sources_basedir, package_name ) )
        os.chdir( '%s/%s/%s' % ( self.mountpoint, self.sources_basedir, package_name ) )
        if os.path.isfile( '%s/%s/%s/PKGBUILD' % ( self.mountpoint, self.sources_basedir, package_name ) ):
            self.status_lst[-1] += ''  # += "."  # ..Still working"  # No need to download anything. We have PKGBUILD already.
        elif filenames_lst in ( None, [] ):
            url = 'aur.archlinux.org/packages/%s/%s/%s.tar.gz' % ( package_name[:2], package_name, package_name )
            wget( url = url, extract_to_path = '%s/%s' % ( self.mountpoint, self.sources_basedir ), quiet = True , title_str = self.title_str, status_lst = self.status_lst )
        else:
            for fname in filenames_lst:
                file_to_download = '%s/%s/%s/%s' % ( self.mountpoint, self.sources_basedir, package_name, fname )
                try:
                    os.unlink( file_to_download )
                except FileNotFoundError:
                    pass
                wget( url = 'http://projects.archlinux.org/svntogit/packages.git/plain/trunk/%s?h=packages/%s' \
                                 % ( fname, package_name ), save_as_file = file_to_download, attempts = 20,
                                 quiet = True, title_str = self.title_str, status_lst = self.status_lst )
        system_or_die( 'mv PKGBUILD PKGBUILD.ori' )
        system_or_die( r"cat PKGBUILD.ori | sed s/march/phr34k/ | sed s/\'libutil-linux\'// | sed s/\'java-service-wrapper\'// | sed s/arch=\(.*/arch=\(\'%s\'\)/ | sed s/phr34k/march/ > PKGBUILD" % ( self.architecture ) )
        chroot_this( self.mountpoint, 'cd %s/%s && makepkg --skipchecksums --asroot --nobuild -f' % ( self.sources_basedir, package_name ), 'Failed to download %s' % ( package_name ), \
                                    title_str = self.title_str, status_lst = self.status_lst, attempts = 2 )
        return 0

    def build_package( self, source_pathname ):
        logme( 'ArchlinuxDistro - build_package() - starting' )
        package_name = os.path.basename( source_pathname )
        package_path = os.path.dirname( source_pathname )
        str_to_add = "Kernel & rootfs" if package_name == 'linux-chromebook' else "%s" % ( package_name )
        self.status_lst.append( [ str_to_add ] )
        chroot_this( self.mountpoint, 'cd %s && makepkg --skipchecksums --asroot --noextract -f ' % ( source_pathname ), \
                                "Failed to chroot make %s within %s" % ( package_name, package_path ),
                                title_str = self.title_str, status_lst = self.status_lst )
        self.status_lst[-1] += '...Built.'

    def configure_distrospecific_tweaks( self ):
        logme( 'ArchlinuxDistro - configure_distrospecific_tweaks() - starting' )
        self.status_lst.append( ['Installing distro-specific tweaks'] )
        friendly_list_of_packages_to_exclude = ''.join( r + ' ' for r in self.list_of_mkfs_packages ) + os.path.basename( self.kernel_src_basedir )
        do_a_sed( '%s/etc/pacman.conf' % ( self.mountpoint ), '#.*IgnorePkg.*', 'IgnorePkg = %s' % ( friendly_list_of_packages_to_exclude ) )
        logme( 'FYI, ArchLinux has no distro-specific post-install tweaks at present' )
        self.status_lst[-1] += '...tweaked.'

    def downgrade_systemd_if_necessary( self, bad_verno ):
        if bad_verno == None or 0 == chroot_this( self.mountpoint, 'pacman -Q systemd | fgrep "systemd %s"' % ( bad_verno ) ):
            wget( url = 'https://dl.dropboxusercontent.com/u/59916027/chrubix/systemd-212-3-armv7h.pkg.tar.xz',
#            wget( url = 'http://rollback.adminempire.com/2014/06/03/armv7h/core/systemd-212-3-armv7h.pkg.tar.xz',
                            save_as_file = '%s/tmp/systemd-212-3-armv7h.pkg.tar.xz' % ( self.mountpoint ),
                            status_lst = self.status_lst, title_str = self.title_str )
            chroot_this( self.mountpoint, 'yes "" | pacman -U /tmp/systemd-212-3-armv7h.pkg.tar.xz',
                            status_lst = self.status_lst, title_str = self.title_str,
                            on_fail = 'Failed to downgrade systemd' )
            self.status_lst[-1] += ' (downgraded SystemD)'

    def install_final_push_of_packages( self ):
        logme( 'ArchlinuxDistro - install_final_push_of_packages() - starting' )
        self.status_lst.append( 'Installed' )
        for my_fname in ( 'ssss-0.5-3-armv7h.pkg.tar.xz', 'florence-0.6.2-1-armv7h.pkg.tar.xz' ):
            try:
                system_or_die( 'cp /usr/local/bin/Chrubix/blobs/apps/%s /%s/tmp/' % ( my_fname, self.mountpoint ) )
            except RuntimeError:
                wget( url = 'https://dl.dropboxusercontent.com/u/59916027/chrubix/%s' % ( my_fname ),
                save_as_file = '%s/tmp/%s' % ( self.mountpoint, my_fname ),
                status_lst = self.status_lst,
                title_str = self.title_str )
            if 0 == chroot_this( self.mountpoint, 'yes "" | pacman -U /tmp/%s' % ( my_fname ) ):
                self.status_lst[-1] += ' ' + my_fname.split( '-' )[0]
            else:
                failed( 'Failed to install ' + my_fname.split( '-' )[0] )
#        perl-cpan-meta-check perl-class-load-xs perl-eval-closure perl-mro-compat perl-package-depreciationmanager perl-sub-name perl-task-weaken \
# perl-test-checkdeps perl-test-without-module perl-moose
        failed_pkgs = self.install_from_AUR
        attempts = 0
        while failed_pkgs != '' and attempts < 5:
            self.update_and_upgrade_all()
            attempts += 1
            packages_to_install = failed_pkgs
            failed_pkgs = ''
            for pkg_name in packages_to_install.split( ' ' ):
                if pkg_name in ( None, '', ' ' ):
                    continue
                try:
                    self.build_and_install_software_from_archlinux_source( pkg_name, quiet = True )
                    self.status_lst[-1] += ' %s' % ( pkg_name )
                except RuntimeError:
                    failed_pkgs += ' %s' % ( pkg_name )
        self.status_lst[-1] += '...OK.'
        if failed_pkgs != '':
            self.status_lst.append( ['Warning - failed to install%s' % ( failed_pkgs )] )
        self.status_lst[-1] += ' etc. '
#        self.status_lst.append( ['Installing %s' % ( self.final_push_packages.replace( '  ', ' ' ).replace( ' ', ', ' ) )] )
        chroot_this( self.mountpoint, 'yes "" 2>/dev/null | pacman -S --needed %s' % ( self.final_push_packages ), title_str = self.title_str, status_lst = self.status_lst,
                     on_fail = 'Failed to install final push of packages', attempts = 20 )
        self.update_and_upgrade_all()
        self.downgrade_systemd_if_necessary( None )  # '213-5' )
        self.status_lst[-1] += '...complete.'

    def configure_boot_process( self ):
        logme( 'configure_boot_process() --- No further action need be taken.' )
