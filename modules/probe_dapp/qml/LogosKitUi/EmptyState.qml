import QtQuick
import QtQuick.Layouts

// Fuse's empty state (Refero: Fuse wallet home, "There is nothing here yet"):
// a bold line, one quiet line of help, and an optional pill. No illustration
// chrome. For "nothing here yet", never for errors. `glyph` is kept for API
// compatibility and not drawn.
ColumnLayout {
    id: es
    property string glyph: "info"
    property string title: ""
    property string body: ""
    property string actionText: ""
    property string actionTone: "neutral"
    signal action()
    Accessible.role: Accessible.Grouping
    Accessible.name: es.title

    spacing: 6
    Txt {
        Layout.fillWidth: true
        Layout.topMargin: 12
        text: es.title
        font.pixelSize: 17
        font.weight: Font.Bold
        horizontalAlignment: Text.AlignHCenter
    }
    Txt {
        visible: es.body !== ""
        Layout.fillWidth: true
        text: es.body
        tone: "text2"
        font.pixelSize: 14
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        lineHeight: 1.2
    }
    Btn {
        visible: es.actionText !== ""
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 12
        text: es.actionText
        tone: es.actionTone
        onClicked: es.action()
    }
}
