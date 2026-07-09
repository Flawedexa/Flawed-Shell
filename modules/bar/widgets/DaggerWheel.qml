import QtQuick
import QtQuick.Shapes
import "../../../config"
import "../../../services"
import "../../common"

// DaggerWheel.qml — Katarina's blade wheel as a living, pickable bar widget.
//
// Geometry: traced from the actual Battle Queen Katarina glTF mesh, using
// ALL SIX connected pieces of the Blade1-material submesh — blade, curved
// guard/hook, twin hilt prongs, and the pommel ring/tip — unioned and
// lightly simplified (68-point outline). Not just the blade shaft.
//
// Rendering: two-tone fill. The blade shaft reads as pale tinted steel;
// the guard/prong/pommel portion (bottom ~42% of the shape) is clipped and
// re-filled with the fully saturated blade color, plus a small bright gem
// dot where the ring sits — so it reads as "steel blade, jeweled hilt"
// rather than one flat colored silhouette.
//
// Colors: extracted from the real Gem1–Gem6 textures on that model
// (peak-saturation pixel per gem).
//
// Requires (add to ShellSettings if not already present):
//   property bool barShowDaggerWheel: true
//   property int  daggerWheelSelected: -1   // persists the chosen blade
// and a barWidgetMeta entry:
//   daggerWheel: { setting: "barShowDaggerWheel", label: "Dagger Wheel" }
//
// THEME HOOK: applies the pick via `ShellSettings.accentColor` in _select().
// Swap that one line if your accent setting has a different name/API.

