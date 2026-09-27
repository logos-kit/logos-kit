import QtQuick
import QtQuick.Layouts
import "Fmt.js" as Fmt

// Accounts (plan S7): pick, add public or private, rename.
ColumnLayout {
    id: av
    property var store
    property string editing: ""
    property string problem: ""
    property bool busy: false
    signal picked()
    width: parent ? parent.width : 400
    spacing: 8

    function add(kind) {
        busy = true
        problem = ""
        store.call("newAccount", { kind: kind }, function (v, e) {
            av.busy = false
            if (e) { av.problem = Fmt.errorText(e); return }
            av.store.selected = v.accountId
            av.store.refreshAll()
        })
    }

    Txt { text: "Accounts"; font.pixelSize: 20; font.weight: Font.DemiBold }
    Repeater {
        model: av.store.accounts
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: av.editing === modelData.accountId ? 110 : 64
            radius: Theme.rRow
            readonly property bool on: av.store.current && av.store.current.accountId === modelData.accountId
            color: on ? Theme.surface2 : "transparent"
            border.width: 1
            border.color: on ? Theme.text3 : Theme.line
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Identicon { seed: modelData.accountId; size: 36 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        RowLayout {
                            spacing: 6
                            Txt { text: Fmt.accountName(modelData); font.weight: Font.DemiBold; Layout.maximumWidth: 200 }
                            Tag { text: modelData.kind === "private" ? "Private" : "Public"; tone: modelData.kind === "private" ? "private" : "pending"; icon: modelData.kind === "private" ? "shield" : "" }
                        }
                        Txt { text: Fmt.short(modelData.accountId) + " · " + Fmt.amount(modelData.native, 0) + " LEZ"; tone: "text2"; font.pixelSize: 12; mono: true }
                    }
                    Txt {
                        text: "Rename"; tone: "action"; font.pixelSize: 12
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: av.editing = av.editing === modelData.accountId ? "" : modelData.accountId }
                    }
                }
                RowLayout {
                    visible: av.editing === modelData.accountId
                    Layout.fillWidth: true
                    spacing: 6
                    Field { id: lbl; Layout.fillWidth: true; text: modelData.label || ""; placeholderText: "Name (up to 32 characters)"; maximumLength: 32 }
                    Btn {
                        text: "Save"
                        onClicked: av.store.call("setLabel", { account: modelData.accountId, label: lbl.text.trim() || null }, function (v, e) {
                            if (e) { av.problem = Fmt.errorText(e); return }
                            av.editing = ""
                            av.store.refreshAll()
                        })
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                anchors.rightMargin: 70
                enabled: av.editing !== modelData.accountId
                cursorShape: Qt.PointingHandCursor
                onClicked: { av.store.selected = modelData.accountId; av.picked() }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 8
        Btn { objectName: "newPublic"; Layout.fillWidth: true; icon: "plus"; text: "Public account"; busy: av.busy; onClicked: av.add("public") }
        Btn { objectName: "newPrivate"; Layout.fillWidth: true; icon: "shield"; tone: "private"; text: "Private account"; busy: av.busy; onClicked: av.add("private") }
    }
    Txt { visible: av.problem !== ""; Layout.fillWidth: true; text: av.problem; tone: "danger"; wrapMode: Text.Wrap; font.pixelSize: 13 }
}
