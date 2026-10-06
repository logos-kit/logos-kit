import QtQuick
import "../LogosKitUi"
import QtQuick.Layouts

// Tray sheet (brand.md, design-lab Sheet.tsx): floats 10 px off the edges,
// its height follows the measured content (200 ms calm curve), it slides up
// with the overshoot curve, steps swap with depth (forward enters from 1.08,
// back from 0.94), and ✕ becomes ← after the first step. It holds focus,
// closes on Esc or a scrim click unless `busy`, and stays open until the
// backend answers.
Item {
    id: sheet
    anchors.fill: parent
    visible: open || panel.y < height
    z: 50

    property bool open: false
    property string stepKey: ""
    property bool first: true
    property bool busy: false
    property int dir: 1
    property real maxWidth: 520
    default property alias content: holder.data
    signal closeRequested()
    signal backRequested()

    readonly property real innerWidth: panel.width - 40

    onOpenChanged: if (open) panel.forceActiveFocus()

    onStepKeyChanged: {
        if (!open || Theme.reducedMotion) return
        swap.stop()
        holder.scale = dir > 0 ? 1.08 : 0.94
        holder.opacity = 0
        swap.start()
    }

    ParallelAnimation {
        id: swap
        NumberAnimation { target: holder; property: "scale"; to: 1; duration: Theme.dStep; easing.type: Easing.Bezier; easing.bezierCurve: Theme.calm }
        NumberAnimation { target: holder; property: "opacity"; to: 1; duration: Theme.dStep }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: sheet.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.dSheet } }
        MouseArea {
            anchors.fill: parent
            onClicked: if (!sheet.busy) sheet.closeRequested()
        }
    }

    Rectangle {
        id: panel
        objectName: "sheetPanel"
        width: Math.min(sheet.width - 20, sheet.maxWidth)
        x: (sheet.width - width) / 2
        readonly property real wanted: head.height + holder.implicitHeight + 24
        height: Math.min(wanted, sheet.height - 20)
        y: sheet.open ? sheet.height - height - 10 : sheet.height + 20
        radius: Theme.rSheet
        color: Theme.sheet
        border.width: Theme.dark ? 1 : 0
        border.color: Theme.line
        clip: true
        focus: sheet.open
        Behavior on y { NumberAnimation { duration: Theme.dSheet; easing.type: Easing.Bezier; easing.bezierCurve: Theme.overshoot } }
        Behavior on height { NumberAnimation { duration: Theme.dHeight; easing.type: Easing.Bezier; easing.bezierCurve: Theme.calm } }
        Keys.onEscapePressed: if (!sheet.busy) sheet.closeRequested()

        // Clicks on the sheet don't reach the scrim.
        MouseArea { anchors.fill: parent }

        Item {
            id: head
            width: parent.width
            height: 52
            IconButton {
                objectName: sheet.first ? "sheetClose" : "sheetBack"
                x: 20
                y: 16
                glyph: sheet.first ? "x" : "back"
                label: sheet.first ? "Close" : "Back"
                enabled: !sheet.busy
                onClicked: sheet.first ? sheet.closeRequested() : sheet.backRequested()
            }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 30; width: 36; height: 4; radius: 2; color: Theme.line }
        }

        Flickable {
            anchors.top: head.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            contentHeight: holder.implicitHeight + 20
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            Item {
                id: holder
                width: sheet.innerWidth
                implicitHeight: childrenRect.height
                transformOrigin: Item.Top
            }
        }
    }
}
