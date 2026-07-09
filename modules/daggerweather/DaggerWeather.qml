import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../services"

PanelWindow {
    id: root

    screen: Quickshell.screens[0]
    WlrLayershell.layer: WlrLayer.Bottom
    color: "transparent"
    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true

    readonly property var _blades: [
        { color: "#d8008e", name: "Rose" },
        { color: "#c604e7", name: "Sinister" },
        { color: "#00dfc6", name: "Crystal" },
        { color: "#ef0c18", name: "Blood" },
        { color: "#10a6ff", name: "Storm" },
        { color: "#4a34b5", name: "Prestige" }
    ]
    readonly property int _bladeCount: _blades.length

    readonly property string _bladePath: "M3.08,59.9 L3.47,58.64 L0.72,54.97 L0.01,52.22 L0.0,48.48 L1.38,47.91 L2.09,50.37 L3.47,52.06 L5.06,53.21 L5.19,46.93 L5.23,41.94 L5.33,37.7 L5.43,29.3 L5.63,20.61 L5.94,12.26 L6.15,8.56 L6.42,4.73 L6.82,0.0 L7.23,4.73 L7.5,8.56 L7.71,12.26 L8.02,20.61 L8.13,25.1 L8.22,29.3 L8.32,37.7 L8.42,41.94 L8.46,46.93 L8.62,55.07 L8.08,58.69 L9.5,60.89 L11.03,63.09 L11.72,64.91 L11.81,68.05 L10.78,70.52 L9.81,72.28 L8.59,73.53 L8.71,75.0 L8.37,77.02 L8.93,78.37 L8.87,78.73 L8.18,80.17 L8.17,81.86 L8.08,83.46 L8.53,84.58 L8.56,85.07 L7.96,85.69 L7.91,89.1 L8.51,93.8 L8.96,95.18 L6.83,100.0 L4.7,95.18 L5.14,93.78 L5.75,89.08 L5.71,85.71 L5.09,85.07 L5.12,84.58 L5.57,83.46 L5.49,81.86 L5.47,80.17 L4.78,78.73 L4.72,78.37 L5.27,77.06 L5.08,75.72 L4.14,72.08 L3.96,71.75 L3.08,69.4 L2.35,64.65 L3.08,59.9 Z"
    readonly property real _pathW: 11.81
    readonly property real _pathH: 100.0
    readonly property real _hiltStartFrac: 0.58
    readonly property real _gemX: 5.91
    readonly property real _gemY: 84.55

    // Diamond size
    readonly property real _diamondSize: 260
    readonly property real _ringRadius: 145

    // Current cycle state
    property int cycleIndex: 0
    property int selectedIndex: -1
    property real spinAngle: 0

    function _cycle(delta) {
        cycleIndex = (cycleIndex + delta + _bladeCount) % _bladeCount
        _spinAnim.from = spinAngle
        _spinAnim.to = spinAngle + delta * 60
        _spinAnim.start()
        _autoSelectTimer.restart()
    }

    function _select(index) {
        selectedIndex = index
        ShellSettings.neutralAccent = _blades[index].color
    }

    // Auto-select after pause
    Timer {
        id: _autoSelectTimer
        interval: 1400
        onTriggered: {
            if (selectedIndex !== cycleIndex)
                _select(cycleIndex)
        }
    }

    // Idle spin: slow rotation when nothing selected
    Timer {
        id: _idleTimer
        interval: 3000
        running: selectedIndex === -1
        repeat: true
        onTriggered: _cycle(1)
    }

    // Spin animation
    NumberAnimation {
        id: _spinAnim
        target: _ring
        property: "rotation"
        duration: 400
        easing.type: Easing.OutCubic
    }

    Behavior on spinAngle {
        enabled: !ShellSettings.reduceMotion
        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
    }

    // ---- main content ----
    Item {
        id: _content
        x: parent.width - 380 - 40
        y: parent.height - 400 - 60
        width: 380
        height: 400

        readonly property color currentColor: selectedIndex >= 0
            ? _blades[selectedIndex].color
            : _blades[cycleIndex].color

        // Diamond glow
        Rectangle {
            anchors.centerIn: parent
            width: _diamondSize + 20
            height: width
            radius: width / 2
            color: Theme.withAlpha(_content.currentColor, 0.08)
            transform: Rotation { angle: 45 }
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        // Diamond quadrants (Canvas)
        Canvas {
            id: _diamond
            anchors.centerIn: parent
            width: _diamondSize
            height: _diamondSize
            antialiasing: true

            property color topColor: Theme.mix(_content.currentColor, "#ffffff", 0.5)
            property color rightColor: _content.currentColor
            property color bottomColor: Theme.mix(_content.currentColor, "#000000", 0.4)
            property color leftColor: Theme.mix(_content.currentColor, "#ffffff", 0.2)

            onTopColorChanged: requestPaint()
            onRightColorChanged: requestPaint()
            onBottomColorChanged: requestPaint()
            onLeftColorChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                const s = width
                const cx = s / 2
                const cy = s / 2
                const r = s / 2

                ctx.clearRect(0, 0, s, s)
                ctx.save()
                ctx.translate(cx, cy)
                ctx.rotate(45 * Math.PI / 180)

                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(r, -r)
                ctx.lineTo(-r, -r)
                ctx.closePath()
                ctx.fillStyle = _diamond.topColor
                ctx.fill()

                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(r, -r)
                ctx.lineTo(r, r)
                ctx.closePath()
                ctx.fillStyle = _diamond.rightColor
                ctx.fill()

                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(r, r)
                ctx.lineTo(-r, r)
                ctx.closePath()
                ctx.fillStyle = _diamond.bottomColor
                ctx.fill()

                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(-r, r)
                ctx.lineTo(-r, -r)
                ctx.closePath()
                ctx.fillStyle = _diamond.leftColor
                ctx.fill()

                ctx.strokeStyle = Theme.withAlpha("#ffffff", 0.2)
                ctx.lineWidth = 1.5
                ctx.strokeRect(-r, -r, s, s)

                ctx.restore()
            }
        }

        // Inner diamond border
        Rectangle {
            anchors.centerIn: parent
            width: _diamondSize - 12
            height: width
            color: "transparent"
            border.color: Theme.withAlpha(_content.currentColor, 0.15)
            border.width: 1
            transform: Rotation { angle: 45 }
            Behavior on border.color { ColorAnimation { duration: 300 } }
        }

        // Blade name label
        Text {
            anchors.centerIn: parent
            text: _blades[selectedIndex >= 0 ? selectedIndex : cycleIndex].name
            color: Theme.withAlpha(_content.currentColor, 0.9)
            font.pixelSize: 22
            font.weight: 700
            font.letterSpacing: 4
            transform: Translate { y: -20 }
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        // Blade color indicator dot
        Rectangle {
            anchors.centerIn: parent
            width: 14
            height: 14
            radius: 7
            color: _content.currentColor
            opacity: 0.8
            transform: Translate { y: 20 }
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        // Dagger ring
        Item {
            id: _ring
            anchors.centerIn: parent
            width: _ringRadius * 2
            height: _ringRadius * 2

            Repeater {
                model: _bladeCount

                delegate: Item {
                    id: _slot
                    required property int index
                    readonly property real angle: index * 60
                    readonly property color bladeColor: _blades[index].color
                    readonly property bool isCurrent: index === cycleIndex
                    readonly property real emphasis: isCurrent ? 1.0 : 0.45

                    x: _ringRadius + Math.sin(angle * Math.PI / 180) * _ringRadius - width / 2
                    y: _ringRadius - Math.cos(angle * Math.PI / 180) * _ringRadius - height / 2
                    width: 20
                    height: 40

                    readonly property bool _hov: _slotHov.hovered
                    HoverHandler { id: _slotHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: _select(_slot.index) }

                    // Dagger shape
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        opacity: _slot.emphasis
                        scale: _slot.isCurrent ? 1.25 : (_slot._hov ? 1.1 : 1.0)
                        transformOrigin: Item.Bottom
                        rotation: _slot.angle + 90
                        Behavior on rotation { enabled: !ShellSettings.reduceMotion; NumberAnimation { duration: Motion.fast } }
                        Behavior on scale { enabled: !ShellSettings.reduceMotion; NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

                        ShapePath {
                            strokeWidth: 0
                            fillColor: _slot.bladeColor
                            scale: Qt.size(parent.width / _pathW, parent.height / _pathH)
                            PathSvg { path: _bladePath }
                        }
                    }
                }
            }
        }

        // Interaction overlay
        Item {
            anchors.fill: parent

            WheelHandler {
                onWheel: (event) => {
                    _cycle(event.angleDelta.y > 0 ? -1 : 1)
                    event.accepted = true
                }
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: _cycle(1)
            }

            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: {
                    if (selectedIndex >= 0) {
                        selectedIndex = -1
                        _autoSelectTimer.stop()
                    } else {
                        _cycle(-1)
                    }
                }
            }
        }

        // Decorative angle marks
        Repeater {
            model: 4
            Rectangle {
                x: parent.width / 2 - 1
                y: _diamondSize * 0.15
                width: 2
                height: 20
                color: Theme.withAlpha("#ffffff", 0.12)
                transformOrigin: Item.TopLeft
                rotation: index * 90 + 45
            }
        }
    }

    // ---- small nav arrows at the bottom ----
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        width: 60
        height: 20

        Text {
            anchors.left: parent.left
            text: "◀"
            color: Theme.withAlpha("#ffffff", 0.35)
            font.pixelSize: 14
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: _cycle(-1) }
        }
        Text {
            anchors.centerIn: parent
            text: selectedIndex >= 0 ? "✓" : "↻"
            color: selectedIndex >= 0
                ? _blades[selectedIndex].color
                : Theme.withAlpha("#ffffff", 0.5)
            font.pixelSize: 14
            font.weight: 700
        }
        Text {
            anchors.right: parent.right
            text: "▶"
            color: Theme.withAlpha("#ffffff", 0.35)
            font.pixelSize: 14
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: _cycle(1) }
        }
    }
}
