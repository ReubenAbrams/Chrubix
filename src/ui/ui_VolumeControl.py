# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'ui/VolumeControl.ui'
#
# Created: Mon Jun 29 14:06:00 2015
#      by: PyQt4 UI code generator 4.10.4
#
# WARNING! All changes made in this file will be lost!

from PyQt4 import QtCore, QtGui

try:
    _fromUtf8 = QtCore.QString.fromUtf8
except AttributeError:
    def _fromUtf8(s):
        return s

try:
    _encoding = QtGui.QApplication.UnicodeUTF8
    def _translate(context, text, disambig):
        return QtGui.QApplication.translate(context, text, disambig, _encoding)
except AttributeError:
    def _translate(context, text, disambig):
        return QtGui.QApplication.translate(context, text, disambig)

class Ui_VolumeControlWidget(object):
    def setupUi(self, VolumeControlWidget):
        VolumeControlWidget.setObjectName(_fromUtf8("VolumeControlWidget"))
        VolumeControlWidget.resize(240, 19)
        self.progressBar = QtGui.QProgressBar(VolumeControlWidget)
        self.progressBar.setGeometry(QtCore.QRect(20, 0, 211, 20))
        self.progressBar.setProperty("value", 0)
        self.progressBar.setObjectName(_fromUtf8("progressBar"))
        self.speakeron = QtGui.QLabel(VolumeControlWidget)
        self.speakeron.setEnabled(False)
        self.speakeron.setGeometry(QtCore.QRect(0, 0, 21, 21))
        self.speakeron.setText(_fromUtf8(""))
        self.speakeron.setPixmap(QtGui.QPixmap(_fromUtf8("music_on-512.png")))
        self.speakeron.setScaledContents(True)
        self.speakeron.setObjectName(_fromUtf8("speakeron"))

        self.retranslateUi(VolumeControlWidget)
        QtCore.QMetaObject.connectSlotsByName(VolumeControlWidget)

    def retranslateUi(self, VolumeControlWidget):
        VolumeControlWidget.setWindowTitle(_translate("VolumeControlWidget", "Form", None))

