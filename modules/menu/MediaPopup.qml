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

        readonly property int _pad: 12

        width:  320
        height: _inner.height
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

            Item {
                id: _inner
                width: parent.width
                height: _row.implicitHeight + card._pad * 2

                Row {
                    id: _row
                    anchors.left: parent.left
                    anchors.leftMargin: card._pad
                    anchors.right: parent.right
                    anchors.rightMargin: card._pad
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    // ── Album art (square thumbnail) ──
                    Rectangle {
                        id: _artBlock
                        width: 84; height: 84
                        radius: 10
                        antialiasing: true
                        clip: true
                        color: Theme.menuCard

                        Image {
                            id: _artImg
                            anchors.fill: parent
                            source: Media.stableArtUrl.length > 0 ? Media.stableArtUrl : ""
                            sourceSize.width: 84; sourceSize.height: 84
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: _artImg.status !== Image.Ready
                            text: "󰝚"
                            color: Theme.withAlpha(Theme.subtext, 0.20)
                            font.family: Settings.font
                            font.pixelSize: 28
                            renderType: Text.NativeRendering
                        }
                    }

                    // ── Text + seek + controls ──
                    Column {
                        width: parent.width - _artBlock.width - parent.spacing
                        spacing: 2

                        Text {
                            width: parent.width
                            visible: Media.identity.length > 0 && (Media.title.length > 0 || Media.artist.length > 0)
                            text: (Media.identity ?? "").toUpperCase()
                            color: Theme.withAlpha(Theme.accent, 0.65)
                            font.family: Settings.font
                            font.pixelSize: Settings.fontSize - 3
                            font.letterSpacing: 1.2
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }

                        Text {
                            width: parent.width
                            text: Media.title.length > 0 ? Media.title : "No track"
                            color: Theme.text
                            font.family: Settings.font
                            font.pixelSize: Settings.fontSize + 1
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }

                        Text {
                            width: parent.width
                            text: Media.artist.length > 0 ? Media.artist : ""
                            color: Theme.withAlpha(Theme.subtext, 0.78)
                            font.family: Settings.font
                            font.pixelSize: Settings.fontSize - 1
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }

                        // ── Seek bar ──
                        Item {
                            id: _sb
                            width: parent.width
                            height: Media.hasPosition ? 22 : 0
                            visible: Media.hasPosition
                            clip: false

                            property real _dragRatio: 0
                            property bool _dragging: false
                            property bool _hovered: false
                            readonly property real _effectiveRatio: _dragging ? _dragRatio : Media.positionRatio

                            Text {
                                id: _elapsed
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: Media.formatTime(_sb._dragging ? _sb._dragRatio * Media.length : Media.positionNow)
                                color: Theme.withAlpha(Theme.text, 0.45)
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
                                    width: parent.width * _sb._effectiveRatio
                                    height: parent.height
                                    radius: 2
                                    color: Theme.accent
                                    Behavior on width {
                                        enabled: !_sb._dragging && Media.playing
                                        NumberAnimation { duration: 420; easing.type: Easing.Linear }
                                    }
                                }

                                Rectangle {
                                    id: _thumb
                                    x: parent.width * _sb._effectiveRatio - width / 2
                                    y: parent.height / 2 - height / 2
                                    width: 12; height: 12; radius: 6
                                    color: Theme.accent
                                    visible: _sb._hovered || _sb._dragging
                                    scale: _sb._dragging ? 1.0 : (_sb._hovered ? 0.85 : 0)
                                    opacity: _sb._dragging ? 1.0 : (_sb._hovered ? 1.0 : 0)
                                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onEntered: _sb._hovered = true
                                    onExited: if (!_sb._dragging) _sb._hovered = false
                                    onPressed: mouse => {
                                        if (!Media.canSeek) return
                                        _sb._dragging = true
                                        _sb._hovered = true
                                        _sb._dragRatio = Math.max(0, Math.min(1, mouse.x / width))
                                    }
                                    onPositionChanged: mouse => {
                                        if (!_sb._dragging || !Media.canSeek) return
                                        _sb._dragRatio = Math.max(0, Math.min(1, mouse.x / width))
                                    }
                                    onReleased: mouse => {
                                        if (!_sb._dragging) return
                                        _sb._dragging = false
                                        if (!_sb._hovered) _sb._hovered = false
                                        if (Media.canSeek) Media.seekToRatio(_sb._dragRatio)
                                    }
                                    onCanceled: {
                                        if (_sb._dragging) {
                                            _sb._dragging = false
                                            if (!_sb._hovered) _sb._hovered = false
                                        }
                                    }
                                }
                            }

                            Text {
                                id: _total
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: Media.formatTime(Media.length)
                                color: Theme.withAlpha(Theme.text, 0.38)
                                font.family: Settings.font
                                font.pixelSize: Settings.fontSize - 3
                                renderType: Text.NativeRendering
                            }
                        }

                        // ── Transport controls ──
                        Row {
                            spacing: 20
                            anchors.horizontalCenter: parent.horizontalCenter

                            Item {
                                width: 34; height: 34
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: Media.player ? (Media.player.canGoPrevious ? 1.0 : 0.25) : 0.25
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: Media.previous() }
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒮"
                                    color: Theme.text
                                    font.family: Settings.font
                                    font.pixelSize: Settings.fontSize + 6
                                    renderType: Text.NativeRendering
                                }
                            }

                            Item {
                                id: _playBtn
                                width: 40; height: 40
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: Media.player ? (Media.player.canTogglePlaying ? 1.0 : 0.25) : 0.25

                                HoverHandler { id: _playH; cursorShape: Qt.PointingHandCursor }
                                TapHandler { id: _playT; onTapped: Media.togglePlay() }

                                scale: _playT.pressed ? 0.85 : 1.0
                                transformOrigin: Item.Center
                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 20
                                    color: Theme.withAlpha(Theme.accent, _playT.pressed ? 0.28 : (_playH.hovered ? 0.22 : 0.16))
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 20
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Theme.withAlpha(Theme.accent, 0.30)
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: Media.playing ? "󰏤" : "󰐊"
                                    color: Theme.accent
                                    font.family: Settings.font
                                    font.pixelSize: Settings.fontSize + 10
                                    renderType: Text.NativeRendering
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                            }

                            Item {
                                width: 34; height: 34
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: Media.player ? (Media.player.canGoNext ? 1.0 : 0.25) : 0.25
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: Media.next() }
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒭"
                                    color: Theme.text
                                    font.family: Settings.font
                                    font.pixelSize: Settings.fontSize + 6
                                    renderType: Text.NativeRendering
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
