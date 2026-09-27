import QtQuick
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

    component Section: Txt { tone: "text3"; font.pixelSize: 12; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase; font.letterSpacing: 0.8; Layout.topMargin: 8 }

    Txt { text: "Settings"; font.pixelSize: 20; font.weight: Font.DemiBold }

    // -- network ----------------------------------------------------------------------
    Section { text: "Network" }
    Repeater {
        model: st.store.state.zones || []
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 56
            radius: Theme.rRow
            readonly property bool on: modelData.id === st.store.zone.id
            color: on ? Theme.surface2 : "transparent"
            border.width: 1
            border.color: on ? Theme.text3 : Theme.line
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Txt { text: modelData.chain + (parent.parent.parent.on ? " · in use" : ""); font.weight: Font.DemiBold }
                    Txt { Layout.fillWidth: true; text: modelData.sequencer; mono: true; font.pixelSize: 11; tone: "text2" }
                }
                Btn {
                    visible: !parent.parent.on
                    text: "Switch"
                    onClicked: st.switchTo = modelData.id
                }
                Btn {
                    visible: parent.parent.on
                    text: "Test"
                    onClicked: st.store.call("testZone", {}, function (v, e) {
                        st.note = e ? Fmt.errorText(e) : "Connected. Latest block " + Fmt.amount(String(v.tip), 0) + "."
                    })
                }
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

    // -- privacy --------------------------------------------------------------------------
    Section { text: "Privacy" }
    Notice { tone: "private"; text: "Logos Kit makes no analytics or third-party calls. It talks only to the endpoints below." }
    InfoRow { label: "Sequencer"; value: st.store.zone.sequencer || ""; mono: true }
    InfoRow { label: "Faucet"; value: st.store.state.faucet || "None (off)" }
    InfoRow { label: "Proving"; value: "On this device" }

    // -- security ----------------------------------------------------------------------------
    Section { text: "Security" }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Txt { text: "Auto-lock"; tone: "text2"; font.pixelSize: 13; Layout.fillWidth: true }
        Repeater {
            model: [[300, "5 min"], [900, "15 min"], [3600, "1 h"]]
            Rectangle {
                implicitHeight: 30
                implicitWidth: al.implicitWidth + 20
                radius: 15
                readonly property bool on: !!st.store.state.status && st.store.state.status.autoLockSecs === modelData[0]
                color: on ? Theme.text : Theme.surface2
                Txt { id: al; anchors.centerIn: parent; text: modelData[1]; font.pixelSize: 12; font.weight: Font.DemiBold; color: parent.on ? Theme.bg : Theme.text }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: st.store.call("setAutoLock", { secs: modelData[0] }, function () { st.store.refreshState() }) }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Field { id: rpw; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "Password to show the recovery phrase" }
        Btn {
            text: "Reveal"
            enabled: rpw.text.length > 0
            onClicked: st.store.call("revealPhrase", { password: rpw.text }, function (v, e) {
                rpw.text = ""
                if (e) { st.problem = Fmt.errorText(e); return }
                st.words = v.words
            })
        }
    }
    Rectangle {
        visible: st.words.length > 0
        Layout.fillWidth: true
        implicitHeight: phr.implicitHeight + 24
        radius: Theme.rRow
        color: Theme.surface2
        Txt { id: phr; x: 12; y: 12; width: parent.width - 24; text: st.words.join(" "); mono: true; font.pixelSize: 13; wrapMode: Text.Wrap }
    }
    Btn { visible: st.words.length > 0; Layout.fillWidth: true; text: "Hide phrase"; onClicked: st.words = [] }

    // -- connected apps -------------------------------------------------------------------------
    Section { text: "Connected apps" }
    Txt { visible: st.apps.length === 0; text: "No apps are connected."; tone: "text2"; font.pixelSize: 13 }
    Repeater {
        model: st.apps
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 64
            radius: Theme.rRow
            color: Theme.surface2
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Txt { text: modelData.requester; mono: true; font.weight: Font.DemiBold }
                    Txt { Layout.fillWidth: true; text: modelData.accounts.length + " account" + (modelData.accounts.length === 1 ? "" : "s") + " · " + modelData.caps.join(", ").replace(/_/g, " "); tone: "text2"; font.pixelSize: 12 }
                }
                Btn {
                    tone: "danger"; text: "Revoke"
                    onClicked: st.store.call("revoke", { requester: modelData.requester }, function () { st.load() })
                }
            }
        }
    }

    Section { text: "Wallet" }
    Btn { objectName: "lockNow"; Layout.fillWidth: true; icon: "lock"; text: "Lock now"; onClicked: st.store.call("lock", {}, function () { st.store.refreshAll() }) }

    Txt { visible: st.note !== ""; Layout.fillWidth: true; text: st.note; tone: "ok"; wrapMode: Text.Wrap; font.pixelSize: 13 }
    Txt { visible: st.problem !== ""; Layout.fillWidth: true; text: st.problem; tone: "danger"; wrapMode: Text.Wrap; font.pixelSize: 13 }
}
