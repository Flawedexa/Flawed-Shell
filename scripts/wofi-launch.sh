#!/usr/bin/env bash
# Usage: wofi-launch.sh <bg_r> <bg_g> <bg_b> <bg_a> <fg_r> <fg_g> <fg_b> <accent_r> <accent_g> <accent_b> <surface_r> <surface_g> <surface_b> <surface_a> <screen_w> <xoff> <yoff>
set -euo pipefail

BGR="${1:-9}"   BGG="${2:-10}"  BGB="${3:-12}"  BGA="${4:-0.82}"
FGR="${5:-242}" FGG="${6:-244}" FGB="${7:-248}"
AGR="${8:-187}" AGG="${9:-154}" AGB="${10:-247}"
SFR="${11:-23}" SFG="${12:-25}" SFB="${13:-29}" SFA="${14:-0.82}"
SCRW="${15:-1920}"
XOFF="${16:-0}"
YOFF="${17:-0}"

STYLE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wofi"
mkdir -p "$STYLE_DIR"

cat > "$STYLE_DIR/style.css" << CSS
window {
    margin: 0;
    padding: 0;
    background-color: rgba(${BGR},${BGG},${BGB},${BGA});
    border-radius: 14px;
    font-family: "JetBrainsMono Nerd Font", monospace;
    font-size: 13px;
    border: 1px solid rgba(${AGR},${AGG},${AGB},0.20);
}

#outer-box {
    margin: 0;
    padding: 8px;
    background-color: transparent;
}

#input {
    margin: 4px 8px 8px 8px;
    padding: 8px 12px;
    background-color: rgba(${SFR},${SFG},${SFB},${SFA});
    color: rgb(${FGR},${FGG},${FGB});
    border: 1px solid rgba(${AGR},${AGG},${AGB},0.20);
    border-radius: 10px;
    font-family: "JetBrainsMono Nerd Font", monospace;
    font-size: 13px;
    min-height: 20px;
}

#input:focus {
    border-color: rgb(${AGR},${AGG},${AGB});
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
    background-color: rgba(${SFR},${SFG},${SFB},0.50);
    color: rgb(${FGR},${FGG},${FGB});
    border-radius: 10px;
    border: 1px solid transparent;
}

#entry:selected {
    background-color: rgba(${AGR},${AGG},${AGB},0.14);
    border-color: rgba(${AGR},${AGG},${AGB},0.40);
}

#text {
    margin: 0 8px;
    color: rgb(${FGR},${FGG},${FGB});
}

#text:selected {
    color: #ffffff;
}

#img {
    margin: 0 4px 0 0;
}
CSS

# Position the menu below the click: left side uses top_left aligned to click,
# right side uses top_right so the right edge aligns with the click instead
# of overflowing past the screen edge.
MID=$((SCRW / 2))
if [ "$XOFF" -gt "$MID" ]; then
    FROM_RIGHT=$((SCRW - XOFF))
    exec wofi --location=top_right --xoffset="$FROM_RIGHT" --yoffset="$YOFF"
else
    MAX_X=$((SCRW - 330))
    [ "$XOFF" -gt "$MAX_X" ] && XOFF=$MAX_X
    [ "$XOFF" -lt 0 ] && XOFF=0
    exec wofi --location=top_left --xoffset="$XOFF" --yoffset="$YOFF"
fi
