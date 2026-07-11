import QtQuick
import Quickshell
import Quickshell.Io
import "../../../config"
import "../../../services"
import "../../common"

Pill {
    glyph: "󰀻"
    text:  expanded ? "Apps" : ""
    accessibleName: "Application launcher"
    accessibleDescription: "Open the application launcher"

    readonly property bool toolAvailable: SystemTools.hasWofi
    readonly property bool show: ShellSettings.barShowLauncher && toolAvailable
    visible: opacity > 0.01
    opacity: show ? 1.0 : 0.0
    scale:   show ? 1.0 : 0.7
    transformOrigin: Item.Center
    Behavior on opacity { enabled: !ShellSettings.reduceMotion; NumberAnimation { duration: Motion.normal; easing.type: Easing.OutCubic } }
    Behavior on scale   { enabled: !ShellSettings.reduceMotion; NumberAnimation { duration: Motion.normal; easing.type: Easing.OutQuart } }

    interactive: show

    Process { id: _launchProc }

    HoverHandler { cursorShape: Qt.PointingHandCursor; enabled: root.interactive }

    pressed: _tap.pressed
    TapHandler {
        id: _tap
        enabled: root.interactive
        acceptedButtons: Qt.LeftButton
        onTapped: {
            if (!SystemTools.hasWofi) return
            // Toggle: if already running, kill it; otherwise launch
            if (_launchProc.running) {
                _launchProc.close()
                return
            }
            var sp = _tap.point.scenePosition
            var gap = 4
            function _rc(v) { return Math.round(v * 255) }
            _launchProc.exec([
                Quickshell.shellDir + "/scripts/wofi-launch.sh",
                String(_rc(Theme.panel.r)), String(_rc(Theme.panel.g)), String(_rc(Theme.panel.b)), String(Theme.panel.a),
                String(_rc(Theme.text.r)), String(_rc(Theme.text.g)), String(_rc(Theme.text.b)),
                String(_rc(Theme.accent.r)), String(_rc(Theme.accent.g)), String(_rc(Theme.accent.b)),
                String(_rc(Theme.panel.r)), String(_rc(Theme.panel.g)), String(_rc(Theme.panel.b)), String(Theme.panel.a),
                String(Screen.width),
                String(Math.round(sp.x)),
                String(Math.round(sp.y + gap))
            ])
        }
    }
}
