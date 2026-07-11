import QtQuick
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
            if (SystemTools.hasWofi && !_launchProc.running)
                _launchProc.exec(["wofi"])
        }
    }
}
