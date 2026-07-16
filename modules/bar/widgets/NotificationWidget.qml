import QtQuick
import "../../../config"
import "../../../services"
import "../../common"

Pill {
    glyph: _glyphText
    text:  expanded ? "Notifications" : ""
    accessibleName: "Notifications"
    accessibleDescription: "Open notifications"

    property var screen: null
    readonly property bool toolAvailable: true
    readonly property bool show: ShellSettings.barShowNotifications && toolAvailable
    visible: opacity > 0.01
    opacity: show ? 1.0 : 0.0
    scale:   show ? 1.0 : 0.7
    transformOrigin: Item.Center
    Behavior on opacity { enabled: !ShellSettings.reduceMotion; NumberAnimation { duration: Motion.normal; easing.type: Easing.OutCubic } }
    Behavior on scale   { enabled: !ShellSettings.reduceMotion; NumberAnimation { duration: Motion.normal; easing.type: Easing.OutQuart } }

    interactive: show

    readonly property string _glyphText: Notifications.activeCount > 0 ? "󰂚" : "󰂜"

    HoverHandler { cursorShape: Qt.PointingHandCursor; enabled: root.interactive }

    pressed: _tap.pressed
    TapHandler {
        id: _tap
        enabled: root.interactive
        acceptedButtons: Qt.LeftButton
        onTapped: {
            const sp = _tap.point.scenePosition
            NotificationPopupState.toggleAt(sp.x, root.screen)
        }
    }
}
