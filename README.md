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

