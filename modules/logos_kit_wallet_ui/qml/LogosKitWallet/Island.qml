import QtQuick
import "../LogosKitUi"
import QtQuick.Layouts
import "Fmt.js" as Fmt

// The proof island (Tray): a pill pinned to the top while a proof runs and
// its sheet is closed. Tapping it reopens the proof.
Rectangle {
    id: isl
    property var status: null
    signal clicked()
    readonly property bool running: !!status && !Fmt.isFinal(status)
    visible: opacity > 0
    opacity: running ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 200 } }
    implicitHeight: 36
    width: lay.implicitWidth + 26
    Behavior on width { SpringAnimation { spring: 3; damping: 0.3 } }
    radius: 18
    color: Theme.island
    border.width: 1
    border.color: "#1affffff"
    RowLayout {
        id: lay
        anchors.centerIn: parent
        spacing: 9
        Ring { size: 18; thickness: 3; track: "#26ffffff"; range: "#a59fff"; value: Fmt.proofProgress(isl.status) }
        Txt { text: isl.status && isl.status.lifecycle === "proving" ? "Proving" : "Sending"; color: "#ffffff"; font.pixelSize: 13; font.weight: Font.DemiBold }
        Txt {
            visible: !!isl.status && isl.status.lifecycle === "proving"
            text: isl.status ? Fmt.mmss(isl.status.etaSeconds) : ""
            color: "#99ffffff"; font.pixelSize: 13; num: true
        }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: isl.clicked() }
}
