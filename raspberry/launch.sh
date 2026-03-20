#!/bin/bash
# =============================================================================
# KSDOS Watch - Launcher for Raspberry Pi with TFT display
#
# Display modes (set DISPLAY_MODE below):
#   framebuffer  - Output directly to TFT via /dev/fb1 (headless, no X11)
#   x11          - Output via X11 (requires a running X server on the TFT)
#   hdmi         - Output via HDMI (for testing without TFT)
# =============================================================================

DISK_IMG="/home/pi/ksdos/disk.img"
DISPLAY_MODE="framebuffer"   # framebuffer | x11 | hdmi
TFT_DEVICE="/dev/fb1"        # framebuffer device for the TFT
SCALE="1"                    # integer scale factor (1 = native, 2 = 2x)

# Memory: 32MB is plenty for KSDOS (original: 4MB)
MEMORY="32"

# --------------------------------------------------------------------------
# Sanity checks
# --------------------------------------------------------------------------
if [ ! -f "$DISK_IMG" ]; then
    echo "ERROR: disk image not found at $DISK_IMG"
    echo "  Run: sudo bash setup.sh"
    exit 1
fi

# --------------------------------------------------------------------------
# Hide the console cursor on TFT
# --------------------------------------------------------------------------
if [ -e "$TFT_DEVICE" ]; then
    echo -ne "\033[?25l" > "$TFT_DEVICE" 2>/dev/null || true
fi

# --------------------------------------------------------------------------
# Build QEMU flags common to all modes
# --------------------------------------------------------------------------
QEMU_FLAGS=(
    -drive "format=raw,file=$DISK_IMG,if=floppy"
    -boot a
    -m "$MEMORY"
    -vga std
    -no-reboot
    -name "KSDOS"
)

# --------------------------------------------------------------------------
# Launch according to display mode
# --------------------------------------------------------------------------
case "$DISPLAY_MODE" in

    framebuffer)
        # Output to TFT framebuffer (/dev/fb1) via SDL's fbcon driver.
        # KSDOS text mode (720x400) is automatically scaled to fit the TFT.
        if [ ! -e "$TFT_DEVICE" ]; then
            echo "WARNING: $TFT_DEVICE not found, falling back to /dev/fb0 (HDMI)"
            TFT_DEVICE="/dev/fb0"
        fi
        export SDL_FBDEV="$TFT_DEVICE"
        export SDL_VIDEODRIVER="fbcon"
        export SDL_NOMOUSE=1
        # Scale QEMU output to display resolution
        TFT_RES=$(fbset -fb "$TFT_DEVICE" 2>/dev/null | grep "geometry" | awk '{print $2"x"$3}')
        echo "KSDOS starting on $TFT_DEVICE ($TFT_RES)..."
        exec qemu-system-i386 "${QEMU_FLAGS[@]}" -display sdl,show-cursor=off
        ;;

    x11)
        # Output to X11 window (useful if running LXDE or similar on Pi)
        export DISPLAY="${DISPLAY:-:0}"
        exec qemu-system-i386 "${QEMU_FLAGS[@]}" -display sdl,show-cursor=off
        ;;

    hdmi)
        # Standard HDMI output — useful for testing without the TFT connected
        export DISPLAY="${DISPLAY:-:0}"
        exec qemu-system-i386 "${QEMU_FLAGS[@]}" -display sdl
        ;;

    *)
        echo "ERROR: Unknown DISPLAY_MODE '$DISPLAY_MODE'"
        echo "  Valid options: framebuffer | x11 | hdmi"
        exit 1
        ;;
esac
