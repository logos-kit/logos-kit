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
    width: parent ? parent.width : 400
    spacing: 10

    function load() {
        problem = ""; note = ""; words = []
        store.call("grants", {}, function (v, e) { if (!e) st.grants = v || [] })
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
        model: st.store.state.zones || []
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
    InfoRow { label: "Faucet"; value: st.store.state.faucet || "None (off)" }
    InfoRow { label: "Proving"; value: "On this device" }

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
                        text: modelData.accounts.length + " account" + (modelData.accounts.length === 1 ? "" : "s") + " · " + modelData.caps.join(", ").replace(/_/g, " ")
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
