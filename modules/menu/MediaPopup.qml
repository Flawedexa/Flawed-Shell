pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland._WlrLayerShell
import Quickshell.Hyprland
import "../../config"
import "../../services"
import "../common"

PanelWindow {
    id: win

    required property ShellScreen targetScreen

    readonly property HyprlandMonitor _monitor: Hyprland.monitorFor(win.screen)

    Connections {
        target: win._monitor
        function onActiveWorkspaceChanged() { if (MediaState.open) MediaState.close() }
    }

    screen:        targetScreen
    color:         "transparent"
    exclusiveZone: -1
    WlrLayershell.namespace: "flawed-mediapopup"
    WlrLayershell.keyboardFocus: MediaState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: MediaState.open || card.opacity > 0.001

    anchors { top: true; left: true; right: true; bottom: true }

    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; enabled: MediaState.open; onActivated: MediaState.close() }

    Connections {
        target: MenuState
        function onOpenChanged() { if (MenuState.open && MediaState.open) MediaState.close() }
    }

    Item { id: _fillArea; anchors.fill: parent }
    mask: Region { item: MediaState.open ? _fillArea : null }

    OutsideTapDismiss {
        state: MediaState
        card: card
    }

    Loader {
        active: MediaState.open && ShellSettings.barFloating && ShellSettings.barShadow
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
        open: MediaState.open
        anchorX: MediaState.anchorX
        barBottom: ShellSettings.barPosition === "bottom"

        readonly property int _artH: 180
        readonly property int _pad:  12

        width:  320
        height: _inner.implicitHeight
        activeFocusOnTab: true
        Accessible.role: Accessible.Pane
        Accessible.name: "Media player"

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Space) { Media.togglePlay(); event.accepted = true }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            clip: true
            color: "transparent"
            layer.enabled: true

            Column {
                id: _inner
                width: parent.width
                spacing: 0

                Item {
                    width: parent.width
                    height: card._artH

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: card.radius
                        color: "transparent"

                        Image {
                            id: _art
                            anchors.fill: parent
                            source: Media.stableArtUrl.length > 0 ? Media.stableArtUrl : ""
                            sourceSize.width: 320; sourceSize.height: card._artH
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            visible: status === Image.Ready
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.menuCard
                            visible: _art.status !== Image.Ready
                            Text {
                                anchors.centerIn: parent
                                text: "󰝚"
                                color: Theme.withAlpha(Theme.subtext, 0.20)
                                font.family: Settings.font
                                font.pixelSize: 48
                                renderType: Text.NativeRendering
                            }
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 60
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: _art.visible ? Theme.menuCard : "transparent" }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 2
                    padding: card._pad

                    Text {
                        width: parent.width - card._pad * 2
                        text: Media.title.length > 0 ? Media.title : "No track"
                        color: Theme.text
                        font.family: Settings.font
                        font.pixelSize: Settings.fontSize + 1
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        width: parent.width - card._pad * 2
                        text: Media.artist.length > 0 ? Media.artist : (Media.identity.length > 0 ? Media.identity : "")
                        color: Theme.withAlpha(Theme.subtext, 0.78)
                        font.family: Settings.font
                        font.pixelSize: Settings.fontSize - 1
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }

                Item {
                    id: _seekBar
                    width: parent.width
                    height: Media.hasPosition ? 34 : 0
                    visible: Media.hasPosition

                    property real _dragRatio: 0
                    property bool _dragging: false
                    property bool _hovered: false
                    readonly property real _effectiveRatio: _dragging ? _dragRatio : Media.positionRatio

                    Text {
                        id: _elapsed
                        anchors.left: parent.left; anchors.leftMargin: card._pad
                        anchors.verticalCenter: parent.verticalCenter
                        text: Media.formatTime(_dragging ? _dragRatio * Media.length : Media.positionNow)
                        color: Theme.withAlpha(Theme.text, 0.50)
                        font.family: Settings.font
                        font.pixelSize: Settings.fontSize - 3
                        renderType: Text.NativeRendering
                    }

                    Rectangle {
                        id: _track
                        anchors.left: _elapsed.right; anchors.leftMargin: 6
                        anchors.right: _total.left; anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        height: 4
                        radius: 2
                        color: Theme.withAlpha(Theme.text, 0.15)

                        Rectangle {
                            id: _fill
                            width: parent.width * _seekBar._effectiveRatio
                            height: parent.height
                            radius: 2
                            color: Theme.accent
                            Behavior on width {
                                enabled: !_seekBar._dragging && Media.playing
                                NumberAnimation { duration: 420; easing.type: Easing.Linear }
                            }
                        }

                        Rectangle {
                            id: _thumb
                            x: parent.width * _seekBar._effectiveRatio - width / 2
                            y: parent.height / 2 - height / 2
                            width: 12
                            height: 12
                            radius: 6
                            color: Theme.accent
                            visible: _seekBar._hovered || _seekBar._dragging
                            scale: _seekBar._dragging ? 1.0 : (_seekBar._hovered ? 0.85 : 0)
                            opacity: _seekBar._dragging ? 1.0 : (_seekBar._hovered ? 1.0 : 0)
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            id: _dragMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onEntered: _seekBar._hovered = true
                            onExited: if (!_seekBar._dragging) _seekBar._hovered = false

                            onPressed: mouse => {
                                if (!Media.canSeek) return
                                _seekBar._dragging = true
                                _seekBar._hovered = true
                                _seekBar._dragRatio = Math.max(0, Math.min(1, mouse.x / width))
                            }

                            onPositionChanged: mouse => {
                                if (!_seekBar._dragging || !Media.canSeek) return
                                _seekBar._dragRatio = Math.max(0, Math.min(1, mouse.x / width))
                            }

                            onReleased: mouse => {
                                if (!_seekBar._dragging) return
                                _seekBar._dragging = false
                                if (!_seekBar._hovered) _seekBar._hovered = false
                                if (Media.canSeek)
                                    Media.seekToRatio(_seekBar._dragRatio)
                            }

                            onCanceled: {
                                if (_seekBar._dragging) {
                                    _seekBar._dragging = false
                                    if (!_seekBar._hovered) _seekBar._hovered = false
                                }
                            }
                        }
                    }

                    Text {
                        id: _total
                        anchors.right: parent.right; anchors.rightMargin: card._pad
                        anchors.verticalCenter: parent.verticalCenter
                        text: Media.formatTime(Media.length)
                        color: Theme.withAlpha(Theme.text, 0.42)
                        font.family: Settings.font
                        font.pixelSize: Settings.fontSize - 3
                        renderType: Text.NativeRendering
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 24
                    padding: 8

                    Item {
                        width: 36; height: 36
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: Media.player ? (Media.player.canGoPrevious ? 1.0 : 0.25) : 0.25

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Media.previous() }

                        Text {
                            anchors.centerIn: parent
                            text: "󰒮"
                            color: Theme.text
                            font.family: Settings.font
                            font.pixelSize: Settings.fontSize + 8
                            renderType: Text.NativeRendering
                        }
                    }

                    Item {
                        width: 44; height: 44
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: Media.player ? (Media.player.canTogglePlaying ? 1.0 : 0.25) : 0.25

                        HoverHandler { id: _playH; cursorShape: Qt.PointingHandCursor }
                        TapHandler { id: _playT; onTapped: Media.togglePlay() }

                        scale: _playT.pressed ? 0.85 : 1.0
                        transformOrigin: Item.Center
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                        Rectangle {
                            anchors.fill: parent
                            radius: 22
                            color: Theme.withAlpha(Theme.accent, _playT.pressed ? 0.28 : (_playH.hovered ? 0.22 : 0.16))
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: 22
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.withAlpha(Theme.accent, 0.30)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Media.playing ? "󰏤" : "󰐊"
                            color: Theme.accent
                            font.family: Settings.font
                            font.pixelSize: Settings.fontSize + 12
                            renderType: Text.NativeRendering
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                    }

                    Item {
                        width: 36; height: 36
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: Media.player ? (Media.player.canGoNext ? 1.0 : 0.25) : 0.25

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Media.next() }

                        Text {
                            anchors.centerIn: parent
                            text: "󰒭"
                            color: Theme.text
                            font.family: Settings.font
                            font.pixelSize: Settings.fontSize + 8
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }
    }
}
