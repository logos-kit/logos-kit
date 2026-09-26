import QtQuick
import QtQuick.Layouts
import Logos.Theme
import Logos.Controls

// S0 throwaway probe. NEVER published.
// 1. Identity hop: requesterName (intent, attested by the shell) vs the
//    caller name the core sees when this dApp calls it directly.
// 2. Sandbox: Canvas paint, Qt.openUrlExternally, bundled SVG, rich-text.
// Every result is also console.log'd with a PROBE: prefix for basecamp.log.
Item {
    id: root
    width: 560
    height: 520

    property var results: ({})
    property bool canvasPainted: false

    function record(key, value) {
        var r = root.results
        r[key] = value
        root.results = r
        console.log("PROBE: " + key + " = " + JSON.stringify(value))
    }

    function parse(raw) {
        var v = raw
        for (var i = 0; i < 2 && typeof v === "string"; i++) {
            try { v = JSON.parse(v) } catch (e) { break }
        }
        return v
    }

    function runDirect() {
        logos.callModuleAsync("logos_kit_wallet", "whoami", [], function (raw) {
            record("dappSeenByCore", parse(raw))
        }, 10000)
    }

    function runIntent() {
        logos.request("lez.wallet.connect", { chains: ["lez:testnet"] }, function (res) {
            record("intentResult", { ok: res.ok, error: res.error, data: res.data })
        })
    }

    function runSandbox() {
        record("openUrlExternally_https", Qt.openUrlExternally("https://explorer.testnet.lez.logos.co/"))
        record("canvasPaintedAfterShow", root.canvasPainted)
        record("svgStatus", svg.status === Image.Ready ? "ready" : ("status=" + svg.status))
    }

    Rectangle { anchors.fill: parent; color: Theme.palette.background }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing.large
        spacing: Theme.spacing.medium

        LogosText { text: "Logos Kit probe (dev)"; font.pixelSize: 24 }

        RowLayout {
            spacing: Theme.spacing.small
            LogosButton { objectName: "btnDirect"; text: "1. Direct call"; onClicked: root.runDirect() }
            LogosButton { objectName: "btnIntent"; text: "2. Intent"; onClicked: root.runIntent() }
            LogosButton { objectName: "btnSandbox"; text: "3. Sandbox"; onClicked: root.runSandbox() }
        }

        RowLayout {
            spacing: Theme.spacing.large
            Image { id: svg; source: "logo.svg"; sourceSize.width: 48; sourceSize.height: 48 }
            Canvas {
                width: 48; height: 48
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.fillStyle = "#22C55E"
                    ctx.fillRect(0, 0, width, height)
                    root.canvasPainted = true
                }
            }
            // Rich-text probe: rendered as PlainText, so tags must show literally.
            LogosText { text: "<b>bold?</b>"; textFormat: Text.PlainText; objectName: "plainTextProbe" }
        }

        LogosText {
            objectName: "results"
            Layout.fillWidth: true
            wrapMode: Text.WrapAnywhere
            textFormat: Text.PlainText
            color: Theme.palette.textSecondary
            text: JSON.stringify(root.results, null, 2)
        }
    }
}
