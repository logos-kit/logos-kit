import QtQuick
import QtQuick.Layouts
import "Units.js" as Units

// A selectable account for connect / pick sheets (Codex review §4, P0).
// Avatar, the public/private badge, the label, balance, and a check box that
// is a real control: focusable, Space/Enter toggles, announced as a check
// box. From 21st.dev micka_design/checkbox-group (id 10365, animated check
// on a card) and the account rows of AppKit's selector.
Rectangle {
    id: ac
    property string accountId: ""
    property string name: ""
    property string kind: "public"        // public | private
    property string balance: ""           // raw integer, native LEZ
    property bool checked: false
    property bool multi: true             // check box (true) or radio (false)
    property bool controlled: false       // the parent owns `checked` (keep its binding)
    signal toggled(bool checked)
    Layout.fillWidth: true
    implicitHeight: 66
    radius: Theme.rRow
    color: checked ? Theme.soft(kind === "private" ? Theme.priv : Theme.action, 0.09) : mouse.containsMouse ? Theme.soft(Theme.text, 0.04) : Theme.surface2
    border.width: checked ? 1.5 : 0
    border.color: kind === "private" ? Theme.priv : Theme.action
    Behavior on color { ColorAnimation { duration: Theme.dFast } }
    activeFocusOnTab: true
    Accessible.role: multi ? Accessible.CheckBox : Accessible.RadioButton
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.name: name + ", " + (kind === "private" ? "private" : "public") + " account" + (balance !== "" ? ", " + Units.lez(balance) : "")
    function flip() {
        var next = multi ? !checked : true
        if (!controlled) checked = next
        toggled(next)
    }
    Keys.onSpacePressed: flip()
    Keys.onReturnPressed: flip()

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 12
        Item {
            implicitWidth: 38; implicitHeight: 38
            Identicon { seed: ac.accountId; size: 38 }
            Rectangle {
                visible: ac.kind === "private"
                width: 16; height: 16; radius: 8; x: 25; y: 25
                color: Theme.priv; border.width: 2; border.color: Theme.surface2
                Glyph { anchors.centerIn: parent; name: "lock"; color: "#ffffff"; width: 9; height: 9; stroke: 2.6 }
            }
        }
        ColumnLayout {
            spacing: 2
            Layout.fillWidth: true
            RowLayout {
                spacing: 8
                Txt { text: ac.name; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.maximumWidth: 180 }
                Badge { text: ac.kind === "private" ? "Private" : "Public"; tone: ac.kind === "private" ? "private" : "neutral"; dot: false; implicitHeight: 20 }
            }
            Txt {
                text: (ac.balance !== "" ? Units.lez(ac.balance) + " · " : "") + ac.accountId.slice(0, 6) + "…" + ac.accountId.slice(-4)
                tone: "text2"; num: true; font.pixelSize: 12; Layout.fillWidth: true
            }
        }
        // The box: a check (multi) or a dot (radio).
        Rectangle {
            implicitWidth: 22; implicitHeight: 22
            radius: ac.multi ? 7 : 11
            color: ac.checked ? (ac.kind === "private" ? Theme.priv : Theme.action) : "transparent"
            border.width: ac.checked ? 0 : 1.5
            border.color: Theme.text3
            Behavior on color { ColorAnimation { duration: Theme.dFast } }
            Glyph { anchors.centerIn: parent; visible: ac.multi; name: "check"; color: "#ffffff"; width: 13; height: 13; stroke: 3
                    scale: ac.checked ? 1 : 0; Behavior on scale { enabled: !Theme.reducedMotion; NumberAnimation { duration: 200; easing.type: Easing.OutBack } } }
            Rectangle { anchors.centerIn: parent; visible: !ac.multi && ac.checked; width: 8; height: 8; radius: 4; color: "#ffffff" }
        }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { ac.forceActiveFocus(); ac.flip() } }
    FocusRing { anchors.fill: parent; ringRadius: Theme.rRow + 3 }
}
