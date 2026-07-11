#!/usr/bin/env bash
# Usage: wofi-launch.sh <bg_hex> <fg_hex> <accent_hex> <surface_hex> <xoffset> <yoffset>
set -euo pipefail

BG="${1:-#090a0c}"
FG="${2:-#f2f4f8}"
ACCENT="${3:-#bb9af7}"
SURFACE="${4:-#17191d}"
XOFF="${5:-0}"
YOFF="${6:-0}"

STYLE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wofi"
mkdir -p "$STYLE_DIR"

cat > "$STYLE_DIR/style.css" << CSS
window {
    margin: 0;
    padding: 0;
    background-color: ${BG}cc;
    border-radius: 14px;
    font-family: "JetBrainsMono Nerd Font", monospace;
    font-size: 13px;
    border: 1px solid ${ACCENT}33;
}

#outer-box {
    margin: 0;
    padding: 8px;
    background-color: transparent;
}

#input {
    margin: 4px 8px 8px 8px;
    padding: 8px 12px;
    background-color: ${SURFACE}cc;
    color: ${FG};
    border: 1px solid ${ACCENT}33;
    border-radius: 10px;
    font-family: "JetBrainsMono Nerd Font", monospace;
    font-size: 13px;
    min-height: 20px;
}

#input:focus {
    border-color: ${ACCENT};
}

#scroll {
    margin: 0 4px;
    padding: 0;
    background-color: transparent;
}

#inner-box {
    margin: 0;
    padding: 0;
    background-color: transparent;
}

#entry {
    margin: 2px 4px;
    padding: 6px 10px;
    background-color: ${SURFACE}80;
    color: ${FG};
    border-radius: 10px;
    border: 1px solid transparent;
}

#entry:selected {
    background-color: ${ACCENT}22;
    border-color: ${ACCENT}66;
}

#entry:focus {
    background-color: ${ACCENT}18;
    border-color: ${ACCENT}44;
}

#text {
    margin: 0 8px;
    color: ${FG};
}

#text:selected {
    color: #ffffff;
}

#img {
    margin: 0 4px 0 0;
}
CSS

exec wofi --location=top_left --xoffset="$XOFF" --yoffset="$YOFF"
