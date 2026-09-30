import QtQuick
import QtQuick.Controls.Basic as C

// From 21st.dev wensity/tooltip (id 31328):
// https://21st.dev/@wensity/components/tooltip
// Put inside the element it explains: shows after 400 ms of hover or on
// focus; fades and rises 4 px (150 ms). Plain text only.
C.ToolTip {
    id: tip
    property Item target: parent
    visible: target && (hov.hovered || target.activeFocus) && text !== ""
    delay: 400
    timeout: -1
    padding: 0
    contentItem: Txt {
        text: tip.text
        color: Theme.dark ? "#0e0e12" : "#ffffff"
        font.pixelSize: 12
        font.weight: Font.Medium
        leftPadding: 10; rightPadding: 10; topPadding: 6; bottomPadding: 6
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
    background: Rectangle { radius: 10; color: Theme.dark ? "#f4f4f6" : "#0e0e12" }
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dFast }
        NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.dFast; easing.type: Easing.OutCubic }
    }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.reducedMotion ? 0 : 100 } }
    HoverHandler { id: hov; parent: tip.target }
}
