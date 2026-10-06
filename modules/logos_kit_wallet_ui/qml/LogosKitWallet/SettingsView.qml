import QtQuick
import "../LogosKitUi"
import QtQuick.Layouts
import "Fmt.js" as Fmt

// Settings (ux-spec §10): network, privacy, security, connected apps.
ColumnLayout {
    id: st
    property var store
    property var grants: []
    property var words: []
    property string problem: ""
    property string note: ""
    property string switchTo: ""
    property bool addingZone: false
    property bool changingPassword: false
    width: parent ? parent.width : 400

    // What each permission lets an app do, in the words the connect sheet uses.
    readonly property var capWords: ({
        accounts: "see the accounts you picked",
        read_public: "see public balances",
        read_private: "see private balances",
        propose_tx: "ask you to approve transactions",
        sign_message: "ask you to sign messages",
        request_proof: "ask for membership proofs"
    })
    function capText(caps) {
        return caps.map(function (c) { return st.capWords[c] || c.replace(/_/g, " ") }).join(", ")
    }
    spacing: 10

    property var programs: []
    function load() {
        problem = ""; note = ""; words = []
        store.call("grants", {}, function (v, e) { if (!e) st.grants = v || [] })
        store.call("programs", {}, function (v, e) { if (!e) st.programs = v || [] })
    }
    onVisibleChanged: if (visible) load()

    // Grants grouped by app: {requester: {accounts: {id: [caps]}}}
    readonly property var apps: {
        var byApp = {}, order = []
        for (var i = 0; i < grants.length; i++) {
            var g = grants[i]
            if (!byApp[g.requester]) { byApp[g.requester] = { requester: g.requester, accounts: [], caps: [] }; order.push(g.requester) }
            var a = byApp[g.requester]
            if (a.accounts.indexOf(g.account) < 0) a.accounts.push(g.account)
            if (a.caps.indexOf(g.capability) < 0) a.caps.push(g.capability)
        }
        return order.map(function (k) { return byApp[k] })
    }

    component Section: Txt { tone: "text2"; font.pixelSize: 12; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase; font.letterSpacing: 0.8; Layout.topMargin: 12 }

    Txt { text: "Settings"; font.pixelSize: 20; font.weight: Font.Bold }

    // -- network ----------------------------------------------------------------------
    Section { text: "Network" }
    Repeater {
        model: st.store.zones
        SettingsRow {
            readonly property bool on: modelData.id === st.store.zone.id
            glyph: "link"
            title: (modelData.chain === "lez:preview" ? "LEZ preview" : modelData.chain === "lez:testnet" ? "LEZ testnet" : modelData.chain === "lez:local" ? "Local network" : modelData.chain) + (on ? " · in use" : "")
            description: modelData.sequencer
            chevron: false
            Btn {
                text: parent.on ? "Test" : "Switch"
                onClicked: parent.on
                    ? st.store.call("testZone", {}, function (v, e) {
                        st.note = e ? "" : "Connected. Latest block " + Fmt.amount(String(v.tip), 0) + "."
                        st.problem = e ? Fmt.errorText(e) : ""
                    })
                    : st.switchTo = modelData.id
            }
        }
    }
    RowLayout {
        visible: st.switchTo !== ""
        Layout.fillWidth: true
        spacing: 6
        Field { id: zpw; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "Password to switch networks" }
        Btn {
            tone: "ink"; text: "Switch"
            enabled: zpw.text.length > 0
            onClicked: st.store.call("switchZone", { zone: st.switchTo, password: zpw.text }, function (v, e) {
                zpw.text = ""
                if (e) { st.problem = Fmt.errorText(e); return }
                st.switchTo = ""
                st.store.selected = ""
                st.store.refreshAll()
            }, 60000)
        }
    }

    Btn {
        objectName: "addZoneOpen"
        visible: !st.addingZone
        Layout.fillWidth: true
        icon: "plus"
        text: "Add a network"
        onClicked: st.addingZone = true
    }
    ColumnLayout {
        visible: st.addingZone
        Layout.fillWidth: true
        spacing: 6
        Field { id: zoneName; objectName: "addZoneName"; Layout.fillWidth: true; placeholderText: "Name, e.g. My devnet" }
        Field { id: zoneUrl; objectName: "addZoneUrl"; Layout.fillWidth: true; mono: true; placeholderText: "Sequencer URL (https://…)" }
        Txt { Layout.fillWidth: true; text: "Logos Kit makes a separate set of accounts for each network. Your recovery phrase covers all of them."; tone: "text3"; font.pixelSize: 12; wrapMode: Text.Wrap }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Btn { Layout.fillWidth: true; text: "Cancel"; onClicked: { st.addingZone = false; zoneName.text = ""; zoneUrl.text = "" } }
            Btn {
                objectName: "addZoneSave"
                Layout.fillWidth: true
                tone: "ink"
                text: "Add"
                readonly property string slug: zoneName.text.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
                enabled: slug.length > 0 && /^https?:\/\/\S+$/.test(zoneUrl.text.trim())
                onClicked: st.store.call("addZone", { id: "lez-" + slug, chain: "lez:" + slug, sequencer: zoneUrl.text.trim() }, function (v, e) {
                    if (e) { st.problem = Fmt.errorText(e); return }
                    st.problem = ""
                    st.note = "Added " + zoneName.text.trim() + ". Switch to it above."
                    st.addingZone = false; zoneName.text = ""; zoneUrl.text = ""
                    st.store.refreshState()
                })
            }
        }
    }

    // -- appearance ---------------------------------------------------------------------
    Section { text: "Appearance" }
    SettingsRow {
        glyph: Theme.dark ? "moon" : "sun"
        title: "Theme"
        chevron: false
        SegmentedControl {
            options: ["Dark", "Light"]
            currentIndex: Theme.dark ? 0 : 1
            onActivated: function (i) {
                Theme.dark = i === 0
                st.store.call("setPrefs", { theme: Theme.dark ? "dark" : "light" }, null)
            }
        }
    }
    SettingsRow {
        glyph: "zap"
        title: "Motion"
        description: (st.store.state.motion || "system") === "system"
            ? "Following your computer" + (st.store.state.systemReducedMotion ? " (reduced)" : "")
            : st.store.state.motion === "reduce" ? "Animations are off; changes appear at once" : "All animations on"
        chevron: false
        SegmentedControl {
            readonly property var values: ["system", "reduce", "full"]
            options: ["System", "Reduce", "Full"]
            currentIndex: Math.max(0, values.indexOf(st.store.state.motion || "system"))
            onActivated: function (i) {
                st.store.call("setPrefs", { motion: values[i] }, function () { st.store.refreshState() })
            }
        }
    }

    // -- privacy --------------------------------------------------------------------------
    Section { text: "Privacy" }
    Notice { tone: "private"; text: "Logos Kit makes no analytics or third-party calls. It talks only to the endpoints below." }
    InfoRow { label: "Sequencer"; value: st.store.zone.sequencer || ""; mono: true }
    InfoRow { label: "Faucet"; value: st.store.state.faucetHost || "None (off)"; mono: !!st.store.state.faucetHost }
    InfoRow { visible: !!st.store.state.explorer; label: "Explorer"; value: "Only when you open a link" }
    InfoRow { label: "Proving"; value: "On this device" }
    SettingsRow {
        objectName: "lowMemoryRow"
        glyph: "zap"
        title: "Low-memory proving"
        description: "Private transactions use about 2 GB of memory instead of 4.6 GB, and take longer."
        chevron: false
        Toggle {
            objectName: "lowMemoryToggle"
            checked: !!st.store.state.lowMemory
            onToggled: function (on) { st.store.call("setPrefs", { lowMemory: on }, function () { st.store.refreshState() }) }
        }
    }

    // -- security ----------------------------------------------------------------------------
    Section { text: "Security" }
    SettingsRow {
        glyph: "clock"
        title: "Auto-lock"
        description: "Lock the wallet after this long without use"
        chevron: false
        SegmentedControl {
            readonly property var secs: [300, 900, 3600]
            options: ["5 min", "15 min", "1 h"]
            currentIndex: Math.max(0, secs.indexOf(st.store.state.status ? st.store.state.status.autoLockSecs : 900))
            onActivated: function (i) { st.store.call("setAutoLock", { secs: secs[i] }, function () { st.store.refreshState() }) }
        }
    }
    SettingsRow {
        glyph: "key"
        title: "Recovery phrase"
        description: "Shown after your password, never copied anywhere"
        chevron: false
    }
    RowLayout {
        visible: st.words.length === 0
        Layout.fillWidth: true
        spacing: 6
        Field { id: rpw; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "Password to show the recovery phrase" }
        Btn {
            text: "Show"
            icon: "eye"
            enabled: rpw.text.length > 0
            onClicked: st.store.call("revealPhrase", { password: rpw.text }, function (v, e) {
                rpw.text = ""
                if (e) { st.problem = Fmt.errorText(e); return }
                st.words = v.words
            })
        }
    }
    Card {
        visible: st.words.length > 0
        Layout.fillWidth: true
        pad: 14
        PhraseGrid { width: parent.width; words: st.words; revealed: true; columns: st.width < 400 ? 2 : 3 }
    }
    Btn { visible: st.words.length > 0; Layout.fillWidth: true; text: "Hide phrase"; onClicked: st.words = [] }

    SettingsRow {
        objectName: "changePasswordRow"
        glyph: "lock"
        title: "Password"
        description: "Unlocks this wallet on this device"
        chevron: false
        Btn { text: st.changingPassword ? "Cancel" : "Change"; onClicked: { st.changingPassword = !st.changingPassword; curPw.text = ""; newPw.text = ""; newPw2.text = "" } }
    }
    ColumnLayout {
        visible: st.changingPassword
        Layout.fillWidth: true
        spacing: 6
        Field { id: curPw; objectName: "pwCurrent"; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "Current password" }
        Field { id: newPw; objectName: "pwNew"; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "New password" }
        PasswordStrength { Layout.fillWidth: true; password: newPw.text }
        Field { id: newPw2; objectName: "pwNew2"; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "New password again"; invalid: newPw2.text !== "" && newPw2.text !== newPw.text }
        Btn {
            objectName: "pwSave"
            Layout.fillWidth: true
            tone: "ink"
            text: "Change password"
            enabled: curPw.text.length > 0 && newPw.text.length >= 10 && newPw.text === newPw2.text
            onClicked: st.store.call("changePassword", { current: curPw.text, new: newPw.text }, function (v, e) {
                curPw.text = ""; newPw.text = ""; newPw2.text = ""
                if (e) { st.problem = Fmt.errorText(e); return }
                st.problem = ""
                st.changingPassword = false
                st.note = "Password changed. Your recovery phrase didn't change."
            }, 60000)
        }
    }

    // -- programs you named ----------------------------------------------------------------
    Section { text: "Programs you named" }
    Txt {
        Layout.fillWidth: true
        text: "Your own names for programs apps ask you to use. Approvals show the name with “named by you”; it doesn't verify the program."
        tone: "text3"; font.pixelSize: 12; wrapMode: Text.Wrap
    }
    Repeater {
        model: st.programs
        SettingsRow {
            glyph: "pencil"
            title: modelData.name
            description: Fmt.short(modelData.account)
            chevron: false
            Btn {
                text: "Forget"
                onClicked: st.store.call("forgetProgram", { account: modelData.account }, function (v, e) {
                    if (e) { st.problem = Fmt.errorText(e); return }
                    st.load()
                })
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Field { id: progId; objectName: "programAccount"; Layout.fillWidth: true; mono: true; placeholderText: "Program address" }
        Field { id: progName; objectName: "programName"; Layout.preferredWidth: 140; placeholderText: "Your name for it" }
        Btn {
            objectName: "programAdd"
            text: "Add"
            enabled: /^[1-9A-HJ-NP-Za-km-z]{32,44}$/.test(progId.text.trim()) && progName.text.trim().length > 0
            onClicked: st.store.call("nameProgram", { account: progId.text.trim(), name: progName.text.trim() }, function (v, e) {
                if (e) { st.problem = Fmt.errorText(e); return }
                progId.text = ""; progName.text = ""
                st.load()
            })
        }
    }

    // -- backup -----------------------------------------------------------------------------
    Section { text: "Backup" }
    SettingsRow {
        objectName: "backupRow"
        glyph: "download"
        title: "Encrypted backup"
        description: "Saves your accounts, labels, connected apps and history to a file. It opens only with your password."
        chevron: false
        Btn {
            objectName: "backupSave"
            text: "Save"
            onClicked: st.store.call("exportBackup", {}, function (v, e) {
                if (e) { st.problem = Fmt.errorText(e); return }
                st.problem = ""
                st.note = "Saved to " + v.path + ". Keep your recovery phrase too: a backup needs the password it was made with."
            }, 60000)
        }
    }

    // -- connected apps -------------------------------------------------------------------------
    Section { text: "Connected apps" }
    EmptyState {
        visible: st.apps.length === 0
        Layout.fillWidth: true
        glyph: "link"
        title: "No apps connected"
        body: "Apps you connect in Basecamp show up here, with what they can see."
    }
    Repeater {
        model: st.apps
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: appRow.implicitHeight + 24
            radius: Theme.rRow
            color: Theme.surface2
            RowLayout {
                id: appRow
                anchors.left: parent.left; anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 12
                spacing: 12
                AppAvatar { store: st.store; requester: modelData.requester; size: 40 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Txt { text: st.store.appName(modelData.requester); font.pixelSize: 14; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    Txt { text: modelData.requester; mono: true; tone: "text3"; font.pixelSize: 11; Layout.fillWidth: true }
                    Txt {
                        Layout.fillWidth: true
                        text: "Can " + st.capText(modelData.caps) + " · " + modelData.accounts.length + " account" + (modelData.accounts.length === 1 ? "" : "s")
                        tone: "text2"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone
                    }
                }
                Btn {
                    tone: "danger"; text: "Revoke"
                    onClicked: st.store.call("revoke", { requester: modelData.requester }, function () { st.load() })
                }
            }
            Component.onCompleted: st.store.loadApp(modelData.requester)
        }
    }

    Section { text: "Wallet" }
    Btn { objectName: "lockNow"; Layout.fillWidth: true; large: true; icon: "lock"; text: "Lock now"; onClicked: st.store.call("lock", {}, function () { st.store.refreshAll() }) }

    Notice { visible: st.note !== ""; Layout.fillWidth: true; text: st.note; tone: "info" }
    Notice { visible: st.problem !== ""; Layout.fillWidth: true; text: st.problem; tone: "danger" }
}
