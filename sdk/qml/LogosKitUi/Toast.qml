import QtQuick
import QtQuick.Layouts

// One toast card (see ToastHost for the stack and the 21st.dev sources).
// Icon by tone, title, optional body and action; drag sideways to dismiss.
Item {
    id: t
    property var data_: ({})
    property bool entered: false
    property real swipeX: 0
    signal dismissRequested()
    signal actionRequested()
    implicitHeight: card.implicitHeight
    height: implicitHeight

    readonly property string kind: data_.tone || "info"
    readonly property color accent: kind === "ok" ? Theme.ok : kind === "danger" ? Theme.danger
        : kind === "warn" ? Theme.warn : kind === "pending" ? Theme.text2 : Theme.action

    Behavior on y { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.dSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.sonner } }
    Behavior on scale { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.dSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.sonner } }
    Behavior on opacity { NumberAnimation { duration: Theme.dBase } }
    Behavior on swipeX { enabled: !drag.active; NumberAnimation { duration: Theme.dBase; easing.type: Easing.OutCubic } }
    Component.onCompleted: entered = true

    Shadow { anchors.fill: card; radius: card.radius; level: 3 }
    Rectangle {
        id: card
        width: t.width
        implicitHeight: lay.implicitHeight + 26
        radius: 18
        color: Theme.raised
        border.width: 1
        border.color: Theme.line
        opacity: 1 - Math.min(1, Math.abs(t.swipeX) / (t.width * 0.8))

        RowLayout {
            id: lay
            anchors.left: parent.left; anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 14; anchors.rightMargin: 12
            spacing: 12
            Item {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 1
                implicitWidth: 26; implicitHeight: 26
                Rectangle { anchors.fill: parent; radius: 13; color: Theme.soft(t.accent, 0.15) }
                Spinner { anchors.centerIn: parent; visible: t.kind === "pending"; size: 14; color: t.accent }
                Glyph {
                    anchors.centerIn: parent
                    visible: t.kind !== "pending"
                    name: t.kind === "ok" ? "check" : t.kind === "danger" ? "x" : t.kind === "warn" ? "warning" : "info"
                    color: t.accent; width: 14; height: 14; stroke: 2.6
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Txt { text: t.data_.title || ""; font.pixelSize: 14; font.weight: Font.DemiBold; Layout.fillWidth: true }
                Txt {
                    visible: !!t.data_.body
                    text: t.data_.body || ""
                    tone: "text2"; font.pixelSize: 12
                    wrapMode: Text.Wrap; elide: Text.ElideNone; maximumLineCount: 3
                    Layout.fillWidth: true
                }
            }
            Btn {
                visible: !!t.data_.action
                text: t.data_.action || ""
                tone: "ink"
                implicitHeight: 30
                Layout.alignment: Qt.AlignVCenter
                onClicked: t.actionRequested()
            }
            IconButton { glyph: "x"; size: 26; Layout.alignment: Qt.AlignTop; onClicked: t.dismissRequested() }
        }
        DragHandler {
            id: drag
            target: null
            xAxis.enabled: true
            yAxis.enabled: false
            onTranslationChanged: t.swipeX = translation.x
            onActiveChanged: if (!active) {
                if (Math.abs(t.swipeX) > t.width * 0.35) t.dismissRequested()
                else t.swipeX = 0
            }
        }
    }
}
