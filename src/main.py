#!/usr/local/bin/python3
#
# main.py
# Main subroutine of the CHRUBIX project
#

import sys
import os
# import hashlib
from chrubix.utils import logme
# from chrubix import save_distro_record, load_distro_record


try:
    from PyQt4.QtCore import QString
except ImportError:
    QString = str

'''
If you call me from the command line of the ChromeOS Developer Mode, I'll process the
command-line parameters and probably install Linux on the SD card of your Chromebook.
'''
logme( '**************************** WELCOME TO CHRUBIX ****************************' )
if os.system( 'cat /proc/cmdline 2>/dev/null | fgrep root=/dev/dm-0 > /dev/null' ) == 0:
    from chrubix import exec_cli
    logme( 'Calling exec_cli()' )
    res = exec_cli( sys.argv )
    print( 'The Python portion of Chrubix is exiting now (res=%d)\n' % ( res ) )
    sys.exit( res )


if __name__ == "__main__":
    import gui
    gui.main()



