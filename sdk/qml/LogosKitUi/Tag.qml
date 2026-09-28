import QtQuick
import QtQuick.Layouts

// Small status tag: ok | pending | unconfirmed | private | danger | action.
Rectangle {
    id: tag
    property string text: ""
    property string tone: "pending"
    property string icon: ""
    readonly property color fg: tone === "ok" ? Theme.ok : tone === "unconfirmed" ? Theme.warn
        : tone === "private" ? Theme.privText : tone === "danger" ? Theme.danger
        : tone === "action" ? Theme.action : Theme.text2
    implicitHeight: 22
    implicitWidth: r.implicitWidth + 16
    radius: 11
    color: tone === "pending" ? Theme.surface2 : tone === "private" ? Theme.privSoft : Theme.soft(fg, 0.14)
    RowLayout {
        id: r
        anchors.centerIn: parent
        spacing: 4
        Glyph { visible: tag.icon !== ""; name: tag.icon; color: tag.fg; implicitWidth: 11; implicitHeight: 11; stroke: 2.4 }
        Txt { text: tag.text; color: tag.fg; font.pixelSize: 11; font.weight: Font.DemiBold }
    }
}
