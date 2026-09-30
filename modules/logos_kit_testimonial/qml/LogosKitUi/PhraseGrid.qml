import QtQuick
import QtQuick.Layouts

// From 21st.dev diarmuradi/recovery-code (id 29244) and the numbered word
// grids of Family / Rabby. Shows a recovery phrase as numbered cells,
// hidden behind a "Tap to reveal" veil until `revealed`. Mono, selectable
// nowhere (no accidental clipboard). For confirm steps, `blanks` lists the
// indexes to leave empty and `filled` maps index → chosen word.
Item {
    id: pg
    property var words: []
    property bool revealed: false
    property var blanks: []
    property var filled: ({})
    property int columns: 3
    signal revealRequested()
    implicitHeight: grid.implicitHeight
    Layout.fillWidth: true

    GridLayout {
        id: grid
        width: pg.width
        columns: pg.columns
        rowSpacing: 8
        columnSpacing: 8
        Repeater {
            model: pg.words
            Rectangle {
                readonly property bool blank: pg.blanks.indexOf(index) >= 0
                readonly property string word: blank ? (pg.filled[index] || "") : modelData
                Layout.fillWidth: true
                implicitHeight: 40
                radius: 14
                color: blank && word === "" ? "transparent" : Theme.surface2
                border.width: blank ? 1.5 : 0
                border.color: blank && word === "" ? Theme.text3 : Theme.action
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8
                    Txt { text: index + 1; num: true; tone: "text3"; font.pixelSize: 11; Layout.preferredWidth: 16 }
                    Txt {
                        text: parent.parent.word
                        mono: true
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        Layout.fillWidth: true
                        opacity: pg.revealed || parent.parent.blank ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.dBase } }
                    }
                }
                // Hidden: a row of dots in place of the word.
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 36
                    spacing: 4
                    visible: !pg.revealed && !parent.blank
                    Repeater { model: 5; Rectangle { width: 6; height: 6; radius: 3; color: Theme.text3; opacity: 0.6 } }
                }
            }
        }
    }
    Rectangle {
        anchors.fill: grid
        radius: 16
        color: Theme.soft(Theme.surface, 0.4)
        visible: !pg.revealed && pg.blanks.length === 0
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.dBase } }
        Rectangle {
            anchors.centerIn: parent
            implicitWidth: hint.implicitWidth + 28; implicitHeight: 40; radius: 20
            activeFocusOnTab: parent.visible
            Accessible.role: Accessible.Button
            Accessible.name: "Reveal recovery phrase"
            Keys.onReturnPressed: pg.revealRequested()
            Keys.onSpacePressed: pg.revealRequested()
            FocusRing { anchors.fill: parent }
            width: implicitWidth; height: implicitHeight
            color: Theme.text
            Row {
                id: hint
                anchors.centerIn: parent
                spacing: 8
                Glyph { name: "eye"; color: Theme.bg; width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter }
                Txt { text: "Tap to reveal"; color: Theme.bg; font.pixelSize: 14; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.revealRequested() }
    }
}
