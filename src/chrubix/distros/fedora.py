#!/usr/local/bin/python3
#
# fedora.py
#


from chrubix.distros import Distro
from chrubix.utils import wget, system_or_die, unmount_sys_tmp_proc_n_dev, mount_sys_tmp_proc_n_dev, logme, chroot_this, \
                        failed

class FedoraDistro( Distro ):
    def __init__( self ):
        super( FedoraDistro, self ).__init__()
        self.name = 'fedora'
        self.architecture = 'arm'
        assert( self.important_packages not in ( '', None ) )
        self.final_push_packages += ' wmsystemtray lxdm network-manager-gnome'
        self.important_packages += ' \
xf86-video-fbdev cgpt xz mkinitcpio xf86-video-armsoc exo xf86-input-synaptics libxpm dtc xmlto xorg-server festival-us \
xorg-xmessage mesa pyqt gptfdisk xlockmore bluez-libs alsa-plugins acpi xorg-xinit sdl libcanberra icedtea-web-java7 \
libnotify talkfilters chromium xorg-server-utils java-runtime libxmu libxfixes apache-ant junit uboot-mkimage'

    def install_barebones_root_filesystem( self ):
        logme( 'FedoraDistro - install_barebones_root_filesystem() - starting' )
        unmount_sys_tmp_proc_n_dev( self.mountpoint )
        wget( url = 'http://parasense.fedorapeople.org/remixes/chromebook/f19-chromebook-MATE.img.xz',
                                        extract_to_path = self.mountpoint, decompression_flag = 'J',
                                        title_str = self.title_str, status_lst = self.status_lst )
        mount_sys_tmp_proc_n_dev( self.mountpoint )
        failed( 'Exiting here for test porpoises' )
        return 0

    def install_final_push_of_packages( self ):  # See https://twiki.grid.iu.edu/bin/view/Documentation/Release3/YumRpmBasics
        logme( 'Fedora - install_final_push_of_packages() - starting' )
#        self.build_and_install_software_from_archlinux_source( 'wmsystemtray' )
        self.status_lst.append( ['Installing %s' % ( self.final_push_packages.replace( '  ', ' ' ).replace( ' ', ', ' ) )] )
        res = 999
        attempts = 5
        while res != 0 and attempts > 0:
            attempts -= 1
            res = chroot_this( self.mountpoint, 'yes 2>/dev/null | yum install %s' % ( self.final_push_packages ), title_str = self.title_str, status_lst = self.status_lst )
            if res != 0:
                system_or_die( 'rm -f %s/var/lib/pacman/db.lck; sync; sync; sync; sleep 3' % ( self.mountpoint ) )
        assert( attempts > 0 )
#        self.status_lst[-1] += '...Done.'

    def configure_distrospecific_tweaks( self ):
        self.status_lst.append( ['configure_distrospecific_tweaks() --- to be written'] )

    def download_mkfs_sources( self ):
        self.status_lst.append( ['download_mkfs_sources() --- to be written'] )

    def build_package( self, source_pathname ):
        failed( "build_package(%s) --- please define in subclass" % ( source_pathname ) )

    def install_package_manager_tweaks( self ):
        failed( "please define in subclass. Don't forget! Exclude jfsprogs, btrfsprogs, xfsprogs, linux kernel." )

    def update_and_upgrade_all( self ):
        failed( "please define in subclass" )

    def install_important_packages( self ):
        failed( "please define in subclass" )

    def install_kernel_and_mkfs( self ):
        failed( 'please define in subclass' )

    def build_mkfs_n_kernel_for_OS_w_preexisting_PKGBUILDs( self ):
        failed( "please define in subclass" )

class NineteenFedoraDistro( FedoraDistro ):
    def __init__( self ):
        super( NineteenFedoraDistro, self ).__init__()
        self.branch = '19'

