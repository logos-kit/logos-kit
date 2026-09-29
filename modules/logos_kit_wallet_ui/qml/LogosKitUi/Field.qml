import QtQuick
import QtQuick.Controls.Basic as C

// Text input styled to Tray (surface2 row, 20 px corners).
C.TextField {
    id: f
    property bool mono: false
    property bool invalid: false
    color: Theme.text
    placeholderTextColor: Theme.text3
    selectionColor: Theme.soft(Theme.action, 0.35)
    selectedTextColor: Theme.text
    font.family: mono ? Theme.mono : Theme.font
    font.pixelSize: 15
    leftPadding: 16
    rightPadding: 16
    topPadding: 13
    bottomPadding: 13
    background: Rectangle {
        radius: Theme.rRow
        color: Theme.surface2
        border.width: f.activeFocus || f.invalid ? 2 : 0
        border.color: f.invalid ? Theme.danger : Theme.action
    }
}
