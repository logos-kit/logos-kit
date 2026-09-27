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
    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: parent.pad
    }
}
