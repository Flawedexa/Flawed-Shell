# Shared by install.sh, check.sh, and CI: one module list, one import-root
# lookup, instead of three diverging copies. Quickshell packages may split
# service plugins even when the `qs` binary exists, so check actual QML
# import paths rather than assuming one distro layout.

FLAWED_REQUIRED_QML_MODULES=(
    Quickshell.Bluetooth
    Quickshell.Hyprland
    Quickshell.Services.Mpris
    Quickshell.Services.Notifications
    Quickshell.Services.Pipewire
    Quickshell.Services.SystemTray
    Quickshell.Services.UPower
    Quickshell.Wayland
    Quickshell.Widgets
)

_flawed_qml_import_roots=()
if [ -n "${QML2_IMPORT_PATH:-}" ]; then
    IFS=: read -r -a _flawed_qml_import_roots <<< "$QML2_IMPORT_PATH"
fi
if [ -n "${QML_IMPORT_PATH:-}" ]; then
    _flawed_qml_extra_roots=()
    IFS=: read -r -a _flawed_qml_extra_roots <<< "$QML_IMPORT_PATH"
    _flawed_qml_import_roots+=("${_flawed_qml_extra_roots[@]}")
    unset _flawed_qml_extra_roots
fi
for _flawed_qtpaths in qtpaths6 qtpaths; do
    if command -v "$_flawed_qtpaths" >/dev/null 2>&1; then
        _flawed_qml_qt_root="$("$_flawed_qtpaths" --query QT_INSTALL_QML 2>/dev/null || true)"
        [ -n "$_flawed_qml_qt_root" ] && _flawed_qml_import_roots+=("$_flawed_qml_qt_root")
        unset _flawed_qml_qt_root
        break
    fi
done
unset _flawed_qtpaths
_flawed_qml_import_roots+=(/usr/lib/qt6/qml /usr/lib64/qt6/qml /usr/local/lib/qt6/qml)

_qml_module_available() {
    local module_path="${1//./\/}" root
    for root in "${_flawed_qml_import_roots[@]}"; do
        [ -n "$root" ] || continue
        [ -r "$root/$module_path/qmldir" ] && return 0
    done
    return 1
}
