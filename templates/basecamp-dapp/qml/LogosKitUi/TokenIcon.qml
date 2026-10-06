import QtQuick

// A token's mark. Native (LGO): the Logos mark on a black disc (never
// recoloured). Others: `source` (a bundled PNG from the token list,
// `Qt.resolvedUrl` it); without one, Family's initials circle: 1–3 letters
// from `label` on a quiet tone picked from the definition id (the same on
// every device), in the warning tone for an unverified token (`warn`), or
// an identicon when there's no label. A private badge when needed.
// Unverified tokens never get their own image (docs/dev/lp0001-decisions.md D6).
Item {
    id: ti
    property string definition: ""     // empty = the native token (LGO)
    property url source: ""
    property string label: ""          // symbol or name, for the initials
    property bool warn: false
    property real size: 40
    property bool isPrivate: false
    readonly property string initials: {
        var clean = label.replace(/[^A-Za-z0-9 ]/g, "").trim()
        if (clean === "") return ""
        var words = clean.split(/ +/)
        var out = words.length > 1 ? words[0].charAt(0) + words[1].charAt(0) : clean.substring(0, clean.length <= 3 ? 3 : 2)
        return out.toUpperCase()
    }
    property bool imageFailed: false
    readonly property bool showImage: definition !== "" && source.toString() !== "" && !imageFailed
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
        visible: ti.showImage
        source: ti.source
        sourceSize: Qt.size(ti.size * 2, ti.size * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        onStatusChanged: ti.imageFailed = status === Image.Error
    }
    // Initials circle (Family): a muted tone from the definition id.
    Rectangle {
        id: initialsDisc
        anchors.fill: parent
        radius: width / 2
        visible: ti.definition !== "" && !ti.showImage && ti.initials !== ""
        readonly property int hash: {
            var h = 2166136261
            for (var i = 0; i < ti.definition.length; i++) { h ^= ti.definition.charCodeAt(i); h = (h * 16777619) >>> 0 }
            return h
        }
        color: ti.warn ? Theme.soft(Theme.warn, Theme.dark ? 0.22 : 0.16)
             : Qt.hsla((hash % 360) / 360, Theme.dark ? 0.16 : 0.12, Theme.dark ? 0.26 : 0.90, 1)
        border.width: ti.warn ? 1 : 0
        border.color: Theme.soft(Theme.warn, 0.5)
        Txt {
            anchors.centerIn: parent
            text: ti.initials
            color: ti.warn ? Theme.warn : Theme.text
            font.pixelSize: Math.round(ti.size * (ti.initials.length > 2 ? 0.30 : 0.38))
            font.weight: Font.DemiBold
        }
    }
    Identicon {
        visible: ti.definition !== "" && !ti.showImage && ti.initials === ""
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
        border.color: Theme.bg
        Glyph { anchors.centerIn: parent; name: "lock"; color: Theme.privOn; width: parent.width * 0.56; height: width; stroke: 2.6 }
    }
}
