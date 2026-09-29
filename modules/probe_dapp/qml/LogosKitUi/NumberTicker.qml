import QtQuick

// From 21st.dev soralabs/number-flow (id 28181, odometer digits, 900 ms
// expo-out) and unlumen/animate-digits (id 20071, only changed digits move):
// https://21st.dev/@soralabs/components/number-flow
// Shows a pre-formatted string ("12,480.5"); each digit rolls to its new
// value, other characters swap in place. Digits are keyed from the right,
// so adding a thousands digit doesn't re-roll the others. Tabular figures.
Row {
    id: nt
    property string value: "0"
    property int pixelSize: 40
    property int weight: Font.DemiBold
    property color color: Theme.text
    property bool masked: false       // "••••" for hidden balances
    readonly property string shown: masked ? "••••••" : value
    readonly property string text: shown      // for tests and accessibility
    Accessible.role: Accessible.StaticText
    Accessible.name: masked ? "Hidden" : value
    spacing: 0
    Repeater {
        model: nt.shown.length
        Item {
            id: cell
            readonly property string ch: nt.shown.charAt(index)
            readonly property bool digit: ch >= "0" && ch <= "9"
            // Each column is as wide as the digit it shows, easing between
            // widths, so a "1" doesn't leave a tabular gap.
            width: digit ? glyph.advanceWidth : other.implicitWidth
            Behavior on width { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.dNumber; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.expoOut } }
            TextMetrics { id: glyph; font.family: Theme.font; font.pixelSize: nt.pixelSize; font.weight: nt.weight; text: cell.digit ? cell.ch : "0" }
            height: probe.height
            clip: true
            TextMetrics { id: probe; font.family: Theme.font; font.pixelSize: nt.pixelSize; font.weight: nt.weight; text: "0" }
            Column {
                visible: cell.digit
                y: -(cell.digit ? parseInt(cell.ch) : 0) * probe.height
                Behavior on y { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.dNumber; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.expoOut } }
                Repeater {
                    model: 10
                    Text {
                        height: probe.height
                        width: cell.width
                        horizontalAlignment: Text.AlignHCenter
                        text: index
                        textFormat: Text.PlainText
                        color: nt.color
                        font.family: Theme.font
                        font.pixelSize: nt.pixelSize
                        font.weight: nt.weight
                    }
                }
            }
            Text {
                id: other
                visible: !cell.digit
                text: cell.ch
                textFormat: Text.PlainText
                color: nt.color
                font.family: Theme.font
                font.pixelSize: nt.pixelSize
                font.weight: nt.weight
            }
        }
    }
}
