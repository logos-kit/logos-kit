import QtQuick
import QtQuick.Layouts

// From 21st.dev cnippet-dev/currency-amount-input-group (id 28357), laid out
// the way Family and Rabby do sends: a large centred figure that shrinks to
// fit, the token chip beside it, then "Balance … · Max". Invalid input
// shakes once (300 ms). Digits and one decimal point only; `decimals` caps
// the fraction. The text stays a string (u128 never becomes a JS number).
ColumnLayout {
    id: af
    property alias text: input.text
    property string symbol: "LEZ"
    property Component tokenIcon: null
    property string balance: ""        // formatted, shown as "Balance 12.5 LEZ"
    property int decimals: 0
    property bool invalid: false
    property string errorText: ""
    property bool tokenSelectable: true
    signal maxClicked()
    signal tokenClicked()
    signal submitted()
    spacing: 10

    function shake() { if (!Theme.reducedMotion) shakeAnim.restart() }
    onInvalidChanged: if (invalid) shake()

    Item {
        Layout.fillWidth: true
        implicitHeight: 72
        Row {
            id: fig
            anchors.centerIn: parent
            spacing: 10
            transform: Translate { id: nudge }
            TextInput {
                id: input
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(contentWidth, 24)
                color: af.invalid ? Theme.danger : Theme.text
                font.family: Theme.font
                font.pixelSize: Math.max(26, Math.min(52, 52 * 7 / Math.max(7, text.length)))
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                selectionColor: Theme.soft(Theme.action, 0.35)
                horizontalAlignment: TextInput.AlignHCenter
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: RegularExpressionValidator {
                    regularExpression: af.decimals > 0 ? new RegExp("^[0-9]{0,30}(\\.[0-9]{0," + af.decimals + "})?$") : /^[0-9]{0,30}$/
                }
                Behavior on font.pixelSize { NumberAnimation { duration: Theme.dFast } }
                Behavior on color { ColorAnimation { duration: Theme.dFast } }
                onAccepted: af.submitted()
                Text {
                    visible: input.text === ""
                    anchors.centerIn: parent
                    text: "0"
                    color: Theme.text3
                    font: input.font
                }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: chip.implicitWidth + 20
                implicitHeight: 38
                width: implicitWidth; height: implicitHeight
                radius: 19
                color: chipMouse.containsMouse && af.tokenSelectable ? Theme.soft(Theme.text, 0.1) : Theme.surface2
                Behavior on color { ColorAnimation { duration: Theme.dFast } }
                RowLayout {
                    id: chip
                    anchors.centerIn: parent
                    spacing: 6
                    Loader { sourceComponent: af.tokenIcon; visible: af.tokenIcon !== null }
                    Txt { text: af.symbol; font.pixelSize: 15; font.weight: Font.DemiBold }
                    Glyph { visible: af.tokenSelectable; name: "chevronDown"; color: Theme.text2; width: 14; height: 14 }
                }
                MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; enabled: af.tokenSelectable; cursorShape: Qt.PointingHandCursor; onClicked: af.tokenClicked() }
            }
        }
        SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: nudge; property: "x"; to: -8; duration: 50 }
            NumberAnimation { target: nudge; property: "x"; to: 7; duration: 60 }
            NumberAnimation { target: nudge; property: "x"; to: -4; duration: 60 }
            NumberAnimation { target: nudge; property: "x"; to: 2; duration: 60 }
            NumberAnimation { target: nudge; property: "x"; to: 0; duration: 70 }
        }
    }
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 8
        Txt {
            visible: af.errorText === "" && af.balance !== ""
            text: "Balance " + af.balance + " " + af.symbol
            tone: "text2"; num: true; font.pixelSize: 13
        }
        Txt { visible: af.errorText !== ""; text: af.errorText; tone: "danger"; font.pixelSize: 13 }
        Rectangle {
            visible: af.balance !== ""
            implicitWidth: mx.implicitWidth + 16; implicitHeight: 24; radius: 12
            color: Theme.soft(Theme.action, 0.13)
            Txt { id: mx; anchors.centerIn: parent; text: "Max"; tone: "action"; font.pixelSize: 12; font.weight: Font.DemiBold }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: af.maxClicked() }
        }
    }
}
