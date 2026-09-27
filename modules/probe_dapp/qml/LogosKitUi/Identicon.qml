import QtQuick

// Deterministic identicon: a mirrored 5×5 grid over a two-hue gradient, the
// same hash as the design-lab prototype. Rectangles only (no Canvas).
Rectangle {
    id: idc
    property string seed: ""
    property real size: 32
    property bool square: false
    width: size
    height: size
    radius: square ? size * 0.28 : size / 2
    clip: true

    function fnv(s) {
        var h = 2166136261
        for (var i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619) }
        return h >>> 0
    }
    readonly property int h1: fnv(seed) % 360
    readonly property int h2: (h1 + 48) % 360
    readonly property var cells: {
        var out = [], bits = fnv(seed + ":cells")
        for (var y = 0; y < 5; y++)
            for (var x = 0; x < 3; x++)
                if ((bits >>> (y * 3 + x)) & 1) {
                    out.push([x, y])
                    if (x < 2) out.push([4 - x, y])
                }
        return out
    }
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Qt.hsla(idc.h1 / 360, 0.72, 0.60, 1) }
        GradientStop { position: 1; color: Qt.hsla(idc.h2 / 360, 0.70, 0.42, 1) }
    }
    Repeater {
        model: idc.cells
        Rectangle {
            x: (modelData[0] + 1) * idc.size / 7
            y: (modelData[1] + 1) * idc.size / 7
            width: Math.ceil(idc.size / 7)
            height: Math.ceil(idc.size / 7)
            color: "#d9ffffff"
        }
    }
}
