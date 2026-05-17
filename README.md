# Multi Background SDDM Theme

A custom **SDDM (Simple Desktop Display Manager)** theme that dynamically changes the background based on the selected user.

> 🔥 Each user gets their own personalized login screen background.

## Theme from qylock by Darkkal44 : https://github.com/Darkkal44/qylock

---

## ✨ Features

- 👤 **Per-user background support**
- 🎨 Clean and customizable UI
- ⚡ Lightweight and fast
- 🖼️ Supports images / videos (if configured)
- 🛠️ Easy to extend for more users

---

## 📸 Preview

[Preview](./preview/preview.mp4)

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

> Make sure that you have `sudo` privileges since the script writes to a system directory.
