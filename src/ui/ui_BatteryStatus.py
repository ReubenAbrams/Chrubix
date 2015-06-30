# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'ui/BatteryStatus.ui'
#
# Created: Mon Jun 29 15:49:21 2015
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

class Ui_BatteryStatusWidget(object):
    def setupUi(self, BatteryStatusWidget):
        BatteryStatusWidget.setObjectName(_fromUtf8("BatteryStatusWidget"))
        BatteryStatusWidget.resize(591, 242)
        self.textBrowserBatty = QtGui.QTextBrowser(BatteryStatusWidget)
        self.textBrowserBatty.setGeometry(QtCore.QRect(0, 0, 291, 241))
        font = QtGui.QFont()
        font.setFamily(_fromUtf8("Courier"))
        font.setPointSize(10)
        font.setBold(True)
        font.setWeight(75)
        self.textBrowserBatty.setFont(font)
        self.textBrowserBatty.setObjectName(_fromUtf8("textBrowserBatty"))
        self.textBrowserMains = QtGui.QTextBrowser(BatteryStatusWidget)
        self.textBrowserMains.setGeometry(QtCore.QRect(300, 0, 291, 241))
        font = QtGui.QFont()
        font.setFamily(_fromUtf8("Courier"))
        font.setPointSize(10)
        font.setBold(True)
        font.setWeight(75)
        self.textBrowserMains.setFont(font)
        self.textBrowserMains.setObjectName(_fromUtf8("textBrowserMains"))

        self.retranslateUi(BatteryStatusWidget)
        QtCore.QMetaObject.connectSlotsByName(BatteryStatusWidget)

    def retranslateUi(self, BatteryStatusWidget):
        BatteryStatusWidget.setWindowTitle(_translate("BatteryStatusWidget", "Form", None))
        self.textBrowserBatty.setHtml(_translate("BatteryStatusWidget", "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0//EN\" \"http://www.w3.org/TR/REC-html40/strict.dtd\">\n"
"<html><head><meta name=\"qrichtext\" content=\"1\" /><style type=\"text/css\">\n"
"p, li { white-space: pre-wrap; }\n"
"</style></head><body style=\" font-family:\'Courier\'; font-size:10pt; font-weight:600; font-style:normal;\">\n"
"<p style=\"-qt-paragraph-type:empty; margin-top:0px; margin-bottom:0px; margin-left:0px; margin-right:0px; -qt-block-indent:0; text-indent:0px; font-size:14pt; font-weight:400;\"><br /></p></body></html>", None))

