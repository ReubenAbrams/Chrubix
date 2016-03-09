#!/usr/local/bin/python3

'''simple brightness controller for Chrubix

'''

import sys
import os
# import hashlib
from chrubix.utils import logme, read_oneliner_file
# from chrubix import save_distro_record, load_distro_record


try:
    from PyQt4.QtCore import QString
except ImportError:
    QString = str


TIME_BETWEEN_CHECKS = 200  # .2 seconds
DELAY_BEFORE_HIDING = 3000  # 3 seconds


from PyQt4.QtCore import  pyqtSignature, Qt, QTimer
# from PyQt4.Qt import QLineEdit, QPixmap
from PyQt4 import QtGui  # , uic
# from PyQt4 import QtCore
# import resources_rc
from ui.ui_BrightnessControl import Ui_BrightnessControlWidget


class BrightnessControlWidget( QtGui.QDialog, Ui_BrightnessControlWidget ):
    def __init__( self ):
#        self._password = None
        self.cycles = 99
        self.brightnow_fname = '%s/.brightnow' % ( os.path.expanduser( "~" ) )
        super( BrightnessControlWidget, self ).__init__()
        self.setupUi( self )
        self.setWindowFlags( Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.ToolTip )  # QtCore.Qt.Tool )
        self.show()
        self.raise_()
        self.setAttribute( Qt.WA_ShowWithoutActivating )
#        self.setBrightness( 0 )
        self.hide()
        self.old_brightness = None
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
        if os.path.exists( self.brightnow_fname ):
            try:
                new_brightness = int( read_oneliner_file( self.brightnow_fname ) )
#                logme( 'curr bri = %d' % ( new_brightness ) )
                if new_brightness != self.old_brightness:
                    self.setBrightness( new_brightness )
                    self.old_brightness = new_brightness
#                    logme( 'Updating brightness to %d' % ( new_brightness ) )
            except ValueError:
                logme( 'Bad entry for %s' % ( self.brightnow_fname ) )
#        else:
#            print( 'Waiting for .brightnow to appear' )
        QTimer.singleShot( TIME_BETWEEN_CHECKS, self.monitor )


    def setBrightness( self, brightness ):
#        logme( 'setBrightness(%d)' % ( brightness ) )
        self.cycles = 0
        self.show()
        self.progressBar.setValue( brightness )
        self.update()
        self.repaint()
#        self.raise_()

    @pyqtSignature( "" )
    def closeEvent( self, event ):
        event.accept()
        sys.exit()


#------------------------------------------------------------------------------------------------------------------------------------


if __name__ == "__main__":
    app = QtGui.QApplication( sys.argv )
    window = BrightnessControlWidget()
    screen = QtGui.QDesktopWidget().screenGeometry()
    window.setGeometry( screen.width() - window.width() * 2 - 2, screen.height() - 49, window.width(), window.height() )
    sys.exit( app.exec_() )


