import QtQuick
import QtQuick.Layouts
import "LogosKit"

// Dev-only dApp: the prize's core flow through the QML SDK (connect → send →
// status), plus sign and test funds. Every result is shown as plain text.
Item {
    id: root
    width: 480
    height: 640

    property var session: null
    property string account: session && session.accounts.length ? session.accounts[0].address : ""
    property string log: "not connected"
    property string status: ""

    LogosKit { id: kit; chain: "lez:local"; visible: root.visible }

    function say(t) { root.log = t; console.log("[probe] " + t) }
    function fail(what) { return function (e) { root.say(what + " failed: " + (e && e.code) + " " + (e && e.message)) } }

    Rectangle { anchors.fill: parent; color: "#101014" }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10

        Text { text: "Probe dApp"; color: "white"; font.pixelSize: 22; font.bold: true }
        Text { objectName: "probeAccount"; text: root.account || "—"; color: "#9a9aa5"; textFormat: Text.PlainText; font.family: "Menlo" }

        component Action: Rectangle {
            property string label
            signal go()
            Layout.fillWidth: true
            implicitHeight: 40
            radius: 20
            color: m.pressed ? "#3a3a44" : "#26262c"
            Text { anchors.centerIn: parent; text: parent.label; color: "white"; font.pixelSize: 14 }
            MouseArea { id: m; anchors.fill: parent; onClicked: parent.go() }
        }

        Action {
            objectName: "probeConnect"; label: "Connect"
            onGo: kit.api.connect({ accountKinds: ["public"] }).then(function (s) {
                root.session = s
                root.say("connected: " + s.accounts.length + " account(s), session " + s.sessionId)
            }, fail("connect"))
        }
        Action {
            objectName: "probeSend"; label: "Send 7 LEZ"
            onGo: kit.api.transfer(root.account, "US517G5965aydkZ46HS38QLi7UQiSojurfbQfKCELFx", "7").then(function (r) {
                root.say("approved, handle " + r.handle)
                kit.api.watchTransaction(r.handle, function (s) {
                    root.status = s.lifecycle + " / " + s.outcome + (s.txHash ? " " + s.txHash.substring(0, 12) + "…" : "")
                }, fail("watch"))
            }, fail("send"))
        }
        Action {
            objectName: "probeSign"; label: "Sign a message"
            onGo: kit.api.signMessage(root.account, Qt.btoa("hello from probe_dapp")).then(function (r) {
                root.say("signature " + r.signature.substring(0, 16) + "…")
            }, fail("sign"))
        }
        Action {
            objectName: "probeFunds"; label: "Get test funds"
            onGo: kit.api.requestFunds(root.account).then(function (r) {
                root.say("faucet: " + r.status + (r.amount ? " +" + r.amount : ""))
            }, fail("funds"))
        }
        Action {
            objectName: "probeBalance"; label: "Read balance"
            onGo: kit.api.getWalletBalance(root.account).then(function (b) {
                root.say("balance " + b.amount + " (block " + b.asOfBlock + ")")
            }, fail("balance"))
        }

        Text { objectName: "probeLog"; Layout.fillWidth: true; text: root.log; color: "white"; wrapMode: Text.Wrap; textFormat: Text.PlainText }
        Text { objectName: "probeStatus"; Layout.fillWidth: true; text: root.status; color: "#4bd166"; wrapMode: Text.Wrap; textFormat: Text.PlainText }
        Item { Layout.fillHeight: true }
    }
}
