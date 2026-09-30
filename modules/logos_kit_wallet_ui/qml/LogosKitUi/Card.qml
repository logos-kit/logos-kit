import QtQuick

// Tray card: surface, 26 px corners; a soft shadow ring in light mode.
Rectangle {
    default property alias content: inner.data
    property int pad: 18
    color: Theme.surface
    radius: Theme.rCard
    border.width: Theme.dark ? 0 : 1
    border.color: Theme.line
    implicitHeight: inner.childrenRect.height + pad * 2
    property int elevation: Theme.dark ? 0 : 1
    Shadow { anchors.fill: parent; radius: parent.radius; level: Math.max(1, parent.elevation); visible: parent.elevation > 0 }
    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: parent.pad
    }
}
