#!/usr/local/bin/python3
#
# stage2.py
# - stage two, which is called (and then self-deleted) if Evil Maid Protection enabled


import sys
import os
import chrubix
from chrubix.utils import failed, logme, system_or_die, chroot_this, read_oneliner_file, \
                            mount_sys_tmp_proc_n_dev, unmount_sys_tmp_proc_n_dev, poweroff_now


try:
    import urwid
except ImportError:
    os.system( 'easy_install urwid' )
    import urwid



if __name__ == "__main__":
    logme( 'stage2.py --- starting' )
    testval = urwid  # stop silly warning in Eclipse
    distro = chrubix.load_distro_record()
    distro.mountpoint = '/'
    # Rebuild etc. shouldn't be necessary. Stage 1 took care of all that jazz.
                # Rebuild kernel, mk*fs, cryptsetup  w/ KTHX and PHEZ enabled... but re-use the original kthx special code, please!
                # Build; install them (on myself)
    # mkfs.xfs (?) /dev/mmcblk1p2
    distro.update_status_with_newline( '*** STAGE 2 INSTALLING! ***' )
#    distro.update_status_with_newline( 'kernel dev = %s; spare dev = %s; root dev = %s' % ( distro.kernel_dev, distro.spare_dev, distro.root_dev ) )
    system_or_die( '%s %s %s' % ( distro.crypto_filesystem_mkfs_binary, distro.crypto_filesystem_formatting_options, distro.spare_dev ), status_lst = distro.status_lst, title_str = distro.title_str )
#    system_or_die( 'yes Y | mkfs -t ext4 %s' % ( distro.spare_dev ), status_lst = distro.status_lst, title_str = distro.title_str )
    # mount it
#    system_or_die( 'mkdir -p /tmp/.p2' )
#    system_or_die( 'mount %s /tmp/.p2' % ( distro.spare_dev ) )
#    distro.remove_all_junk()
    distro.update_status_with_newline( 'Building a squashfs and installing kernel' )
    res = distro.squash_OS( prefixpath = '/tmp/.p2' )  # Compress filesystem => sqfs. Also rebuild+install MBR, initramfs, etc.
    if res != 0:
        distro.update_status_with_newline( 'I failed abysmally.' )
        print( "FAILED ABYSMALLY.\n" )
        print( "Type 'exit' to reboot\n" )
        os.system( 'bash' )
    else:
        distro.update_status_with_newline( 'Done. Success!' )
        os.system( 'clear' )
        print( "Success! Exiting w/ retval=%d\n" % ( res ) )
        os.system( 'echo "Press <Enter> to reboot. Then, switch computer on and press <Ctrl>U to log in."; read line' )
    os.system( 'sync;sync;sync; umount /dev/* &> /dev/null; umount /dev/null* ' )
    os.system( 'echo 1 > /proc/sys/kernel/sysrq; echo b > /proc/sysrq-trigger' )
    os.system( 'sleep 5' )
    poweroff_now()
    sys.exit( res )
