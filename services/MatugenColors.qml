pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property color background: "#131318"
    property color surface:    "#1f1f25"
    property color text:       "#e4e1e9"
    property color subtext:    "#c7c5d0"
    property color accent:     "#bfc1ff"
    property color error:      "#ffb4ab"
    property color warning:    "#e8b9d4"
    property color success:    "#c5c4dd"

    function updateFromJson(jsonStr) {
        try {
            const data = JSON.parse(jsonStr)
            const c = data?.colors
            if (!c) return
            const m = data?.mode ?? "dark"
            const _g = (name, fallback) => {
                const entry = c[name]
                if (!entry) return fallback
                return entry[m]?.color ?? entry.default?.color ?? fallback
            }
            root.background = Qt.color(_g("background", "#131318"))
            root.surface    = Qt.color(_g("surface_container", "#1f1f25"))
            root.text       = Qt.color(_g("on_surface", "#e4e1e9"))
            root.subtext    = Qt.color(_g("on_surface_variant", "#c7c5d0"))
            root.accent     = Qt.color(_g("primary", "#bfc1ff"))
            root.error      = Qt.color(_g("error", "#ffb4ab"))
            root.warning    = Qt.color(_g("tertiary", "#e8b9d4"))
            root.success    = Qt.color(_g("secondary", "#c5c4dd"))
        } catch(e) {
            console.warn("MatugenColors: failed to parse JSON —", e)
        }
    }
}
