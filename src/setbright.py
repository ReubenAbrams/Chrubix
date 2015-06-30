#!/usr/local/bin/python3
#
# setbright.py
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
from ui.ui_BrightnessControl import Ui_BrightnessControlWidget

# from testvol import VolumeControlWidget

class BrightnessControlWidget( QtGui.QDialog, Ui_BrightnessControlWidget ):
    def __init__( self ):
#        self._password = None
        self.cycles = 99
        super( BrightnessControlWidget, self ).__init__()
        uic.loadUi( "ui/BrightnessControl.ui", self )
        self.setupUi( self )
        self.setWindowFlags( Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.ToolTip )  # QtCore.Qt.Tool )
        self.show()
        self.raise_()
        self.setAttribute( Qt.WA_ShowWithoutActivating )
        self.setBrightness( 0 )
        self.hide()
#        self.speaker_width = self.speakeron.width()
#        self.speaker_height = self.speakeron.height()
        self.brightnesspath = None
        self.current_brightness = None
        QTimer.singleShot( TIME_BETWEEN_CHECKS, self.monitor )

    def monitor( self ):
        noof_checks = DELAY_BEFORE_HIDING / TIME_BETWEEN_CHECKS
        if self.cycles > noof_checks:
            self.hide()
#            print( 'hiding again' )
        else:
            self.cycles += 1
#        print( 'checking' )
        if self.current_brightness is None:
            self.brightnesspath = '%s/brightness' % ( read_oneliner_file( '/tmp/.brightness.path' ) )
            self.current_brightness = int ( read_oneliner_file( self.brightnesspath ) )
        new_brightness = int ( read_oneliner_file( self.brightnesspath ) )
        if self.current_brightness != new_brightness:
            self.current_brightness = new_brightness
            self.setBrightness( self.current_brightness )
        QTimer.singleShot( TIME_BETWEEN_CHECKS, self.monitor )


    def setBrightness( self, brig ):
        print( 'setBrightness(%d)' % ( brig ) )
        self.cycles = 0
        self.show()
#        if vol < 15:
#            self.speakeroff.resize( self.speaker_width, self.speaker_height )
#            self.speakeron.resize( 0, 0 )
#        else:
#            self.speakeron.resize( self.speaker_width, self.speaker_height )
#            self.speakeroff.resize( 0, 0 )
        self.progressBar.setValue( ( brig * 100 ) / 2800 )
        self.update()
        self.repaint()
#        self.raise_()

    @pyqtSignature( "" )
    def closeEvent( self, event ):
        event.accept()
        sys.exit()


if __name__ == "__main__":
    app = QtGui.QApplication( sys.argv )
    window = BrightnessControlWidget()
    screen = QtGui.QDesktopWidget().screenGeometry()
    window.setGeometry( screen.width() - window.width() * 2 - 9, screen.height() - 49, window.width(), window.height() )
    sys.exit( app.exec_() )


