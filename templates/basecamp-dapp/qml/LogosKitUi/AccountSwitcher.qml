import QtQuick
import QtQuick.Layouts

// From 21st.dev originui/dropdown-menu (id 385) laid out like Rabby's and
// Family's account pickers: the trigger shows the identicon, name and a
// caret; the panel lists accounts with kind and balance, a check on the
// selected one, and "New account" at the bottom.
//
// accounts: [{ id, name, kind: "public"|"private", balance }]
Item {
    id: sw
    property var accounts: []
    property string currentId: ""
    property string symbol: "LEZ"
    signal selected(string id)
    signal createRequested()
    implicitWidth: trig.implicitWidth
    implicitHeight: 40

    readonly property var current: {
        for (var i = 0; i < accounts.length; i++) if (accounts[i].id === currentId) return accounts[i]
        return accounts.length ? accounts[0] : null
    }

    Rectangle {
        id: trig
        anchors.fill: parent
        implicitWidth: tl.implicitWidth + 22
        radius: height / 2
        color: tm.containsMouse || pop.opened ? Theme.soft(Theme.text, 0.08) : Theme.surface2
        Behavior on color { ColorAnimation { duration: Theme.dFast } }
        RowLayout {
            id: tl
            anchors.centerIn: parent
            spacing: 8
            Item {
                implicitWidth: 26; implicitHeight: 26
                Identicon { seed: sw.current ? sw.current.id : ""; size: 26 }
                Rectangle {
                    visible: sw.current && sw.current.kind === "private"
                    width: 12; height: 12; radius: 6; x: 16; y: 16
                    color: Theme.priv; border.width: 2; border.color: Theme.surface2
                }
            }
            Txt { text: sw.current ? sw.current.name : "No account"; font.pixelSize: 14; font.weight: Font.DemiBold }
            Glyph {
                name: "chevronDown"; color: Theme.text2; width: 14; height: 14
                rotation: pop.opened ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: Theme.dBase; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emph } }
            }
        }
        MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.opened ? pop.close() : pop.open() }
    }

    Popover {
        id: pop
        panelWidth: 300
        Repeater {
            model: sw.accounts
            Rectangle {
                width: pop.panelWidth - 12
                height: 54
                radius: 14
                color: am.containsMouse ? Theme.soft(Theme.text, 0.06) : "transparent"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    spacing: 10
                    Identicon { seed: modelData.id; size: 32 }
                    ColumnLayout {
                        spacing: 1
                        Layout.fillWidth: true
                        Txt { text: modelData.name; font.pixelSize: 14; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        Txt {
                            text: (modelData.kind === "private" ? "Private" : "Public") + (modelData.balance !== undefined ? " · " + modelData.balance + " " + sw.symbol : "")
                            tone: modelData.kind === "private" ? "priv" : "text2"; num: true; font.pixelSize: 12
                        }
                    }
                    Glyph { visible: modelData.id === sw.currentId; name: "check"; color: Theme.action; width: 16; height: 16; stroke: 2.6 }
                }
                MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { sw.currentId = modelData.id; sw.selected(modelData.id); pop.close() } }
            }
        }
        Rectangle { width: pop.panelWidth - 12; height: 1; color: Theme.line }
        Rectangle {
            width: pop.panelWidth - 12
            height: 46
            radius: 14
            color: nm.containsMouse ? Theme.soft(Theme.text, 0.06) : "transparent"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                spacing: 10
                Rectangle { implicitWidth: 28; implicitHeight: 28; radius: 14; color: Theme.surface2
                    Glyph { anchors.centerIn: parent; name: "plus"; color: Theme.text; width: 14; height: 14 } }
                Txt { text: "New account"; font.pixelSize: 14; font.weight: Font.DemiBold }
            }
            MouseArea { id: nm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { pop.close(); sw.createRequested() } }
        }
    }
}
