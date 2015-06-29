/********************************************************************************
** Form generated from reading UI file 'volctrlwidget.ui'
**
** Created by: Qt User Interface Compiler version 5.4.1
**
** WARNING! All changes made in this file will be lost when recompiling UI file!
********************************************************************************/

#ifndef UI_VOLCTRLWIDGET_H
#define UI_VOLCTRLWIDGET_H

#include <QtCore/QVariant>
#include <QtWidgets/QAction>
#include <QtWidgets/QApplication>
#include <QtWidgets/QButtonGroup>
#include <QtWidgets/QGridLayout>
#include <QtWidgets/QHeaderView>
#include <QtWidgets/QProgressBar>
#include <QtWidgets/QWidget>

QT_BEGIN_NAMESPACE

class Ui_VolCtrlWidget
{
public:
    QWidget *gridLayoutWidget;
    QGridLayout *gridLayout;
    QProgressBar *progressBar;

    void setupUi(QWidget *VolCtrlWidget)
    {
        if (VolCtrlWidget->objectName().isEmpty())
            VolCtrlWidget->setObjectName(QStringLiteral("VolCtrlWidget"));
        VolCtrlWidget->resize(349, 202);
        gridLayoutWidget = new QWidget(VolCtrlWidget);
        gridLayoutWidget->setObjectName(QStringLiteral("gridLayoutWidget"));
        gridLayoutWidget->setGeometry(QRect(60, 40, 160, 61));
        gridLayout = new QGridLayout(gridLayoutWidget);
        gridLayout->setSpacing(6);
        gridLayout->setContentsMargins(11, 11, 11, 11);
        gridLayout->setObjectName(QStringLiteral("gridLayout"));
        gridLayout->setContentsMargins(0, 0, 0, 0);
        progressBar = new QProgressBar(gridLayoutWidget);
        progressBar->setObjectName(QStringLiteral("progressBar"));
        progressBar->setValue(24);

        gridLayout->addWidget(progressBar, 0, 0, 1, 1);


        retranslateUi(VolCtrlWidget);

        QMetaObject::connectSlotsByName(VolCtrlWidget);
    } // setupUi

    void retranslateUi(QWidget *VolCtrlWidget)
    {
        VolCtrlWidget->setWindowTitle(QApplication::translate("VolCtrlWidget", "VolCtrlWidget", 0));
    } // retranslateUi

};

namespace Ui {
    class VolCtrlWidget: public Ui_VolCtrlWidget {};
} // namespace Ui

QT_END_NAMESPACE

#endif // UI_VOLCTRLWIDGET_H
