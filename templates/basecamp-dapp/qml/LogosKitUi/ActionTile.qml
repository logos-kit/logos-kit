import QtQuick
import QtQuick.Layouts

// The quick actions under the balance, Phantom-style (Refero: Phantom wallet
// home): equal tiles in a row, glyph over caption, `ink` for the main one.
// Press scales 0.96.
Rectangle {
    id: at
    property string glyph: "arrowUp"
    property string text: ""
    property string tone: "neutral"    // neutral | ink | private
    signal clicked()
    readonly property bool filled: tone === "ink" || tone === "private"
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    implicitHeight: 76
    radius: 20
    color: filled ? Theme.action
         : m.containsMouse ? Theme.soft(Theme.text, 0.1) : Theme.surface
    scale: m.pressed ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: Theme.dPress } }
    Behavior on color { ColorAnimation { duration: Theme.dFast } }
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: at.text
    Keys.onReturnPressed: at.clicked()
    Keys.onSpacePressed: at.clicked()
    FocusRing { anchors.fill: parent }
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 6
        Glyph { Layout.alignment: Qt.AlignHCenter; name: at.glyph; color: at.filled ? Theme.privOn : Theme.text; width: 22; height: 22 }
        Txt { Layout.alignment: Qt.AlignHCenter; text: at.text; color: at.filled ? Theme.privOn : Theme.text; font.pixelSize: 13; font.weight: Font.DemiBold }
    }
    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: at.clicked() }
}
