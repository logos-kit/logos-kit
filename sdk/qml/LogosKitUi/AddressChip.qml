import QtQuick
import QtQuick.Layouts

// From 21st.dev cubby-ui/copy-button (id 27896, icon morph copy → check) and
// ddoemonn/copy-button (id 23529, idle / copied / reset):
// https://21st.dev/@cubby-ui/components/copy-button
// An account or address as a pill: identicon, a shortened id (mono), and a
// copy icon that morphs into a check for 1.5 s. Emits copied(full).
Rectangle {
    id: ac
    property string address: ""
    property string label: ""          // optional name before the id
    property bool identicon: true
    property int head: 6
    property int tail: 4
    signal copied(string value)
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: "Copy address " + ac.address
    Keys.onReturnPressed: ac.copy()
    Keys.onSpacePressed: ac.copy()

    property bool done: false
    readonly property string shortId: address.length > head + tail + 1
        ? address.slice(0, head) + "…" + address.slice(address.length - tail) : address
    implicitHeight: 34
    implicitWidth: row.implicitWidth + 16
    radius: 17
    color: mouse.containsMouse ? Theme.soft(Theme.text, 0.09) : Theme.surface2
    Behavior on color { ColorAnimation { duration: Theme.dFast } }

    TextEdit { id: clip; visible: false }
    function copy() {
        clip.text = address; clip.selectAll(); clip.copy(); clip.text = ""
        done = true; reset.restart(); copied(address)
    }
    Timer { id: reset; interval: 1500; onTriggered: ac.done = false }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 7
        Identicon { visible: ac.identicon; seed: ac.address; size: 20 }
        Txt { visible: ac.label !== ""; text: ac.label; font.pixelSize: 13; font.weight: Font.DemiBold }
        Txt { text: ac.shortId; mono: true; tone: ac.label !== "" ? "text2" : "text"; font.pixelSize: 12 }
        Item {
            implicitWidth: 16; implicitHeight: 16
            Glyph {
                anchors.fill: parent; name: "copy"; color: Theme.text2
                opacity: ac.done ? 0 : 1; scale: ac.done ? 0.5 : 1; rotation: ac.done ? -45 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.dFast } }
                Behavior on scale { NumberAnimation { duration: Theme.dFast; easing.type: Easing.OutCubic } }
                Behavior on rotation { NumberAnimation { duration: Theme.dFast } }
            }
            Glyph {
                anchors.fill: parent; name: "check"; color: Theme.ok; stroke: 2.6
                opacity: ac.done ? 1 : 0; scale: ac.done ? 1 : 0.5
                Behavior on opacity { NumberAnimation { duration: Theme.dFast } }
                Behavior on scale { enabled: !Theme.reducedMotion; NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
            }
        }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ac.copy() }
    Tooltip { text: ac.done ? "Copied" : "Copy " + ac.address; target: ac }
    FocusRing { anchors.fill: parent }
}
