#!/usr/local/bin/python3
#
# setvol.py
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
        self.volnow_fname = '%s/.volnow' % ( os.path.expanduser( "~" ) )
        super( VolumeControlWidget, self ).__init__()
        uic.loadUi( "ui/VolumeControl.ui", self )
        self.setupUi( self )
        self.setWindowFlags( Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.ToolTip )  # QtCore.Qt.Tool )
        self.show()
        self.raise_()
        self.setAttribute( Qt.WA_ShowWithoutActivating )
        self.setVolume( 0 )
        self.hide()
        self.old_vol = None
#        self.speaker_width = self.speakeron.width()
#        self.speaker_height = self.speakeron.height()
        QTimer.singleShot( TIME_BETWEEN_CHECKS, self.monitor )

    def monitor( self ):
        noof_checks = DELAY_BEFORE_HIDING / TIME_BETWEEN_CHECKS
        if self.cycles > noof_checks:
            self.hide()
#            print( 'hiding again' )
        else:
            self.cycles += 1
#        print( 'checking' )
        if os.path.exists( self.volnow_fname ):
            try:
                new_vol = int( read_oneliner_file( self.volnow_fname ) )
                if new_vol != self.old_vol:
                    self.setVolume( new_vol )
                    self.old_vol = new_vol
            except ValueError:
                logme( 'Bad entry for %s' % ( self.volnow_fname ) )
#        else:
#            print( 'Waiting for .volnow to appear' )
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
    app = QtGui.QApplication( sys.argv )
    window = VolumeControlWidget()
    screen = QtGui.QDesktopWidget().screenGeometry()
    window.setGeometry( screen.width() - window.width() - 1, screen.height() - 49, window.width(), window.height() )
    sys.exit( app.exec_() )


