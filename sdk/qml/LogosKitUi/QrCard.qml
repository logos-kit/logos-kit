import QtQuick
import QtQuick.Layouts
import "qrcodegen.js" as QrGen

// From 21st.dev tom_ui/qr-code (id 12249): rounded finder patterns and dot
// data modules: https://21st.dev/@tom_ui/components/qr-code
// Drawn with Rectangles on white (no Canvas, no data: images in the
// sandbox). The centre carries the Logos mark on a white plate (error
// correction M leaves room for it; `low` switches to L for long payloads and
// drops the mark). Below: an optional caption.
ColumnLayout {
    id: qc
    property string text: ""
    property bool low: false
    property real size: 220
    property string caption: ""
    spacing: 12
    readonly property int quiet: 2
    readonly property var modules: {
        if (!text) return null
        try { return low ? QrGen.modulesLow(text) : QrGen.modules(text) } catch (e) { return null }
    }
    readonly property int n: modules ? modules.size : 0
    readonly property real cell: n ? (size - 28) / (n + quiet * 2) : 0
    function on(x, y) { return modules.bits.charAt(y * n + x) === "1" }
    function inFinder(x, y) {
        return (x < 7 && y < 7) || (x >= n - 7 && y < 7) || (x < 7 && y >= n - 7)
    }
    readonly property bool mark: !low && n >= 25
    function inMark(x, y) { var c = (n - 1) / 2, r = Math.floor(n * 0.11); return mark && Math.abs(x - c) <= r && Math.abs(y - c) <= r }
    readonly property var dots: {
        var out = []
        if (!modules) return out
        for (var y = 0; y < n; y++) for (var x = 0; x < n; x++)
            if (on(x, y) && !inFinder(x, y) && !inMark(x, y)) out.push([x, y])
        return out
    }

    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: qc.size; implicitHeight: qc.size
        radius: 24
        color: "#ffffff"
        border.width: Theme.dark ? 0 : 1
        border.color: Theme.line
        Item {
            id: grid
            x: 14 + qc.quiet * qc.cell; y: x
            width: qc.n * qc.cell; height: width
            Repeater {
                model: qc.dots
                Rectangle {
                    x: modelData[0] * qc.cell + qc.cell * 0.08
                    y: modelData[1] * qc.cell + qc.cell * 0.08
                    width: qc.cell * 0.84; height: width; radius: width / 2
                    color: "#0e0e12"
                }
            }
            Repeater {
                model: qc.modules ? [[0, 0], [qc.n - 7, 0], [0, qc.n - 7]] : []
                Rectangle {
                    x: modelData[0] * qc.cell; y: modelData[1] * qc.cell
                    width: 7 * qc.cell; height: width; radius: qc.cell * 2
                    color: "#0e0e12"
                    Rectangle {
                        anchors.centerIn: parent; width: 5 * qc.cell; height: width; radius: qc.cell * 1.4; color: "#ffffff"
                        Rectangle { anchors.centerIn: parent; width: 3 * qc.cell; height: width; radius: qc.cell; color: "#0e0e12" }
                    }
                }
            }
            Rectangle {
                visible: qc.mark
                anchors.centerIn: parent
                width: (Math.floor(qc.n * 0.11) * 2 + 1) * qc.cell; height: width; radius: width * 0.28
                color: "#0e0e12"
                LogosMark { anchors.centerIn: parent; size: parent.width * 0.58; white: true }
            }
        }
        Txt { anchors.centerIn: parent; visible: !qc.modules && qc.text !== ""; text: "Too long for a QR code"; color: "#555" }
    }
    Txt {
        visible: qc.caption !== ""
        Layout.alignment: Qt.AlignHCenter
        text: qc.caption; tone: "text2"; font.pixelSize: 12
    }
}
