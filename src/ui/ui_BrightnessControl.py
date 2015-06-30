# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'ui/BrightnessControl.ui'
#
# Created: Tue Jun 30 10:31:54 2015
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

class Ui_BrightnessControlWidget(object):
    def setupUi(self, BrightnessControlWidget):
        BrightnessControlWidget.setObjectName(_fromUtf8("BrightnessControlWidget"))
        BrightnessControlWidget.resize(240, 19)
        self.progressBar = QtGui.QProgressBar(BrightnessControlWidget)
        self.progressBar.setGeometry(QtCore.QRect(20, 0, 211, 20))
        self.progressBar.setProperty("value", 0)
        self.progressBar.setObjectName(_fromUtf8("progressBar"))
        self.brightnesson = QtGui.QLabel(BrightnessControlWidget)
        self.brightnesson.setEnabled(False)
        self.brightnesson.setGeometry(QtCore.QRect(0, 0, 21, 21))
        self.brightnesson.setText(_fromUtf8(""))
        self.brightnesson.setPixmap(QtGui.QPixmap(_fromUtf8("brightness-up.png")))
        self.brightnesson.setScaledContents(True)
        self.brightnesson.setObjectName(_fromUtf8("brightnesson"))

        self.retranslateUi(BrightnessControlWidget)
        QtCore.QMetaObject.connectSlotsByName(BrightnessControlWidget)

    def retranslateUi(self, BrightnessControlWidget):
        BrightnessControlWidget.setWindowTitle(_translate("BrightnessControlWidget", "Form", None))

