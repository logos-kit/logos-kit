import QtQuick
import "qrcodegen.js" as QrGen

// QR code drawn as runs of Rectangles on white (the sandbox refuses data:
// URIs and a Canvas never paints in the plugin widget). `low` uses error
// correction L, for the long private receive code.
Rectangle {
    id: qr
    property string text: ""
    property bool low: false
    property real size: 220
    readonly property int quiet: 3
    readonly property var modules: {
        if (!text) return null
        try { return low ? QrGen.modulesLow(text) : QrGen.modules(text) } catch (e) { return null }
    }
    readonly property real cell: modules ? size / (modules.size + quiet * 2) : 0
    readonly property var runs: {
        var out = []
        if (!modules) return out
        for (var y = 0; y < modules.size; y++) {
            var x = 0
            while (x < modules.size) {
                if (modules.bits.charAt(y * modules.size + x) !== "1") { x++; continue }
                var s = x
                while (x < modules.size && modules.bits.charAt(y * modules.size + x) === "1") x++
                out.push([s, y, x - s])
            }
        }
        return out
    }
    width: size
    height: size
    radius: 16
    color: "#ffffff"
    Repeater {
        model: qr.runs
        Rectangle {
            x: (modelData[0] + qr.quiet) * qr.cell
            y: (modelData[1] + qr.quiet) * qr.cell
            width: modelData[2] * qr.cell + 0.5
            height: qr.cell + 0.5
            color: "#000000"
        }
    }
    Txt { anchors.centerIn: parent; visible: !qr.modules && qr.text !== ""; text: "Too long for a QR code"; color: "#555" }
}
