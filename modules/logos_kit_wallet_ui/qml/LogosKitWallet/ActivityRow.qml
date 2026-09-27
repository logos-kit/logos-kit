import QtQuick
import QtQuick.Layouts
import "Fmt.js" as Fmt

// One transaction/request row (ux-spec §7). A row that is proving shows its
// phase, time left and an easing bar.
Item {
    id: row
    property var status: ({})
    signal clicked()
    Layout.fillWidth: true
    implicitHeight: 58 + (proving ? 8 : 0)

    readonly property bool proving: status.lifecycle === "proving" || status.lifecycle === "signing"
                                    || (status.lifecycle === "submitted" && !!status.route && status.route !== "public")
    readonly property bool priv: !!status.route && status.route !== "public"
    readonly property var tag: Fmt.statusTag(status)
    readonly property string kind: (status.title || "").indexOf("Connect") === 0 ? "link"
        : (status.title || "").toLowerCase().indexOf("testimonial") >= 0 ? "check"
        : status.route === "shield" ? "shield" : priv ? "lock" : "arrowUp"

    RowLayout {
        anchors.fill: parent
        spacing: 12
        Rectangle {
            implicitWidth: 36; implicitHeight: 36; radius: 14
            color: row.priv ? Theme.privSoft : Theme.surface2
            Glyph { anchors.centerIn: parent; name: row.kind; width: 16; height: 16; color: row.priv ? Theme.privText : Theme.text2 }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Txt { Layout.fillWidth: true; text: row.status.title || "Transaction"; font.weight: Font.DemiBold }
            Txt {
                Layout.fillWidth: true
                tone: "text2"
                font.pixelSize: 12
                text: row.proving && row.status.lifecycle === "proving"
                      ? "Generating proof · about " + Fmt.mmss(row.status.etaSeconds) + " left"
                      : (row.status.requester ? "Asked by " + row.status.requester + " · " : "")
                        + Fmt.ago(row.status.phaseStartedMs, row.status.nowMs)
            }
            Rectangle {
                visible: row.proving
                Layout.fillWidth: true
                implicitHeight: 3; radius: 2
                color: Theme.surface2
                Rectangle {
                    height: parent.height; radius: 2; color: Theme.priv
                    width: parent.width * Fmt.proofProgress(row.status)
                    Behavior on width { NumberAnimation { duration: 400 } }
                }
            }
        }
        Tag { visible: !row.proving; text: row.tag[0]; tone: row.tag[1] }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: row.clicked() }
}
