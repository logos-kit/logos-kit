import QtQuick
import "../LogosKitUi"
import QtQuick.Layouts
import "Fmt.js" as Fmt

// Account chip (Tray home): identicon, short name, balance; ring when selected.
Rectangle {
    id: chip
    property var account: ({})
    property bool selected: false
    signal clicked()
    implicitHeight: 46
    implicitWidth: lay.implicitWidth + 22
    radius: 23
    color: Theme.surface
    border.width: selected ? 2 : 0
    border.color: Theme.text
    RowLayout {
        id: lay
        anchors.verticalCenter: parent.verticalCenter
        x: 8
        spacing: 8
        Identicon { seed: chip.account.accountId || ""; size: 28 }
        ColumnLayout {
            spacing: 0
            RowLayout {
                spacing: 4
                Glyph { visible: chip.account.kind === "private"; name: "shield"; implicitWidth: 11; implicitHeight: 11; color: Theme.privText; stroke: 2.4 }
                Txt { text: Fmt.accountName(chip.account); font.pixelSize: 12; font.weight: Font.DemiBold; Layout.maximumWidth: 140 }
            }
            Txt { text: Fmt.amount(chip.account.native, 0); tone: "text2"; font.pixelSize: 12; num: true }
        }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
}
