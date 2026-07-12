pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../../config"
import "../../services"

Item {
    id: root
    width: parent ? parent.width : 0

    property var _images: []
    property int _offset: 0
    readonly property int _maxOffset: Math.max(0, _images.length - 3)

    function _setWallpaper(path: string): void {
        ShellSettings.wallpaperCurrent = path
        const cmd = "awww img \"" + path + "\" 2>/dev/null || " +
            "swww img \"" + path + "\" 2>/dev/null || " +
            "(pkill -x swaybg 2>/dev/null; swaybg -i \"" + path + "\" -m fill &)"
        _setter.exec(["bash", "-c", cmd])
        if (ShellSettings.matugenAuto)
            _matuGen.exec(["matugen", "image", path,
                "--json", "hex", "--prefer", "darkness"])
    }



    function _randomWallpaper(): void {
        if (root._images.length === 0) return
        const pick = root._images[Math.floor(Math.random() * root._images.length)]
        root._setWallpaper(pick)
    }

    function _scanWallpapers(): void {
        const dir = ShellSettings.wallpaperDir
        if (!dir || dir.length === 0) { root._images = []; return }
        _scanner.exec(["bash", "-c",
            "d=\"" + dir + "\"; d=\"${d/#\\~/$HOME}\"; ls -1 \"$d\" 2>/dev/null | grep -iE '\\.(jpg|jpeg|png|gif|bmp|webp)$' | sort | while IFS= read -r f; do echo \"$d/$f\"; done"])
    }

    Process {
        id: _scanner
        stdout: StdioCollector { id: _scanOut }
        onExited: {
            if (exitCode !== 0) { root._images = []; return }
            const lines = (_scanOut.text || "").split(/\r?\n/).filter(l => l.trim().length > 0)
            root._images = lines
            root._restoreOffset()
        }
    }

    Process {
        id: _setter
    }

    Process {
        id: _matuGen
        stdout: StdioCollector { id: _matuOut }
        onExited: {
            if (exitCode !== 0) return
            const raw = (_matuOut.text ?? "").trim()
            // matugen outputs JSON to stdout; extract the actual JSON payload.
            // The output may contain banner/log lines before the JSON block.
            const brace = raw.indexOf("{")
            if (brace < 0) return
            MatugenColors.updateFromJson(raw.substring(brace))
        }
    }

    onVisibleChanged: { if (visible) _scanWallpapers() }
    Component.onCompleted: _scanWallpapers()

    function _isActive(slot: int): bool {
        const idx = root._offset + slot
        return idx >= 0 && idx < root._images.length
            && root._images[idx] === ShellSettings.wallpaperCurrent
    }

    function _restoreOffset(): void {
        const activeIdx = root._images.indexOf(ShellSettings.wallpaperCurrent)
        if (activeIdx >= 0)
            root._offset = Math.max(0, Math.min(activeIdx - 1, root._images.length - 3))
        else
            root._offset = 0
    }

    function _refreshImages(): void {
        const imgs = [_img0, _img1, _img2]
        for (let i = 0; i < 3; i++) {
            const idx = root._offset + i
            const src = idx < root._images.length
                ? "file://" + root._images[idx].replace(/ /g, "%20")
                : ""
            imgs[i].source = src
        }
    }

    on_ImagesChanged: _refreshImages()
    on_OffsetChanged: _refreshImages()

    implicitHeight: _sec.implicitHeight

    Column {
        id: _sec
        width: parent.width
        spacing: 0

        SectionLabel { label: "WALLPAPER" }

        SettingsCard {
            id: _card
            width: parent.width

            Column {
                id: _col
                width: parent.width
                spacing: 0
                property bool isRadiusGroup: true
                property Item radiusColumn: _col

                Item {
                    width: parent.width
                    height: 44
                    property real topRadius: _card.radius
                    property real bottomRadius: 0

                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Folder"
                        color: Theme.withAlpha(Theme.subtext, 0.66)
                        font.family: Settings.font
                        font.pixelSize: Settings.fontSize - 1
                        renderType: Text.NativeRendering
                    }
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 62
                        anchors.right: parent.right; anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: ShellSettings.wallpaperDir
                        color: Theme.text
                        font.family: Settings.font
                        font.pixelSize: Settings.fontSize
                        elide: Text.ElideLeft
                        renderType: Text.NativeRendering
                    }
                }

                Item {
                    id: _carousel
                    width: parent.width
                    height: 90
                    property real topRadius: 0
                    property real bottomRadius: _card.radius
                    visible: _images.length > 0

                    Rectangle {
                        x: 8
                        y: (parent.height - height) / 2
                        width: 24; height: 50; radius: 6
                        visible: root._offset > 0
                        color: Theme.menuControl
                        border.width: 1
                        border.color: Theme.menuControlLine
                        Text {
                            anchors.centerIn: parent
                            text: "\u25C0"
                            color: Theme.text
                            font.pixelSize: 13
                            renderType: Text.NativeRendering
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._offset = Math.max(0, root._offset - 1)
                        }
                    }

                    Item {
                        x: 40; y: 5; width: 110; height: 80
                        clip: true
                        Rectangle { anchors.fill: parent; color: Theme.menuBase; radius: 4 }
                        Image {
                            id: _img0
                            anchors.fill: parent
                            anchors.margins: 2
                            fillMode: Image.PreserveAspectCrop
                        }
                        Rectangle {
                            anchors.top: parent.top; anchors.right: parent.right
                            anchors.topMargin: 4; anchors.rightMargin: 4
                            width: 18; height: 18; radius: 9
                            color: Theme.accent
                            visible: root._isActive(0)
                            Text {
                                anchors.centerIn: parent
                                text: "\u2713"
                                color: "white"
                                font.pixelSize: 10
                                font.bold: true
                                renderType: Text.NativeRendering
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const idx = root._offset + 0
                                if (idx < root._images.length) root._setWallpaper(root._images[idx])
                            }
                        }
                    }

                    Item {
                        x: 156; y: 5; width: 110; height: 80
                        clip: true
                        Rectangle { anchors.fill: parent; color: Theme.menuBase; radius: 4 }
                        Image {
                            id: _img1
                            anchors.fill: parent
                            anchors.margins: 2
                            fillMode: Image.PreserveAspectCrop
                        }
                        Rectangle {
                            anchors.top: parent.top; anchors.right: parent.right
                            anchors.topMargin: 4; anchors.rightMargin: 4
                            width: 18; height: 18; radius: 9
                            color: Theme.accent
                            visible: root._isActive(1)
                            Text {
                                anchors.centerIn: parent
                                text: "\u2713"
                                color: "white"
                                font.pixelSize: 10
                                font.bold: true
                                renderType: Text.NativeRendering
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const idx = root._offset + 1
                                if (idx < root._images.length) root._setWallpaper(root._images[idx])
                            }
                        }
                    }

                    Item {
                        x: 272; y: 5; width: 110; height: 80
                        clip: true
                        Rectangle { anchors.fill: parent; color: Theme.menuBase; radius: 4 }
                        Image {
                            id: _img2
                            anchors.fill: parent
                            anchors.margins: 2
                            fillMode: Image.PreserveAspectCrop
                        }
                        Rectangle {
                            anchors.top: parent.top; anchors.right: parent.right
                            anchors.topMargin: 4; anchors.rightMargin: 4
                            width: 18; height: 18; radius: 9
                            color: Theme.accent
                            visible: root._isActive(2)
                            Text {
                                anchors.centerIn: parent
                                text: "\u2713"
                                color: "white"
                                font.pixelSize: 10
                                font.bold: true
                                renderType: Text.NativeRendering
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const idx = root._offset + 2
                                if (idx < root._images.length) root._setWallpaper(root._images[idx])
                            }
                        }
                    }

                    Rectangle {
                        x: parent.width - 8 - 24
                        y: (parent.height - height) / 2
                        width: 24; height: 50; radius: 6
                        visible: root._offset < root._maxOffset
                        color: Theme.menuControl
                        border.width: 1
                        border.color: Theme.menuControlLine
                        Text {
                            anchors.centerIn: parent
                            text: "\u25B6"
                            color: Theme.text
                            font.pixelSize: 13
                            renderType: Text.NativeRendering
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._offset = Math.min(root._maxOffset, root._offset + 1)
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 34
                    visible: _images.length > 0
                    Row {
                        anchors.centerIn: parent
                        spacing: 16
                        Rectangle {
                            width: 28; height: 28; radius: 6
                            color: Theme.menuControl
                            border.width: 1
                            border.color: Theme.menuControlLine
                            Text {
                                anchors.centerIn: parent
                                text: "\u21BB"
                                color: Theme.text
                                font.pixelSize: 14
                                renderType: Text.NativeRendering
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root._scanWallpapers()
                            }
                        }
                        Rectangle {
                            width: 28; height: 28; radius: 6
                            color: Theme.menuControl
                            border.width: 1
                            border.color: Theme.menuControlLine
                            Text {
                                anchors.centerIn: parent
                                text: "\u2685"
                                color: Theme.text
                                font.pixelSize: 14
                                renderType: Text.NativeRendering
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root._randomWallpaper()
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 52
                    property real topRadius: 0
                    property real bottomRadius: _card.radius
                    visible: _images.length === 0
                    Text {
                        anchors.centerIn: parent
                        text: "Add images to " + ShellSettings.wallpaperDir
                        color: Theme.withAlpha(Theme.subtext, 0.5)
                        font.family: Settings.font
                        font.pixelSize: Settings.fontSize - 1
                        renderType: Text.NativeRendering
                    }
                }
            }
        }
    }
}
