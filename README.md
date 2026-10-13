# Multi Background SDDM Theme

A custom **SDDM (Simple Desktop Display Manager)** theme that dynamically changes the background based on the selected user.

> 🔥 Each user gets their own personalized login screen background.

#### [SDDM Theme used is from qylock by Darkkal44](https://github.com/Darkkal44/qylock)

---

## 📸 Preview



https://github.com/user-attachments/assets/3380a83c-f4ff-4340-9b52-448b717a18b8



---
## Installation

Clone the repository and run the install command:

```bash
git clone https://github.com/mbsurya19122004/Multi_Background.git
cd Multi_Background
chmod +x MultiBG.bash
./MultiBG.bash -install
```

`-install` does the whole setup in one go:

1. **Installs all dependencies automatically** (only what is missing): `sddm`, Qt6 `Qt5Compat` + `QtMultimedia`, `PySide6`, `ImageMagick`, `ffmpeg`. Supports **pacman** (Arch), **apt** (Debian/Ubuntu), **dnf** (Fedora) and **zypper** (openSUSE); PySide6 falls back to `pip` if your distro doesn't package it. Skip this step with `./MultiBG.bash -install --no-deps`.
2. Builds the profile pictures and copies the theme to `/usr/share/sddm/themes/Multi_Background`.
3. Sets it as the active SDDM theme.
4. **Adds the settings GUI as a desktop app**: search for **Multi_Background Settings** in your application menu, or run `multibg-settings` (or `./MultiBG.bash -gui`).

> The GUI edits the files in the folder you cloned, so keep that folder in place. Press **Install** in the GUI (or re-run `./MultiBG.bash -install`) to apply changes to SDDM.

---

## ⚙️ Setting an SDDM Background Video

Use the script with the `-setBG` flag followed by the username and the path to the `.mp4` video file.

### Syntax

```bash
cd /usr/share/sddm/themes/Multi_Background
```

```bash
./MultiBG.sh -setBG <username> <video_file>
```

### Example

```bash
./MultiBG.sh -setBG ocean ~/Videos/ocean.mp4
```

