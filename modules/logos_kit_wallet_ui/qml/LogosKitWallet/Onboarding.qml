import QtQuick
import "../LogosKitUi"
import QtQuick.Layouts
import QtQuick.Controls.Basic as C
import "Fmt.js" as Fmt

// First run (create / restore) and unlock (ux-spec.md §1). Stays up after
// the wallet opens until the phrase is confirmed and the accounts are shown.
Item {
    id: ob
    property var store
    // welcome | password | phrase | confirm | ready | restore | unlock
    property string step: store.initialized ? "unlock" : "welcome"
    readonly property bool inFlow: ["phrase", "confirm", "ready"].indexOf(step) >= 0
    property var words: []
    property var accounts: []
    property bool revealed: false
    property bool working: false
    property string problem: ""
    readonly property var checks: [3, 11, 19]
    signal done()

    function go(s) { problem = ""; step = s }

    Connections {
        target: ob.store
        function onLoadedChanged() { if (!ob.inFlow) ob.step = ob.store.initialized ? "unlock" : "welcome" }
        function onInitializedChanged() { if (!ob.inFlow && ob.store.initialized && ob.step === "welcome") ob.step = "unlock" }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: Math.max(height, col.implicitHeight + 64)
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: Math.min(ob.width - 32, 440)
            x: (ob.width - width) / 2
            y: Math.max(32, (parent.height - implicitHeight) / 2)
            spacing: 14

            // -- header ----------------------------------------------------------
            Stepper {
                visible: ob.step === "password" || ob.step === "phrase" || ob.step === "confirm"
                Layout.fillWidth: true
                Layout.bottomMargin: 8
                steps: ["Password", "Back up", "Confirm"]
                current: ob.step === "password" ? 0 : ob.step === "phrase" ? 1 : 2
            }
            Rectangle {
                visible: ob.step !== "ready"
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 64; implicitHeight: 64; radius: 20; color: "#000000"
                border.width: 1; border.color: "#1affffff"
                LogosMark { anchors.centerIn: parent; size: 46 }
            }
            SuccessCheck { visible: ob.step === "ready"; Layout.alignment: Qt.AlignHCenter; size: 72 }
            Txt {
                Layout.alignment: Qt.AlignHCenter
                text: ob.step === "unlock" ? "Welcome back"
                    : ob.step === "password" ? "Set a password"
                    : ob.step === "phrase" ? "Your recovery phrase"
                    : ob.step === "confirm" ? "Check your phrase"
                    : ob.step === "ready" ? "Your accounts are ready"
                    : ob.step === "restore" ? "Restore a wallet"
                    : "Logos Kit"
                font.pixelSize: 26
                font.weight: Font.Bold
            }
            Txt {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: col.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                tone: "text2"
                font.pixelSize: 14
                text: ob.step === "unlock" ? "Enter your password to open the wallet."
                    : ob.step === "password" ? "It unlocks the wallet on this device only."
                    : ob.step === "phrase" ? "Anyone with these words controls your funds. Write them down and keep them offline."
                    : ob.step === "confirm" ? "Type the words it asks for."
                    : ob.step === "ready" ? "One public and one private account, on " + (ob.store.zone.chain || "LEZ") + "."
                    : ob.step === "restore" ? "Enter the 24 words of a Logos Kit or LEZ wallet."
                    : "A wallet for the Logos Execution Zone. Private by default."
            }
            Badge {
                Layout.alignment: Qt.AlignHCenter
                visible: ob.step === "welcome" || ob.step === "unlock"
                text: ob.store.zone.chain === "lez:local" ? "Local network" : ob.store.zone.chain === "lez:preview" ? "Preview network · LEZ 0.3" : "Testnet"
                tone: "ok"
                live: true
            }

            // -- welcome ---------------------------------------------------------
            ColumnLayout {
                visible: ob.step === "welcome"
                Layout.fillWidth: true
                spacing: 10
                Item { implicitHeight: 8 }
                Btn { objectName: "createWallet"; Layout.fillWidth: true; large: true; tone: "ink"; text: "Create wallet"; onClicked: ob.go("password") }
                Btn { objectName: "restoreWallet"; Layout.fillWidth: true; large: true; text: "Restore from recovery phrase"; onClicked: ob.go("restore") }
                // Zones are data. The testnet is the default; the others are for
                // development, so they wait behind "Advanced".
                property bool advanced: false
                Txt {
                    objectName: "welcomeAdvanced"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    visible: (ob.store.state.zones || []).length > 1 && !parent.advanced && ob.store.zone.chain === "lez:testnet"
                    text: "Advanced: choose a network"
                    tone: "text3"
                    font.pixelSize: 12
                    font.underline: advMouse.containsMouse
                    MouseArea { id: advMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.parent.advanced = true }
                }
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    spacing: 6
                    visible: (ob.store.state.zones || []).length > 1 && (parent.advanced || ob.store.zone.chain !== "lez:testnet")
                    Txt { Layout.alignment: Qt.AlignHCenter; text: "Network"; tone: "text3"; font.pixelSize: 12 }
                    SegmentedControl {
                        Layout.alignment: Qt.AlignHCenter
                        readonly property var zones: ob.store.state.zones || []
                        options: zones.map(function (z) { return z.chain === "lez:preview" ? "Preview" : z.chain === "lez:testnet" ? "Testnet" : z.chain === "lez:local" ? "Local" : z.chain })
                        currentIndex: {
                            for (var i = 0; i < zones.length; i++) if (zones[i].id === ob.store.zone.id) return i
                            return 0
                        }
                        onActivated: function (i) { ob.store.call("setPrefs", { zone: zones[i].id }, function () { ob.store.refreshState() }) }
                    }
                }
            }

            // -- password (create) -------------------------------------------------
            ColumnLayout {
                visible: ob.step === "password"
                Layout.fillWidth: true
                spacing: 10
                Field { id: pw1; objectName: "password"; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "Password (8+ characters)" }
                PasswordStrength { Layout.fillWidth: true; password: pw1.text; minLength: 8 }
                Field { id: pw2; objectName: "password2"; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "Confirm password"; invalid: text.length > 0 && text !== pw1.text; onAccepted: createBtn.clicked() }
                Btn {
                    id: createBtn
                    objectName: "continueCreate"
                    Layout.fillWidth: true; large: true; tone: "ink"; text: "Continue"
                    busy: ob.working
                    enabled: Fmt.password_ok(pw1.text) && pw1.text === pw2.text
                    onClicked: {
                        ob.working = true
                        ob.problem = ""
                        ob.store.call("create", { password: pw1.text }, function (v, e) {
                            ob.working = false
                            if (e) { ob.problem = Fmt.errorText(e); return }
                            ob.words = v.words
                            ob.accounts = v.accounts
                            pw1.text = ""; pw2.text = ""
                            ob.revealed = false
                            ob.go("phrase")
                            ob.store.refreshAll()
                        }, 60000)
                    }
                }
                Btn { Layout.fillWidth: true; tone: "ghost"; text: "Back"; onClicked: ob.go("welcome") }
            }

            // -- phrase --------------------------------------------------------------
            ColumnLayout {
                visible: ob.step === "phrase"
                Layout.fillWidth: true
                spacing: 12
                Card {
                    Layout.fillWidth: true
                    pad: 14
                    PhraseGrid {
                        width: parent.width
                        words: ob.words
                        revealed: ob.revealed
                        columns: col.width < 380 ? 2 : 3
                        onRevealRequested: ob.revealed = true
                    }
                }
                Btn { visible: !ob.revealed; objectName: "revealPhrase"; Layout.fillWidth: true; icon: "eye"; text: "Reveal"; onClicked: ob.revealed = true }
                Notice { tone: "warn"; text: "Write them on paper, in order. Never type them into a website or share them: Logos Kit will never ask for them." }
                Btn { objectName: "savedPhrase"; Layout.fillWidth: true; large: true; tone: "ink"; text: "I've saved it"; enabled: ob.revealed; onClicked: ob.go("confirm") }
            }

            // -- confirm -------------------------------------------------------------
            ColumnLayout {
                id: confirmCol
                visible: ob.step === "confirm"
                Layout.fillWidth: true
                spacing: 10
                Repeater {
                    id: checkRep
                    model: ob.checks
                    Field {
                        Layout.fillWidth: true
                        objectName: "confirmWord" + modelData
                        placeholderText: "Word #" + modelData + " of your phrase"
                        inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                    }
                }
                Btn {
                    objectName: "confirmPhrase"
                    Layout.fillWidth: true; large: true; tone: "ink"; text: "Confirm"
                    onClicked: {
                        for (var i = 0; i < ob.checks.length; i++) {
                            var want = ob.words[ob.checks[i] - 1]
                            var got = checkRep.itemAt(i).text.trim().toLowerCase()
                            if (got !== want) {
                                ob.problem = "That's not word " + ob.checks[i] + "."
                                shake.start()
                                return
                            }
                        }
                        ob.words = []
                        ob.go("ready")
                    }
                }
                Btn { Layout.fillWidth: true; tone: "ghost"; text: "Show the phrase again"; onClicked: ob.go("phrase") }
                SequentialAnimation {
                    id: shake
                    alwaysRunToEnd: true
                    NumberAnimation { target: confirmCol; property: "x"; to: -8; duration: Theme.reducedMotion ? 0 : 50 }
                    NumberAnimation { target: confirmCol; property: "x"; to: 8; duration: 50 }
                    NumberAnimation { target: confirmCol; property: "x"; to: 0; duration: 50 }
                }
            }

            // -- ready -----------------------------------------------------------------
            ColumnLayout {
                visible: ob.step === "ready"
                Layout.fillWidth: true
                spacing: 10
                Repeater {
                    model: ob.accounts
                    Card {
                        Layout.fillWidth: true
                        pad: 14
                        RowLayout {
                            width: parent.width
                            spacing: 12
                            Item {
                                implicitWidth: 40; implicitHeight: 40
                                Identicon { seed: modelData.accountId; size: 40 }
                                Rectangle {
                                    visible: modelData.kind === "private"
                                    width: 16; height: 16; radius: 8; x: 27; y: 27
                                    color: Theme.priv; border.width: 2; border.color: Theme.surface
                                    Glyph { anchors.centerIn: parent; name: "lock"; color: "#ffffff"; width: 9; height: 9; stroke: 2.6 }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                RowLayout {
                                    spacing: 8
                                    Txt { text: Fmt.accountName(modelData); font.pixelSize: 15; font.weight: Font.DemiBold }
                                    Badge { text: modelData.kind === "private" ? "Private" : "Public"; tone: modelData.kind === "private" ? "private" : "neutral"; dot: false }
                                }
                                Txt {
                                    Layout.fillWidth: true
                                    tone: "text2"
                                    font.pixelSize: 12
                                    wrapMode: Text.Wrap
                                    elide: Text.ElideNone
                                    text: modelData.kind === "private" ? "Balance and history are only visible to you." : "Visible on-chain. Pays fees and posts publicly."
                                }
                            }
                        }
                    }
                }
                Btn {
                    objectName: "readyFunds"
                    Layout.fillWidth: true; large: true; tone: "ink"; icon: "droplet"; text: "Get test LGO"
                    visible: !!ob.store.state.faucet
                    onClicked: {
                        var pub = null
                        for (var i = 0; i < ob.accounts.length && !pub; i++) if (ob.accounts[i].kind === "public") pub = ob.accounts[i]
                        if (pub) { ob.store.selected = pub.accountId; ob.store.requestFunds(pub.accountId) }
                        ob.go("welcome")
                        ob.done()
                    }
                }
                Btn { objectName: "goWallet"; Layout.fillWidth: true; large: true; text: "Go to wallet"; onClicked: { ob.go("welcome"); ob.done() } }
            }

            // -- restore ---------------------------------------------------------------
            ColumnLayout {
                visible: ob.step === "restore"
                Layout.fillWidth: true
                spacing: 10
                C.TextArea {
                    id: phraseIn
                    objectName: "restorePhrase"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    wrapMode: TextEdit.Wrap
                    placeholderText: "word1 word2 word3 …"
                    placeholderTextColor: Theme.text3
                    color: Theme.text
                    font.family: Theme.mono
                    font.pixelSize: 14
                    padding: 14
                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                    background: Rectangle { radius: Theme.rRow; color: Theme.surface2 }
                }
                Txt {
                    readonly property int n: phraseIn.text.trim() === "" ? 0 : phraseIn.text.trim().split(/\s+/).length
                    text: n + " of 24 words"
                    tone: n === 24 || n === 12 ? "ok" : "text3"
                    font.pixelSize: 12
                }
                Field { id: birthday; Layout.fillWidth: true; placeholderText: "First used (optional, YYYY-MM-DD): speeds up the scan" ; inputMask: "" }
                Field { id: rp1; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "New password (8+ characters)" }
                Field { id: rp2; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "Confirm password"; invalid: text.length > 0 && text !== rp1.text }
                Btn {
                    objectName: "restoreGo"
                    Layout.fillWidth: true; large: true; tone: "ink"; text: "Restore"
                    busy: ob.working
                    enabled: Fmt.password_ok(rp1.text) && rp1.text === rp2.text && phraseIn.text.trim().split(/\s+/).length >= 12
                    onClicked: {
                        var ms = null
                        var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(birthday.text.trim())
                        if (m) ms = Date.UTC(+m[1], +m[2] - 1, +m[3])
                        else if (birthday.text.trim() !== "") { ob.problem = "Use the date format YYYY-MM-DD, or leave it empty."; return }
                        ob.working = true
                        ob.problem = ""
                        ob.store.call("restore", { password: rp1.text, phrase: phraseIn.text, birthdayMs: ms }, function (v, e) {
                            ob.working = false
                            if (e) { ob.problem = Fmt.errorText(e); return }
                            phraseIn.text = ""; rp1.text = ""; rp2.text = ""
                            ob.store.refreshAll()
                            ob.done()
                        }, 60000)
                    }
                }
                Notice { text: "Restoring scans the chain for your accounts. Funds found so far are usable while it runs." }
                Btn { Layout.fillWidth: true; tone: "ghost"; text: "Back"; onClicked: ob.go("welcome") }
            }

            // -- unlock ----------------------------------------------------------------
            ColumnLayout {
                visible: ob.step === "unlock"
                Layout.fillWidth: true
                spacing: 10
                Field {
                    id: upw
                    objectName: "unlockPassword"
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    placeholderText: "Password"
                    focus: ob.step === "unlock"
                    onAccepted: unlockBtn.clicked()
                }
                Btn {
                    id: unlockBtn
                    objectName: "unlock"
                    Layout.fillWidth: true; large: true; tone: "ink"; text: "Unlock"
                    busy: ob.working
                    enabled: upw.text.length > 0 && !(ob.store.state.unlockWaitSecs > 0)
                    onClicked: {
                        ob.working = true
                        ob.problem = ""
                        ob.store.call("unlock", { password: upw.text }, function (v, e) {
                            ob.working = false
                            if (e) { ob.problem = Fmt.errorText(e); ob.store.refreshState(); return }
                            upw.text = ""
                            ob.store.refreshAll()
                            ob.done()
                        }, 60000)
                    }
                }
                Txt {
                    visible: ob.store.state.unlockWaitSecs > 0
                    Layout.alignment: Qt.AlignHCenter
                    tone: "warn"
                    font.pixelSize: 12
                    text: "Too many tries. Wait " + ob.store.state.unlockWaitSecs + " s."
                }
                Txt {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: col.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    tone: "text3"
                    font.pixelSize: 12
                    text: "Forgot your password? Your recovery phrase restores this wallet on a fresh install."
                }
            }

            Notice {
                visible: ob.problem !== ""
                objectName: "onboardingProblem"
                Layout.fillWidth: true
                tone: "danger"
                text: ob.problem
            }
        }
    }
}
