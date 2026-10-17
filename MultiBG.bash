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

SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

# Privilege escalation, in this order:
#   1. already root            -> run directly
#   2. SUDO_ASKPASS is set     -> sudo -A (the GUI does this)
#   3. no terminal + pkexec    -> pkexec (graphical polkit password prompt, e.g. app-menu launch)
#   4. otherwise               -> plain sudo (asks in the terminal)
sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif [ -z "$SUDO_ASKPASS" ] && [ ! -t 0 ] && command -v pkexec >/dev/null 2>&1; then
        pkexec "$@"
    else
        command sudo ${SUDO_ASKPASS:+-A} "$@"
    fi
}

# Print a message and, when there is no terminal (app-menu launch), also show a desktop notification.
say() {
    echo "$*"
    [ -t 2 ] || { command -v notify-send >/dev/null 2>&1 && notify-send "Multi_Background" "$*" 2>/dev/null; }
    return 0
}

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
    if [ ! -f "$py" ] || ! gui_python_ok; then
        local msg="The GUI needs PySide6 and multibg_gui.py next to this script. Automatic installation did not succeed - run: $SELF -install  (installs all dependencies)"
        echo "$msg" >&2
        # Started from an app menu (no terminal): a desktop notification is the only way to tell the user
        [ -t 2 ] || { command -v notify-send >/dev/null 2>&1 && notify-send "Multi_Background" "$msg"; }
        [ -t 2 ] && { echo >&2; usage; }
        return 1
    fi
    MULTIBG_SCRIPT="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")" exec python3 "$py"
}

