import QtQuick
import QtQuick.Layouts

// The round quick actions under the balance (Send, Receive, Shield, Faucet),
// Family-style: a 52 px disc with a glyph and a caption; press scales 0.94.
ColumnLayout {
    id: at
    property string glyph: "arrowUp"
    property string text: ""
    property string tone: "neutral"    // neutral | ink | private
    signal clicked()
    spacing: 6
    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 52; implicitHeight: 52; radius: 26
        color: at.tone === "ink" ? Theme.text : at.tone === "private" ? Theme.priv
             : m.containsMouse ? Theme.soft(Theme.text, 0.1) : Theme.surface2
        scale: m.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: Theme.dPress } }
        Behavior on color { ColorAnimation { duration: Theme.dFast } }
        Glyph { anchors.centerIn: parent; name: at.glyph; color: at.tone === "ink" ? Theme.bg : at.tone === "private" ? "#ffffff" : Theme.text; width: 20; height: 20 }
        MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: at.clicked() }
    }
    Txt { Layout.alignment: Qt.AlignHCenter; text: at.text; tone: "text2"; font.pixelSize: 12; font.weight: Font.Medium }
}
