import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import QtMultimedia
import Qt.labs.folderlistmodel

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "transparent"
    focus: true
    readonly property real s: width / 1920

    // Palette
    readonly property color fg:       "#ffffff"
    readonly property color gold:     "#c9a063"
    readonly property color errorClr: "#ff7a7a"

    // State
    property int  userIndex:    userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int  sessionIndex: (sessionModel && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
    property bool sessionMenuOpen: false
    property bool passwordOpen: false
    property bool loginError: false
    property bool loggingIn: false
    property string loginErrorMsg: "Incorrect password"
    property date now: new Date()

    // Session button: stays small until clicked, collapses again when left alone
    readonly property bool sessionHover: sessionPillHover.hovered || sessionMenuHover.hovered
    onSessionHoverChanged: if (!sessionHover && sessionMenuOpen) sessionIdle.restart()
    onSessionMenuOpenChanged: if (sessionMenuOpen) sessionIdle.restart()

    Timer {
        id: sessionIdle
        interval: 5000
        onTriggered: if (root.sessionMenuOpen && !root.sessionHover) root.sessionMenuOpen = false
    }

    Keys.onEscapePressed: {
        if (root.loggingIn) return
        root.sessionMenuOpen = false
        root.passwordOpen = false
    }

    onPasswordOpenChanged: {
        if (passwordOpen) {
            focusTimer.restart()
        } else {
            passInput.text = ""
            root.loginError = false
            root.forceActiveFocus()
        }
    }

    Timer { id: focusTimer; interval: 120; onTriggered: passInput.forceActiveFocus() }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // Connect to SDDM login failed signal
    Connections {
        target: sddm
        function onLoginFailed() {
            root.loggingIn = false
            root.loginError = true
            passInput.text = ""
            passInput.forceActiveFocus()
            errorShakeAnim.restart()
        }
    }

    FolderListModel {
        id: fontFolder
        folder: Qt.resolvedUrl("font")
        nameFilters: ["*.ttf", "*.otf"]
    }

    FontLoader {
        id: serifFont
        source: fontFolder.count > 0 ? "font/" + fontFolder.get(0, "fileName") : ""
    }

    // Minimalist round "glass" button. Put an icon inside it as a child item.
    // (Inline components can't see outer ids, so scale/font are passed in.)
    component GlassButton: Item {
        id: btn
        property real u: 1
        property string label: ""
        property string fontFamily: ""
        property color accent: "#c9a063"
        signal clicked()
        default property alias content: iconSlot.data
        readonly property bool hovered: ma.containsMouse

        width: 44 * u
        height: 44 * u
        scale: ma.pressed ? 0.94 : 1.0
        Behavior on scale { NumberAnimation { duration: 120 } }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: btn.hovered ? "#33ffffff" : "#1fffffff"
            border.width: 1
            border.color: btn.hovered ? btn.accent : "#33ffffff"
            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }
        }

        Item { id: iconSlot; anchors.fill: parent }

        // Label fades in above the button on hover
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: 10 * btn.u
            text: btn.label
            font.family: btn.fontFamily
            font.pixelSize: 13 * btn.u
            font.letterSpacing: 1 * btn.u
            color: "#ffffff"
            opacity: btn.hovered ? 0.85 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    // ───────────── Backgrounds ─────────────
    // Looks next to this file for <name>.mp4 or <name>.jpg
    //   default.(mp4|jpg)   -> shown until a user profile is clicked
    //   <login>.(mp4|jpg)   -> shown only while that user's profile is in focus
    FolderListModel {
        id: bgFolder
        folder: Qt.resolvedUrl(".")
        nameFilters: ["*.mp4", "*.jpg"]
        showDirs: false
    }

    function bgFor(name) {
        var c = bgFolder.count
        var wanted = [name + ".mp4", name + ".jpg"]
        for (var w = 0; w < wanted.length; w++)
            for (var i = 0; i < c; i++)
                if (bgFolder.get(i, "fileName") === wanted[w]) return wanted[w]
        return ""
    }

    readonly property string defaultBg: bgFor("default")
    readonly property string userBg:
        (userHelper.currentItem && userHelper.currentItem.uLogin !== "")
        ? bgFor(userHelper.currentItem.uLogin) : ""
    // User background only while their profile is focused (password field open)
    readonly property string activeBg: (passwordOpen && userBg !== "") ? userBg : defaultBg

    property string shownBg: ""
    readonly property bool shownIsVideo: shownBg.slice(-4) === ".mp4"

    onActiveBgChanged: {
        if (shownBg === "")
            shownBg = activeBg          // first load: no fade
        else if (activeBg !== shownBg)
            bgSwitch.restart()
    }

    // Fade to black, swap the background, fade back in
    SequentialAnimation {
        id: bgSwitch
        NumberAnimation { target: bgFade; property: "opacity"; to: 1; duration: 250 }
        ScriptAction { script: root.shownBg = root.activeBg }
        PauseAnimation { duration: 150 }
        NumberAnimation { target: bgFade; property: "opacity"; to: 0; duration: 350 }
    }

    // Helpers that expose the current user / session
    ListView {
        id: sessionHelper
        model: sessionModel
        currentIndex: root.sessionIndex
        opacity: 0
        width: 1
        height: 1
        z: -100
        delegate: Item {
            property string sName: (model && model.name) ? model.name : ""
        }
    }

    ListView {
        id: userHelper
        model: userModel
        currentIndex: root.userIndex
        opacity: 0
        width: 1
        height: 1
        z: -100
        delegate: Item {
            property string uName: (model && (model.realName || model.name)) ? (model.realName || model.name) : ""
            property string uLogin: (model && model.name) ? model.name : ""
        }
    }

    function selectUser(i) {
        if (root.loggingIn) return
        root.sessionMenuOpen = false
        if (root.userIndex === i && root.passwordOpen) {
            root.passwordOpen = false
            return
        }
        root.userIndex = i
        root.loginError = false
        passInput.text = ""
        root.passwordOpen = true
        focusTimer.restart()
    }

    function login() {
        if (root.loggingIn) return
        var n = ""
        if (userHelper.currentItem && userHelper.currentItem.uName !== "") {
            n = userHelper.currentItem.uLogin
        } else {
            n = userModel.lastUser
        }
        root.loginError = false
        root.loggingIn = true
        sddm.login(n, passInput.text, root.sessionIndex)
    }

    // ───────────── Background ─────────────
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        z: -1000
    }

    MediaPlayer {
        id: player
        source: root.shownIsVideo ? Qt.resolvedUrl(root.shownBg) : ""
        videoOutput: bgVideo
        loops: MediaPlayer.Infinite

        onSourceChanged: {
            stop()
            if (root.shownIsVideo) play()
        }

        onErrorOccurred: function(error, errorString) {
            console.log("Video error:", errorString)
            // A broken user video falls back to the default background
            if (root.shownBg !== root.defaultBg) root.shownBg = root.defaultBg
        }

        Component.onCompleted: if (root.shownIsVideo) play()
    }

    VideoOutput {
        id: bgVideo
        anchors.fill: parent
        visible: root.shownIsVideo
        fillMode: VideoOutput.PreserveAspectCrop
        z: -500
    }

    Image {
        id: bgImage
        anchors.fill: parent
        z: -500
        visible: !root.shownIsVideo && root.shownBg !== ""
        source: visible ? Qt.resolvedUrl(root.shownBg) : ""
        asynchronous: true
        cache: false
        fillMode: Image.PreserveAspectCrop
    }

    // Black overlay used for the cross-fade between backgrounds
    Rectangle {
        id: bgFade
        anchors.fill: parent
        color: "#000000"
        opacity: 0
        z: -400
    }

    Rectangle {
        anchors.fill: parent
        z: -300
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#40000000" }
            GradientStop { position: 1.0; color: "#59000000" }
        }
    }

    // Click on empty space: close password field / session menu
    MouseArea {
        anchors.fill: parent
        z: -200
        onClicked: {
            root.sessionMenuOpen = false
            if (!root.loggingIn) root.passwordOpen = false
        }
    }

    // ───────────── Clock (top center) ─────────────
    Column {
        id: clockWidget
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 80 * s
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, "dddd, MMMM d")
            font.family: serifFont.name
            font.pixelSize: 30 * s
            font.letterSpacing: 1 * s
            color: root.fg
            opacity: 0.9
            layer.enabled: true
            layer.effect: DropShadow { color: "#88000000"; radius: 10 }
        }

        // Time + orbiting moon (ring is tilted: far half behind the digits,
        // near half in front, and the moon swaps sides with scale/brightness)
        Item {
            id: timeBlock
            anchors.horizontalCenter: parent.horizontalCenter
            width: timeLabel.width
            height: timeLabel.height

            // The ring keeps a fixed size/tightness; only its roll (tilt) eases back
            // and forth. The ring shapes themselves are never re-drawn - just rotated -
            // so the motion stays perfectly smooth. The moon uses the same tilt.
            property real phase: 0
            NumberAnimation on phase {
                from: 0; to: Math.PI * 2
                duration: 24000
                loops: Animation.Infinite
                running: true
            }
            readonly property real baseTilt: -4
            readonly property real tiltDeg: baseTilt + 9 * Math.sin(phase)
            readonly property real tiltRad: tiltDeg * Math.PI / 180
            readonly property real orbitW: timeLabel.width + 50 * s
            readonly property real orbitH: timeLabel.height * 0.40
            readonly property color ringClr: "#c9a063"

            property real t: 0
            NumberAnimation on t {
                from: 0; to: Math.PI * 2
                duration: 14000
                loops: Animation.Infinite
                running: true
            }
            // +1 = closest to the viewer (front), -1 = farthest (behind)
            readonly property real depth: Math.sin(t)
            readonly property real near: (depth + 1) / 2

            // Far half of the ring - hidden behind the digits
            Shape {
                z: 10
                width: timeBlock.orbitW
                height: timeBlock.orbitH
                anchors.centerIn: parent
                rotation: timeBlock.tiltDeg
                antialiasing: true
                // Qt 6.6+: analytic curve rendering = smooth edges without MSAA
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 1.2
                    strokeColor: Qt.rgba(timeBlock.ringClr.r, timeBlock.ringClr.g, timeBlock.ringClr.b, 0.22)
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: timeBlock.orbitW / 2; centerY: timeBlock.orbitH / 2
                        radiusX: timeBlock.orbitW / 2; radiusY: timeBlock.orbitH / 2
                        startAngle: 180; sweepAngle: 180
                    }
                }
            }

            // Digits
            Text {
                id: timeLabel
                text: Qt.formatTime(root.now, "HH:mm")
                font.family: serifFont.name
                font.pixelSize: 160 * s
                font.letterSpacing: 2 * s
                color: root.fg
                z: 50
                layer.enabled: true
                layer.effect: DropShadow { color: "#88000000"; radius: 16 }
            }

            // Near half of the ring - passes over the digits
            Shape {
                z: 60
                width: timeBlock.orbitW
                height: timeBlock.orbitH
                anchors.centerIn: parent
                rotation: timeBlock.tiltDeg
                antialiasing: true
                // Qt 6.6+: analytic curve rendering = smooth edges without MSAA
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 1.8
                    strokeColor: Qt.rgba(timeBlock.ringClr.r, timeBlock.ringClr.g, timeBlock.ringClr.b, 0.75)
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: timeBlock.orbitW / 2; centerY: timeBlock.orbitH / 2
                        radiusX: timeBlock.orbitW / 2; radiusY: timeBlock.orbitH / 2
                        startAngle: 0; sweepAngle: 180
                    }
                }
            }

            // Moon: bigger/brighter and in front when near, smaller/dimmer and behind when far
            Rectangle {
                id: moon
                width: 14 * s
                height: 14 * s
                radius: width / 2
                color: "#f1dcb0"
                antialiasing: true
                z: timeBlock.depth >= 0 ? 100 : 20
                scale: 0.7 + 0.5 * timeBlock.near
                opacity: 0.5 + 0.5 * timeBlock.near

                // point on the ellipse, then rotated by the ring's tilt
                property real ex: (timeBlock.orbitW / 2) * Math.cos(timeBlock.t)
                property real ey: (timeBlock.orbitH / 2) * Math.sin(timeBlock.t)
                x: timeBlock.width  / 2 + ex * Math.cos(timeBlock.tiltRad) - ey * Math.sin(timeBlock.tiltRad) - width  / 2
                y: timeBlock.height / 2 + ex * Math.sin(timeBlock.tiltRad) + ey * Math.cos(timeBlock.tiltRad) - height / 2

                layer.enabled: true
                layer.effect: DropShadow { color: "#c9a063"; radius: 10; samples: 21; spread: 0.2 }
            }
        }
    }

    // ───────────── Login (center center) ─────────────
    Item {
        id: loginCenter
        anchors.centerIn: parent
        width: 900 * s
        height: 380 * s

        // Avatars. When one is clicked it grows, the others collapse away,
        // and the row re-centers around the selected user.
        Row {
            id: userRow
            anchors.horizontalCenter: parent.horizontalCenter
            y: (root.passwordOpen ? 30 : 65) * s
            spacing: root.passwordOpen ? 0 : 48 * s

            Behavior on y { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            Behavior on spacing { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

            Repeater {
                model: userModel
                delegate: Item {
                    id: userItem

                    property bool selected: root.userIndex === index
                    property bool focusedUser: root.passwordOpen && selected
                    property bool hiddenUser: root.passwordOpen && !selected
                    property real avatarSize: (focusedUser ? 176 : 128) * s
                    property url localAvatar: Qt.resolvedUrl("avatars/" + model.name + ".png")
                    property string rawIcon: (model.icon !== undefined && model.icon !== null) ? String(model.icon) : ""
                    property bool triedIcon: false

                    width: hiddenUser ? 0 : (focusedUser ? 220 * s : 140 * s)
                    height: 250 * s
                    opacity: hiddenUser ? 0 : 1
                    visible: opacity > 0
                    scale: (avMa.containsMouse && !focusedUser) ? 1.06 : 1.0

                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                    Behavior on avatarSize { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                    Item {
                        id: avatar
                        width: userItem.avatarSize
                        height: userItem.avatarSize
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "#33ffffff"
                        }

                        // Initial shown when no picture is available
                        Text {
                            anchors.centerIn: parent
                            text: ((model.realName || model.name) || "?").charAt(0).toUpperCase()
                            font.family: serifFont.name
                            font.pixelSize: avatar.width * 0.44
                            color: root.fg
                            visible: avImg.status !== Image.Ready
                        }

                        // 1st choice: <theme>/avatars/<username>.png
                        // 2nd choice: whatever SDDM reports as the user's icon
                        Image {
                            id: avImg
                            anchors.fill: parent
                            visible: false
                            asynchronous: true
                            cache: false
                            mipmap: true
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(512, 512)
                            source: userItem.localAvatar
                            onStatusChanged: {
                                if (status === Image.Error && !userItem.triedIcon && userItem.rawIcon !== "") {
                                    userItem.triedIcon = true
                                    source = (userItem.rawIcon.indexOf("://") >= 0)
                                             ? userItem.rawIcon
                                             : "file://" + userItem.rawIcon
                                }
                            }
                        }

                        Rectangle {
                            id: avMask
                            anchors.fill: parent
                            radius: width / 2
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: parent
                            source: avImg
                            maskSource: avMask
                            visible: avImg.status === Image.Ready
                        }

                        // Ring
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "transparent"
                            border.width: 2 * s
                            border.color: userItem.focusedUser ? root.gold : "#66ffffff"
                            Behavior on border.color { ColorAnimation { duration: 250 } }
                        }

                        layer.enabled: true
                        layer.effect: DropShadow { color: "#66000000"; radius: 14; verticalOffset: 4 }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: avatar.bottom
                        anchors.topMargin: 16 * s
                        text: (model.realName || model.name)
                        font.family: serifFont.name
                        font.pixelSize: 26 * s
                        font.letterSpacing: 1 * s
                        color: root.fg
                        layer.enabled: true
                        layer.effect: DropShadow { color: "#88000000"; radius: 8 }
                    }

                    MouseArea {
                        id: avMa
                        anchors.fill: parent
                        enabled: !userItem.hiddenUser
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectUser(index)
                    }
                }
            }
        }

        // Password field (appears after clicking a profile picture)
        Item {
            id: fieldWrap
            width: 340 * s
            height: 52 * s
            anchors.horizontalCenter: parent.horizontalCenter
            y: (root.passwordOpen ? 284 : 300) * s
            opacity: root.passwordOpen ? 1 : 0
            visible: opacity > 0
            enabled: root.passwordOpen

            Behavior on opacity { NumberAnimation { duration: 350 } }
            Behavior on y { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

            transform: Translate { id: shakeT; x: 0 }

            SequentialAnimation {
                id: errorShakeAnim
                NumberAnimation { target: shakeT; property: "x"; to: 12 * s;  duration: 50; easing.type: Easing.OutCubic }
                NumberAnimation { target: shakeT; property: "x"; to: -12 * s; duration: 90 }
                NumberAnimation { target: shakeT; property: "x"; to: 8 * s;   duration: 80 }
                NumberAnimation { target: shakeT; property: "x"; to: -5 * s;  duration: 70 }
                NumberAnimation { target: shakeT; property: "x"; to: 0;       duration: 60; easing.type: Easing.InCubic }
            }

            // Frosted pill
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: "#2effffff"
                border.width: 1
                border.color: root.loginError ? root.errorClr : "#55ffffff"
                Behavior on border.color { ColorAnimation { duration: 300 } }
            }

            TextInput {
                id: passInput
                anchors.fill: parent
                anchors.leftMargin: 26 * s
                anchors.rightMargin: 60 * s
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignLeft
                echoMode: TextInput.Password
                passwordCharacter: "●"
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData | Qt.ImhNoAutoUppercase
                font.family: serifFont.name
                font.pixelSize: 18 * s
                font.letterSpacing: 3 * s
                color: root.loggingIn ? "transparent" : root.fg
                readOnly: root.loggingIn
                clip: true
                selectionColor: root.gold

                Behavior on color { ColorAnimation { duration: 250 } }

                cursorDelegate: Rectangle {
                    width: 2 * s
                    color: root.gold
                    opacity: root.loggingIn ? 0 : 1
                }

                onTextChanged: if (root.loginError) root.loginError = false
                onAccepted: root.login()
                Keys.onEscapePressed: {
                    if (!root.loggingIn) root.passwordOpen = false
                }
            }

            // Placeholder
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 26 * s
                anchors.verticalCenter: parent.verticalCenter
                text: "Enter Password"
                font.family: serifFont.name
                font.pixelSize: 18 * s
                font.letterSpacing: 1 * s
                color: root.fg
                opacity: (passInput.text.length === 0 && !root.loggingIn) ? 0.5 : 0
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }

            // Authenticating status
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 26 * s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10 * s
                opacity: root.loggingIn ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 300 } }

                Text {
                    text: "Authenticating"
                    font.family: serifFont.name
                    font.pixelSize: 16 * s
                    font.letterSpacing: 1 * s
                    color: root.fg
                    anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                    spacing: 5 * s
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: 3
                        delegate: Rectangle {
                            width: 5 * s
                            height: 5 * s
                            radius: width / 2
                            color: root.gold
                            opacity: 0.2
                            SequentialAnimation on opacity {
                                running: root.loggingIn
                                loops: Animation.Infinite
                                PauseAnimation { duration: index * 180 }
                                NumberAnimation { from: 0.2; to: 1.0; duration: 350; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 1.0; to: 0.2; duration: 350; easing.type: Easing.InOutSine }
                                PauseAnimation { duration: (2 - index) * 180 }
                            }
                        }
                    }
                }
            }

            // Sweeping progress line
            Item {
                id: progressTrack
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 26 * s
                anchors.rightMargin: 26 * s
                anchors.bottomMargin: 5 * s
                height: 2 * s
                clip: true
                opacity: root.loggingIn ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 300 } }

                Rectangle {
                    id: sweep
                    width: parent.width * 0.35
                    height: parent.height
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: root.gold }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    SequentialAnimation on x {
                        running: root.loggingIn
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: -sweep.width
                            to: progressTrack.width
                            duration: 1100
                            easing.type: Easing.InOutSine
                        }
                    }
                }
            }

            // Submit button / spinner
            Item {
                id: loginBtn
                anchors.right: parent.right
                anchors.rightMargin: 8 * s
                anchors.verticalCenter: parent.verticalCenter
                width: 36 * s
                height: 36 * s
                opacity: (passInput.text.length > 0 || root.loggingIn) ? 1 : 0
                scale: (passInput.text.length > 0 || root.loggingIn) ? 1.0 : 0.8
                Behavior on opacity { NumberAnimation { duration: 300 } }
                Behavior on scale { NumberAnimation { duration: 350; easing.type: Easing.OutBack } }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: arrowMa.containsMouse ? "#55ffffff" : "#33ffffff"
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "→"
                    font.pixelSize: 18 * s
                    color: root.fg
                    opacity: root.loggingIn ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                Item {
                    id: spinner
                    anchors.fill: parent
                    opacity: root.loggingIn ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    RotationAnimator on rotation {
                        from: 0; to: 360
                        duration: 1000
                        loops: Animation.Infinite
                        running: root.loggingIn
                    }

                    Shape {
                        anchors.fill: parent
                        antialiasing: true
                        ShapePath {
                            strokeWidth: 2
                            strokeColor: root.gold
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: 18 * s; centerY: 18 * s
                                radiusX: 16 * s; radiusY: 16 * s
                                startAngle: 0
                                sweepAngle: 100
                            }
                        }
                    }
                }

                MouseArea {
                    id: arrowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.login()
                }
            }
        }

        // Error message
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 348 * s
            text: root.loginErrorMsg
            font.family: serifFont.name
            font.pixelSize: 16 * s
            font.letterSpacing: 1 * s
            color: root.errorClr
            opacity: (root.loginError && root.passwordOpen) ? 0.95 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            layer.enabled: true
            layer.effect: DropShadow { color: "#88000000"; radius: 6 }
        }
    }

    // ───────────── Bottom left: session button ─────────────
    Item {
        id: sessionWidget
        anchors.left: parent.left
        anchors.leftMargin: 60 * s
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60 * s
        width: sessionPill.width
        height: 44 * s
        z: 1000

        Rectangle {
            id: sessionPill
            height: 44 * s
            width: root.sessionMenuOpen ? Math.max(sessionLabel.implicitWidth + 44 * s + 22 * s, 120 * s) : 44 * s
            radius: height / 2
            color: (sessionMa.containsMouse || root.sessionMenuOpen) ? "#33ffffff" : "#1fffffff"
            border.width: 1
            border.color: (sessionMa.containsMouse || root.sessionMenuOpen) ? root.gold : "#33ffffff"
            clip: true

            Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }

            HoverHandler { id: sessionPillHover }

            // Tiny monitor icon
            Item {
                id: sessionIcon
                width: 44 * s
                height: 44 * s
                Rectangle {
                    width: 16 * s; height: 11 * s; radius: 2 * s
                    x: 14 * s; y: 12 * s
                    color: "transparent"
                    border.width: 1.5 * s
                    border.color: sessionMa.containsMouse || root.sessionMenuOpen ? root.gold : root.fg
                }
                Rectangle {
                    width: 8 * s; height: 1.5 * s; radius: 1 * s
                    x: 18 * s; y: 28 * s
                    color: sessionMa.containsMouse || root.sessionMenuOpen ? root.gold : root.fg
                }
            }

            Text {
                id: sessionLabel
                x: 40 * s
                anchors.verticalCenter: parent.verticalCenter
                text: (sessionHelper.currentItem && sessionHelper.currentItem.sName ? sessionHelper.currentItem.sName : "Wayland")
                font.family: serifFont.name
                font.pixelSize: 16 * s
                font.letterSpacing: 1 * s
                color: root.fg
                opacity: root.sessionMenuOpen ? 0.9 : 0
                Behavior on opacity { NumberAnimation { duration: 250 } }
            }

            MouseArea {
                id: sessionMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.sessionMenuOpen = !root.sessionMenuOpen
            }
        }

        // Session list (opens upwards while expanded)
        Rectangle {
            id: sessionMenu
            anchors.left: sessionPill.left
            anchors.bottom: sessionPill.top
            anchors.bottomMargin: 12 * s
            width: 220 * s
            height: root.sessionMenuOpen ? (40 * s * sessionModel.count) + 16 * s : 0
            radius: 16 * s
            color: "#66000000"
            border.width: 1
            border.color: "#33ffffff"
            clip: true
            opacity: root.sessionMenuOpen ? 1 : 0
            Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }
            Behavior on opacity { NumberAnimation { duration: 250 } }

            HoverHandler { id: sessionMenuHover }

            Column {
                anchors.fill: parent
                anchors.margins: 8 * s
                spacing: 8 * s

                Repeater {
                    model: sessionModel
                    delegate: Item {
                        width: parent.width
                        height: 32 * s

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12 * s
                            anchors.verticalCenter: parent.verticalCenter
                            text: model.name
                            font.family: serifFont.name
                            font.pixelSize: 15 * s
                            font.letterSpacing: 1 * s
                            color: root.sessionIndex === index ? root.gold : root.fg
                            opacity: (root.sessionIndex === index || mMa.containsMouse) ? 1.0 : 0.6
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }

                        MouseArea {
                            id: mMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.sessionIndex = index
                                root.sessionMenuOpen = false
                            }
                        }
                    }
                }
            }
        }
    }

    // ───────────── Bottom right: restart / shut down ─────────────
    Row {
        id: powerButtons
        anchors.right: parent.right
        anchors.rightMargin: 60 * s
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60 * s
        spacing: 14 * s
        z: 1000

        GlassButton {
            id: restartBtn
            u: root.s
            label: "Restart"
            fontFamily: serifFont.name
            onClicked: sddm.reboot()

            // circular arrow
            Shape {
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 1.6 * root.s
                    strokeColor: restartBtn.hovered ? root.gold : root.fg
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathAngleArc {
                        centerX: 22 * root.s; centerY: 22 * root.s
                        radiusX: 8 * root.s;  radiusY: 8 * root.s
                        startAngle: -40; sweepAngle: 270
                    }
                }
                ShapePath {
                    strokeWidth: 1.6 * root.s
                    strokeColor: restartBtn.hovered ? root.gold : root.fg
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    startX: 11.86 * root.s; startY: 15.87 * root.s
                    PathLine { x: 16.86 * root.s; y: 15.87 * root.s }
                    PathLine { x: 15.99 * root.s; y: 20.79 * root.s }
                }
            }
        }

        GlassButton {
            id: shutBtn
            u: root.s
            label: "Shut Down"
            fontFamily: serifFont.name
            onClicked: sddm.powerOff()

            // power symbol
            Shape {
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 1.6 * root.s
                    strokeColor: shutBtn.hovered ? root.gold : root.fg
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 22 * root.s; centerY: 23 * root.s
                        radiusX: 8 * root.s;  radiusY: 8 * root.s
                        startAngle: -50; sweepAngle: 280
                    }
                }
                ShapePath {
                    strokeWidth: 1.6 * root.s
                    strokeColor: shutBtn.hovered ? root.gold : root.fg
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: 22 * root.s; startY: 12 * root.s
                    PathLine { x: 22 * root.s; y: 21 * root.s }
                }
            }
        }
    }
}
