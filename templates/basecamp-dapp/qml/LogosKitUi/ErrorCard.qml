import QtQuick
import QtQuick.Layouts

// From 21st.dev olewandowski1/error-empty-state (id 19376, destructive accent
// + retry) and serafimcloud/error-message (id 12393, compact tinted card):
// https://21st.dev/@olewandowski1/components/error-empty-state
// A human sentence first, what to do next second, the technical detail
// behind "Details". Retry is the primary action; a second action is optional.
Rectangle {
    id: ec
    property string title: "Something went wrong"
    property string body: ""
    property string detail: ""        // raw error text, hidden by default
    property string retryText: "Try again"
    property string secondaryText: ""
    property bool busy: false
    property string glyph: "warning"
    signal retry()
    signal secondary()
    property bool showDetail: false
    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 36
    radius: Theme.rCard
    color: Theme.soft(Theme.danger, Theme.dark ? 0.09 : 0.06)
    border.width: 1
    border.color: Theme.soft(Theme.danger, 0.22)
    clip: true
    Behavior on implicitHeight { NumberAnimation { duration: Theme.dHeight; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emph } }

    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 18
        spacing: 10
        RowLayout {
            spacing: 12
            Layout.fillWidth: true
            Rectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 36; implicitHeight: 36; radius: 12
                color: Theme.soft(Theme.danger, 0.16)
                Glyph { anchors.centerIn: parent; name: ec.glyph; color: Theme.danger; width: 18; height: 18 }
            }
            ColumnLayout {
                spacing: 4
                Layout.fillWidth: true
                Txt { text: ec.title; font.pixelSize: 15; font.weight: Font.DemiBold; wrapMode: Text.Wrap; elide: Text.ElideNone; Layout.fillWidth: true }
                Txt { visible: ec.body !== ""; text: ec.body; tone: "text2"; font.pixelSize: 13; wrapMode: Text.Wrap; elide: Text.ElideNone; lineHeight: 1.2; Layout.fillWidth: true }
            }
        }
        Rectangle {
            visible: ec.showDetail && ec.detail !== ""
            Layout.fillWidth: true
            implicitHeight: dt.implicitHeight + 20
            radius: 12
            color: Theme.soft(Theme.text, Theme.dark ? 0.05 : 0.04)
            Txt { id: dt; x: 10; y: 10; width: parent.width - 20; text: ec.detail; mono: true; tone: "text2"; font.pixelSize: 11; wrapMode: Text.WrapAnywhere; elide: Text.ElideNone }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 8
            Btn { text: ec.retryText; tone: "ink"; busy: ec.busy; icon: "refresh"; onClicked: ec.retry() }
            Btn { visible: ec.secondaryText !== ""; text: ec.secondaryText; tone: "ghost"; onClicked: ec.secondary() }
            Item { Layout.fillWidth: true }
            Txt {
                visible: ec.detail !== ""
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: text
                Keys.onReturnPressed: ec.showDetail = !ec.showDetail
                Keys.onSpacePressed: ec.showDetail = !ec.showDetail
                FocusRing { anchors.fill: parent; ringRadius: 6 }
                text: ec.showDetail ? "Hide details" : "Details"
                tone: "text2"; font.pixelSize: 12; font.weight: Font.DemiBold
                MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: ec.showDetail = !ec.showDetail }
            }
        }
    }
}
