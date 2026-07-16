import QtQuick
import "../../config"
import "../../services"

Item {
    id: root

    required property var state
    required property Item card
    property int guardInterval: 250

    anchors.fill: parent
    property bool _ignoreOutsideTap: false

    Connections {
        target: ShellSettings
        function onBarPositionChanged() {
            if (!root.state.open) {
                card.edgeOffset = card._closedOffset
                return
            }
            root._ignoreOutsideTap = true
            _guard.restart()
        }
    }

    Connections {
        target: root.state
        function onOpenChanged() {
            if (!root.state.open) {
                _guard.stop()
                root._ignoreOutsideTap = false
            }
        }
    }

    Timer {
        id: _guard
        interval: root.guardInterval
        repeat: false
        onTriggered: root._ignoreOutsideTap = false
    }

    TapHandler {
        id: _dismiss
        enabled: root.state.open && card.scaleAmt > 0.95
        onTapped: {
            if (root._ignoreOutsideTap) return
            const p = _dismiss.point.position
            if (p.x < card.x || p.x > card.x + card.width ||
                p.y < card.y || p.y > card.y + card.height)
                root.state.close()
        }
    }
}
