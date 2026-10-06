import QtQuick

// Deterministic avatar: a smooth two-tone orb from the seed's hash (the same
// FNV-1a as before), no pixel grid. The gradient sits on the rounded shape
// itself (QtQuick's `clip` cuts square), plus a soft highlight.
Rectangle {
    id: idc
    property string seed: ""
    property real size: 32
    property bool square: false
    width: size
    height: size
    radius: square ? size * 0.28 : size / 2

    function fnv(s) {
        var h = 2166136261
        for (var i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619) }
        return h >>> 0
    }
    readonly property int hash: fnv(seed)
    readonly property real h1: (hash % 360) / 360
    readonly property real h2: (h1 + 0.08 + ((hash >>> 9) % 120) / 1000) % 1

    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.hsla(idc.h1, 0.7, 0.66, 1) }
        GradientStop { position: 1.0; color: Qt.hsla(idc.h2, 0.72, 0.46, 1) }
    }
    Rectangle {
        width: idc.size * 0.46; height: width; radius: width / 2
        x: idc.size * 0.16; y: idc.size * 0.12
        color: Qt.rgba(1, 1, 1, 0.22)
    }
}
