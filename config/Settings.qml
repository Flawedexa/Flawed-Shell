pragma Singleton

import QtQuick
import Quickshell
import "../services"

Singleton {
    id: root

    property string font: ShellSettings.fontFamily + ", monospace"

    readonly property int fontSize: Math.round(ShellSettings.fontSize * ShellSettings.uiScale)
    readonly property int hPad: 14

    readonly property bool hyprLuaConfig: false

    readonly property list<string> lockCommand: ["hyprlock"]
    readonly property list<string> suspendCommand: ["systemctl", "suspend"]
    readonly property list<string> rebootCommand: ["systemctl", "reboot"]
    readonly property list<string> poweroffCommand: ["systemctl", "poweroff"]
}
