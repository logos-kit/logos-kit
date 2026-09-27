import QtQuick
import QtQuick.Controls.Basic as C

// Multi-line input styled to Tray. `maxBytes` counts UTF-8 bytes (what
// on-chain limits count), shown bottom-right once you're near it.
Rectangle {
    id: box
    property alias text: area.text
    property alias placeholderText: area.placeholderText
    property alias area: area
    property int maxBytes: 0
    property bool invalid: false
    readonly property int bytes: utf8Length(area.text)
    readonly property bool over: maxBytes > 0 && bytes > maxBytes

    function utf8Length(s) {
        var n = 0
        for (var i = 0; i < s.length; i++) {
            var c = s.charCodeAt(i)
            if (c < 0x80) n += 1
            else if (c < 0x800) n += 2
            else if (c >= 0xd800 && c < 0xdc00) { n += 4; i++ }
            else n += 3
        }
        return n
    }

    implicitHeight: 132
    radius: Theme.rRow
    color: Theme.surface2
    border.width: area.activeFocus || invalid || over ? 2 : 0
    border.color: invalid || over ? Theme.danger : Theme.action

    C.ScrollView {
        anchors.fill: parent
        anchors.bottomMargin: counter.visible ? 22 : 0
        C.TextArea {
            id: area
            color: Theme.text
            placeholderTextColor: Theme.text3
            selectionColor: Theme.soft(Theme.action, 0.35)
            selectedTextColor: Theme.text
            font.family: Theme.font
            font.pixelSize: 15
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            leftPadding: 16
            rightPadding: 16
            topPadding: 14
            bottomPadding: 10
            background: null
        }
    }
    Txt {
        id: counter
        visible: box.maxBytes > 0 && box.bytes > box.maxBytes * 0.7
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        text: box.bytes + " / " + box.maxBytes
        tone: box.over ? "danger" : "text3"
        font.pixelSize: 11
        num: true
    }
}
