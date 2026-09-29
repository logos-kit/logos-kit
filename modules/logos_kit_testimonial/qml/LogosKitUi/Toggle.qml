import QtQuick

// From 21st.dev micka_design/switch (id 10334, the thumb stretches while
// pressed) and serafimcloud/switch (id 21948, spring-eased thumb):
// https://21st.dev/@micka_design/components/switch
// Named Toggle so it never clashes with QtQuick.Controls' Switch.
Item {
    id: sw
    property bool checked: false
    property color onColor: Theme.ok
    signal toggled(bool checked)
    implicitWidth: 46
    implicitHeight: 28
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.checked: checked
    opacity: enabled ? 1 : 0.4

    function flip() { checked = !checked; toggled(checked) }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? sw.onColor : Theme.soft(Theme.text, Theme.dark ? 0.16 : 0.12)
        border.width: sw.activeFocus ? 2 : 0
        border.color: Theme.action
        Behavior on color { ColorAnimation { duration: Theme.dBase } }
    }
    Rectangle {
        id: thumb
        readonly property real d: sw.height - 6
        y: 3
        height: d
        width: mouse.pressed ? d + 6 : d
        radius: d / 2
        color: "#ffffff"
        x: sw.checked ? sw.width - width - 3 : 3
        Behavior on x { enabled: !Theme.reducedMotion; SpringAnimation { spring: 5; damping: 0.38; epsilon: 0.2 } }
        Behavior on width { NumberAnimation { duration: Theme.dFast; easing.type: Easing.OutCubic } }
        Shadow { anchors.fill: parent; radius: parent.radius; level: 1; strength: 0.35 }
    }
    MouseArea { id: mouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.flip() }
    Keys.onSpacePressed: flip()
    Keys.onReturnPressed: flip()
}
