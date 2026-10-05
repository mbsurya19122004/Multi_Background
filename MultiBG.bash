#!/bin/bash

THEME="Multi_Background"
# Folder this script lives in (works no matter where you run it from)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# -setBG writes backgrounds here (next to the script / Main.qml), not into /usr/share
BG_DIR="$SCRIPT_DIR"
# Everything (backgrounds, avatars, fonts, ThemeSettings.qml) lives in SCRIPT_DIR, the dev copy.
# /usr/share/sddm/... is only touched by -install.
THEME_DIR="${MULTIBG_THEME_DIR:-/usr/share/sddm/themes/$THEME}"
AVATAR_DIR="$SCRIPT_DIR/avatars"
AVATAR_SIZE=512

# When launched from the GUI, sudo gets its password from SUDO_ASKPASS.
# In a normal terminal this does nothing special.
sudo() { command sudo ${SUDO_ASKPASS:+-A} "$@"; }

# Run a command with sudo only when the folder it writes to is not writable by us.
# usage: as_needed <dir> <command...>
as_needed() {
    local d="$1"; shift
    if [ -w "$d" ]; then "$@"; else sudo "$@"; fi
}

# Only allow the GUI helpers below to touch files inside this theme folder.
inside_theme() {
    local p; p="$(realpath -m -- "$1")"
    case "$p" in "$SCRIPT_DIR"/*) return 0 ;; esac
    echo "Refusing to touch $1 (outside $SCRIPT_DIR)" >&2
    return 1
}

launch_gui() {
    local py="$SCRIPT_DIR/multibg_gui.py"
    if [ ! -f "$py" ] || ! python3 -c 'import PySide6' 2>/dev/null; then
        echo "The GUI needs PySide6 (Arch: sudo pacman -S pyside6) and multibg_gui.py next to this script." >&2
        echo >&2
        usage
        return 1
    fi
    MULTIBG_SCRIPT="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")" exec python3 "$py"
}

usage() {
echo "Usage:"
echo "  $0                (no arguments: opens the settings GUI)"
echo "  $0 -gui"
echo "  $0 -install"
echo "  $0 -avatars"
echo "  $0 -setAvatar <name> <image_file>"
echo "  $0 -setBG <name|default> <video_or_image_file>"
echo "  $0 -tap"
echo "  $0 -preview"
echo "  $0 -untap"
echo
echo "Description:"
echo "  Installs the Multi_Background SDDM theme, builds profile"
echo "  pictures for every user, and allows setting custom"
echo "  background videos for users."
echo
echo "Flags:"
echo "  -gui"
echo "      Opens the graphical settings window (needs PySide6)."
echo "      It also edits the look of the theme: accent color, clock"
echo "      format, font, dimming, texts (saved in ThemeSettings.qml)."
echo
echo "  -install"
echo "      The only command that touches /usr/share. Builds the avatars,"
echo "      then copies this folder to:"
echo "      /usr/share/sddm/themes/Multi_Background"
echo
echo "      Also sets the theme as the current SDDM theme"
echo "      by updating the SDDM configuration."
echo
echo "  -preview"
echo "      Runs sddm-greeter in test mode on THIS folder, so you can"
echo "      see changes without installing anything."
echo
echo "  -avatars"
echo "      (Re)builds avatars/<username>.png for every normal user"
echo "      (UID 1000-60000) from ~/.face, ~/.face.icon or the"
echo "      AccountsService icon, into the avatars/ folder next to this"
echo "      script. Run it again after changing your profile picture."
echo
echo "  -setAvatar <name> <image_file>"
echo "      Uses any png/jpg as the profile picture of one user"
echo "      (saved in avatars/ next to this script)."
echo
echo "  -setBG <name|default> <video_or_image_file>"
echo "      Sets a background video (mp4/webm/mkv/...) or image"
echo "      (png/jpg/webp/...) for a user, or for everybody when the"
echo "      name is: default"
echo
echo "      default -> shown on the login screen until a profile is clicked"
echo "      <name>  -> shown only while that user's profile is in focus,"
echo "                 then it goes back to the default one"
echo
echo "      The file is saved in the folder of this script (next to"
echo "      Main.qml), so it does not need the theme to be installed."
echo "      Run -install afterwards to copy it to the SDDM theme folder."
echo
echo "  -tap"
echo "      Turns on tap-to-click for touchpads on the SDDM login screen"
echo "      (the greeter does not use your desktop's touchpad settings)."
echo
echo "  -untap"
echo "      Removes the tap-to-click snippet written by -tap."
echo
echo "  Helpers used by the GUI (they only touch files in this folder):"
echo "      -rmBG <name>          remove the background of a user / default"
echo "      -setFont <ttf|otf>    use this font file for the theme (font/)"
echo "      -clearFont            remove the theme font file"
echo "      -put <src> <dest>     copy a file to <dest> inside this folder"
echo
echo "Arguments:"
echo "  <name>         Login name of the user (or: default, for -setBG)"
echo "  <image_file>   Path to a png/jpg image"
echo "  <video_or_image_file>  Path to a video or an image"
echo
echo "Examples:"
echo "  $0 -install"
echo "  $0 -avatars"
echo "  $0 -setAvatar kashi ~/Pictures/me.png"
echo "  $0 -setBG default ~/Videos/city.mp4"
echo "  $0 -setBG default ~/Pictures/wall.png"
echo "  $0 -setBG kashi ~/Videos/ocean.mp4"
}

# Square-crop + convert any image to a 512x512 png (works on a temp copy, so the
# dev folder never ends up with root-owned files unless it is not writable).
# Tries ImageMagick, then ffmpeg (handles webp/avif), then a plain copy.
make_avatar() {
    local src="$1" dst="$2" im="" err="" stage out ok=0 SUDO_AV=""
    [ -w "$(dirname "$dst")" ] || SUDO_AV="sudo"

    stage=$(mktemp) || return 1
    out=$(mktemp --suffix=.png) || { rm -f "$stage"; return 1; }
    if [ -r "$src" ]; then cp -f "$src" "$stage"; else sudo cat "$src" > "$stage" 2>/dev/null; fi
    if [ ! -s "$stage" ]; then
        echo "  cannot read $src" >&2
        rm -f "$stage" "$out"; return 1
    fi

    if command -v magick >/dev/null 2>&1; then im="magick"
    elif command -v convert >/dev/null 2>&1; then im="convert"
    fi

    if [ -n "$im" ]; then
        if err=$("$im" "${stage}[0]" -auto-orient -gravity center \
                -resize "${AVATAR_SIZE}x${AVATAR_SIZE}^" -extent "${AVATAR_SIZE}x${AVATAR_SIZE}" \
                "png:$out" 2>&1) && [ -s "$out" ]; then
            ok=1
        else
            echo "  ImageMagick failed: $err" >&2
        fi
    fi

    if [ "$ok" -eq 0 ] && command -v ffmpeg >/dev/null 2>&1; then
        if err=$(ffmpeg -y -loglevel error -i "$stage" -frames:v 1 \
                -vf "crop='min(iw,ih)':'min(iw,ih)',scale=${AVATAR_SIZE}:${AVATAR_SIZE}" \
                -f image2 -c:v png "$out" 2>&1) && [ -s "$out" ]; then
            ok=1
        else
            echo "  ffmpeg failed: $err" >&2
        fi
    fi

    # Last resort: copy as-is (Qt detects the format from the content),
    # but only if the file really is an image.
    if [ "$ok" -eq 0 ]; then
        if command -v file >/dev/null 2>&1 && ! file --mime-type -b "$stage" | grep -q '^image/'; then
            echo "  $src is not a valid image file" >&2
            rm -f "$stage" "$out"; return 1
        fi
        cp -f "$stage" "$out" && ok=1
        [ "$ok" -eq 1 ] && echo "  (copied without converting - install ImageMagick for best results)" >&2
    fi

    if [ "$ok" -eq 1 ] && $SUDO_AV cp -f "$out" "$dst" && $SUDO_AV chmod 644 "$dst"; then
        rm -f "$stage" "$out"
        return 0
    fi

    rm -f "$stage" "$out"
    echo "  could not write $dst" >&2
    return 1
}

# Save a background for <name> (a login name, or "default") next to this script.
# Videos are stored as <name>.mp4, images as <name>.jpg - the theme looks
# for exactly those names. Setting one type removes the other for that name.
set_bg() {
    local name="$1" file="$2" mime="" ext="" kind="" im="" SUDO_BG=""
    [ -w "$BG_DIR" ] || SUDO_BG="sudo"

    if command -v file >/dev/null 2>&1; then
        mime=$(file --mime-type -b "$file")
    fi
    case "$mime" in
        video/*) kind="video" ;;
        image/*) kind="image" ;;
        *)
            ext="${file##*.}"; ext="${ext,,}"
            case "$ext" in
                mp4|webm|mkv|mov|avi|m4v|gif) kind="video" ;;
                png|jpg|jpeg|webp|bmp|avif)   kind="image" ;;
            esac
            ;;
    esac

    if [ -z "$kind" ]; then
        echo "Unrecognised file type: $file (expected a video or an image)" >&2
        return 1
    fi

    if [ "$kind" = "video" ]; then
        $SUDO_BG cp -f "$file" "$BG_DIR/$name.mp4" || return 1
        $SUDO_BG chmod 644 "$BG_DIR/$name.mp4"
        $SUDO_BG rm -f "$BG_DIR/$name.jpg"
        echo "+ $name: video -> $BG_DIR/$name.mp4"
    else
        if command -v magick >/dev/null 2>&1; then im="magick"
        elif command -v convert >/dev/null 2>&1; then im="convert"
        fi
        if [ -n "$im" ]; then
            $SUDO_BG "$im" "${file}[0]" -auto-orient -quality 92 "jpg:$BG_DIR/$name.jpg" || return 1
        else
            # No ImageMagick: copy as-is (Qt detects the format from the content)
            $SUDO_BG cp -f "$file" "$BG_DIR/$name.jpg" || return 1
        fi
        $SUDO_BG chmod 644 "$BG_DIR/$name.jpg"
        $SUDO_BG rm -f "$BG_DIR/$name.mp4"
        echo "+ $name: image -> $BG_DIR/$name.jpg"
    fi
    return 0
}

# Tap-to-click on the login screen. SDDM's greeter runs as its own user, so it
# never sees the touchpad settings of your desktop; libinput defaults to tap OFF.
enable_tap() {
    local ds
    ds=$( { cat /etc/sddm.conf /etc/sddm.conf.d/*.conf 2>/dev/null; } | grep -i '^DisplayServer=' | tail -n1 | cut -d= -f2 | tr -d ' ' )
    echo "SDDM greeter display server: ${ds:-x11 (default)}"

    # X11 greeter (default): libinput option via an xorg.conf.d snippet
    sudo mkdir -p /etc/X11/xorg.conf.d
    echo 'Section "InputClass"
    Identifier "sddm touchpad tap-to-click"
    MatchIsTouchpad "on"
    MatchDevicePath "/dev/input/event*"
    Driver "libinput"
    Option "Tapping" "on"
EndSection' | sudo tee /etc/X11/xorg.conf.d/90-sddm-touchpad.conf >/dev/null
    echo "+ wrote /etc/X11/xorg.conf.d/90-sddm-touchpad.conf"

    case "${ds,,}" in
        wayland)
            echo
            echo "Your greeter runs on Wayland, so the file above is not used. Depending on the compositor:"
            echo "  weston: add to /var/lib/sddm/.config/weston.ini ->  [libinput]  then  enable-tap=true"
            echo "  kwin:   set Tap = true for your touchpad in /var/lib/sddm/.config/kcminputrc"
            echo "Or switch the greeter to X11 in /etc/sddm.conf.d/ ->  [General]  DisplayServer=x11"
            ;;
    esac
    echo "Restart SDDM (or reboot) to apply: sudo systemctl restart sddm  (this ends your session!)"
}

# Build avatars/<username>.png (next to this script) for all normal users.
install_avatars() {
    mkdir -p "$AVATAR_DIR" 2>/dev/null || sudo mkdir -p "$AVATAR_DIR"
    chmod 755 "$AVATAR_DIR" 2>/dev/null || sudo chmod 755 "$AVATAR_DIR"

    local count=0 user uid home src cand
    while IFS=: read -r user _ uid _ _ home _; do
        { [ "$uid" -ge 1000 ] && [ "$uid" -le 60000 ]; } || continue

        src=""
        for cand in "$home/.face" "$home/.face.icon" "/var/lib/AccountsService/icons/$user"; do
            if { [ -f "$cand" ] && [ -r "$cand" ]; } || { sudo test -f "$cand" && sudo test -r "$cand"; }; then
                src="$cand"; break
            fi
        done

        if [ -z "$src" ]; then
            echo "- $user: no .face found (looked in $home and AccountsService) - skipped"
            continue
        fi

        if make_avatar "$src" "$AVATAR_DIR/$user.png"; then
            echo "+ $user: $src -> $AVATAR_DIR/$user.png"
            count=$((count + 1))
        else
            echo "! $user: failed to convert $src" >&2
        fi
    done < <(getent passwd)

    echo "Avatars written: $count"
    [ "$count" -eq 0 ] && echo "Tip: put a picture at ~/.face (png/jpg), then run: $0 -avatars"
    return 0
}

# Open the theme straight from this folder in SDDM's test mode (no install needed).
preview_theme() {
    local g=""
    for g in sddm-greeter-qt6 sddm-greeter; do command -v "$g" >/dev/null 2>&1 && break || g=""; done
    if [ -z "$g" ]; then
        echo "sddm-greeter-qt6 not found (it ships with the sddm package)." >&2
        return 1
    fi
    echo "Previewing $SCRIPT_DIR with $g --test-mode (close the window to stop)"
    "$g" --test-mode --theme "$SCRIPT_DIR"
}

case "$1" in
    -h|--help)
        usage
        exit 0
        ;;

    ""|-gui)
        launch_gui || exit 1
        ;;

    -setBG)
        if [ -z "$2" ] || [ ! -f "$3" ]; then
            echo "Usage: $0 -setBG <name|default> <video_or_image_file>" >&2
            [ -n "$3" ] && [ ! -f "$3" ] && echo "File not found: $3" >&2
            exit 1
        fi
        if [ "$2" != "default" ] && ! getent passwd "$2" >/dev/null; then
            echo "Warning: no system user called '$2'. <name> must be the login name (or: default)." >&2
        fi
        if set_bg "$2" "$3"; then
            echo "Saved in $BG_DIR - run '$0 -install' to apply it to the SDDM theme."
        else
            exit 1
        fi
        ;;

    -setAvatar)
        if [ -z "$2" ] || [ ! -f "$3" ]; then
            echo "Usage: $0 -setAvatar <name> <image_file>" >&2
            [ -n "$3" ] && [ ! -f "$3" ] && echo "File not found: $3" >&2
            exit 1
        fi
        if ! getent passwd "$2" >/dev/null; then
            echo "Warning: no system user called '$2'. <name> must be the login name (check with: whoami)." >&2
        fi
        mkdir -p "$AVATAR_DIR" 2>/dev/null || sudo mkdir -p "$AVATAR_DIR"
        if make_avatar "$3" "$AVATAR_DIR/$2.png"; then
            echo "+ $2: $3 -> $AVATAR_DIR/$2.png"
            ls -l "$AVATAR_DIR/$2.png"
        else
            echo "! failed to set avatar for $2" >&2
            exit 1
        fi
        ;;

    -avatars)
        install_avatars
        ;;

    -tap)
        enable_tap
        ;;

    -preview)
        preview_theme || exit 1
        ;;

    -untap)
        sudo rm -f /etc/X11/xorg.conf.d/90-sddm-touchpad.conf
        echo "- removed /etc/X11/xorg.conf.d/90-sddm-touchpad.conf"
        echo "Restart SDDM (or reboot) to apply."
        ;;

    -rmBG)
        if ! [[ "$2" =~ ^[A-Za-z0-9._-]+$ ]]; then
            echo "Usage: $0 -rmBG <name|default>" >&2
            exit 1
        fi
        as_needed "$BG_DIR" rm -f "$BG_DIR/$2.mp4" "$BG_DIR/$2.jpg"
        echo "- removed background for $2 (run -install to remove it from the SDDM copy)"
        ;;

    -setFont)
        if [ ! -f "$2" ]; then echo "File not found: $2" >&2; exit 1; fi
        case "${2,,}" in
            *.ttf|*.otf) ;;
            *) echo "A font must be a .ttf or .otf file" >&2; exit 1 ;;
        esac
        FONT_DIR="$SCRIPT_DIR/font"
        [ -d "$FONT_DIR" ] || as_needed "$SCRIPT_DIR" mkdir -p "$FONT_DIR"
        as_needed "$FONT_DIR" bash -c 'rm -f "$1"/*.ttf "$1"/*.otf "$1"/*.TTF "$1"/*.OTF' _ "$FONT_DIR"
        as_needed "$FONT_DIR" cp -f "$2" "$FONT_DIR/$(basename "$2")" || exit 1
        as_needed "$FONT_DIR" chmod 644 "$FONT_DIR/$(basename "$2")"
        echo "+ font: $(basename "$2") -> $FONT_DIR"
        ;;

    -clearFont)
        FONT_DIR="$SCRIPT_DIR/font"
        if [ -d "$FONT_DIR" ]; then
            as_needed "$FONT_DIR" bash -c 'rm -f "$1"/*.ttf "$1"/*.otf "$1"/*.TTF "$1"/*.OTF' _ "$FONT_DIR"
        fi
        echo "- removed the theme font file (the system default font is used)"
        ;;

    -put)
        if [ ! -f "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 -put <src_file> <dest_inside_theme_folder>" >&2
            exit 1
        fi
        inside_theme "$3" || exit 1
        as_needed "$(dirname "$3")" cp -f "$2" "$3" || exit 1
        as_needed "$(dirname "$3")" chmod 644 "$3"
        echo "+ wrote $3"
        ;;

    -install)
        # Avatars are built in this folder first, then everything is copied together
        install_avatars

        sudo mkdir -p "$THEME_DIR"

        # Keep the installed backgrounds identical to this folder: an old installed
        # .mp4 must not shadow a new .jpg (and vice versa), and removed ones go away.
        for f in "$THEME_DIR"/*.mp4 "$THEME_DIR"/*.jpg; do
            [ -f "$f" ] || continue
            [ -f "$SCRIPT_DIR/$(basename "$f")" ] || sudo rm -f "$f"
        done

        sudo cp -r "$SCRIPT_DIR"/* "$THEME_DIR/"

        # Make the theme the active one (own drop-in file; doesn't overwrite /etc/sddm.conf)
        sudo mkdir -p /etc/sddm.conf.d
        echo "[Theme]
Current=$THEME" | sudo tee /etc/sddm.conf.d/10-theme.conf
        ;;

    *)
        usage
        exit 1
        ;;
esac
