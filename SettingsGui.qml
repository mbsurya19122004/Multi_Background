import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Dialogs

ApplicationWindow {
    id: win
    width: 1160
    height: 840
    minimumWidth: 980
    minimumHeight: 700
    visible: true
    title: "Multi_Background — SDDM settings"
    color: Pal.bg

    // ───────────────────────── state ─────────────────────────
    property int page: 0
    property string bgTarget: "default"
    property string bgFile: ""
    property bool installAfter: false
    property bool chainInstall: false
    property bool clearBgAfter: false
    property string avatarUser: ""
    property string colorKey: ""
    property var draft: ({})
    property bool previewAfterSave: false
    property bool forceClose: false
    property bool pvError: false
    property bool logOpen: false
    property bool pwHandled: false
    property string pwPrompt: ""
    property bool pwRetry: false
    property string toastText: ""
    property string toastKind: "info"

    readonly property var pageNames: ["Overview", "Backgrounds", "Avatars", "Appearance", "Touchpad"]
    readonly property var pageIcons: ["⌂", "▣", "☺", "✦", "☝"]
    readonly property var targets: ["default"].concat(backend.users.map(function (u) { return u.login }))
    readonly property bool dirty: JSON.stringify(draft) !== JSON.stringify(backend.settings)

    // background preview source: the file you just picked, otherwise what is saved
    readonly property var pvInfo: { backend.rev; return backend.bgInfo(bgTarget) }
    readonly property string pvKind: bgFile !== "" ? backend.fileKind(bgFile) : pvInfo.kind
    readonly property string pvPath: bgFile !== "" ? bgFile : pvInfo.path
    readonly property string pvUrl: bgFile !== "" ? backend.fileUrl(bgFile) : pvInfo.url
    readonly property string pvThumb: (pvError && pvKind === "video") ? backend.thumbnail(pvPath) : ""

    function clockText(d, fmt, hide) {
        if (!hide) return Qt.formatTime(d, fmt)
        var h = d.getHours() % 12
        if (h === 0) h = 12
        var f = fmt.replace(/[Aa][Pp]?/g, "").replace(/h+/g, function (m) {
            return "'" + (m.length >= 2 && h < 10 ? "0" + h : "" + h) + "'"
        })
        return Qt.formatTime(d, f).trim()
    }
    function dv(k) { return draft[k] !== undefined ? draft[k] : backend.defaults[k] }
    function setD(k, v) { var d = Object.assign({}, draft); d[k] = v; draft = d }
    function showToast(msg, kind) { toastText = msg; toastKind = kind || "info"; toastTimer.restart() }
    function validHex(t) { return /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(t) }
    function pickBgFile(path) {
        if (backend.fileKind(path) === "none") { showToast("That is not a video or image file", "err"); return }
        bgFile = path
    }
    Component.onCompleted: draft = Object.assign({}, backend.settings)
    onBgTargetChanged: { bgFile = ""; pvError = false }
    onPvUrlChanged: pvError = false

    // ───────────────────────── reusable pieces ─────────────────────────
    component Card: Rectangle {
        id: card
        default property alias content: cl.data
        property int pad: 20
        property string heading: ""
        Layout.fillWidth: true
        radius: 16; color: Pal.card
        border.width: 1; border.color: Pal.border
        implicitHeight: cl.implicitHeight + pad * 2
        ColumnLayout {
            id: cl
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: card.pad }
            spacing: 12
            Text {
                visible: card.heading !== ""
                text: card.heading; color: Pal.gold
                font.pixelSize: 12; font.letterSpacing: 1.6; font.capitalization: Font.AllUppercase
                Layout.fillWidth: true
            }
        }
    }
    component T: Text {
        color: Pal.text; font.pixelSize: 14; wrapMode: Text.WordWrap
    }
    component Dim: Text {
        color: Pal.dim; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true
    }
    component Lbl: Text {
        color: Pal.text; font.pixelSize: 14
        Layout.preferredWidth: 150; Layout.alignment: Qt.AlignVCenter
    }
    component GBtn: Button {
        id: b
        property string kind: "ghost"        // primary | ghost | danger
        property bool needsIdle: false       // disabled while a script task runs
        property bool canClick: true
        enabled: canClick && !(needsIdle && backend.busy)
        implicitHeight: 40
        leftPadding: 20; rightPadding: 20
        opacity: enabled ? 1 : 0.45
        contentItem: Text {
            text: b.text; font.pixelSize: 14; font.weight: Font.Medium
            color: b.kind === "primary" ? "#14110d" : (b.kind === "danger" ? Pal.err : Pal.text)
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: height / 2
            scale: b.pressed ? 0.97 : 1
            color: b.kind === "primary" ? (b.hovered ? Pal.goldHi : Pal.gold)
                 : b.kind === "danger"  ? (b.hovered ? "#33ff7a7a" : "#1aff7a7a")
                 :                        (b.hovered ? "#2effffff" : "#1fffffff")
            border.width: 1
            border.color: b.kind === "primary" ? Pal.gold : (b.kind === "danger" ? "#66ff7a7a" : Pal.line)
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 90 } }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }
    component Field: TextField {
        id: f
        color: Pal.text; font.pixelSize: 14
        placeholderTextColor: "#66ffffff"
        selectByMouse: true
        selectionColor: Pal.gold; selectedTextColor: "#14110d"
        implicitHeight: 38
        leftPadding: 12; rightPadding: 12
        background: Rectangle {
            radius: 10; color: Pal.field
            border.width: 1; border.color: f.activeFocus ? Pal.gold : Pal.line
        }
    }
    component Badge: Rectangle {
        id: bd
        property string text: ""
        property string level: "ok"          // ok | warn | bad | info
        readonly property color c: level === "ok" ? Pal.ok : level === "warn" ? Pal.warn : level === "bad" ? Pal.err : Pal.dim
        implicitWidth: bt.implicitWidth + 20; implicitHeight: 24; radius: 12
        color: Qt.rgba(c.r, c.g, c.b, 0.14); border.width: 1; border.color: Qt.rgba(c.r, c.g, c.b, 0.5)
        Text { id: bt; anchors.centerIn: parent; text: bd.text; color: bd.c; font.pixelSize: 12; font.weight: Font.Medium }
    }
    component Combo: ComboBox {
        id: cb
        implicitHeight: 38
        font.pixelSize: 14
        delegate: ItemDelegate {
            width: cb.width; height: 34
            highlighted: cb.highlightedIndex === index
            contentItem: Text {
                text: modelData; font.pixelSize: 14
                color: parent.highlighted ? Pal.gold : Pal.text
                verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
            }
            background: Rectangle { radius: 8; color: parent.highlighted ? "#26ffffff" : "transparent" }
        }
        indicator: Text {
            x: cb.width - width - 12; anchors.verticalCenter: parent.verticalCenter
            text: "▾"; color: Pal.dim; font.pixelSize: 14
        }
        contentItem: Text {
            leftPadding: 12; rightPadding: 30
            text: cb.displayText; color: Pal.text; font.pixelSize: 14
            verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
        }
        background: Rectangle {
            radius: 10; color: Pal.field
            border.width: 1; border.color: (cb.activeFocus || cb.popup.visible) ? Pal.gold : Pal.line
        }
        popup: Popup {
            y: cb.height + 4; width: cb.width; padding: 4
            implicitHeight: Math.min(contentItem.implicitHeight + 8, 320)
            contentItem: ListView {
                clip: true; implicitHeight: contentHeight
                model: cb.popup.visible ? cb.delegateModel : null
                currentIndex: cb.highlightedIndex
                ScrollBar.vertical: ScrollBar {}
            }
            background: Rectangle { radius: 12; color: Pal.card2; border.width: 1; border.color: Pal.border }
        }
    }
    component Spin: SpinBox {
        id: sp
        editable: true
        implicitHeight: 38; implicitWidth: 140
        contentItem: TextInput {
            text: sp.textFromValue(sp.value, sp.locale)
            color: Pal.text; font.pixelSize: 14
            horizontalAlignment: Qt.AlignHCenter; verticalAlignment: Qt.AlignVCenter
            readOnly: !sp.editable; validator: sp.validator
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            selectByMouse: true; selectionColor: Pal.gold
        }
        up.indicator: Rectangle {
            x: sp.width - width; height: parent.height; width: 34; radius: 10
            color: sp.up.pressed ? "#33ffffff" : "transparent"
            Text { anchors.centerIn: parent; text: "+"; color: Pal.text; font.pixelSize: 18 }
        }
        down.indicator: Rectangle {
            x: 0; height: parent.height; width: 34; radius: 10
            color: sp.down.pressed ? "#33ffffff" : "transparent"
            Text { anchors.centerIn: parent; text: "−"; color: Pal.text; font.pixelSize: 18 }
        }
        background: Rectangle {
            radius: 10; color: Pal.field
            border.width: 1; border.color: sp.activeFocus ? Pal.gold : Pal.line
        }
    }
    component Sld: Slider {
        id: sl
        implicitHeight: 28
        background: Rectangle {
            x: sl.leftPadding; y: sl.topPadding + sl.availableHeight / 2 - height / 2
            width: sl.availableWidth; height: 4; radius: 2; color: "#33ffffff"
            Rectangle { width: sl.visualPosition * parent.width; height: parent.height; radius: 2; color: Pal.gold }
        }
        handle: Rectangle {
            x: sl.leftPadding + sl.visualPosition * (sl.availableWidth - width)
            y: sl.topPadding + sl.availableHeight / 2 - height / 2
            width: 20; height: 20; radius: 10
            color: sl.pressed ? Pal.goldHi : Pal.gold; border.width: 2; border.color: "#14110d"
        }
    }
    component Tog: Switch {
        id: sw
        implicitHeight: 28
        indicator: Rectangle {
            implicitWidth: 46; implicitHeight: 26; radius: 13
            x: sw.leftPadding; y: parent.height / 2 - height / 2
            color: sw.checked ? Pal.gold : "#26ffffff"
            border.width: 1; border.color: sw.checked ? Pal.gold : Pal.line
            Behavior on color { ColorAnimation { duration: 150 } }
            Rectangle {
                x: sw.checked ? parent.width - width - 3 : 3; y: 3
                width: 20; height: 20; radius: 10
                color: sw.checked ? "#14110d" : Pal.text
                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }
        }
        contentItem: Item {}
    }
    component Check: CheckBox {
        id: ck
        indicator: Rectangle {
            implicitWidth: 22; implicitHeight: 22; radius: 6
            x: ck.leftPadding; y: parent.height / 2 - height / 2
            color: ck.checked ? Pal.gold : Pal.field
            border.width: 1; border.color: ck.checked ? Pal.gold : Pal.line
            Text { anchors.centerIn: parent; text: "✓"; color: "#14110d"; font.pixelSize: 14; visible: ck.checked }
        }
        contentItem: Text {
            leftPadding: ck.indicator.width + 10; text: ck.text
            color: Pal.text; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter
        }
    }
    component Pill: Rectangle {
        id: pill
        property string text: ""
        property bool active: false
        signal clicked()
        implicitWidth: pt.implicitWidth + 28; implicitHeight: 34; radius: 17
        color: active ? "#26c9a063" : (pm.containsMouse ? "#1fffffff" : "#14ffffff")
        border.width: 1; border.color: active ? Pal.gold : Pal.line
        Behavior on color { ColorAnimation { duration: 120 } }
        Text { id: pt; anchors.centerIn: parent; text: pill.text; font.pixelSize: 14
               color: pill.active ? Pal.gold : Pal.text }
        MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
    }
    component ColorRow: RowLayout {
        id: cr
        property string label: ""
        property string value: "#ffffff"
        signal edited(string v)
        signal pick()
        spacing: 12
        Lbl { text: cr.label }
        Rectangle {
            width: 38; height: 38; radius: 19
            color: cr.value; border.width: 2; border.color: "#66ffffff"
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cr.pick() }
        }
        Field {
            Layout.preferredWidth: 130
            text: cr.value
            onEditingFinished: cr.edited(text)
        }
    }
    component Page: ScrollView {
        id: ps
        default property alias content: body.data
        property string title: ""
        property string subtitle: ""
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ColumnLayout {
            x: 36; y: 30
            width: ps.availableWidth - 72
            spacing: 6
            Text { text: ps.title; color: Pal.text; font.pixelSize: 30; font.weight: Font.Light; font.letterSpacing: 1 }
            Dim { text: ps.subtitle; Layout.bottomMargin: 14 }
            ColumnLayout { id: body; Layout.fillWidth: true; spacing: 16 }
            Item { Layout.preferredHeight: 30 }
        }
    }

    // ───────────────────────── dialogs ─────────────────────────
    FileDialog {
        id: bgDialog
        title: "Choose a video or image"
        nameFilters: ["Backgrounds (*.mp4 *.webm *.mkv *.mov *.avi *.m4v *.gif *.png *.jpg *.jpeg *.webp *.bmp *.avif)", "All files (*)"]
        onAccepted: win.pickBgFile(backend.localPath(selectedFile.toString()))
    }
    FileDialog {
        id: avDialog
        title: "Choose a profile picture"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.avif *.bmp)", "All files (*)"]
        onAccepted: backend.run(["-setAvatar", win.avatarUser, backend.localPath(selectedFile.toString())], "Profile picture updated")
    }
    FileDialog {
        id: fontDialog
        title: "Choose a font file"
        nameFilters: ["Fonts (*.ttf *.otf)", "All files (*)"]
        onAccepted: backend.run(["-setFont", backend.localPath(selectedFile.toString())], "Font file set")
    }
    ColorDialog {
        id: colorDialog
        onAccepted: win.setD(win.colorKey, selectedColor.toString())
    }
    FontLoader { id: previewFont; source: backend.fontUrl }

    // sudo password pop-up (opened by the SUDO_ASKPASS helper)
    Popup {
        id: pwPopup
        modal: true; focus: true
        anchors.centerIn: Overlay.overlay
        width: 430; padding: 26
        closePolicy: Popup.CloseOnEscape
        Overlay.modal: Rectangle { color: "#b0000000" }
        background: Rectangle { radius: 18; color: Pal.card2; border.width: 1; border.color: Pal.gold }
        onOpened: pwField.forceActiveFocus()
        onClosed: { if (!win.pwHandled) backend.cancelPassword(); pwField.text = "" }
        contentItem: ColumnLayout {
            spacing: 14
            Text { text: "🔒  Administrator password"; color: Pal.gold; font.pixelSize: 18 }
            Dim { text: "This step needs sudo. The password stays in memory only while this window is open." }
            Text {
                visible: win.pwRetry
                text: "✘ Wrong password — try again"; color: Pal.err; font.pixelSize: 13
            }
            Field {
                id: pwField
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: win.pwPrompt
                onAccepted: submit.clicked()
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight; spacing: 10
                GBtn { text: "Cancel"; onClicked: pwPopup.close() }
                GBtn {
                    id: submit
                    text: "Unlock"; kind: "primary"; canClick: pwField.text.length > 0
                    onClicked: { win.pwHandled = true; backend.submitPassword(pwField.text); pwPopup.close() }
                }
            }
        }
    }
    Popup {
        id: confirmClose
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 400; padding: 26
        Overlay.modal: Rectangle { color: "#b0000000" }
        background: Rectangle { radius: 18; color: Pal.card2; border.width: 1; border.color: Pal.border }
        contentItem: ColumnLayout {
            spacing: 14
            Text { text: "Unsaved appearance changes"; color: Pal.text; font.pixelSize: 18 }
            Dim { text: "You changed the look settings but did not save them." }
            RowLayout {
                Layout.alignment: Qt.AlignRight; spacing: 10
                GBtn { text: "Keep editing"; onClicked: confirmClose.close() }
                GBtn { text: "Discard"; kind: "danger"; onClicked: { win.forceClose = true; win.close() } }
                GBtn { text: "Save & quit"; kind: "primary"
                       onClicked: { backend.saveSettings(win.draft); win.forceClose = true; win.close() } }
            }
        }
    }
    onClosing: function (close) {
        if (dirty && !forceClose) { close.accepted = false; confirmClose.open() }
        else backend.shutdown()
    }

    Connections {
        target: backend
        function onDone(ok, label) {
            if (label === "__cancelled__") win.showToast("Cancelled", "warn")
            else if (ok) win.showToast(label !== "" ? label : "Done", "ok")
            else { win.showToast("Failed — see the Activity log", "err"); win.logOpen = true }
            if (ok && win.clearBgAfter) win.bgFile = ""
            win.clearBgAfter = false
            if (ok && win.chainInstall) {
                win.chainInstall = false
                backend.run(["-install"], "Installed to SDDM")
                return
            }
            win.chainInstall = false
        }
        function onLogged(t) { logArea.append(t) }
        function onToast(msg, kind) { win.showToast(msg, kind) }
        function onPasswordRequested(prompt, retry) {
            win.pwPrompt = prompt; win.pwRetry = retry; win.pwHandled = false
            pwField.text = ""
            pwPopup.open()
        }
        function onPasswordDismissed() { win.pwHandled = true; pwPopup.close() }
        function onSettingsSaved(ok) {
            if (ok) {
                win.draft = Object.assign({}, backend.settings)
                win.showToast("Appearance saved", "ok")
                if (win.previewAfterSave) backend.startPreview()
            }
            win.previewAfterSave = false
        }
    }
    Connections {
        target: backend
        function onBusyChanged() { if (backend.busy) win.logOpen = true }
    }

    // ───────────────────────── layout ─────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ───── sidebar ─────
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 236
            color: Pal.side
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Pal.border }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 4

                Row {
                    spacing: 12; Layout.bottomMargin: 26; Layout.topMargin: 6
                    Rectangle {
                        width: 38; height: 38; radius: 19; color: "transparent"
                        border.width: 2; border.color: Pal.gold
                        Rectangle { width: 12; height: 12; radius: 6; color: "#f1dcb0"; x: 22; y: 4 }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "Multi_Background"; color: Pal.gold; font.pixelSize: 18; font.letterSpacing: 1 }
                        Text { text: "SDDM theme studio"; color: Pal.dim; font.pixelSize: 12 }
                    }
                }

                Repeater {
                    model: win.pageNames
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 44; radius: 12
                        color: win.page === index ? "#22c9a063" : (nav.containsMouse ? "#12ffffff" : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Rectangle {
                            visible: win.page === index
                            width: 3; height: 22; radius: 2; color: Pal.gold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            x: 18; anchors.verticalCenter: parent.verticalCenter
                            text: win.pageIcons[index]; font.pixelSize: 17
                            color: win.page === index ? Pal.gold : Pal.dim
                        }
                        Text {
                            x: 50; anchors.verticalCenter: parent.verticalCenter
                            text: modelData; font.pixelSize: 15
                            color: win.page === index ? Pal.gold : Pal.text
                        }
                        Rectangle {
                            visible: index === 3 && win.dirty
                            width: 8; height: 8; radius: 4; color: Pal.warn
                            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                            id: nav; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.page = index
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: sudoCol.implicitHeight + 24
                    radius: 14; color: Pal.card; border.width: 1; border.color: Pal.border
                    ColumnLayout {
                        id: sudoCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 6
                        RowLayout {
                            spacing: 8
                            Rectangle { width: 9; height: 9; radius: 5; color: backend.sudoUnlocked ? Pal.ok : Pal.dim }
                            Text { text: backend.sudoUnlocked ? "Admin unlocked" : "Admin locked"; color: Pal.text; font.pixelSize: 13 }
                        }
                        Dim { text: backend.sudoUnlocked ? "Remembered until you close the window." : "A password pop-up appears whenever a step needs sudo." ; font.pixelSize: 11 }
                        GBtn {
                            visible: backend.sudoUnlocked; text: "Forget password"
                            implicitHeight: 30; Layout.fillWidth: true
                            onClicked: backend.forgetPassword()
                        }
                    }
                }
            }
        }

        // ───── content ─────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: win.page

                // ═════════ Overview ═════════
                Page {
                    title: "Overview"
                    subtitle: "Everything you change here is saved in this theme folder. Nothing in /usr/share is touched until you press Install."

                    RowLayout {
                        Layout.fillWidth: true; spacing: 16
                        Card {
                            heading: "Working folder"; Layout.alignment: Qt.AlignTop
                            T { text: backend.scriptDir; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; font.pixelSize: 13 }
                            RowLayout {
                                spacing: 8
                                Badge { text: backend.folderWritable ? "writable" : "read-only"; level: backend.folderWritable ? "ok" : "warn" }
                                Badge { text: backend.previewRunning ? "preview running" : "preview stopped"; level: backend.previewRunning ? "ok" : "info" }
                            }
                        }
                        Card {
                            heading: "SDDM installation"; Layout.alignment: Qt.AlignTop
                            T { text: backend.themeDir; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; font.pixelSize: 13 }
                            RowLayout {
                                spacing: 8
                                Badge { text: backend.themeInstalled ? "installed" : "not installed"; level: backend.themeInstalled ? "ok" : "warn" }
                                Badge { text: "active: " + backend.activeTheme
                                        level: backend.activeTheme === "Multi_Background" ? "ok" : "warn" }
                            }
                        }
                    }

                    RowLayout {
                        spacing: 12
                        GBtn {
                            text: backend.previewRunning ? "■  Stop preview" : "▶  Preview this folder"
                            kind: "primary"
                            onClicked: backend.previewRunning ? backend.stopPreview() : backend.startPreview()
                        }
                        GBtn { text: "⬇  Install / update SDDM copy"; needsIdle: true
                               onClicked: backend.run(["-install"], "Installed to SDDM") }
                        GBtn { text: "↻  Re-check"; onClicked: backend.refreshStatus() }
                    }

                    Card {
                        heading: "Requirements"
                        Repeater {
                            model: backend.checks
                            delegate: RowLayout {
                                Layout.fillWidth: true; spacing: 12
                                Rectangle {
                                    width: 24; height: 24; radius: 12
                                    color: modelData.level === "ok" ? "#2286c28b" : modelData.level === "warn" ? "#22e3b45a" : "#22ff7a7a"
                                    Text {
                                        anchors.centerIn: parent; font.pixelSize: 13
                                        text: modelData.level === "ok" ? "✓" : modelData.level === "warn" ? "!" : "✕"
                                        color: modelData.level === "ok" ? Pal.ok : modelData.level === "warn" ? Pal.warn : Pal.err
                                    }
                                }
                                T { text: modelData.name; Layout.preferredWidth: 200; font.weight: Font.Medium }
                                Dim { text: modelData.detail; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                            }
                        }
                    }
                }

                // ═════════ Backgrounds ═════════
                Page {
                    title: "Backgrounds"
                    subtitle: "“default” shows until a profile is clicked. A user's own background shows only while their profile is focused."

                    Flow {
                        Layout.fillWidth: true; spacing: 8
                        Repeater {
                            model: win.targets
                            delegate: Pill {
                                text: modelData; active: win.bgTarget === modelData
                                onClicked: win.bgTarget = modelData
                            }
                        }
                    }

                    // preview
                    Rectangle {
                        id: pv
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(width * 9 / 16, 380)
                        radius: 16; color: "#000000"; clip: true
                        border.width: 1; border.color: Pal.border

                        Loader {
                            id: vl
                            anchors.fill: parent
                            active: win.page === 1 && win.pvKind === "video"
                            visible: active && !win.pvError
                            source: "VideoPreview.qml"
                            onStatusChanged: if (status === Loader.Error) win.pvError = true
                            onLoaded: { item.source = Qt.binding(function () { return win.pvUrl }) }
                            Connections { target: vl.item; ignoreUnknownSignals: true; function onFailed() { win.pvError = true } }
                        }
                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false
                            visible: source.toString() !== ""
                            source: win.pvKind === "image" ? win.pvUrl : win.pvThumb
                        }
                        Column {
                            anchors.centerIn: parent; spacing: 6
                            visible: win.pvKind === "none" || (win.pvKind === "video" && win.pvError && win.pvThumb === "")
                            Text { anchors.horizontalCenter: parent.horizontalCenter
                                   text: win.pvKind === "none" ? "▣" : "⚠"; color: Pal.dim; font.pixelSize: 40 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; color: Pal.dim; font.pixelSize: 14
                                   text: win.pvKind === "none" ? "No background yet — drop a video or image here"
                                                               : "Can't preview this video here (it may still work in SDDM)" }
                        }
                        Row {
                            anchors { left: parent.left; top: parent.top; margins: 14 }
                            spacing: 8
                            Badge { visible: win.pvKind !== "none"; text: win.pvKind === "video" ? "VIDEO" : "IMAGE"; level: "info" }
                            Badge { visible: win.bgFile !== ""; text: "NOT SAVED YET"; level: "warn" }
                        }
                        DropArea {
                            id: bgDrop
                            anchors.fill: parent
                            keys: ["text/uri-list"]
                            onDropped: function (drop) { if (drop.hasUrls) win.pickBgFile(backend.localPath(drop.urls[0].toString())) }
                            Rectangle {
                                anchors.fill: parent; radius: 16; color: "#33c9a063"
                                border.width: 2; border.color: Pal.gold; visible: bgDrop.containsDrag
                                Text { anchors.centerIn: parent; text: "Drop to preview"; color: Pal.goldHi; font.pixelSize: 20 }
                            }
                        }
                    }

                    Card {
                        heading: "Change background for “" + win.bgTarget + "”"
                        RowLayout {
                            Layout.fillWidth: true; spacing: 12
                            GBtn { text: "Choose file…"; onClicked: bgDialog.open() }
                            T {
                                Layout.fillWidth: true; elide: Text.ElideMiddle; wrapMode: Text.NoWrap
                                color: win.bgFile !== "" ? Pal.text : Pal.dim; font.pixelSize: 13
                                text: win.bgFile !== "" ? win.bgFile
                                    : (win.pvInfo.kind === "none" ? "nothing saved — choose or drop a file"
                                                                  : "saved: " + win.pvInfo.path + "  (" + win.pvInfo.size + ")")
                            }
                        }
                        Check {
                            text: "Also install to SDDM afterwards (leave off while developing)"
                            checked: win.installAfter; onToggled: win.installAfter = checked
                        }
                        RowLayout {
                            spacing: 12
                            GBtn {
                                text: "Save background"; kind: "primary"; needsIdle: true
                                canClick: win.bgFile !== ""
                                onClicked: {
                                    win.chainInstall = win.installAfter
                                    win.clearBgAfter = true
                                    backend.run(["-setBG", win.bgTarget, win.bgFile], "Background saved")
                                }
                            }
                            GBtn {
                                text: "Discard choice"; canClick: win.bgFile !== ""
                                onClicked: win.bgFile = ""
                            }
                            GBtn {
                                text: "Remove saved background"; kind: "danger"; needsIdle: true
                                canClick: win.pvInfo.kind !== "none"
                                onClicked: backend.run(["-rmBG", win.bgTarget], "Background removed")
                            }
                        }
                    }
                }

                // ═════════ Avatars ═════════
                Page {
                    title: "Avatars"
                    subtitle: "Pictures are square-cropped to 512×512 and saved in this folder's avatars/ directory. Drop an image on a card to set it."

                    RowLayout {
                        spacing: 12
                        GBtn { text: "↻  Rebuild all from ~/.face"; needsIdle: true
                               onClicked: backend.run(["-avatars"], "Avatars rebuilt") }
                    }
                    Flow {
                        Layout.fillWidth: true; spacing: 18
                        Repeater {
                            model: backend.users
                            delegate: Rectangle {
                                id: avCard
                                width: 210; height: 270; radius: 18
                                color: avDrop.containsDrag ? "#26c9a063" : Pal.card
                                border.width: 1; border.color: avDrop.containsDrag ? Pal.gold : Pal.border
                                Behavior on color { ColorAnimation { duration: 120 } }
                                DropArea {
                                    id: avDrop
                                    anchors.fill: parent; keys: ["text/uri-list"]
                                    onDropped: function (drop) {
                                        if (!drop.hasUrls) return
                                        var p = backend.localPath(drop.urls[0].toString())
                                        if (backend.fileKind(p) !== "image") { win.showToast("That is not an image", "err"); return }
                                        backend.run(["-setAvatar", modelData.login, p], "Profile picture updated")
                                    }
                                }
                                Column {
                                    anchors.centerIn: parent; spacing: 10
                                    Rectangle {
                                        width: 112; height: 112; radius: 56
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        color: "#22ffffff"; border.width: 2; border.color: Pal.gold; clip: true
                                        Text {
                                            anchors.centerIn: parent; color: Pal.text; font.pixelSize: 44
                                            visible: img.status !== Image.Ready
                                            text: modelData.name.charAt(0).toUpperCase()
                                        }
                                        Image {
                                            id: img
                                            anchors.fill: parent; cache: false; asynchronous: true
                                            fillMode: Image.PreserveAspectCrop
                                            sourceSize: Qt.size(256, 256)
                                            source: modelData.avatar
                                        }
                                    }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter
                                           text: modelData.name; color: Pal.text; font.pixelSize: 16 }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter
                                           text: "login: " + modelData.login; color: Pal.dim; font.pixelSize: 12 }
                                    Badge { anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.hasAvatar ? "picture set" : "no picture yet"
                                            level: modelData.hasAvatar ? "ok" : "warn" }
                                    GBtn {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Choose image…"; needsIdle: true; implicitHeight: 34
                                        onClicked: { win.avatarUser = modelData.login; avDialog.open() }
                                    }
                                }
                            }
                        }
                    }
                }

                // ═════════ Appearance ═════════
                ColumnLayout {
                    spacing: 0
                    Page {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        title: "Appearance"
                        subtitle: "Colors, clock, font and texts of the login screen. Save writes ThemeSettings.qml next to Main.qml."

                        // mini login-screen mock
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 250
                            radius: 16; color: "#000000"; clip: true
                            border.width: 1; border.color: Pal.border
                            Image {
                                anchors.fill: parent; fillMode: Image.PreserveAspectCrop; cache: false
                                source: { backend.rev; var i = backend.bgInfo("default"); return i.kind === "image" ? i.url : "" }
                            }
                            Rectangle { anchors.fill: parent; color: "#000000"; opacity: win.dv("dim") + 0.05 }
                            Column {
                                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 18 }
                                spacing: 0
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: win.dv("dateFormat") !== ""
                                    text: Qt.formatDate(new Date(), win.dv("dateFormat"))
                                    color: win.dv("textColor"); opacity: 0.9
                                    font.family: win.dv("fontFamily") !== "" ? win.dv("fontFamily") : previewFont.name
                                    font.pixelSize: win.dv("dateSize") * 0.4
                                }
                                Item {
                                    width: clk.width + 30; height: clk.height
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    Rectangle {
                                        visible: win.dv("showOrbit")
                                        anchors.centerIn: parent
                                        width: clk.width + 26; height: clk.height * 0.38; radius: height / 2
                                        color: "transparent"; border.width: 1.5
                                        border.color: Qt.rgba(Qt.color(win.dv("accent")).r, Qt.color(win.dv("accent")).g, Qt.color(win.dv("accent")).b, 0.7)
                                        rotation: -4
                                        Rectangle { width: 8; height: 8; radius: 4; color: "#f1dcb0"; x: parent.width - 20; y: -3 }
                                    }
                                    Text {
                                        id: clk
                                        anchors.centerIn: parent
                                        text: win.clockText(new Date(), win.dv("clockFormat"), win.dv("hideAmPm"))
                                        color: win.dv("textColor")
                                        font.family: win.dv("fontFamily") !== "" ? win.dv("fontFamily") : previewFont.name
                                        font.pixelSize: win.dv("clockSize") * 0.4
                                    }
                                }
                            }
                            Column {
                                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 16 }
                                spacing: 8
                                Rectangle {
                                    width: 190; height: 30; radius: 15; color: "#2effffff"
                                    border.width: 1; border.color: "#55ffffff"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter; x: 14
                                        text: win.dv("passwordHint"); color: win.dv("textColor"); opacity: 0.55; font.pixelSize: 12
                                        font.family: win.dv("fontFamily") !== "" ? win.dv("fontFamily") : previewFont.name
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: win.dv("errorText"); color: win.dv("errorColor"); font.pixelSize: 12
                                    font.family: win.dv("fontFamily") !== "" ? win.dv("fontFamily") : previewFont.name
                                }
                            }
                            Rectangle {
                                width: 46; height: 46; radius: 23; color: "#22ffffff"
                                anchors { left: parent.left; bottom: parent.bottom; margins: 16 }
                                border.width: 2; border.color: win.dv("accent")
                            }
                            Badge { anchors { right: parent.right; top: parent.top; margins: 12 } text: "LIVE MOCK-UP"; level: "info" }
                        }

                        Card {
                            heading: "Colors"
                            ColorRow {
                                label: "Accent color"; value: win.dv("accent")
                                onEdited: function (v) { if (win.validHex(v)) win.setD("accent", v); else win.showToast("Use a hex color like #c9a063", "warn") }
                                onPick: { win.colorKey = "accent"; colorDialog.selectedColor = win.dv("accent"); colorDialog.open() }
                            }
                            ColorRow {
                                label: "Text color"; value: win.dv("textColor")
                                onEdited: function (v) { if (win.validHex(v)) win.setD("textColor", v); else win.showToast("Use a hex color like #ffffff", "warn") }
                                onPick: { win.colorKey = "textColor"; colorDialog.selectedColor = win.dv("textColor"); colorDialog.open() }
                            }
                            ColorRow {
                                label: "Error color"; value: win.dv("errorColor")
                                onEdited: function (v) { if (win.validHex(v)) win.setD("errorColor", v); else win.showToast("Use a hex color like #ff7a7a", "warn") }
                                onPick: { win.colorKey = "errorColor"; colorDialog.selectedColor = win.dv("errorColor"); colorDialog.open() }
                            }
                        }

                        Card {
                            heading: "Clock & date"
                            RowLayout {
                                spacing: 12
                                Lbl { text: "Clock format" }
                                Field { Layout.preferredWidth: 200; text: win.dv("clockFormat"); onTextEdited: win.setD("clockFormat", text) }
                                Combo {
                                    Layout.preferredWidth: 220
                                    model: ["24 h  (HH:mm)", "24 h + seconds  (HH:mm:ss)", "12 h  (hh:mm AP)", "12 h short  (h:mm AP)", "12 h, no AM/PM  (hh:mm)", "12 h, no AM/PM, no zero  (h:mm)"]
                                    displayText: "presets…"
                                    onActivated: function (i) {
                                        var f = ["HH:mm", "HH:mm:ss", "hh:mm AP", "h:mm AP", "hh:mm", "h:mm"][i]
                                        var d = Object.assign({}, win.draft)
                                        d.clockFormat = f
                                        d.hideAmPm = (i >= 4)
                                        win.draft = d
                                    }
                                }
                            }
                            RowLayout {
                                spacing: 12
                                Lbl { text: "12-hour, no AM/PM" }
                                Tog { checked: win.dv("hideAmPm"); onToggled: win.setD("hideAmPm", checked) }
                                Dim { text: "turns h / hh into 12-hour values and hides AM/PM" }
                            }
                            RowLayout {
                                spacing: 12
                                Lbl { text: "Date format" }
                                Field { Layout.preferredWidth: 200; text: win.dv("dateFormat"); placeholderText: "empty = hide the date"
                                        onTextEdited: win.setD("dateFormat", text) }
                                Combo {
                                    Layout.preferredWidth: 220
                                    model: ["Monday, October 5", "Mon 5 Oct", "05/10/2026", "2026-10-05", "(hidden)"]
                                    displayText: "presets…"
                                    onActivated: function (i) { win.setD("dateFormat", ["dddd, MMMM d", "ddd d MMM", "dd/MM/yyyy", "yyyy-MM-dd", ""][i]) }
                                }
                            }
                            RowLayout {
                                spacing: 12
                                Lbl { text: "Clock size" }
                                Spin { from: 40; to: 400; stepSize: 10; value: win.dv("clockSize"); onValueModified: win.setD("clockSize", value) }
                                Lbl { text: "Date size"; Layout.leftMargin: 24; Layout.preferredWidth: 90 }
                                Spin { from: 10; to: 120; stepSize: 2; value: win.dv("dateSize"); onValueModified: win.setD("dateSize", value) }
                            }
                            RowLayout {
                                spacing: 12
                                Lbl { text: "Moon & ring" }
                                Tog { checked: win.dv("showOrbit"); onToggled: win.setD("showOrbit", checked) }
                                Dim { text: "orbit animation around the clock" }
                            }
                            RowLayout {
                                spacing: 12
                                Lbl { text: "Background dimming" }
                                Sld {
                                    Layout.preferredWidth: 280; from: 0; to: 0.9; stepSize: 0.05; value: win.dv("dim")
                                    onMoved: win.setD("dim", Math.round(value * 100) / 100)
                                }
                                T { text: Math.round(win.dv("dim") * 100) + " %"; color: Pal.dim }
                            }
                        }

                        Card {
                            heading: "Font"
                            RowLayout {
                                spacing: 12
                                Lbl { text: "Font family" }
                                Combo {
                                    Layout.preferredWidth: 320
                                    model: ["(use theme font file)"].concat(backend.systemFonts)
                                    currentIndex: {
                                        var f = win.dv("fontFamily")
                                        if (!f) return 0
                                        var i = model.indexOf(f)
                                        return i < 0 ? 0 : i
                                    }
                                    onActivated: function (i) { win.setD("fontFamily", i === 0 ? "" : model[i]) }
                                }
                            }
                            RowLayout {
                                spacing: 12
                                Lbl { text: "Theme font file" }
                                T {
                                    Layout.preferredWidth: 230; elide: Text.ElideMiddle; wrapMode: Text.NoWrap; font.pixelSize: 13
                                    color: backend.fontFiles.length ? Pal.text : Pal.dim
                                    text: backend.fontFiles.length ? backend.fontFiles[0] : "none (system default)"
                                }
                                GBtn { text: "Choose .ttf / .otf…"; needsIdle: true; onClicked: fontDialog.open() }
                                GBtn { text: "Clear"; needsIdle: true; canClick: backend.fontFiles.length > 0
                                       onClicked: backend.run(["-clearFont"], "Font file removed") }
                            }
                            Dim { text: "A family chosen above wins over the font file. System fonts must also be installed for the sddm user, so a font file is the safer choice." }
                        }

                        Card {
                            heading: "Texts"
                            RowLayout {
                                spacing: 12
                                Lbl { text: "Password hint" }
                                Field { Layout.preferredWidth: 320; text: win.dv("passwordHint"); onTextEdited: win.setD("passwordHint", text) }
                            }
                            RowLayout {
                                spacing: 12
                                Lbl { text: "Wrong-password text" }
                                Field { Layout.preferredWidth: 320; text: win.dv("errorText"); onTextEdited: win.setD("errorText", text) }
                            }
                        }
                    }

                    // sticky save bar
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 66
                        color: Pal.side
                        Rectangle { width: parent.width; height: 1; color: Pal.border }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 36; rightMargin: 36 }
                            spacing: 10
                            Badge { text: win.dirty ? "unsaved changes" : "all saved"; level: win.dirty ? "warn" : "ok" }
                            Item { Layout.fillWidth: true }
                            GBtn { text: "Reset to defaults"; onClicked: { win.draft = Object.assign({}, backend.defaults) } }
                            GBtn { text: "Revert"; canClick: win.dirty; onClicked: { backend.reloadSettings(); win.draft = Object.assign({}, backend.settings) } }
                            GBtn { text: "Save"; canClick: win.dirty; needsIdle: true; onClicked: backend.saveSettings(win.draft) }
                            GBtn { text: "Save & preview"; kind: "primary"; needsIdle: true
                                   onClicked: { win.previewAfterSave = true; backend.saveSettings(win.draft) } }
                        }
                    }
                }

                // ═════════ Touchpad ═════════
                Page {
                    title: "Touchpad"
                    subtitle: "The SDDM greeter runs as its own user and ignores your desktop's touchpad settings, so tap-to-click is off by default."

                    Card {
                        heading: "Tap-to-click on the login screen"
                        RowLayout {
                            spacing: 10
                            Badge { text: backend.tapEnabled ? "enabled" : "not enabled"; level: backend.tapEnabled ? "ok" : "info" }
                            Badge { text: "greeter: " + backend.displayServer; level: "info" }
                        }
                        Dim { text: "Writes /etc/X11/xorg.conf.d/90-sddm-touchpad.conf (used by the X11 greeter). For a Wayland greeter the Activity log tells you what else to change." }
                        RowLayout {
                            spacing: 12
                            GBtn { text: "Enable tap-to-click"; kind: "primary"; needsIdle: true
                                   onClicked: backend.run(["-tap"], "Tap-to-click enabled") }
                            GBtn { text: "Disable"; needsIdle: true; canClick: backend.tapEnabled
                                   onClicked: backend.run(["-untap"], "Tap-to-click disabled") }
                        }
                        Dim { text: "Takes effect after SDDM restarts — reboot, or restart the sddm service (that ends your session)." }
                    }
                }
            }

            // ───── activity drawer ─────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: win.logOpen ? 230 : 44
                Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                color: Pal.side; clip: true
                Rectangle { width: parent.width; height: 1; color: Pal.border }

                ColumnLayout {
                    anchors.fill: parent; spacing: 0
                    RowLayout {
                        Layout.fillWidth: true; Layout.preferredHeight: 44
                        Layout.leftMargin: 20; Layout.rightMargin: 16; spacing: 10
                        MouseArea { id: logHead; Layout.fillWidth: true; Layout.fillHeight: true
                                    cursorShape: Qt.PointingHandCursor; onClicked: win.logOpen = !win.logOpen
                            Row {
                                anchors.verticalCenter: parent.verticalCenter; spacing: 10
                                Text { text: win.logOpen ? "▾" : "▸"; color: Pal.dim; font.pixelSize: 14 }
                                Text { text: "Activity"; color: Pal.text; font.pixelSize: 14; font.weight: Font.Medium }
                                BusyIndicator { visible: backend.busy; running: backend.busy; width: 20; height: 20 }
                                Text { visible: backend.busy; text: "working…"; color: Pal.gold; font.pixelSize: 13 }
                            }
                        }
                        GBtn { text: "Cancel"; kind: "danger"; visible: backend.busy; implicitHeight: 30; onClicked: backend.cancel() }
                        GBtn { text: "Copy"; implicitHeight: 30; visible: win.logOpen
                               onClicked: { logArea.selectAll(); logArea.copy(); logArea.deselect(); win.showToast("Log copied", "info") } }
                        GBtn { text: "Clear"; implicitHeight: 30; visible: win.logOpen; onClicked: logArea.clear() }
                    }
                    ScrollView {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.bottomMargin: 10
                        TextArea {
                            id: logArea
                            readOnly: true; wrapMode: TextArea.Wrap; selectByMouse: true
                            color: "#cfc6b4"; font.family: "monospace"; font.pixelSize: 12
                            background: null
                            onTextChanged: cursorPosition = length
                        }
                    }
                }
            }
        }
    }

    // ───────────────────────── toast ─────────────────────────
    Timer { id: toastTimer; interval: 3800 }
    Rectangle {
        id: toastBox
        z: 200
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 66 }
        width: Math.min(tt.implicitWidth + 44, parent.width - 80); height: 44; radius: 22
        opacity: toastTimer.running ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        color: Pal.card2
        border.width: 1
        border.color: win.toastKind === "ok" ? Pal.ok : win.toastKind === "err" ? Pal.err : win.toastKind === "warn" ? Pal.warn : Pal.gold
        Text {
            id: tt; anchors.centerIn: parent; width: parent.width - 40
            horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
            text: (win.toastKind === "ok" ? "✓  " : win.toastKind === "err" ? "✕  " : win.toastKind === "warn" ? "!  " : "")
                  + win.toastText
            color: Pal.text; font.pixelSize: 14
        }
    }
}