Item {
    id: root
    readonly property bool show: ShellSettings.barShowDaggerWheel
    visible: show

    readonly property var _colors: ["#d8008e", "#c604e7", "#00dfc6", "#ef0c18", "#10a6ff", "#4a34b5"]
    readonly property var _names:  ["Death", "Sinister", "Bloodstone", "Deadly", "Redeemed", "Prestige"]

    // full 6-piece traced outline: blade + guard hook + twin prongs + pommel ring/tip
    readonly property string _bladePath: "M3.08,59.9 L3.47,58.64 L0.72,54.97 L0.01,52.22 L0.0,48.48 L1.38,47.91 L2.09,50.37 L3.47,52.06 L5.06,53.21 L5.19,46.93 L5.23,41.94 L5.33,37.7 L5.43,29.3 L5.63,20.61 L5.94,12.26 L6.15,8.56 L6.42,4.73 L6.82,0.0 L7.23,4.73 L7.5,8.56 L7.71,12.26 L8.02,20.61 L8.13,25.1 L8.22,29.3 L8.32,37.7 L8.42,41.94 L8.46,46.93 L8.62,55.07 L8.08,58.69 L9.5,60.89 L11.03,63.09 L11.72,64.91 L11.81,68.05 L10.78,70.52 L9.81,72.28 L8.59,73.53 L8.71,75.0 L8.37,77.02 L8.93,78.37 L8.87,78.73 L8.18,80.17 L8.17,81.86 L8.08,83.46 L8.53,84.58 L8.56,85.07 L7.96,85.69 L7.91,89.1 L8.51,93.8 L8.96,95.18 L6.83,100.0 L4.7,95.18 L5.14,93.78 L5.75,89.08 L5.71,85.71 L5.09,85.07 L5.12,84.58 L5.57,83.46 L5.49,81.86 L5.47,80.17 L4.78,78.73 L4.72,78.37 L5.27,77.06 L5.08,75.72 L4.14,72.08 L3.96,71.75 L3.08,69.4 L2.35,64.65 L3.08,59.9 Z"
    readonly property real _pathW: 11.81
    readonly property real _pathH: 100.0
    // where the hilt (guard+prongs+pommel) begins, as a fraction of height from the top
    readonly property real _hiltStartFrac: 0.58
    // gem position within the path's own coordinate space
    readonly property real _gemX: 5.91
    readonly property real _gemY: 84.55

    property int selectedIndex: -1
    property bool expanded: false

    readonly property int _iconH: 30
    readonly property int _iconW: Math.round(_iconH * (_pathW / _pathH))

    implicitHeight: parent ? parent.height : _iconH
    implicitWidth: _closedIcon.width + (expanded ? _wheelClip.width : 0) + (expanded ? Metrics.widgetGap : 0)

    readonly property bool _hov: (_hoverMain.hovered && ShellSettings.barHoverHighlight) || activeFocus

    function _select(index) {
        root.selectedIndex = index
        _idleTimer.stop()
        // THEME HOOK — adjust to your actual accent-setting API if different
        ShellSettings.neutralAccent = root._colors[index]
        _closeDelay.restart()
    }

    function _resetToIdle() {
        root.selectedIndex = -1
        _idleTimer.restart()
    }

    property int previewIndex: 0
    Timer {
        id: _idleTimer
        interval: 1800
        running: root.show && root.selectedIndex === -1 && !ShellSettings.reduceMotion
        repeat: true
        onTriggered: root.previewIndex = (root.previewIndex + 1) % root._colors.length
    }

    Timer {
        id: _closeDelay
        interval: 260
        onTriggered: root.expanded = false
    }

    Behavior on implicitWidth {
        enabled: !ShellSettings.reduceMotion
        NumberAnimation { duration: Motion.medium; easing.type: Easing.OutCubic }
    }

    // ---- reusable two-tone dagger visual ----
    component DaggerGlyph: Item {
        id: glyph
        property color bladeColor: "#ffffff"
        property real emphasis: 1.0   // 0..1, dims when not selected/hovered in the wheel
        property bool showGem: true

        readonly property color _steel: Theme.mix(bladeColor, "#ffffff", 0.6)
        readonly property color _hilt:  bladeColor
        readonly property color _gem:   Theme.mix(bladeColor, "#ffffff", 0.55)

        // base: full silhouette in pale steel tone
        Shape {
            id: _base
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

        // hilt overlay: bottom portion re-filled with the saturated blade color
        Item {
            id: _hiltClip
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

        // gem spark at the ring
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

    // ---- closed / main icon ----
    Item {
        id: _closedIcon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root._iconW + 12
        height: root._iconH

        readonly property int displayIndex: root.selectedIndex >= 0 ? root.selectedIndex : root.previewIndex
        readonly property color displayColor: root._colors[displayIndex]

        HoverHandler { id: _hoverMain; cursorShape: Qt.PointingHandCursor }
        TapHandler { acceptedButtons: Qt.LeftButton; onTapped: root.expanded = !root.expanded }
        TapHandler { acceptedButtons: Qt.RightButton; onTapped: root._resetToIdle() }

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

    // ---- expanded wheel: six blades fanned like a hand of cards ----
    Item {
        id: _wheelClip
        anchors.left: _closedIcon.right
        anchors.leftMargin: root.expanded ? Metrics.widgetGap : 0
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
            spacing: 8

            Repeater {
                model: root._colors.length
                delegate: Item {
                    id: _slot
                    required property int index
                    readonly property color blade: root._colors[index]
                    readonly property bool isSelected: index === root.selectedIndex
                    width: root._iconW + 8
                    height: root._iconH + 10

                    readonly property bool _shov: _hoverSlot.hovered && ShellSettings.barHoverHighlight
                    HoverHandler { id: _hoverSlot; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root._select(_slot.index) }

                    readonly property real _fanAngle: (index - (root._colors.length - 1) / 2) * 7

                    DaggerGlyph {
                        id: _fanGlyph
                        anchors.centerIn: parent
                        width: root._iconW
                        height: root._iconH
                        bladeColor: _slot.blade
                        emphasis: _slot.isSelected ? 1.0 : (_slot._shov ? 0.85 : 0.55)
                        transformOrigin: Item.Bottom
                        rotation: _slot._fanAngle
                        scale: _slot.isSelected ? 1.25 : (_slot._shov ? 1.15 : 1.0)
                        Behavior on rotation { enabled: !ShellSettings.reduceMotion; NumberAnimation { duration: Motion.medium; easing.type: Easing.OutBack } }
                        Behavior on scale    { enabled: !ShellSettings.reduceMotion; NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: "Dagger wheel"
    Accessible.description: "Katarina's blade wheel. Activate to choose a blade and apply its theme."
}
