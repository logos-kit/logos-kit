import QtQuick

// A token's mark. Native (LGO): the Logos mark on a black disc (never
// recoloured). Others: `source` (a bundled SVG/PNG, `Qt.resolvedUrl` it) or
// an identicon from the definition id, with a private badge when needed.
Item {
    id: ti
    property string definition: ""     // empty = the native token (LGO)
    property url source: ""
    property real size: 40
    property bool isPrivate: false
    implicitWidth: size
    implicitHeight: size
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: ti.definition === ""
        color: "#0a0a0c"
        border.width: 1
        border.color: "#14ffffff"
        LogosMark { anchors.centerIn: parent; size: parent.width * 0.52; white: true }
    }
    Image {
        anchors.fill: parent
        visible: ti.definition !== "" && ti.source.toString() !== ""
        source: ti.source
        sourceSize: Qt.size(ti.size * 2, ti.size * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
    Identicon {
        visible: ti.definition !== "" && ti.source.toString() === ""
        seed: ti.definition
        size: ti.size
        square: true
    }
    Rectangle {
        visible: ti.isPrivate
        width: ti.size * 0.42; height: width; radius: width / 2
        x: ti.size - width * 0.8; y: ti.size - width * 0.8
        color: Theme.priv
        border.width: 2
        border.color: Theme.surface
        Glyph { anchors.centerIn: parent; name: "lock"; color: "#ffffff"; width: parent.width * 0.56; height: width; stroke: 2.6 }
    }
}
