import QtQuick
import QtQuick.Layouts

// What an app gets when it connects, after Glow's connect sheet (Refero
// screen ca153aec): a quiet panel, "This app will be able to" with green
// checks, then "It will not be able to" with crosses. `privateRead` adds the
// separate private-account consent line.
Rectangle {
    id: pm
    property bool privateRead: false
    implicitHeight: col.implicitHeight + 32
    radius: Theme.rCard
    color: Theme.surface
    readonly property var can: {
        var out = ["See the accounts you choose and their public balances", "Ask you to approve transactions"]
        if (pm.privateRead) out.push("Read the balance of the private accounts you tick")
        return out
    }
    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 16
        spacing: 10
        Txt { text: "This app will be able to:"; tone: "text2"; font.pixelSize: 13 }
        Repeater {
            model: pm.can
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Glyph { Layout.alignment: Qt.AlignTop; Layout.topMargin: 1; name: "check"; width: 18; height: 18; stroke: 2.4; color: Theme.ok }
                Txt { text: modelData; font.pixelSize: 14; wrapMode: Text.Wrap; elide: Text.ElideNone; Layout.fillWidth: true }
            }
        }
        Txt { Layout.topMargin: 4; text: "It will not be able to:"; tone: "text2"; font.pixelSize: 13 }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Glyph { Layout.alignment: Qt.AlignTop; Layout.topMargin: 1; name: "x"; width: 18; height: 18; stroke: 2.2; color: Theme.text3 }
            Txt { text: "Move funds or sign anything without your approval"; tone: "text2"; font.pixelSize: 14; wrapMode: Text.Wrap; elide: Text.ElideNone; Layout.fillWidth: true }
        }
    }
}
