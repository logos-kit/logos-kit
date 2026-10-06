import QtQuick
import "../LogosKitUi"
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

    Txt { text: "Accounts"; font.pixelSize: 20; font.weight: Font.Bold }
    Txt { Layout.fillWidth: true; text: "Public accounts are visible on-chain and pay fees. Private accounts are seen only by you."; tone: "text2"; font.pixelSize: 13; wrapMode: Text.Wrap; elide: Text.ElideNone }
    Repeater {
        model: av.store.userAccounts
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                AccountCard {
                    multi: false
                    controlled: true
                    accountId: modelData.accountId
                    name: Fmt.accountName(modelData)
                    kind: modelData.kind
                    balance: modelData.native === null || modelData.native === undefined ? "" : String(modelData.native)
                    checked: !!av.store.current && av.store.current.accountId === modelData.accountId
                    onToggled: { av.store.selected = modelData.accountId; av.picked() }
                }
                IconButton {
                    glyph: "pencil"
                    label: "Rename " + Fmt.accountName(modelData)
                    filled: true
                    onClicked: av.editing = av.editing === modelData.accountId ? "" : modelData.accountId
                }
            }
            RowLayout {
                visible: av.editing === modelData.accountId
                Layout.fillWidth: true
                spacing: 6
                Field { id: lbl; Layout.fillWidth: true; text: modelData.label || ""; placeholderText: "Name (up to 32 characters)"; maximumLength: 32; onAccepted: saveBtn.clicked() }
                Btn {
                    id: saveBtn
                    text: "Save"
                    tone: "ink"
                    onClicked: av.store.call("setLabel", { account: modelData.accountId, label: lbl.text.trim() || null }, function (v, e) {
                        if (e) { av.problem = Fmt.errorText(e); return }
                        av.editing = ""
                        av.store.refreshAll()
                    })
                }
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
    Notice { visible: av.problem !== ""; Layout.fillWidth: true; text: av.problem; tone: "danger" }
}
