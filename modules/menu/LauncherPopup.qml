pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland._WlrLayerShell
import Quickshell.Hyprland
import "../../config"
import "../../services"
import "../common"

PanelWindow {
    id: win

    required property ShellScreen targetScreen

    readonly property HyprlandMonitor _monitor: Hyprland.monitorFor(win.screen)
    property bool _ignoreOutsideTap: false

    Connections {
        target: win._monitor
        function onActiveWorkspaceChanged() { if (LauncherState.open) LauncherState.close() }
    }

    screen:        targetScreen
    color:         "transparent"
    exclusiveZone: -1
    WlrLayershell.namespace: "flawed-launcher"
    WlrLayershell.keyboardFocus: LauncherState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: LauncherState.open || card.opacity > 0.001

    anchors { top: true; left: true; right: true; bottom: true }

    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; enabled: LauncherState.open; onActivated: LauncherState.close() }

    Connections {
        target: MenuState
        function onOpenChanged() { if (MenuState.open && LauncherState.open) LauncherState.close() }
    }

    Connections {
        target: ShellSettings
        function onBarPositionChanged() {
            if (!LauncherState.open) return
            win._ignoreOutsideTap = true
            _outsideTapGuard.restart()
        }
    }

    Connections {
        target: LauncherState
        function onOpenChanged() {
            if (!LauncherState.open) {
                _outsideTapGuard.stop()
                win._ignoreOutsideTap = false
            }
        }
    }

    Timer {
        id: _outsideTapGuard
        interval: 250
        repeat: false
        onTriggered: win._ignoreOutsideTap = false
    }

    Item { id: _fillArea; anchors.fill: parent }
    mask: Region { item: LauncherState.open ? _fillArea : null }

    TapHandler {
        id: _dismiss
        enabled: LauncherState.open && card.scaleAmt > 0.95
        onTapped: {
            if (win._ignoreOutsideTap) return
            const p = _dismiss.point.position
            if (p.x < card.x || p.x > card.x + card.width ||
                p.y < card.y || p.y > card.y + card.height)
                LauncherState.close()
        }
    }

    Loader {
        active: LauncherState.open && ShellSettings.barFloating && ShellSettings.barShadow
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
        open: LauncherState.open
        anchorX: LauncherState.anchorX
        barBottom: ShellSettings.barPosition === "bottom"

        readonly property int _pad: 12

        width: 340
        height: _searchField.height + 340 + card._pad * 3 + 2
        activeFocusOnTab: true

        Column {
            x: card._pad; y: card._pad
            width: parent.width - card._pad * 2
            spacing: 8

            TextInput {
                id: _searchField
                width: parent.width
                height: 34
                text: ""
                color: Theme.text
                font.family: Settings.font
                font.pixelSize: Settings.fontSize
                verticalAlignment: TextInput.AlignVCenter
                leftPadding: 8; rightPadding: 8
                activeFocusOnTab: true

                property bool _hasText: text.length > 0

                onTextChanged: _grid.filter(text)

                Keys.onEscapePressed: LauncherState.close()
                Keys.onReturnPressed: {
                    if (_grid._filtered.length > 0) {
                        const app = _grid._filtered[0]
                        if (app) _launchApp(app.desktopId)
                    }
                }
                Keys.onDownPressed: event.accepted = true

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: Theme.withAlpha(Theme.subtext, 0.08)
                    border.width: 1
                    border.color: _searchField.activeFocus
                        ? Theme.withAlpha(Theme.accent, 0.4)
                        : "transparent"
                    z: -1
                }

                Text {
                    anchors.left: parent.left; anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰀻"
                    color: Theme.withAlpha(Theme.subtext, 0.45)
                    font.family: Settings.font
                    font.pixelSize: Settings.fontSize + 2
                    renderType: Text.NativeRendering
                    visible: _searchField.text.length === 0 && !_searchField.activeFocus
                }

                Text {
                    anchors.left: parent.left; anchors.leftMargin: 28
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search apps…"
                    color: Theme.withAlpha(Theme.subtext, 0.35)
                    font.family: Settings.font
                    font.pixelSize: Settings.fontSize
                    renderType: Text.NativeRendering
                    visible: _searchField.text.length === 0 && !_searchField.activeFocus
                }
            }

            ListView {
                id: _listView
                width: parent.width
                height: Math.min(_listView.count * 38, 340)
                clip: true
                model: _grid._filtered
                currentIndex: -1
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    required property int index
                    required property var modelData

                    width: _listView.width
                    height: 38

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 2; anchors.rightMargin: 2
                        radius: 8
                        color: _hov.hovered || parent.activeFocus
                            ? Theme.withAlpha(Theme.accent, 0.12)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.fast } }

                        HoverHandler { id: _hov; cursorShape: Qt.PointingHandCursor }

                        TapHandler {
                            onTapped: _launchApp(modelData.desktopId)
                        }

                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰀻"
                            color: Theme.withAlpha(Theme.subtext, 0.6)
                            font.family: Settings.font
                            font.pixelSize: Settings.fontSize + 2
                            renderType: Text.NativeRendering
                        }

                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 34
                            anchors.right: parent.right; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            color: Theme.text
                            font.family: Settings.font
                            font.pixelSize: Settings.fontSize
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }
                    }

                    Keys.onReturnPressed: {
                        _launchApp(modelData.desktopId)
                        event.accepted = true
                    }
                }

                Item {
                    id: _grid
                    property var _all: []
                    property var _filtered: []
                    property bool _loaded: false
                    property int count: _filtered.length

                    function filter(text: string): void {
                        const q = text.trim().toLowerCase()
                        _filtered = q.length === 0
                            ? _all.slice()
                            : _all.filter(a => (a.name || "").toLowerCase().includes(q))
                    }

                    function load(data: string): void {
                        try {
                            const parsed = JSON.parse(data)
                            if (Array.isArray(parsed)) {
                                _all = parsed
                                _loaded = true
                                filter(_searchField.text)
                            }
                        } catch (e) { /* ignore */ }
                    }
                }
            }
        }
    }

    Process {
        id: _scanProc
        stdout: StdioCollector { id: _scanOut }
        onExited: (code) => {
            if (code === 0) _grid.load(_scanOut.text || "[]")
        }
    }

    property bool _scanStarted: false

    onVisibleChanged: {
        if (visible && LauncherState.open) {
            _searchField.forceActiveFocus()
            _searchField.selectAll()
            if (!_scanStarted) {
                _scanStarted = true
                _scanProc.exec(["bash", "-c",
                    "for f in /usr/share/applications/*.desktop; do " +
                    "  [ -f \"$f\" ] || continue; " +
                    "  name=$(grep -m1 '^Name=' \"$f\" | sed 's/^Name=//'); " +
                    "  icon=$(grep -m1 '^Icon=' \"$f\" | sed 's/^Icon=//'); " +
                    "  id=$(basename \"$f\" .desktop); " +
                    "  [ -n \"$name\" ] && echo \"{\\\"name\\\":\\\"$name\\\",\\\"icon\\\":\\\"$icon\\\",\\\"desktopId\\\":\\\"$id\\\"}\"; " +
                    "done | jq -s . 2>/dev/null || echo '[]'"
                ])
            }
        }
    }

    function _launchApp(desktopId: string): void {
        Quickshell.execDetached(["gtk-launch", desktopId])
        LauncherState.close()
    }
}
