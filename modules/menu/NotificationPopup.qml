pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland._WlrLayerShell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import "../../config"
import "../../services"
import "../common"

PanelWindow {
    id: win

    required property ShellScreen targetScreen

    readonly property HyprlandMonitor _monitor: Hyprland.monitorFor(win.screen)

    Connections {
        target: win._monitor
        function onActiveWorkspaceChanged() { if (NotificationPopupState.open) NotificationPopupState.close() }
    }

    screen:        targetScreen
    color:         "transparent"
    exclusiveZone: -1
    WlrLayershell.namespace: "flawed-notification-popup"
    WlrLayershell.keyboardFocus: NotificationPopupState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: NotificationPopupState.open || card.opacity > 0.001

    anchors { top: true; left: true; right: true; bottom: true }

    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; enabled: NotificationPopupState.open; onActivated: NotificationPopupState.close() }

    Connections {
        target: MenuState
        function onOpenChanged() { if (MenuState.open && NotificationPopupState.open) NotificationPopupState.close() }
    }

    Item { id: _fillArea; anchors.fill: parent }
    mask: Region { item: NotificationPopupState.open ? _fillArea : null }

    OutsideTapDismiss {
        state: NotificationPopupState
        card: card
    }

    Loader {
        active: NotificationPopupState.open && ShellSettings.barFloating && ShellSettings.barShadow
        anchors.fill: card
        opacity: card.opacity
        z: -1
        sourceComponent: FloatingShadow {
            radius: card.radius
            atBottom: card.barBottom
        }
    }

    FloatingPopupCard {
        id: card
        win: win
        open: NotificationPopupState.open
        anchorX: NotificationPopupState.anchorX
        barBottom: ShellSettings.barPosition === "bottom"

        readonly property int _pad: 12

        width:  360
        height: Math.min(_list.contentHeight + _header.height + card._pad * 2, 480)
        activeFocusOnTab: true
        Accessible.role: Accessible.Pane
        Accessible.name: "Notifications"

        Column {
            x: 0; y: card._pad
            width: parent.width
            spacing: 0

            Item {
                id: _header
                width: parent.width
                height: 36

                Text {
                    id: _title
                    anchors.left: parent.left; anchors.leftMargin: card._pad
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications"
                    color: Theme.text
                    font.family: Settings.font
                    font.pixelSize: Settings.fontSize + 1
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }

                Text {
                    anchors.left: _title.right; anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: Notifications.activeCount > 0 ? "(" + Notifications.activeCount + ")" : ""
                    color: Theme.withAlpha(Theme.subtext, 0.60)
                    font.family: Settings.font
                    font.pixelSize: Settings.fontSize - 1
                    renderType: Text.NativeRendering
                }

                Text {
                    id: _clearBtn
                    anchors.right: parent.right; anchors.rightMargin: card._pad
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰅖"
                    color: _clearHov.hovered ? Theme.error : Theme.withAlpha(Theme.subtext, 0.45)
                    font.family: Settings.font
                    font.pixelSize: Settings.fontSize + 2
                    renderType: Text.NativeRendering
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    HoverHandler { id: _clearHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            Notifications.dismissAll()
                            NotificationPopupState.close()
                        }
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: "Dismiss all notifications"
                }
            }

            ListView {
                id: _list
                width: parent.width
                height: Math.min(_list.count * 72, 440)
                clip: true
                model: Notifications.list
                currentIndex: -1
                boundsBehavior: Flickable.StopAtBounds
                headerPositioning: ListView.OverlayHeader

                delegate: Item {
                    required property int index
                    required property var modelData

                    readonly property var notification: modelData.notification
                    readonly property int notifId: modelData.id
                    readonly property real createdAt: modelData.time

                    readonly property string iconSource: {
                        const img = notification.image || ""
                        if (img.length > 0) return img
                        const ai = String(notification.appIcon || "")
                        if (ai.length > 0) {
                            if (ai.startsWith("/") || ai.startsWith("file://")) return ai
                            const p = Quickshell.iconPath(ai, true)
                            if (p.length > 0) return p
                        }
                        return ""
                    }
                    readonly property bool hasIcon: iconSource.length > 0
                    readonly property string summaryText: Notifications.plainText(notification.summary)
                    readonly property string bodyText: Notifications.plainText(notification.body)
                    readonly property string appNameText: notification.appName || ""
                    readonly property bool hasBody: bodyText.length > 0
                    readonly property bool isCritical: notification.urgency === NotificationUrgency.Critical

                    width: _list.width
                    height: 68

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: card._pad; anchors.rightMargin: card._pad
                        anchors.topMargin: 2; anchors.bottomMargin: 2
                        radius: 10
                        color: _hov.hovered
                            ? Theme.withAlpha(Theme.mix(Theme.text, Theme.accent, 0.30), 0.08)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.fast } }

                        HoverHandler { id: _hov; cursorShape: Qt.PointingHandCursor }

                        ClippingRectangle {
                            visible: hasIcon
                            width: 28; height: 28
                            radius: 7
                            color: "transparent"
                            anchors.top: parent.top; anchors.topMargin: 8
                            anchors.left: parent.left; anchors.leftMargin: 10
                            Image {
                                anchors.fill: parent
                                source: iconSource
                                sourceSize.width: 56; sourceSize.height: 56
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }

                        Column {
                            anchors.left: parent.left; anchors.leftMargin: hasIcon ? 48 : 12
                            anchors.right: _closeBtn.left; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                width: parent.width
                                text: summaryText
                                textFormat: Text.PlainText
                                color: isCritical ? Theme.error : Theme.text
                                font.family: Settings.font
                                font.pixelSize: Settings.fontSize
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }

                            Text {
                                visible: hasBody
                                width: parent.width
                                text: bodyText
                                textFormat: Text.PlainText
                                color: Theme.withAlpha(Theme.subtext, 0.72)
                                font.family: Settings.font
                                font.pixelSize: Settings.fontSize - 1
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                renderType: Text.NativeRendering
                            }

                            Row {
                                spacing: 4
                                Text {
                                    text: appNameText
                                    textFormat: Text.PlainText
                                    color: Theme.withAlpha(Theme.menuTextFaint, 0.62)
                                    font.family: Settings.font
                                    font.pixelSize: Settings.fontSize - 3
                                    font.weight: Font.Medium
                                    font.capitalization: Font.AllUppercase
                                    font.letterSpacing: 0.6
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering
                                }
                                Text {
                                    visible: appNameText.length > 0
                                    text: "·"
                                    color: Theme.withAlpha(Theme.menuTextFaint, 0.50)
                                    font.family: Settings.font
                                    font.pixelSize: Settings.fontSize - 3
                                    renderType: Text.NativeRendering
                                }
                                Text {
                                    text: _timeLabel
                                    textFormat: Text.PlainText
                                    color: Theme.withAlpha(Theme.menuTextFaint, 0.62)
                                    font.family: Settings.font
                                    font.pixelSize: Settings.fontSize - 3
                                    renderType: Text.NativeRendering
                                }
                            }
                        }

                        Item {
                            id: _closeBtn
                            anchors.right: parent.right; anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 22; height: 22
                            opacity: _hov.hovered ? 1.0 : 0.0
                            scale: _hov.hovered ? 1.0 : 0.6
                            transformOrigin: Item.Center
                            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                            Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

                            Rectangle {
                                anchors.fill: parent
                                radius: 11
                                color: _closeHov.hovered ? Theme.withAlpha(Theme.error, 0.16) : "transparent"
                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                                HoverHandler { id: _closeHov; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: Notifications.dismissObject(notifId, notification, false)
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    color: _closeHov.hovered ? Theme.error : Theme.withAlpha(Theme.menuTextMuted, 0.60)
                                    font.family: Settings.font
                                    font.pixelSize: Settings.fontSize - 2
                                    renderType: Text.NativeRendering
                                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                                }
                            }
                        }
                    }

                    property string _timeLabel: ""
                    function _updateTime(): void {
                        const secs = (Date.now() - createdAt) / 1000
                        if (secs < 60)        _timeLabel = "just now"
                        else if (secs < 3600) _timeLabel = Math.floor(secs / 60) + "m ago"
                        else {
                            const d = new Date(createdAt)
                            _timeLabel = String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0")
                        }
                    }
                    Component.onCompleted: _updateTime()
                    Timer {
                        interval: 30000
                        running: true
                        repeat: true
                        onTriggered: _updateTime()
                    }
                }

                Item {
                    width: _list.width
                    height: 48
                    visible: Notifications.activeCount === 0

                    Text {
                        anchors.centerIn: parent
                        text: "No notifications"
                        color: Theme.withAlpha(Theme.subtext, 0.42)
                        font.family: Settings.font
                        font.pixelSize: Settings.fontSize
                        renderType: Text.NativeRendering
                    }
                }
            }
        }
    }
}
