pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.DBusMenu
import Quickshell.Widgets
import Quickshell.Wayland._WlrLayerShell
import Quickshell.Hyprland
import "../../config"
import "../../services"
import "../common"

// Tray context menu rendered in QML so it speaks Theme instead of the native platform menu.
PanelWindow {
    id: win

    required property ShellScreen targetScreen

    readonly property HyprlandMonitor _monitor: Hyprland.monitorFor(win.screen)
    readonly property int menuWidth: 220
    readonly property real _cardRadius: Theme.radiusPanel
    property bool _ignoreOutsideTap: false

    // holds the last handle through the close fade so rows don't collapse early
    property var _activeMenu: null
    property bool _rootOpenedSent: false

    function _menuRoot() {
        return win._activeMenu?.menu ?? win._activeMenu
    }
    function _emitMenuSignal(entry, signalName: string, fallbackName: string): bool {
        if (entry === null || entry === undefined) return false

        const fn = entry[signalName]
        if (typeof fn === "function") {
            fn()
            return true
        }

        const fallback = entry[fallbackName]
        if (typeof fallback === "function") {
            fallback()
            return true
        }

        console.warn("Flawed-Shell: tray menu entry has no", signalName, "signal")
        return false
    }
    function _sendRootOpened(): void {
        if (_rootOpenedSent || !TrayMenuState.open) return
        if (_emitMenuSignal(_menuRoot(), "opened", "sendOpened"))
            _rootOpenedSent = true
    }
    function _sendRootClosed(): void {
        if (!_rootOpenedSent) return
        _emitMenuSignal(_menuRoot(), "closed", "sendClosed")
        _rootOpenedSent = false
    }
    function _setActiveMenu(handle): void {
        if (win._activeMenu === handle) return
        win._sendRootClosed()
        win._activeMenu = handle
        win._sendRootOpened()
    }

    // ── Submenu overlays (at win level, outside clipped Flickable) ──
    property Item _subOwner:  null
    property var  _subHandle: null
    property Item _subOwner2: null
    property var  _subHandle2: null

    QsMenuOpener { id: _subOpener;  menu: win._subHandle }
    QsMenuOpener { id: _subOpener2; menu: win._subHandle2 }

    // Walk parent chain manually so QML tracks each parent's x/y as
    // dependency bindings – mapToItem() results are NOT dependency-tracked.
    function _walkUp(item: Item): var {
        if (!item) return Qt.point(0, 0)
        var x = 0, y = 0
        var cur = item
        while (cur && cur !== win) {
            x += cur.x
            y += cur.y
            cur = cur.parent
        }
        return Qt.point(x, y)
    }

    function _getOverlayLevel(item: Item): int {
        var p = item
        while (p) {
            if (p === _subOverlay2) return 2
            if (p === _subOverlay)  return 1
            p = p.parent
        }
        return 0
    }

    function _openSubmenu(entry: Item): void {
        if (!entry || !entry.sub) return
        if (win._subOwner === entry) return

        win._closeSubmenu2()
        if (win._subHandle !== null)
            win._emitMenuSignal(win._subHandle, "closed", "sendClosed")

        win._subOwner = entry
        win._subHandle = entry.modelData

        Qt.callLater(() => {
            if (win._subHandle === entry.modelData)
                win._emitMenuSignal(win._subHandle, "opened", "sendOpened")
        })
    }

    function _toggleSubmenu(entry: Item): void {
        if (!entry || !entry.sub) return
        if (win._subOwner === entry) { win._closeSubmenu(); return }
        win._openSubmenu(entry)
    }

    function _closeSubmenu(): void {
        win._closeSubmenu2()
        if (win._subHandle !== null)
            win._emitMenuSignal(win._subHandle, "closed", "sendClosed")
        win._subOwner = null
        win._subHandle = null
    }

    function _openSubmenu2(entry: Item): void {
        if (!entry || !entry.sub) return
        if (win._subOwner2 === entry) return

        if (win._subHandle2 !== null)
            win._emitMenuSignal(win._subHandle2, "closed", "sendClosed")

        win._subOwner2 = entry
        win._subHandle2 = entry.modelData

        Qt.callLater(() => {
            if (win._subHandle2 === entry.modelData)
                win._emitMenuSignal(win._subHandle2, "opened", "sendOpened")
        })
    }

    function _toggleSubmenu2(entry: Item): void {
        if (!entry || !entry.sub) return
        if (win._subOwner2 === entry) { win._closeSubmenu2(); return }
        win._openSubmenu2(entry)
    }

    function _closeSubmenu2(): void {
        if (win._subHandle2 !== null)
            win._emitMenuSignal(win._subHandle2, "closed", "sendClosed")
        win._subOwner2 = null
        win._subHandle2 = null
    }

    function _focusFirstSubItem(level: int): void {
        const ov = level === 2 ? _subOverlay2 : _subOverlay
        const col = level === 2 ? _subCol2 : _subCol
        if (!ov || !ov.visible) return
        const subs = col.children
        for (let k = 0; k < subs.length; k++) {
            const c = subs[k]
            if (c && c.isMenuRow === true && c.on) { c.forceActiveFocus(); return }
        }
    }

    readonly property bool _subVisible:  win._subOwner  !== null
    readonly property bool _subVisible2: win._subOwner2 !== null

    // Prevent flicker: wait for layout to settle before showing overlay.
    property bool _subReady:  false
    property bool _subReady2: false
    on_SubOwnerChanged: {
        if (win._subOwner) {
            _subOverlay.opacity = 0
            _subReady = false
            _subReadyTimer.restart()
        } else {
            _subReady = false
        }
    }
    on_SubOwner2Changed: {
        if (win._subOwner2) {
            _subOverlay2.opacity = 0
            _subReady2 = false
            _subReadyTimer2.restart()
        } else {
            _subReady2 = false
        }
    }
    Timer {
        id: _subReadyTimer
        interval: 60
        onTriggered: _subReady = true
    }
    Timer {
        id: _subReadyTimer2
        interval: 60
        onTriggered: _subReady2 = true
    }

    onVisibleChanged: if (!visible) win._setActiveMenu(null)
    // lazy-loaded after openAt() already set the handle, so the change signal
    // fired before this popup existed; seed from the current state on creation
    Component.onCompleted: if (TrayMenuState.menuHandle !== null) win._setActiveMenu(TrayMenuState.menuHandle)
    Connections {
        target: TrayMenuState
        function onMenuHandleChanged() {
            if (TrayMenuState.menuHandle !== null) win._setActiveMenu(TrayMenuState.menuHandle)
        }
    }

    Connections {
        target: win._monitor
        function onActiveWorkspaceChanged() { if (TrayMenuState.open) TrayMenuState.close() }
    }

    screen:        targetScreen
    color:         "transparent"
    exclusiveZone: -1
    WlrLayershell.namespace: "flawed-traymenu"
    WlrLayershell.keyboardFocus: TrayMenuState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: TrayMenuState.open || card.opacity > 0.001

    anchors { top: true; left: true; right: true; bottom: true }

    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; enabled: TrayMenuState.open; onActivated: TrayMenuState.close() }

    Connections {
        target: ShellSettings
        function onBarPositionChanged() {
            if (!TrayMenuState.open) return
            win._ignoreOutsideTap = true
            _outsideTapGuard.restart()
        }
    }

    Connections {
        target: TrayMenuState
        function onOpenChanged() {
            if (!TrayMenuState.open) {
                win._closeSubmenu()
                _outsideTapGuard.stop()
                win._ignoreOutsideTap = false
                win._sendRootClosed()
            } else {
                win._sendRootOpened()
            }
        }
    }

    Timer {
        id: _outsideTapGuard
        interval: 250
        repeat: false
        onTriggered: win._ignoreOutsideTap = false
    }

    QsMenuOpener {
        id: _opener
        menu: win._menuRoot()
    }

    Item { id: _fillArea; anchors.fill: parent }
    mask: Region { item: TrayMenuState.open ? _fillArea : null }

    TapHandler {
        id: _dismiss
        enabled: TrayMenuState.open && card.scaleAmt > 0.95
        onTapped: {
            if (win._ignoreOutsideTap) return
            const p = _dismiss.point.position
            if (p.x < card.x || p.x > card.x + card.width ||
                p.y < card.y || p.y > card.y + card.height)
                TrayMenuState.close()
        }
    }

    // recurses into itself for submenu flyouts, any nesting depth
    Component {
        id: _rowDelegate

        Item {
            id: _entry
            required property var modelData

            readonly property bool sep:       modelData?.isSeparator ?? false
            readonly property bool on:        (modelData?.enabled ?? true) && !sep
            readonly property bool sub:       modelData?.hasChildren ?? false
            readonly property int  btnType:   modelData?.buttonType ?? 0
            readonly property bool checkable: btnType !== 0
            readonly property bool checked:   (modelData?.checkState ?? Qt.Unchecked) === Qt.Checked
            readonly property string iconSrc: modelData?.icon ?? ""
            // duck-type marker so focus movement can skip the Repeater and separators
            readonly property bool isMenuRow: !sep
            readonly property int  _overlayLevel: win._getOverlayLevel(_entry)
            readonly property bool subActive:  win._subOwner === _entry || win._subOwner2 === _entry
            readonly property bool hovered:    _rowHover.hovered

            width: win.menuWidth
            height: sep ? 11 : 32

            function _moveFocus(dir: int): void {
                const sibs = _entry.parent ? _entry.parent.children : []
                let i = -1
                for (let k = 0; k < sibs.length; k++) if (sibs[k] === _entry) { i = k; break }
                if (i < 0) return
                for (let k = i + dir; k >= 0 && k < sibs.length; k += dir) {
                    const c = sibs[k]
                    if (c && c.isMenuRow === true && c.on) { c.forceActiveFocus(); return }
                }
            }
            function _focusFirstSub(level: int): void {
                win._focusFirstSubItem(level)
            }
            function _activate(): void {
                if (!_entry.on) return
                if (_entry.sub) {
                    if (_entry._overlayLevel >= 1) {
                        win._toggleSubmenu2(_entry)
                        if (win._subOwner2 === _entry) Qt.callLater(() => _entry._focusFirstSub(2))
                    } else {
                        win._toggleSubmenu(_entry)
                        if (win._subOwner === _entry) Qt.callLater(() => _entry._focusFirstSub(1))
                    }
                } else {
                    win._emitMenuSignal(_entry.modelData, "triggered", "sendTriggered")
                    TrayMenuState.close()
                }
            }

            Component.onDestruction: {
                if (win._subOwner  === _entry) win._closeSubmenu()
                if (win._subOwner2 === _entry) win._closeSubmenu2()
            }

            activeFocusOnTab: _entry.on
            Accessible.role: Accessible.MenuItem
            Accessible.name: _entry.modelData?.text ?? ""
            Keys.onUpPressed:     e => { _entry._moveFocus(-1); e.accepted = true }
            Keys.onDownPressed:   e => { _entry._moveFocus(1);  e.accepted = true }
            Keys.onSpacePressed:  e => { if (!e.isAutoRepeat) _entry._activate(); e.accepted = true }
            Keys.onReturnPressed: e => { if (!e.isAutoRepeat) _entry._activate(); e.accepted = true }
            Keys.onEnterPressed:  e => { if (!e.isAutoRepeat) _entry._activate(); e.accepted = true }
            Keys.onRightPressed: e => {
                if (_entry.sub) {
                    if (_entry._overlayLevel >= 1) {
                        if (win._subOwner2 !== _entry) win._openSubmenu2(_entry)
                        Qt.callLater(() => _entry._focusFirstSub(2))
                    } else {
                        if (win._subOwner !== _entry) win._openSubmenu(_entry)
                        Qt.callLater(() => _entry._focusFirstSub(1))
                    }
                    e.accepted = true
                } else {
                    e.accepted = false
                }
            }
            Keys.onLeftPressed: e => {
                if (win._subOwner2 === _entry) { win._closeSubmenu2(); e.accepted = true }
                else if (win._subOwner === _entry) { win._closeSubmenu(); e.accepted = true }
                else e.accepted = false
            }

            Rectangle {
                visible: _entry.sep
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                color: Theme.menuDivider
            }

            Rectangle {
                visible: !_entry.sep
                anchors.fill: parent
                radius: Theme.radiusControl
                antialiasing: true
                color: (_entry.on && (_entry.hovered || _entry.subActive || _entry.activeFocus))
                    ? Theme.withAlpha(Theme.menuHover, 0.12) : "transparent"
                Behavior on color { enabled: !ShellSettings.reduceMotion; ColorAnimation { duration: Motion.fast } }
            }

            HoverHandler {
                id: _rowHover
                enabled: _entry.on
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: {
                    if (!hovered || !_entry.sub) return
                    if (_entry._overlayLevel >= 1) win._openSubmenu2(_entry)
                    else win._openSubmenu(_entry)
                }
            }
            TapHandler {
                enabled: _entry.on && !_entry.sub
                onTapped: {
                    win._emitMenuSignal(_entry.modelData, "triggered", "sendTriggered")
                    TrayMenuState.close()
                }
            }
            TapHandler {
                enabled: _entry.on && _entry.sub
                onTapped: {
                    if (_entry._overlayLevel >= 1) win._toggleSubmenu2(_entry)
                    else win._toggleSubmenu(_entry)
                }
            }

            Item {
                visible: !_entry.sep
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                opacity: _entry.on ? 1.0 : 0.4

                // Check / radio marker, or icon, share the leading slot.
                Item {
                    id: _mark
                    visible: _entry.checkable
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: visible ? Settings.fontSize : 0
                    height: Settings.fontSize

                    Text {
                        anchors.centerIn: parent
                        visible: _entry.btnType === 1 && _entry.checked
                        text: "󰄬"
                        color: Theme.accent
                        font.family: Settings.font; font.pixelSize: Settings.fontSize
                        renderType: Text.NativeRendering
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        visible: _entry.btnType === 2
                        width: 8; height: 8; radius: 4
                        antialiasing: true
                        color: _entry.checked ? Theme.accent : "transparent"
                        border.width: _entry.checked ? 0 : 1
                        border.color: Theme.withAlpha(Theme.subtext, 0.5)
                    }
                }

                IconImage {
                    id: _icon
                    visible: !_entry.checkable && _entry.iconSrc !== "" && status === Image.Ready
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: Settings.fontSize + 4
                    source: _entry.iconSrc
                    asynchronous: true
                }

                Text {
                    anchors.left: _entry.checkable ? _mark.right : _icon.visible ? _icon.right : parent.left
                    anchors.leftMargin: (_entry.checkable || _icon.visible) ? 8 : 0
                    anchors.right: _arrow.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: _entry.modelData?.text ?? ""
                    textFormat: Text.PlainText
                    color: Theme.text
                    font.family: Settings.font; font.pixelSize: Settings.fontSize
                    renderType: Text.NativeRendering
                    elide: Text.ElideRight
                }

                Text {
                    id: _arrow
                    visible: _entry.sub
                    width: visible ? implicitWidth : 0
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰅂"
                    color: Theme.withAlpha(Theme.subtext, 0.7)
                    font.family: Settings.font; font.pixelSize: Settings.fontSize
                    renderType: Text.NativeRendering
                }
            }

            // Close logic handled by win-level _subCloseWatch timer
        }
    }

    // Floating drop shadow, same elevation cue as the bar/OSD/notification cards.
    Loader {
        active: TrayMenuState.open && ShellSettings.barFloating && ShellSettings.barShadow
        anchors.fill: card
        opacity: card.opacity
        z: -1
        sourceComponent: FloatingShadow {
            radius: card.radius
            atBottom: card.barBottom
        }
    }

    FloatingPopupCard {
        id: card
        win: win
        open: TrayMenuState.open
        anchorX: TrayMenuState.anchorX
        barBottom: TrayMenuState.barBottom

        readonly property int pad: 6
        readonly property real _maxContentH: Math.max(48, win.height - _edgeY - pad * 2 - 8)

        width:  win.menuWidth + pad * 2
        height: Math.min(_col.implicitHeight, _maxContentH) + pad * 2
        radius: Math.min(win._cardRadius, height / 2)

        // The card holds focus on open (paints nothing) so a mouse-open shows
        // no row highlight; Down/Tab hands focus to the first usable row.
        function _focusFirstRow(): void {
            const sibs = _col.children
            for (let k = 0; k < sibs.length; k++) {
                const c = sibs[k]
                if (c && c.isMenuRow === true && c.on) { c.forceActiveFocus(); return }
            }
        }
        Keys.onDownPressed: e => { card._focusFirstRow(); e.accepted = true }
        Keys.onUpPressed:   e => { card._focusFirstRow(); e.accepted = true }
        Connections {
            target: TrayMenuState
            function onOpenChanged() { if (TrayMenuState.open) card.forceActiveFocus() }
        }
        Component.onCompleted: if (TrayMenuState.open) card.forceActiveFocus()

        Flickable {
            id: _scroll
            x: card.pad; y: card.pad
            width: win.menuWidth
            height: Math.max(0, card.height - card.pad * 2)
            contentWidth: width
            contentHeight: _col.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 1800
            maximumFlickVelocity: 2200
            clip: true
            interactive: contentHeight > height

            Column {
                id: _col
                width: win.menuWidth
                spacing: 1

                Repeater {
                    model: _opener.children
                    delegate: _rowDelegate
                }
            }
        }

        ListEdgeFade {
            anchors.fill: _scroll
            visible: _scroll.interactive
            list: _scroll
        }
    }

    // ── Submenu overlay (at win level so it is never clipped) ──────────────
    Rectangle {
        id: _subOverlay
        visible: win._subVisible && win._subReady
        opacity: 0
        z: 20

        Behavior on opacity { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
        onVisibleChanged: if (visible) opacity = 1

        readonly property Item _owner: win._subOwner
        readonly property real _subW: win.menuWidth + 6 * 2
        readonly property real _subH: Math.min(
            _subCol.implicitHeight + 6 * 2, Math.max(48, win.height - 8))

        // Position computed via win._walkUp (shared helper on win).
        readonly property var _entryPos: win._walkUp(_owner)
        readonly property real _entryWinX: _entryPos.x
        readonly property real _entryWinY: _entryPos.y
        readonly property real _entryW:    _owner ? _owner.width : 0
        readonly property bool _flip: _entryWinX + _entryW + 4 + _subW > win.width

        x: _flip ? _entryWinX - _subW - 4 : _entryWinX + _entryW + 4
        y: _entryWinY + Math.max(
            4 - _entryWinY,
            Math.min(-6, win.height - 4 - _entryWinY - _subH)
        )

        width:  _subOverlay._subW
        height: _subOverlay._subH
        radius: Math.min(win._cardRadius, height / 2)
        antialiasing: true
        color: Theme.popup
        border.width: 1
        border.color: Theme.outline

        HoverHandler { id: _subHover }

        Flickable {
            id: _subFlick
            x: 6; y: 6
            width: win.menuWidth
            height: Math.max(0, _subOverlay.height - 12)
            contentWidth: width
            contentHeight: _subCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 1800
            maximumFlickVelocity: 2200
            clip: true
            interactive: contentHeight > height

            Column {
                id: _subCol
                width: win.menuWidth
                spacing: 1

                Repeater {
                    model: _subOpener.children
                    delegate: _rowDelegate
                }
            }
        }

        ListEdgeFade {
            anchors.fill: _subFlick
            visible: _subFlick.interactive
            list: _subFlick
        }
    }

    // ── Submenu overlay level 2 (nested sub-submenus) ─────────────────────
    Rectangle {
        id: _subOverlay2
        visible: win._subVisible2 && win._subReady2
        opacity: 0
        z: 25

        Behavior on opacity { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
        onVisibleChanged: if (visible) opacity = 1

        readonly property Item _owner2: win._subOwner2
        readonly property real _subW2: win.menuWidth + 6 * 2
        readonly property real _subH2: Math.min(
            _subCol2.implicitHeight + 6 * 2, Math.max(48, win.height - 8))

        readonly property var _entryPos2: win._walkUp(_owner2)
        readonly property real _entryWinX2: _entryPos2.x
        readonly property real _entryWinY2: _entryPos2.y
        readonly property real _entryW2: _owner2 ? _owner2.width : 0
        readonly property bool _flip2: _entryWinX2 + _entryW2 + 4 + _subW2 > win.width

        x: _flip2 ? _entryWinX2 - _subW2 - 4 : _entryWinX2 + _entryW2 + 4
        y: _entryWinY2 + Math.max(
            4 - _entryWinY2,
            Math.min(-6, win.height - 4 - _entryWinY2 - _subH2)
        )

        width:  _subOverlay2._subW2
        height: _subOverlay2._subH2
        radius: Math.min(win._cardRadius, height / 2)
        antialiasing: true
        color: Theme.popup
        border.width: 1
        border.color: Theme.outline

        HoverHandler { id: _subHover2 }

        Flickable {
            id: _subFlick2
            x: 6; y: 6
            width: win.menuWidth
            height: Math.max(0, _subOverlay2.height - 12)
            contentWidth: width
            contentHeight: _subCol2.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 1800
            maximumFlickVelocity: 2200
            clip: true
            interactive: contentHeight > height

            Column {
                id: _subCol2
                width: win.menuWidth
                spacing: 1

                Repeater {
                    model: _subOpener2.children
                    delegate: _rowDelegate
                }
            }
        }

        ListEdgeFade {
            anchors.fill: _subFlick2
            visible: _subFlick2.interactive
            list: _subFlick2
        }
    }
}
