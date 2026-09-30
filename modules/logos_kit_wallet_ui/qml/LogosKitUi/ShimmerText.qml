import QtQuick

// From 21st.dev mona_biasia/gradient-shimmer (id 16788):
// https://21st.dev/@mona_biasia/components/gradient-shimmer
// A highlight sweeps across the label (1.45 s, linear, looping). The sandbox
// has no masking effects, so each glyph takes its colour from its distance
// to the sweep. Meant for short live labels: "Proving…", "Checking…".
Row {
    id: sh
    property string text: ""
    property color base: Theme.text3
    property color highlight: Theme.text
    property int pixelSize: 14
    property int weight: Font.Medium
    property bool running: visible && !Theme.reducedMotion
    property real band: 0.35            // width of the bright band, 0..1 of the label
    property real phase: -band
    spacing: 0
    NumberAnimation on phase {
        from: -sh.band; to: 1 + sh.band; duration: 1450
        loops: Animation.Infinite; running: sh.running
    }
    Repeater {
        model: sh.text.length
        Text {
            readonly property real pos: sh.text.length > 1 ? index / (sh.text.length - 1) : 0.5
            readonly property real k: sh.running ? Math.max(0, 1 - Math.abs(pos - sh.phase) / sh.band) : 0
            text: sh.text.charAt(index)
            textFormat: Text.PlainText
            font.family: Theme.font
            font.pixelSize: sh.pixelSize
            font.weight: sh.weight
            color: Qt.rgba(sh.base.r + (sh.highlight.r - sh.base.r) * k,
                           sh.base.g + (sh.highlight.g - sh.base.g) * k,
                           sh.base.b + (sh.highlight.b - sh.base.b) * k, 1)
        }
    }
}
