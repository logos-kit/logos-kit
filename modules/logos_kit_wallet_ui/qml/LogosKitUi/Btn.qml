import QtQuick
import QtQuick.Layouts

// Pill button (Tray): ink (primary), action (connect), private, neutral,
// ghost, danger. Presses to 0.96. `armDelay` keeps it disabled for a moment
// after it appears (approval buttons arm after 500 ms).
Item {
    id: b
    property string text: ""
    property string icon: ""
    property string tone: "neutral"
    property bool large: false
    property bool busy: false
    property int armDelay: 0
    property bool armed: armDelay === 0
    signal clicked()

    implicitHeight: large ? 52 : 42
    implicitWidth: row.implicitWidth + (large ? 40 : 32)
    opacity: enabled && armed ? 1 : 0.4
    Accessible.role: Accessible.Button
    Accessible.name: text
    activeFocusOnTab: true

    Timer { running: b.armDelay > 0 && b.visible; interval: b.armDelay; onTriggered: b.armed = true }
    onVisibleChanged: if (!visible && armDelay > 0) armed = false

    readonly property color bg: tone === "ink" ? Theme.text : tone === "action" ? Theme.action
        : tone === "private" ? Theme.priv : tone === "danger" ? Theme.danger
        : tone === "ghost" ? "transparent" : Theme.surface2
    readonly property color fg: tone === "ink" ? Theme.bg : (tone === "action" || tone === "private" || tone === "danger") ? "#ffffff"
        : tone === "ghost" ? Theme.text2 : Theme.text

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: b.bg
        border.width: b.tone === "ghost" ? 1 : 0
        border.color: Theme.line
        scale: mouse.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: Theme.dPress } }
        // Hover sheen and a keyboard focus ring (v2).
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: b.tone === "ink" || b.tone === "neutral" || b.tone === "ghost" ? Theme.soft(Theme.dark ? "#ffffff" : "#000000", 0.07) : Theme.soft("#ffffff", 0.14)
            opacity: mouse.containsMouse && b.enabled && b.armed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.dFast } }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: height / 2
            color: "transparent"
            border.width: 2
            border.color: Theme.soft(Theme.action, 0.7)
            visible: b.activeFocus
        }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 8
            Spinner { visible: b.busy; size: 16; color: b.fg }
            Glyph { visible: b.icon !== "" && !b.busy; name: b.icon; color: b.fg; implicitWidth: 16; implicitHeight: 16 }
            Txt {
                text: b.text
                color: b.fg
                font.pixelSize: b.large ? 16 : 14
                font.weight: Font.DemiBold
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: b.enabled && b.armed && !b.busy
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
    Keys.onReturnPressed: if (enabled && armed && !busy) clicked()
    Keys.onSpacePressed: if (enabled && armed && !busy) clicked()
}
