import QtQuick
import QtQuick.Layouts

// From 21st.dev diceui/status (id 25395):
// https://21st.dev/@diceui/components/status
// A status pill with a dot; `live` pulses the dot (pending, syncing,
// connected). Tones: neutral, ok, warn, danger, action, private.
Rectangle {
    id: b
    property string text: ""
    property string tone: "neutral"
    property bool live: false
    property bool dot: true
    readonly property color fg: tone === "ok" ? Theme.ok : tone === "warn" ? Theme.warn
        : tone === "danger" ? Theme.danger : tone === "action" ? Theme.action
        : tone === "private" ? Theme.privText : Theme.text2
    implicitHeight: 24
    implicitWidth: r.implicitWidth + 18
    radius: 12
    color: tone === "neutral" ? Theme.surface2 : tone === "private" ? Theme.privSoft : Theme.soft(fg, 0.13)
    RowLayout {
        id: r
        anchors.centerIn: parent
        spacing: 6
        Item {
            visible: b.dot
            implicitWidth: 7; implicitHeight: 7
            Rectangle {
                anchors.centerIn: parent
                width: 7; height: 7; radius: 3.5
                color: b.fg
                opacity: 0.5
                visible: b.live && !Theme.reducedMotion
                SequentialAnimation on scale { loops: Animation.Infinite; running: parent.visible
                    NumberAnimation { from: 1; to: 2.3; duration: 1200; easing.type: Easing.OutCubic } }
                SequentialAnimation on opacity { loops: Animation.Infinite; running: parent.visible
                    NumberAnimation { from: 0.55; to: 0; duration: 1200; easing.type: Easing.OutCubic } }
            }
            Rectangle { anchors.centerIn: parent; width: 7; height: 7; radius: 3.5; color: b.fg }
        }
        Txt { text: b.text; color: b.fg; font.pixelSize: 12; font.weight: Font.DemiBold }
    }
}
