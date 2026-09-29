import QtQuick
import QtQuick.Layouts

// From 21st.dev ai2/alert-dialog-layout (id 28277) and originui/alert-dialog
// (id 1144): https://21st.dev/@ai2/components/alert-dialog-layout
// A centred confirmation: icon, title, message, two buttons. Scales 0.96 → 1
// with a fade (200 ms, emphasized). `tone: "danger"` for destructive ones.
Item {
    id: dlg
    property bool opened: false
    property string title: ""
    property string message: ""
    property string tone: "neutral"   // neutral | danger | private
    property string icon: tone === "danger" ? "warning" : tone === "private" ? "shield" : "info"
    property string confirmText: "Continue"
    property string cancelText: "Cancel"
    property bool busy: false
    default property alias extra: slot.data
    signal confirmed()
    signal cancelled()
    visible: opened || box.opacity > 0
    z: 950
    function open() { opened = true }
    function close() { opened = false }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: dlg.opened ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        MouseArea { anchors.fill: parent; onClicked: {} }
    }
    Item {
        id: box
        width: Math.min(dlg.width - 40, 400)
        height: card.implicitHeight
        anchors.centerIn: parent
        opacity: dlg.opened ? 1 : 0
        scale: dlg.opened ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emph } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emph } }
        Shadow { anchors.fill: card; radius: card.radius; level: 3 }
        Rectangle {
            id: card
            anchors.fill: parent
            radius: Theme.rCard
            color: Theme.surface
            border.width: Theme.dark ? 1 : 0
            border.color: Theme.line
            implicitHeight: col.implicitHeight + 44
            ColumnLayout {
                id: col
                anchors.fill: parent
                anchors.margins: 22
                spacing: 14
                Rectangle {
                    implicitWidth: 44; implicitHeight: 44; radius: 22
                    readonly property color c: dlg.tone === "danger" ? Theme.danger : dlg.tone === "private" ? Theme.priv : Theme.text2
                    color: dlg.tone === "private" ? Theme.privSoft : Theme.soft(c, 0.13)
                    Glyph { anchors.centerIn: parent; name: dlg.icon; color: parent.c; width: 20; height: 20 }
                }
                Txt { text: dlg.title; font.pixelSize: 18; font.weight: Font.DemiBold; wrapMode: Text.Wrap; elide: Text.ElideNone; Layout.fillWidth: true }
                Txt { visible: dlg.message !== ""; text: dlg.message; tone: "text2"; font.pixelSize: 14; wrapMode: Text.Wrap; elide: Text.ElideNone; lineHeight: 1.2; Layout.fillWidth: true }
                ColumnLayout { id: slot; Layout.fillWidth: true; visible: children.length > 0 }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    spacing: 10
                    Btn { text: dlg.cancelText; Layout.fillWidth: true; enabled: !dlg.busy; onClicked: { dlg.cancelled(); dlg.close() } }
                    Btn {
                        text: dlg.confirmText
                        tone: dlg.tone === "danger" ? "danger" : dlg.tone === "private" ? "private" : "ink"
                        busy: dlg.busy
                        Layout.fillWidth: true
                        onClicked: dlg.confirmed()
                    }
                }
            }
        }
    }
    Keys.onEscapePressed: if (!busy) { cancelled(); close() }
}
