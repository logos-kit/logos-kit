import QtQuick
import QtQuick.Layouts

// From 21st.dev hari/transaction-list (id 2943) and felipemenezes098/
// activity-feed (id 29394): https://21st.dev/@hari/components/transaction-list
// kind: send | receive | shield | unshield | faucet | testimonial | call.
// status: pending (dots) | included | unconfirmed | failed. The amount is
// signed and coloured: incoming green, outgoing neutral, failed struck out.
Item {
    id: ar
    property string kind: "send"
    property string title: ""
    property string sub: ""              // "2 min ago · to 3kS…9Y"
    property string amount: ""           // unsigned, formatted
    property string symbol: "LEZ"
    property string status: "included"
    property bool isPrivate: false
    signal clicked()
    Layout.fillWidth: true
    implicitHeight: 62
    readonly property bool incoming: kind === "receive" || kind === "faucet" || kind === "unshield"
    readonly property string glyph: kind === "receive" || kind === "faucet" ? "arrowDown"
        : kind === "shield" || kind === "unshield" ? "shield" : kind === "testimonial" ? "info"
        : kind === "call" ? "link" : "arrowUp"

    Rectangle {
        anchors.fill: parent
        radius: Theme.rRow
        color: mouse.containsMouse ? Theme.soft(Theme.text, 0.04) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.dFast } }
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12
        Rectangle {
            implicitWidth: 40; implicitHeight: 40; radius: 20
            color: ar.status === "failed" ? Theme.soft(Theme.danger, 0.13)
                 : ar.isPrivate || ar.kind === "shield" ? Theme.privSoft
                 : ar.incoming ? Theme.soft(Theme.ok, 0.13) : Theme.surface2
            Glyph {
                anchors.centerIn: parent
                name: ar.status === "failed" ? "x" : ar.glyph
                color: ar.status === "failed" ? Theme.danger : ar.isPrivate || ar.kind === "shield" ? Theme.privText
                     : ar.incoming ? Theme.ok : Theme.text
                width: 18; height: 18
            }
            Rectangle {
                visible: ar.status === "pending"
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: Theme.action
                opacity: 0.6
                SequentialAnimation on opacity { loops: Animation.Infinite; running: parent.visible && !Theme.reducedMotion
                    NumberAnimation { to: 0.15; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.7; duration: 700; easing.type: Easing.InOutSine } }
            }
        }
        ColumnLayout {
            spacing: 2
            Layout.fillWidth: true
            Txt { text: ar.title; font.pixelSize: 14; font.weight: Font.DemiBold; Layout.fillWidth: true }
            RowLayout {
                spacing: 6
                Layout.fillWidth: true
                Dots { visible: ar.status === "pending"; size: 4; color: Theme.action }
                Txt {
                    text: ar.status === "pending" ? "Pending" + (ar.sub ? " · " + ar.sub : "")
                        : ar.status === "unconfirmed" ? "Not confirmed yet" + (ar.sub ? " · " + ar.sub : "")
                        : ar.status === "failed" ? "Failed" + (ar.sub ? " · " + ar.sub : "") : ar.sub
                    tone: ar.status === "failed" ? "danger" : ar.status === "unconfirmed" ? "warn" : "text2"
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
        }
        Txt {
            visible: ar.amount !== ""
            text: (ar.incoming ? "+" : "−") + ar.amount + " " + ar.symbol
            num: true
            font.pixelSize: 14
            font.weight: Font.DemiBold
            font.strikeout: ar.status === "failed"
            tone: ar.status === "failed" ? "text3" : ar.incoming ? "ok" : "text"
        }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ar.clicked() }
}
