import QtQuick
import QtQuick.Layouts
import Logos.Theme
import Logos.Controls

// S0 skeleton of the Logos Kit wallet UI.
// - Paints its own background (the host widget behind a view is white).
// - Pings the core module via callModuleAsync.
// - Declares every LWS-0 intent (generated from protocol/schema/intents.json)
//   and answers `unavailable` until the S7 sheets exist.
Item {
    id: root
    width: 480
    height: 360

    property string coreStatus: "…"
    property string lastRequest: "none yet"

    function parse(raw) {
        var v = raw
        for (var i = 0; i < 2 && typeof v === "string"; i++) {
            try { v = JSON.parse(v) } catch (e) { break }
        }
        return v
    }

    function call(method, args, cb) {
        if (typeof logos === "undefined" || !logos.callModuleAsync) {
            cb({ ok: false, error: "bridge unavailable" })
            return
        }
        logos.callModuleAsync("logos_kit_wallet", method, args, function (raw) { cb(parse(raw)) }, 10000)
    }

    Component.onCompleted: {
        call("ping", [], function (r) { root.coreStatus = JSON.stringify(r) })
    }

    // Until S7 lands the real sheets, every intent is answered immediately
    // with `unavailable`, so a dApp never hangs and nothing is auto-approved.
    // (The S0 identity-hop probe that answered here is recorded in PROGRESS.md.)
    Connections {
        target: typeof logos !== "undefined" ? logos : null
        function onIntentRequested(requestId, intent, params, requesterName) {
            root.lastRequest = requesterName + " → " + intent
            logos.respond(requestId, false, {}, "unavailable")
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.palette.background
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.spacing.medium

        LogosText {
            text: "Logos Kit Wallet"
            font.pixelSize: 24
            Layout.alignment: Qt.AlignHCenter
        }
        LogosText {
            objectName: "coreStatus"
            text: "core: " + root.coreStatus
            textFormat: Text.PlainText
            color: Theme.palette.textSecondary
            Layout.alignment: Qt.AlignHCenter
        }
        LogosText {
            objectName: "lastRequester"
            text: "last requester: " + root.lastRequest
            textFormat: Text.PlainText
            color: Theme.palette.textSecondary
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
