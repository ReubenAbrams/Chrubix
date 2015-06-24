#!/usr/local/bin/python3
#
# stage2.py
# - stage two, which is called (and then self-deleted) if Evil Made Protection enabled


import sys
import os
import chrubix
from chrubix.utils import failed, logme, system_or_die


try:
    import urwid
except ImportError:
    os.system( 'easy_install urwid' )
    import urwid


if __name__ == "__main__":
    logme( 'stage2.py --- starting' )
    testval = urwid  # stop silly warning in Eclipse
    res = 0
    distro = chrubix.load_distro_record()
    distro.mountpoint = '/'
    # Rebuild etc. shouldn't be necessary. Stage 1 took care of all that jazz.
                # Rebuild kernel, mk*fs, cryptsetup  w/ KTHX and PHEZ enabled... but re-use the original kthx special code, please!
                # Build; install them (on myself)
    # mkfs.xfs (?) /dev/mmcblk1p2
    distro.update_status_with_newline( '*** STAGE 2 IS NOW RUNNING ***' )
    distro.update_status_with_newline( 'kernel dev = %s; spare dev = %s; root dev = %s' % ( distro.kernel_dev, distro.spare_dev, distro.root_dev ) )
    system_or_die( 'yes Y | mkfs -t ext4 %s' % ( distro.spare_dev ), status_lst = distro.status_lst, title_str = distro.title_str )
    # mount it
    system_or_die( 'mkdir -p /tmp/.p2' )
    system_or_die( 'mount %s /tmp/.p2' % ( distro.spare_dev ) )
#    distro.remove_all_junk()
    distro.update_status_with_newline( 'Building a squashfs and installing kernel' )
    distro.squash_OS( prefixpath = '/tmp/.p2' )
    # mksquashfs => p2
    # new kernel => p2
    # sign, store new kernel => p12/p1/whatever
    # unmount everything
    # reboot
#    os.system( 'sleep 4' )
    distro.update_status_with_newline( 'Exiting w/ retval=%d' % ( res ) )
    os.system( 'clear' )
    print( "Exiting w/ retval=%d" % ( res ) )
    os.system( 'umount /tmp/.p2' )
    print( "Type 'exit' to reboot\n" )
    os.system( 'bash' )
    os.system( 'sync;sync;sync; reboot' )
    os.system( 'sleep 10' )
    sys.exit( res )


