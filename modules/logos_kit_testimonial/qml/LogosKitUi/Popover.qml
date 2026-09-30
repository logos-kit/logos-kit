import QtQuick
import QtQuick.Controls.Basic as C

// From 21st.dev originui/dropdown-menu (id 385) and coss.com/menu (id 11561):
// https://21st.dev/@originui/components/dropdown-menu
// A floating panel anchored under its parent: scales from 0.96 at the top
// edge and fades (150 ms, emphasized); closes on outside click or Escape.
C.Popup {
    id: pop
    property real panelWidth: 280
    default property alias content: col.data
    y: parent ? parent.height + 6 : 0
    width: panelWidth
    padding: 6
    modal: false
    focus: true
    closePolicy: C.Popup.CloseOnEscape | C.Popup.CloseOnPressOutsideParent
    background: Item {
        Shadow { anchors.fill: parent; radius: 20; level: 3 }
        Rectangle { anchors.fill: parent; radius: 20; color: Theme.raised; border.width: 1; border.color: Theme.line }
    }
    contentItem: Column { id: col; spacing: 2 }
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dFast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emph }
        NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.dFast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emph }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Theme.reducedMotion ? 0 : 100 }
        NumberAnimation { property: "scale"; to: 0.98; duration: Theme.reducedMotion ? 0 : 100 }
    }
    transformOrigin: C.Popup.Top
}
