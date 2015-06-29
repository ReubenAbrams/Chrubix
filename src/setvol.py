#!/usr/local/bin/python3
#
# main.py
# Main subroutine of the CHRUBIX project
#

import sys
import os
import hashlib
from chrubix.utils import logme, read_oneliner_file
from chrubix import save_distro_record, load_distro_record


try:
    from PyQt4.QtCore import QString
except ImportError:
    QString = str


TIME_BETWEEN_CHECKS = 200  # .2 seconds
DELAY_BEFORE_HIDING = 3000  # 3 seconds


from PyQt4.QtCore import SIGNAL, SLOT, pyqtSignature, Qt, QTimer
from PyQt4.Qt import QLineEdit, QPixmap
from PyQt4 import QtGui, uic
from PyQt4 import QtCore
# import resources_rc
from ui.ui_VolumeControl import Ui_VolumeControlWidget

# from testvol import VolumeControlWidget

class VolumeControlWidget( QtGui.QDialog, Ui_VolumeControlWidget ):
    def __init__( self ):
#        self._password = None
        self.cycles = 99
        super( VolumeControlWidget, self ).__init__()
        uic.loadUi( "ui/VolumeControl.ui", self )
        self.setupUi( self )
        self.setWindowFlags( self.windowFlags() | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint )
        self.show()
        self.raise_()
        self.setAttribute( Qt.WA_ShowWithoutActivating )
        self.setVolume( 0 )
        self.hide()
        self.speaker_width = self.speakeron.width()
        self.speaker_height = self.speakeron.height()
        QTimer.singleShot( TIME_BETWEEN_CHECKS, self.monitor )

    def monitor( self ):
        noof_checks = DELAY_BEFORE_HIDING / TIME_BETWEEN_CHECKS
        if self.cycles > noof_checks:
            self.hide()
#            print( 'hiding again' )
        else:
            self.cycles += 1
#        print( 'checking' )
        if os.path.exists( '/tmp/.volnow' ):
            new_vol = 0
            try:
                new_vol = int( read_oneliner_file( '/tmp/.volnow' ) )
            except ValueError:
                pass
            os.unlink( '/tmp/.volnow' )
            self.setVolume( new_vol )
        QTimer.singleShot( TIME_BETWEEN_CHECKS, self.monitor )


    def setVolume( self, vol ):
        print( 'setVolume(%d)' % ( vol ) )
        self.cycles = 0
        self.show()
#        if vol < 15:
#            self.speakeroff.resize( self.speaker_width, self.speaker_height )
#            self.speakeron.resize( 0, 0 )
#        else:
#            self.speakeron.resize( self.speaker_width, self.speaker_height )
#            self.speakeroff.resize( 0, 0 )
        self.progressBar.setValue( vol )
        self.update()
        self.repaint()
#        self.raise_()

    @pyqtSignature( "" )
    def closeEvent( self, event ):
        event.accept()
        sys.exit()


if __name__ == "__main__":
    logme( 'main.py ----- __main__' )
    if os.system( 'mount | grep /dev/mapper/encstateful &> /dev/null' ) == 0 \
    or os.system( 'mount | grep hfs &> /dev/null' ) == 0:
        # compile Qt Creator UI files into Python bindings
    #    os.system( "rm -f ui_AlarmistGreeter.py ui/ui_AlarmistGreeter.py qrc_resources.py" )
        os.system( 'export PATH=/opt/local/bin:$PATH' )
        logme( 'ui etc.' )
        for fname in [f for f in os.listdir( "ui" ) if f[-3:] == ".ui" and f[0] != "." ]:
            if not os.path.exists( 'ui/ui_%s.py' % ( fname[:-3] ) ):
                logme( '=> %s' % ( fname ) )
                os.system( "PATH=/opt/local/bin:$PATH pyuic4 -o ui/ui_" + fname[:-3] + ".py ui/" + fname[:-3] + ".ui" )
                print ( "Processing " + fname )
    if not os.path.exists( 'resources_rc.py' ):
        os.system( "PATH=/opt/local/bin:$PATH pyrcc4 -py3 -o resources_rc.py ui/resources.qrc" )
    app = QtGui.QApplication( sys.argv )
    window = VolumeControlWidget()
    screen = QtGui.QDesktopWidget().screenGeometry()
    window.setGeometry( screen.width() - window.width() - 1, screen.height() - 1, window.width(), window.height() )
    sys.exit( app.exec_() )


