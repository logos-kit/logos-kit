import QtQuick
import QtQuick.Layouts

// From 21st.dev laziekiki/empty-state-kit (id 27024) and uiable/empty-
// background (id 18266): https://21st.dev/@laziekiki/components/empty-state-kit
// A glyph in a soft tile ringed by two faint circles, a title, one line of
// help and an optional action. For "nothing here yet", never for errors.
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

    spacing: 10
    Item {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 112; implicitHeight: 96
        Repeater {
            model: 2
            Rectangle {
                anchors.centerIn: parent
                width: 64 + (index + 1) * 26; height: width; radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Theme.soft(Theme.text, 0.06 - index * 0.025)
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: 58; height: 58; radius: 18
            color: Theme.surface2
            border.width: 1
            border.color: Theme.line
            Glyph { anchors.centerIn: parent; name: es.glyph; color: Theme.text2; width: 24; height: 24 }
        }
    }
    Txt {
        Layout.alignment: Qt.AlignHCenter
        text: es.title
        font.pixelSize: 16
        font.weight: Font.DemiBold
    }
    Txt {
        visible: es.body !== ""
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: 300
        text: es.body
        tone: "text2"
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        lineHeight: 1.2
    }
    Btn {
        visible: es.actionText !== ""
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 6
        text: es.actionText
        tone: es.actionTone
        onClicked: es.action()
    }
}
