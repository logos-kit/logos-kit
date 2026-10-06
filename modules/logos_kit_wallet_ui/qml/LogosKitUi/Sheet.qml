import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "Focus.js" as Focus

// From 21st.dev animbits/magnetic-drawer (id 19360, spring stiffness 300 /
// damping 30, drag to dismiss) and wensity/drawer (id 31360, snap + handle):
// https://21st.dev/@animbits/components/magnetic-drawer
// A bottom sheet over a scrim. Place it over the window (anchors.fill:
// parent). open()/close(); drag the handle or the header down to dismiss
// (past 25% of its height, or a quick flick). `dismissable: false` for
// sheets the user must answer (approvals).
Item {
    id: sh
    property bool opened: false
    property bool dismissable: true
    property string title: ""
    property real maxWidth: 520
    default property alias content: body.data
    signal closed()
    visible: opened || panel.y < height
    z: 900

    function open() { opened = true }
    function close() { if (opened) { opened = false; closed() } }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: sh.opened ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.dSheet; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; enabled: sh.opened; onClicked: if (sh.dismissable) sh.close() }
    }

    Item {
        id: panel
        width: Math.min(sh.width, sh.maxWidth)
        x: (sh.width - width) / 2
        height: Math.min(sh.height - 24, card.implicitHeight)
        property real dragY: 0
        readonly property real rest: sh.height - height
        y: (sh.opened ? rest : sh.height) + dragY
        Behavior on y {
            enabled: !dragger.active && !Theme.reducedMotion
            SpringAnimation { spring: 4.2; damping: 0.36; epsilon: 0.3 }
        }
        Shadow { anchors.fill: card; radius: Theme.rSheet; level: 3 }
        Rectangle {
            id: card
            anchors.fill: parent
            anchors.bottomMargin: -Theme.rSheet     // square off the bottom edge
            radius: Theme.rSheet
            color: Theme.sheet
            border.width: Theme.dark ? 1 : 0
            border.color: Theme.line
            implicitHeight: col.implicitHeight + 18 + Theme.rSheet
            ColumnLayout {
                id: col
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 20
                anchors.topMargin: 10
                spacing: 14
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 38; implicitHeight: 5; radius: 2.5
                    color: Theme.soft(Theme.text, 0.18)
                    visible: sh.dismissable
                }
                RowLayout {
                    visible: sh.title !== ""
                    Layout.fillWidth: true
                    Txt { text: sh.title; font.pixelSize: 18; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    IconButton { glyph: "x"; filled: true; size: 32; visible: sh.dismissable; onClicked: sh.close() }
                }
                ColumnLayout { id: body; Layout.fillWidth: true; spacing: 12 }
            }
            DragHandler {
                id: dragger
                enabled: sh.dismissable
                target: null
                xAxis.enabled: false
                yAxis.minimum: 0
                onTranslationChanged: panel.dragY = Math.max(0, translation.y)
                onActiveChanged: if (!active) {
                    var fast = centroid.velocity.y > 900
                    if (panel.dragY > panel.height * 0.25 || fast) { panel.dragY = 0; sh.close() }
                    else panel.dragY = 0
                }
            }
        }
    }

    // Focus trap: Tab stays inside while open; focus returns on close.
    property Item _returnFocus: null
    onOpenedChanged: {
        var w = sh.Window.window
        if (opened) { _returnFocus = w ? w.activeFocusItem : null; Qt.callLater(function () { Focus.first(sh) }) }
        else if (_returnFocus) { _returnFocus.forceActiveFocus(); _returnFocus = null }
    }
    Keys.onTabPressed: function (e) { if (opened) { Focus.cycle(sh, sh.Window.window, true); e.accepted = true } }
    Keys.onBacktabPressed: function (e) { if (opened) { Focus.cycle(sh, sh.Window.window, false); e.accepted = true } }
    Accessible.role: Accessible.Dialog
    Accessible.name: title
    Keys.onEscapePressed: if (dismissable) close()
}
