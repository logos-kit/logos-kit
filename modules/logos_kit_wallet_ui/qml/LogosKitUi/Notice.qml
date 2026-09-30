import QtQuick
import QtQuick.Layouts

// Inline note: info (neutral), warn, danger, private.
Rectangle {
    id: n
    property string text: ""
    property string tone: "info"
    property string icon: tone === "info" ? "info" : tone === "private" ? "shield" : "warning"
    readonly property color fg: tone === "warn" ? Theme.warn : tone === "danger" ? Theme.danger : tone === "private" ? Theme.privText : Theme.text2
    Layout.fillWidth: true
    implicitHeight: t.implicitHeight + 24
    radius: Theme.rRow
    color: tone === "info" ? Theme.surface2 : tone === "private" ? Theme.privSoft : Theme.soft(fg, 0.1)
    Glyph { id: gl; name: n.icon; color: n.fg; width: 14; height: 14; x: 12; y: 13 }
    Txt {
        id: t
        x: 34
        y: 12
        width: n.width - 46
        text: n.text
        color: n.fg
        font.pixelSize: 12
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        lineHeight: 1.15
    }
}
