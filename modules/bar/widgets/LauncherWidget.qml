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

    interactive: toolAvailable

    HoverHandler { cursorShape: Qt.PointingHandCursor; enabled: root.interactive }

    pressed: _tap.pressed
    TapHandler {
        id: _tap
        enabled: root.interactive
        acceptedButtons: Qt.LeftButton
        onTapped: root.activated()
    }

    Process { id: _launchProc }

    onActivated: {
        if (SystemTools.hasWofi && !_launchProc.running)
            _launchProc.exec(["wofi", "--show", "drun"])
    }
}
