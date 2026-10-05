#!/bin/bash

THEME="Multi_Background"
# Folder this script lives in (works no matter where you run it from)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# -setBG writes backgrounds here (next to the script / Main.qml), not into /usr/share
BG_DIR="$SCRIPT_DIR"
THEME_DIR="/usr/share/sddm/themes/$THEME"
AVATAR_DIR="$THEME_DIR/avatars"
AVATAR_SIZE=512

usage() {
echo "Usage:"
echo "  $0 -install"
echo "  $0 -avatars"
echo "  $0 -setAvatar <name> <image_file>"
echo "  $0 -setBG <name|default> <video_or_image_file>"
echo "  $0 -tap"
echo
echo "Description:"
echo "  Installs the Multi_Background SDDM theme, builds profile"
echo "  pictures for every user, and allows setting custom"
echo "  background videos for users."
echo
echo "Flags:"
echo "  -install"
echo "      Installs the SDDM theme to:"
echo "      /usr/share/sddm/themes/Multi_Background"
echo
echo "      Also sets the theme as the current SDDM theme"
echo "      by updating the SDDM configuration, then builds"
echo "      avatars/<username>.png for every user from their"
echo "      ~/.face (see -avatars)."
echo
echo "  -avatars"
echo "      (Re)builds avatars/<username>.png for every normal user"
echo "      (UID 1000-60000) from ~/.face, ~/.face.icon or the"
echo "      AccountsService icon. Run it again after changing"
echo "      your profile picture."
echo
echo "  -setAvatar <name> <image_file>"
echo "      Uses any png/jpg as the profile picture of one user."
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

# Square-crop + convert any image to a 512x512 png.
# Tries ImageMagick, then ffmpeg (handles webp/avif), then a plain copy.
# Prints the real error if every method fails.
make_avatar() {
    local src="$1" dst="$2" im="" err=""

    if command -v magick >/dev/null 2>&1; then im="magick"
    elif command -v convert >/dev/null 2>&1; then im="convert"
    fi

    if [ -n "$im" ]; then
        err=$(sudo "$im" "${src}[0]" -auto-orient -gravity center \
            -resize "${AVATAR_SIZE}x${AVATAR_SIZE}^" -extent "${AVATAR_SIZE}x${AVATAR_SIZE}" \
            "png:$dst" 2>&1) && sudo test -s "$dst" && { sudo chmod 644 "$dst"; return 0; }
        echo "  ImageMagick failed: $err" >&2
    fi

    if command -v ffmpeg >/dev/null 2>&1; then
        err=$(sudo ffmpeg -y -loglevel error -i "$src" -frames:v 1 \
            -vf "crop='min(iw,ih)':'min(iw,ih)',scale=${AVATAR_SIZE}:${AVATAR_SIZE}" \
            -f image2 -c:v png "$dst" 2>&1) && sudo test -s "$dst" && { sudo chmod 644 "$dst"; return 0; }
        echo "  ffmpeg failed: $err" >&2
    fi

    # Last resort: copy as-is (Qt detects the format from the content),
    # but only if the file really is an image.
    if command -v file >/dev/null 2>&1 && ! sudo file --mime-type -b "$src" | grep -q '^image/'; then
        echo "  $src is not a valid image file" >&2
        return 1
    fi
    if sudo cp -f "$src" "$dst" && sudo test -s "$dst"; then
        sudo chmod 644 "$dst"
        echo "  (copied without converting - install ImageMagick for best results)" >&2
        return 0
    fi

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

# Build avatars/<username>.png for all normal users.
install_avatars() {
    if [ ! -d "$THEME_DIR" ]; then
        echo "Theme is not installed yet. Run: $0 -install" >&2
        return 1
    fi

    sudo mkdir -p "$AVATAR_DIR"
    sudo chmod 755 "$AVATAR_DIR"

    local count=0 user uid home src cand
    while IFS=: read -r user _ uid _ _ home _; do
        { [ "$uid" -ge 1000 ] && [ "$uid" -le 60000 ]; } || continue

        src=""
        for cand in "$home/.face" "$home/.face.icon" "/var/lib/AccountsService/icons/$user"; do
            if sudo test -f "$cand" && sudo test -r "$cand"; then src="$cand"; break; fi
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

case "$1" in
    -h|--help|"")
        usage
        exit 0
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
        if [ ! -d "$THEME_DIR" ]; then
            echo "Theme is not installed yet. Run: $0 -install" >&2
            exit 1
        fi
        sudo mkdir -p "$AVATAR_DIR"
        sudo chmod 755 "$AVATAR_DIR"
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

    -install)
        sudo mkdir -p "$THEME_DIR"

        # A background saved as .jpg must not be shadowed by an old installed .mp4 (and vice versa)
        for f in "$SCRIPT_DIR"/*.mp4 "$SCRIPT_DIR"/*.jpg; do
            [ -f "$f" ] || continue
            b="$(basename "$f")"; n="${b%.*}"; e="${b##*.}"
            [ "$e" = "mp4" ] && o="jpg" || o="mp4"
            sudo rm -f "$THEME_DIR/$n.$o"
        done

        sudo cp -r "$SCRIPT_DIR"/* "$THEME_DIR/"

        # Make the theme the active one (own drop-in file; doesn't overwrite /etc/sddm.conf)
        sudo mkdir -p /etc/sddm.conf.d
        echo "[Theme]
Current=$THEME" | sudo tee /etc/sddm.conf.d/10-theme.conf

        install_avatars
        ;;

    *)
        usage
        exit 1
        ;;
esac
