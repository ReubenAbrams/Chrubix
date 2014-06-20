#!/usr/local/bin/python3
#
# poweroff_if_disk_removed.py
# - if the boot drive is unplugged, poweroff immediately

import sys
import os
import hashlib
from chrubix.utils import logme, read_oneliner_file, generate_temporary_filename, write_oneliner_file, poweroff_now
import subprocess


def home_drive_found_in_udev( home_drive ):
    found = False
    for this_entry in os.listdir( '/dev/disk/by-id' ) :
        full_path = '/dev/disk/by-id/' + this_entry
        real_path = os.path.realpath( full_path )
        if real_path.find( os.path.basename( home_drive ) ) >= 0:
#            print( 'Found home drive %s in uuid file %s => %s' % ( home_drive, full_path, real_path ) )
            found = True
            break
    return found


def run_a_binary( fname ):
    args = ( fname )
    popen = subprocess.Popen( args, stdout = subprocess.PIPE )
    popen.wait()
    output = popen.stdout.read()
    print( output )

if __name__ == "__main__":
    cmdline = read_oneliner_file( '/proc/cmdline' )
    if cmdline.find( 'cryptdevice=' ) >= 0:
        i = cmdline.find( 'cryptdevice=' )
        home_drive = cmdline[i:].split( '=' )[1].split( ':' )[0]
    else:
        i = cmdline.find( 'root=' )
        home_drive = cmdline[i:].split( '=' )[1].split( ' ' )[0]
    print( 'home_drive = %s' % ( home_drive ) )
    if not home_drive_found_in_udev( home_drive ):
        logme( 'Something is wrong with this program. I cannot find my home drive, even at the start...' )
        sys.exit( 1 )
    while True:
        os.system( 'sleep 1' )
        if not home_drive_found_in_udev( home_drive ):
            poweroff_now()
            sys.exit( 0 )
