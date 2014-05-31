# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'ui/TestDlg.ui'
#
# Created: Sat May 31 00:17:19 2014
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

class Ui_TestDlg(object):
    def setupUi(self, TestDlg):
        TestDlg.setObjectName(_fromUtf8("TestDlg"))
        TestDlg.resize(400, 300)
        self.buttonBox = QtGui.QDialogButtonBox(TestDlg)
        self.buttonBox.setGeometry(QtCore.QRect(290, 20, 81, 241))
        self.buttonBox.setOrientation(QtCore.Qt.Vertical)
        self.buttonBox.setStandardButtons(QtGui.QDialogButtonBox.Cancel|QtGui.QDialogButtonBox.Ok)
        self.buttonBox.setObjectName(_fromUtf8("buttonBox"))

        self.retranslateUi(TestDlg)
        QtCore.QObject.connect(self.buttonBox, QtCore.SIGNAL(_fromUtf8("accepted()")), TestDlg.accept)
        QtCore.QObject.connect(self.buttonBox, QtCore.SIGNAL(_fromUtf8("rejected()")), TestDlg.reject)
        QtCore.QMetaObject.connectSlotsByName(TestDlg)

    def retranslateUi(self, TestDlg):
        TestDlg.setWindowTitle(_translate("TestDlg", "Dialog", None))