usage() {
echo "Usage:"
echo "  $0                (no arguments: opens the settings GUI)"
echo "  $0 -gui"
echo "  $0 -install [--no-deps]"
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
echo "  Missing dependencies (sddm, Qt6 modules, PySide6, ImageMagick, ffmpeg)"
echo "  are installed automatically the first time this script is run,"
echo "  on Arch (pacman) and Fedora (dnf); apt and zypper also work."
echo "  Use '-install --no-deps' to skip this."
echo
echo "Flags:"
echo "  -gui"
echo "      Opens the graphical settings window (PySide6 is installed automatically)."
echo "      It also edits the look of the theme: accent color, clock"
echo "      format, font, dimming, texts (saved in ThemeSettings.qml)."
echo
echo "  -install"
echo "      Full setup in one go:"
echo "        1. Installs all missing dependencies automatically (sddm, Qt6"
echo "           Qt5Compat/QtMultimedia, PySide6, ImageMagick, ffmpeg) using"
echo "           pacman, dnf, apt or zypper (PySide6 falls back to pip)."
echo "           Use --no-deps to skip this step."
echo "        2. Builds the avatars, then copies this folder to:"
echo "           /usr/share/sddm/themes/Multi_Background"
echo "        3. Sets the theme as the current SDDM theme."
echo "        4. Adds the settings GUI as a desktop app: an application-menu"
echo "           entry 'Multi_Background Settings' plus the command"
echo "           multibg-settings (the GUI runs from THIS folder, keep it)."
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

# ───────────────────────── dependencies (run automatically on start) ─────────────────────────

# True when PySide6 (with the parts the GUI uses) can be imported.
gui_python_ok() {
    python3 -c 'import PySide6.QtWidgets, PySide6.QtQml, PySide6.QtQuick, PySide6.QtNetwork' 2>/dev/null
}

# Echoes the first supported package manager found on this system.
# pacman = Arch (and derivatives), dnf = Fedora (dnf4 and dnf5).
detect_pm() {
    local pm
    for pm in pacman dnf apt-get zypper; do
        command -v "$pm" >/dev/null 2>&1 && { echo "$pm"; return 0; }
    done
    return 1
}

# True when the Qt6 QML modules Main.qml and the GUI import are present.
# Arch: /usr/lib/qt6/qml   Fedora: /usr/lib64/qt6/qml   Debian/Ubuntu: /usr/lib/<arch>/qt6/qml
qt_qml_ok() {
    local d
    for d in /usr/lib/qt6/qml /usr/lib64/qt6/qml /usr/lib/*-linux-gnu/qt6/qml; do
        [ -d "$d" ] || continue
        [ -d "$d/Qt5Compat/GraphicalEffects" ] && [ -d "$d/QtMultimedia" ] && return 0
    done
    return 1
}

# Prints one line per missing dependency (nothing printed = everything is there).
missing_deps() {
    command -v sddm >/dev/null 2>&1 || echo "sddm"
    command -v python3 >/dev/null 2>&1 || echo "python3"
    gui_python_ok || echo "PySide6"
    qt_qml_ok || echo "Qt6 Qt5Compat + QtMultimedia"
    { command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; } || echo "ImageMagick"
    command -v ffmpeg >/dev/null 2>&1 || echo "ffmpeg"
    command -v file >/dev/null 2>&1 || echo "file"
}

# Install the packages given as arguments with the system package manager.
# One bulk install first; if it fails (e.g. a package name doesn't exist on this
# distro version) every package is retried on its own so one bad name can't block the rest.
pm_install() {
    local pm="$1"; shift
    local -a cmd
    case "$pm" in
        pacman)  cmd=(pacman -S --needed --noconfirm) ;;
        apt-get) cmd=(env DEBIAN_FRONTEND=noninteractive apt-get install -y) ;;
        dnf)     cmd=(dnf install -y) ;;
        zypper)  cmd=(zypper --non-interactive install) ;;
        *)       return 1 ;;
    esac

    sudo "${cmd[@]}" "$@" && return 0

    echo "Bulk install failed - retrying one package at a time..." >&2
    local p failed=()
    for p in "$@"; do
        sudo "${cmd[@]}" "$p" >/dev/null 2>&1 && echo "  + $p" || { echo "  ! $p (not available)" >&2; failed+=("$p"); }
    done
    [ "${#failed[@]}" -eq 0 ]
}

# pip fallback for PySide6, installed for the real user (not root, even under sudo).
pip_install_pyside6() {
    local -a as_user=()
    [ "$(id -u)" -eq 0 ] && [ -n "$SUDO_USER" ] && command -v runuser >/dev/null 2>&1 && as_user=(runuser -u "$SUDO_USER" --)
    "${as_user[@]}" python3 -m pip install --user PySide6 2>/dev/null \
        || "${as_user[@]}" python3 -m pip install --user --break-system-packages PySide6
}

# Installs everything the theme and the settings GUI need. Safe to run repeatedly;
# does nothing when all dependencies are already present.
install_dependencies() {
    local missing
    missing=$(missing_deps)
    if [ -z "$missing" ]; then
        echo "Dependencies: all present."
        return 0
    fi

    say "Installing missing dependencies: $(echo "$missing" | tr '\n' ',' | sed 's/,$//; s/,/, /g')"

    local pm pkgs=()
    if ! pm=$(detect_pm); then
        echo "No supported package manager (pacman, dnf, apt, zypper) found - please install the items above manually." >&2
        return 1
    fi
    echo "Installing with $pm ..."

    case "$pm" in
        pacman)   # Arch Linux
            pkgs=(sddm python python-pip pyside6 qt6-declarative qt6-5compat qt6-multimedia qt6-multimedia-ffmpeg qt6-svg imagemagick ffmpeg file) ;;
        dnf)      # Fedora
            pkgs=(sddm python3 python3-pip python3-pyside6 qt6-qtdeclarative qt6-qt5compat qt6-qtmultimedia qt6-qtsvg ImageMagick ffmpeg-free file) ;;
        apt-get)
            sudo apt-get update -qq
            pkgs=(sddm python3 python3-pip python3-pyside6.qtwidgets python3-pyside6.qtqml python3-pyside6.qtquick python3-pyside6.qtnetwork
                  qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-dialogs qml6-module-qtquick-layouts
                  qml6-module-qtquick-shapes qml6-module-qt-labs-folderlistmodel qml6-module-qt5compat-graphicaleffects
                  qml6-module-qtmultimedia imagemagick ffmpeg file) ;;
        zypper)
            pkgs=(sddm-qt6 python3 python3-pip python3-pyside6 qt6-declarative-imports qt6-qt5compat-imports qt6-multimedia-imports ImageMagick ffmpeg file) ;;
    esac
    pm_install "$pm" "${pkgs[@]}" || echo "Some packages could not be installed (see above)." >&2

    # PySide6 not in the distro repos (or older distro): fall back to pip for the current user
    if ! gui_python_ok; then
        echo "PySide6 not available from $pm - trying pip (user install)..."
        pip_install_pyside6 || echo "pip could not install PySide6 either." >&2
    fi

    missing=$(missing_deps)
    if [ -n "$missing" ]; then
        echo
        say "Still missing after installation (install these manually): $(echo "$missing" | tr '\n' ',' | sed 's/,$//; s/,/, /g')"
        return 1
    fi
    say "Dependencies: all installed."
}

# Called on every normal start of this script: installs whatever is missing, once,
# then does nothing (the check is quick). A failure only warns - the requested
# command still runs, and may report what it is missing.
ensure_dependencies() {
    [ -z "$(missing_deps)" ] && return 0
    install_dependencies || echo "Continuing anyway - some features may not work until the missing items are installed." >&2
    return 0
}

# ───────────────────────── GUI as a desktop app (used by -install) ─────────────────────────

# Home of the real user, even when the script itself was started with sudo.
real_home() {
    if [ "$(id -u)" -eq 0 ] && [ -n "$SUDO_USER" ]; then
        getent passwd "$SUDO_USER" | cut -d: -f6
    else
        echo "$HOME"
    fi
}

# Registers the settings GUI like a normal app: application-menu entry + icon,
# and a `multibg-settings` command. The launcher points at THIS folder, which is
# where the GUI reads and writes everything - so keep this folder in place.
install_desktop_app() {
    local home data bin owner=""
    home=$(real_home)
    [ -n "$home" ] && [ -d "$home" ] || { echo "Could not find a home directory - skipped desktop entry." >&2; return 1; }
    data="${XDG_DATA_HOME:-$home/.local/share}"
    [ "$(id -u)" -eq 0 ] && [ -n "$SUDO_USER" ] && { owner="$SUDO_USER"; data="$home/.local/share"; }
    bin="$home/.local/bin"

    mkdir -p "$data/applications" "$data/icons/hicolor/scalable/apps" "$bin" || return 1

    cat > "$data/icons/hicolor/scalable/apps/multibg-settings.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#2b2418"/><stop offset="1" stop-color="#0d0b08"/>
    </linearGradient>
  </defs>
  <rect width="128" height="128" rx="28" fill="url(#g)"/>
  <rect x="22" y="30" width="84" height="56" rx="8" fill="none" stroke="#c9a063" stroke-width="6"/>
  <path d="M22 76l22-20 18 16 14-12 30 24" fill="none" stroke="#e0b878" stroke-width="6" stroke-linejoin="round" stroke-linecap="round"/>
  <circle cx="84" cy="48" r="7" fill="#e0b878"/>
  <rect x="44" y="96" width="40" height="6" rx="3" fill="#c9a063"/>
</svg>
SVG

    # Exec points at THIS folder's script (the one that works on, and writes to, the dev copy)
    cat > "$data/applications/multibg-settings.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Multi_Background Settings
Exec=bash "$SELF" -gui
Icon=multibg-settings
Terminal=false
Categories=Settings;
DESKTOP
    chmod 755 "$data/applications/multibg-settings.desktop"

    cat > "$bin/multibg-settings" <<LAUNCHER
#!/bin/bash
exec bash "$SELF" -gui "\$@"
LAUNCHER
    chmod 755 "$bin/multibg-settings"

    # Files made while running as root via sudo must belong to the real user
    [ -n "$owner" ] && chown "$owner": "$data/applications/multibg-settings.desktop" \
        "$data/icons/hicolor/scalable/apps/multibg-settings.svg" "$bin/multibg-settings" 2>/dev/null

    command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$data/applications" >/dev/null 2>&1
    command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t "$data/icons/hicolor" >/dev/null 2>&1

    echo "+ desktop app: $data/applications/multibg-settings.desktop"
    echo "+ command:     $bin/multibg-settings"
    case ":$PATH:" in
        *":$bin:"*) ;;
        *) echo "  (add $bin to your PATH to use the 'multibg-settings' command; the app menu entry works already)" ;;
    esac
    echo "  The app runs from $SCRIPT_DIR - don't move or delete that folder."
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

# ───────────────────────── automatic dependency check ─────────────────────────
# Runs on every start so PySide6 and friends are installed as soon as the script is
# launched. Skipped for --help, for the small GUI helper commands (their caller
# already passed this check) and for '-install --no-deps'.
case "$1" in
    -h|--help|-rmBG|-setFont|-clearFont|-put|-tap|-untap) ;;
    *) [ "$2" = "--no-deps" ] || ensure_dependencies ;;
esac

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
        # 1. Dependencies were already handled by ensure_dependencies above
        #    (skipped with: -install --no-deps)
        if [ "$2" = "--no-deps" ]; then
            echo "Skipping dependency installation (--no-deps)."
        else
            echo "Dependencies: checked."
        fi
        echo

        # 2. Avatars are built in this folder first, then everything is copied together
        install_avatars

        sudo mkdir -p "$THEME_DIR"

        # Keep the installed backgrounds identical to this folder: an old installed
        # .mp4 must not shadow a new .jpg (and vice versa), and removed ones go away.
        for f in "$THEME_DIR"/*.mp4 "$THEME_DIR"/*.jpg; do
            [ -f "$f" ] || continue
            [ -f "$SCRIPT_DIR/$(basename "$f")" ] || sudo rm -f "$f"
        done

        sudo cp -r "$SCRIPT_DIR"/* "$THEME_DIR/"

        # Fedora (SELinux): give the copied files the right security labels so the greeter can read them
        command -v restorecon >/dev/null 2>&1 && sudo restorecon -R "$THEME_DIR" >/dev/null 2>&1

        # 3. Make the theme the active one (own drop-in file; doesn't overwrite /etc/sddm.conf)
        sudo mkdir -p /etc/sddm.conf.d
        echo "[Theme]
Current=$THEME" | sudo tee /etc/sddm.conf.d/10-theme.conf

        # 4. Settings GUI as a desktop app (app menu entry + `multibg-settings` command)
        echo
        install_desktop_app

        echo
        echo "Done. Open \"Multi_Background Settings\" from your application menu (or run: $0 -gui)."
        ;;

    *)
        usage
        exit 1
        ;;
esac