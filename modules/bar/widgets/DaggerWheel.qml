import QtQuick
import QtQuick.Shapes
import "../../../config"
import "../../../services"
import "../../common"

// DaggerWheel.qml — Katarina's 6-blade wheel.
// Click/tap the dagger → fan opens. Scroll or use arrows to cycle.
// Pick a blade → full shell theme changes to match.

Item {
    id: root
    readonly property bool show: ShellSettings.barShowDaggerWheel
    visible: show

    // ---- blade data (colors from Gem1–Gem6 textures on the real .glb) ----
    readonly property var _blades: [
        { color: "#d8008e", name: "Rose",   bladeEmphasis: 0.00 },
        { color: "#c604e7", name: "Sinister", bladeEmphasis: 0.08 },
        { color: "#00dfc6", name: "Crystal", bladeEmphasis: 0.16 },
        { color: "#ef0c18", name: "Blood",   bladeEmphasis: 0.24 },
        { color: "#10a6ff", name: "Storm",   bladeEmphasis: 0.32 },
        { color: "#4a34b5", name: "Prestige",bladeEmphasis: 0.40 }
    ]
    readonly property int _bladeCount: _blades.length

    readonly property string _bladePath: "M3.08,59.9 L3.47,58.64 L0.72,54.97 L0.01,52.22 L0.0,48.48 L1.38,47.91 L2.09,50.37 L3.47,52.06 L5.06,53.21 L5.19,46.93 L5.23,41.94 L5.33,37.7 L5.43,29.3 L5.63,20.61 L5.94,12.26 L6.15,8.56 L6.42,4.73 L6.82,0.0 L7.23,4.73 L7.5,8.56 L7.71,12.26 L8.02,20.61 L8.13,25.1 L8.22,29.3 L8.32,37.7 L8.42,41.94 L8.46,46.93 L8.62,55.07 L8.08,58.69 L9.5,60.89 L11.03,63.09 L11.72,64.91 L11.81,68.05 L10.78,70.52 L9.81,72.28 L8.59,73.53 L8.71,75.0 L8.37,77.02 L8.93,78.37 L8.87,78.73 L8.18,80.17 L8.17,81.86 L8.08,83.46 L8.53,84.58 L8.56,85.07 L7.96,85.69 L7.91,89.1 L8.51,93.8 L8.96,95.18 L6.83,100.0 L4.7,95.18 L5.14,93.78 L5.75,89.08 L5.71,85.71 L5.09,85.07 L5.12,84.58 L5.57,83.46 L5.49,81.86 L5.47,80.17 L4.78,78.73 L4.72,78.37 L5.27,77.06 L5.08,75.72 L4.14,72.08 L3.96,71.75 L3.08,69.4 L2.35,64.65 L3.08,59.9 Z"
    readonly property real _pathW: 11.81
    readonly property real _pathH: 100.0
    readonly property real _hiltStartFrac: 0.58
    readonly property real _gemX: 5.91
    readonly property real _gemY: 84.55

    // ---- state ----
    property int cycleIndex: 0
    property int selectedIndex: -1
    property bool expanded: false

    readonly property int _iconH: 30
    readonly property int _iconW: Math.round(_iconH * (_pathW / _pathH))
    readonly property int _arrowW: 12
    readonly property int _closeBtnW: 14

    implicitHeight: parent ? parent.height : _iconH
    implicitWidth: _closedIcon.width + (expanded ? _wheelClip.width : 0)

    readonly property bool _hov: (_hoverMain.hovered && ShellSettings.barHoverHighlight) || activeFocus

    // ---- highlight glow offset per blade (parallax underline) ----
    readonly property real _glowOffset: _blades[cycleIndex].bladeEmphasis

    // ---- select: apply full theme ----
    function _select(index) {
        selectedIndex = index
        const c = _blades[index].color
        ShellSettings.neutralAccent = c
        _closeDelay.restart()
    }

    function _cycle(delta) {
        cycleIndex = (cycleIndex + delta + _bladeCount) % _bladeCount
        _autoSelectTimer.restart()
    }

    // ---- idle preview when nothing selected ----
    Timer {
        id: _idleTimer
        interval: 1800
        running: root.show && root.selectedIndex === -1 && !ShellSettings.reduceMotion
        repeat: true
        onTriggered: root._cycle(1)
    }

    // ---- auto-select after 1.2s of no cycling ----
    Timer {
        id: _autoSelectTimer
        interval: 1200
        onTriggered: {
            if (root.selectedIndex !== root.cycleIndex)
                root._select(root.cycleIndex)
        }
    }

    // ---- close after select ----
    Timer {
        id: _closeDelay
        interval: 320
        onTriggered: root.expanded = false
    }

    Behavior on implicitWidth {
        enabled: !ShellSettings.reduceMotion
        NumberAnimation { duration: Motion.medium; easing.type: Easing.OutCubic }
    }

    // ============================================================
    // DaggerGlyph — two-tone blade renderer
    // ============================================================
    component DaggerGlyph: Item {
        id: glyph
        property color bladeColor: "#ffffff"
        property real emphasis: 1.0
        property bool showGem: true

        readonly property color _steel: Theme.mix(bladeColor, "#ffffff", 0.6)
        readonly property color _hilt:  bladeColor
        readonly property color _gem:   Theme.mix(bladeColor, "#ffffff", 0.55)

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                fillColor: Theme.withAlpha(glyph._steel, 0.35 + 0.65 * glyph.emphasis)
                scale: Qt.size(glyph.width / root._pathW, glyph.height / root._pathH)
                PathSvg { path: root._bladePath }
                Behavior on fillColor { enabled: !ShellSettings.reduceMotion; ColorAnimation { duration: Motion.fast } }
            }
        }

        Item {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: parent.height * (1.0 - root._hiltStartFrac)
            clip: true
            Shape {
                width: glyph.width
                height: glyph.height
                y: -(glyph.height * root._hiltStartFrac)
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 0
                    fillColor: Theme.withAlpha(glyph._hilt, 0.55 + 0.45 * glyph.emphasis)
                    scale: Qt.size(glyph.width / root._pathW, glyph.height / root._pathH)
                    PathSvg { path: root._bladePath }
                    Behavior on fillColor { enabled: !ShellSettings.reduceMotion; ColorAnimation { duration: Motion.fast } }
                }
            }
        }

        Rectangle {
            visible: glyph.showGem
            width: Math.max(2, glyph.width * 0.22)
            height: width
            radius: width / 2
            color: glyph._gem
            opacity: 0.5 + 0.5 * glyph.emphasis
            x: (root._gemX / root._pathW) * glyph.width - width / 2
            y: (root._gemY / root._pathH) * glyph.height - height / 2
            Behavior on color   { enabled: !ShellSettings.reduceMotion; ColorAnimation { duration: Motion.fast } }
            Behavior on opacity { enabled: !ShellSettings.reduceMotion; NumberAnimation { duration: Motion.fast } }
        }
    }

    // ============================================================
    // Arrow button (chevron)
    // ============================================================
    component CycleArrow: Item {
        id: arr
        property bool isLeft: false
        property color arrowColor: "#f2f4f8"
        signal clicked

        width: root._arrowW
        height: 20

        readonly property bool _arHov: _arHover.hovered
        HoverHandler { id: _arHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: arr.clicked() }

        Canvas {
            anchors.fill: parent
            antialiasing: true
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = Theme.withAlpha(arr.arrowColor, arr._arHov ? 0.9 : 0.5)
                ctx.lineWidth = 2
                ctx.lineCap = "round"
                ctx.beginPath()
                if (arr.isLeft) {
                    ctx.moveTo(width * 0.7, height * 0.2)
                    ctx.lineTo(width * 0.3, height * 0.5)
                    ctx.lineTo(width * 0.7, height * 0.8)
                } else {
                    ctx.moveTo(width * 0.3, height * 0.2)
                    ctx.lineTo(width * 0.7, height * 0.5)
                    ctx.lineTo(width * 0.3, height * 0.8)
                }
                ctx.stroke()
            }
        }
        Behavior on opacity { enabled: !ShellSettings.reduceMotion; NumberAnimation { duration: Motion.fast } }
    }

    // ============================================================
    // CLOSED STATE — single blade + cycle arrows + name badge
    // ============================================================
    Item {
        id: _closedIcon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: _arrowW + _daggerCol.width + _nameLabel.width
        height: root._iconH

        readonly property int displayIndex: root.selectedIndex >= 0 ? root.selectedIndex : root.cycleIndex
        readonly property color displayColor: root._blades[displayIndex].color
        readonly property string displayName: root._blades[displayIndex].name

        // left arrow
        CycleArrow {
            id: _leftArr
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            isLeft: true
            onClicked: root._cycle(-1)
        }

        // dagger + name column
        Item {
            id: _daggerCol
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: _leftArr.right
            width: root._iconW + 4

            readonly property bool _dhov: _hoverMain.hovered && ShellSettings.barHoverHighlight

            HoverHandler { id: _hoverMain; cursorShape: Qt.PointingHandCursor }
            TapHandler { acceptedButtons: Qt.LeftButton; onTapped: root.expanded = !root.expanded }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: { root.selectedIndex = -1; root._autoSelectTimer.stop() } }

            // Wheel scroll to cycle
            WheelHandler {
                id: _wheel
                onWheel: (event) => {
                    root._cycle(event.angleDelta.y > 0 ? -1 : 1)
                    event.accepted = true
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: root._iconW * 2.3
                height: width
                radius: width / 2
                color: _closedIcon.displayColor
                opacity: root._hov ? 0.26 : 0.14
                z: -1
                Behavior on opacity { enabled: !ShellSettings.reduceMotion; NumberAnimation { duration: Motion.fast } }
                Behavior on color   { enabled: !ShellSettings.reduceMotion; ColorAnimation { duration: Motion.fast } }
            }

            DaggerGlyph {
                anchors.centerIn: parent
                width: root._iconW
                height: root._iconH
                bladeColor: _closedIcon.displayColor
                scale: root.expanded ? 1.0 : (root._hov ? 1.12 : 1.0)
                Behavior on scale { enabled: !ShellSettings.reduceMotion; NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
            }
        }

        // name label
        Text {
            id: _nameLabel
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: _daggerCol.right
            anchors.leftMargin: 2
            text: _closedIcon.displayName
            color: Theme.withAlpha(_closedIcon.displayColor, root.selectedIndex >= 0 ? 1.0 : 0.7)
            font.pixelSize: Math.round(root._iconH * 0.42)
            font.weight: 700
            Behavior on color { enabled: !ShellSettings.reduceMotion; ColorAnimation { duration: Motion.fast } }
        }

        // right arrow
        CycleArrow {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: _nameLabel.right
            anchors.leftMargin: 2
            isLeft: false
            onClicked: root._cycle(1)
        }
    }

    // ============================================================
    // EXPANDED WHEEL — six blades fanned with selection
    // ============================================================
    Item {
        id: _wheelClip
        anchors.left: _closedIcon.right
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        width: root.expanded ? _wheelRow.implicitWidth : 0
        height: root.height
        opacity: root.expanded ? 1.0 : 0.0

        Behavior on width   { enabled: !ShellSettings.reduceMotion; NumberAnimation { duration: Motion.medium; easing.type: Easing.OutCubic } }
        Behavior on opacity { enabled: !ShellSettings.reduceMotion; NumberAnimation { duration: Motion.fast } }

        Row {
            id: _wheelRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: root._bladeCount
                delegate: Item {
                    id: _slot
                    required property int index
                    readonly property color bladeColor: root._blades[index].color
                    readonly property bool isSelected: index === root.selectedIndex
                    readonly property bool isCycling:  index === root.cycleIndex && root.selectedIndex === -1
                    width: root._iconW + 8
                    height: root._iconH + 10

                    readonly property bool _shov: _hoverSlot.hovered && ShellSettings.barHoverHighlight
                    HoverHandler { id: _hoverSlot; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root._select(_slot.index) }

                    readonly property real _fanAngle: (index - (root._bladeCount - 1) / 2) * 7
                    readonly property real _emphasis: _slot.isSelected ? 1.0 : (_slot.isCycling ? 0.85 : (_slot._shov ? 0.75 : 0.45))

                    DaggerGlyph {
                        id: _fanGlyph
                        anchors.centerIn: parent
                        width: root._iconW
                        height: root._iconH
                        bladeColor: _slot.bladeColor
                        emphasis: _slot._emphasis
                        transformOrigin: Item.Bottom
                        rotation: _slot._fanAngle
                        scale: _slot.isSelected ? 1.3 : (_slot.isCycling ? 1.15 : (_slot._shov ? 1.08 : 1.0))
                        Behavior on rotation { enabled: !ShellSettings.reduceMotion; NumberAnimation { duration: Motion.medium; easing.type: Easing.OutBack } }
                        Behavior on scale    { enabled: !ShellSettings.reduceMotion; NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                    }

                    // Selection underline glow
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: parent.width * 0.5
                        height: 2
                        radius: 1
                        color: _slot.bladeColor
                        opacity: _slot.isSelected ? 1.0 : (_slot.isCycling ? 0.5 : 0.0)
                        Behavior on opacity { enabled: !ShellSettings.reduceMotion; NumberAnimation { duration: Motion.medium } }
                    }
                }
            }
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: "Dagger wheel"
    Accessible.description: "Katarina's blade wheel. Cycle through 6 blades and pick one to theme the shell."
}
