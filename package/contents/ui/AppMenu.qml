import QtQuick 2.2
import QtQuick.Layouts 1.1
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.components 2.0 as PlasmaComponents

Item {
    id: appmenu
    anchors.fill: parent

    property bool appmenuEnabled: plasmoid.configuration.appmenuEnabled
    property bool appmenuNextToButtons: plasmoid.configuration.appmenuNextToButtons
    property bool appmenuFillHeight: plasmoid.configuration.appmenuFillHeight
    property bool appmenuFontBold: plasmoid.configuration.appmenuFontBold
    property bool appmenuDoNotHide: plasmoid.configuration.appmenuDoNotHide
    property bool appmenuEnabledAndNonEmpty: appmenuEnabled && appMenuModel !== null && appMenuModel.menuAvailable
    property bool appmenuOpened: appmenuEnabled && plasmoid.nativeInterface.currentIndex > -1
    property var appMenuModel: null

    property bool appmenuButtonsOffsetEnabled: !buttonsStandalone && appmenuNextToButtons && childrenRect.width > 0
    property double appmenuOffsetWidth: visible && appmenuNextToIconAndText && !appmenuSwitchSidesWithIconAndText
                                                ? appmenu.childrenRect.width + (appmenuButtonsOffsetEnabled ? controlButtonsArea.width : 0) + appmenuSideMargin*2
                                                : 0

    visible: appmenuEnabledAndNonEmpty && !noWindowActive && (appmenuDoNotHide || mouseHover || appmenuOpened)

    GridLayout {
        id: buttonGrid

        Layout.minimumWidth: implicitWidth
        Layout.minimumHeight: implicitHeight

        flow: GridLayout.LeftToRight
        rowSpacing: 0
        columnSpacing: 0

        anchors.top: parent.top
        anchors.left: parent.left

        property double placementOffsetButtons: appmenuNextToButtons && controlButtonsArea.visible ? controlButtonsArea.width + appmenuSideMargin : 0
        property double placementOffset: appmenuNextToIconAndText && appmenuSwitchSidesWithIconAndText
                                            ? activeWindowListView.anchors.leftMargin + windowTitleText.anchors.leftMargin + windowTitleText.contentWidth + appmenuSideMargin
                                            : placementOffsetButtons

        anchors.leftMargin: (bp === 1 || bp === 3) ? parent.width - width - placementOffset : placementOffset
        anchors.topMargin: (bp === 2 || bp === 3) ? 0 : parent.height - height

        Component.onCompleted: {
            plasmoid.nativeInterface.buttonGrid = buttonGrid
            plasmoid.nativeInterface.enabled = appmenuEnabled
        }

        Connections {
            target: plasmoid.nativeInterface
            onRequestActivateIndex: {
                var idx = Math.max(0, Math.min(buttonRepeater.count - 1, index))
                var button = buttonRepeater.itemAt(index)
                if (button) {
                    button.clicked(null)
                }
            }
        }

        PlasmaCore.DataSource {
            id: keystateSource
            engine: "keystate"
            connectedSources: ["Alt"]
        }

        Repeater {
            id: buttonRepeater
            model: appMenuModel

            PlasmaComponents.ToolButton {
                readonly property int buttonIndex: index

                Layout.preferredWidth: minimumWidth + units.smallSpacing * 2
                Layout.preferredHeight: appmenuFillHeight ? appmenu.height : minimumHeight
                /*Layout.fillWidth: root.vertical
                Layout.fillHeight: !root.vertical*/

                font.weight: appmenuFontBold ? Font.Bold : theme.defaultFont.weight
                
                text: {
                    var text = activeMenu
                    
                    var alt = keystateSource.data.Alt;
                    if ( alt.Pressed ) {
                        return text
                    }
                    else {
                        return text.replace('&', '')
                    }
                }

                //}
                // fake highlighted
                checkable: plasmoid.nativeInterface.currentIndex === index
                checked: checkable
                visible: text !== ""
                onClicked: {
                    plasmoid.nativeInterface.trigger(this, index)

                    checked = Qt.binding(function() {
                        return plasmoid.nativeInterface.currentIndex === index;
                    });
                }

                // QMenu opens on press, so we'll replicate that here
                MouseArea {
                    anchors.fill: parent
                    onPressed: parent.clicked()
                }
            }
        }
    }

    Rectangle {
        id: separator
        anchors.left: buttonGrid.left
        anchors.leftMargin: appmenuSwitchSidesWithIconAndText ? - appmenuSideMargin * 0.5 : buttonGrid.width + appmenuSideMargin * 0.5
        anchors.verticalCenter: buttonGrid.verticalCenter
        height: 0.8 * parent.height
        width: 1
        visible: appmenuNextToIconAndText && plasmoid.configuration.appmenuSeparatorEnabled
        color: theme.textColor
        opacity: 0.4
    }

    function initializeAppModel() {
        if (appMenuModel !== null) {
            return
        }
        print('initializing appMenuModel...')
        try {
            appMenuModel = Qt.createQmlObject(
                'import QtQuick 2.2;\
                 import org.kde.plasma.plasmoid 2.0;\
                 import org.kde.private.activeWindowControl 1.0 as ActiveWindowControlPrivate;\
                 ActiveWindowControlPrivate.AppMenuModel {\
                     id: appMenuModel;\
                     onRequestActivateIndex: plasmoid.nativeInterface.requestActivateIndex(index);\
                     Component.onCompleted: {\
                         plasmoid.nativeInterface.model = appMenuModel\
                     }\
                 }', main)
        } catch (e) {
            print('appMenuModel failed to initialize: ' + e)
        }
        print('initializing appmenu...DONE ' + appMenuModel)
        if (appMenuModel !== null) {
            resetAppmenuModel()
        }
    }

    function resetAppmenuModel() {
        if (appmenuEnabled) {
            initializeAppModel()
            if (appMenuModel === null) {
                return
            }
            print('setting model in QML: ' + appMenuModel)
            for (var key in appMenuModel) {
                print('  ' + key + ' -> ' + appMenuModel[key])
            }
            plasmoid.nativeInterface.model = appMenuModel
            buttonRepeater.model = appMenuModel
        } else {
            plasmoid.nativeInterface.model = null
            buttonRepeater.model = null
        }
    }

    onAppmenuEnabledChanged: {
        appmenu.resetAppmenuModel()
        if (appMenuModel !== null) {
            plasmoid.nativeInterface.enabled = appmenuEnabled
        }
    }
}
