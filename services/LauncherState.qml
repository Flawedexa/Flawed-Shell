pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool open: false
    property real anchorX: 0
    property var  triggerScreen: null

    function toggleAt(x: real, screen): void {
        if (open) { close(); return }
        anchorX = x
        if (screen) triggerScreen = screen
        open = true
    }
    function close(): void {
        if (open) open = false
        triggerScreen = null
    }
}
