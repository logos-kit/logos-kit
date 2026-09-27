import QtQuick
import QtQuick.Layouts
import "Fmt.js" as Fmt

// Receive (ux-spec §4): public address, or a private receive code with its
// fingerprint. Both as a QR code drawn with Rectangles.
ColumnLayout {
    id: rv
    property var store
    property var info: null
    property string problem: ""
    width: parent ? parent.width : 400
    spacing: 12

    readonly property var acct: store.current
    readonly property bool priv: !!acct && acct.kind === "private"
    readonly property string payload: info ? (info.kind === "private" ? info.code : info.account) : ""

    function load() {
        info = null
        problem = ""
        if (!acct) return
        store.call("receive", { account: acct.accountId }, function (v, e) {
            if (e) { rv.problem = Fmt.errorText(e); return }
            rv.info = v
        })
    }
    onAcctChanged: if (visible) load()
    onVisibleChanged: if (visible) load()

    Txt { text: rv.priv ? "Receive privately" : "Receive"; font.pixelSize: 20; font.weight: Font.DemiBold }
    Txt {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        tone: "text2"; font.pixelSize: 13
        text: rv.priv ? "Senders need this code to pay you privately. It doesn't reveal your balance."
                      : "Anyone can send to this address. Payments to it are visible on-chain."
    }
    Item {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 240; implicitHeight: 240
        QrCode { anchors.centerIn: parent; visible: rv.payload !== ""; text: rv.payload; low: rv.priv; size: 240 }
        Spinner { anchors.centerIn: parent; visible: rv.payload === "" && rv.problem === ""; size: 28 }
    }
    RowLayout {
        visible: rv.priv && !!rv.info
        Layout.alignment: Qt.AlignHCenter
        spacing: 6
        Glyph { name: "shield"; color: Theme.privText; implicitWidth: 14; implicitHeight: 14 }
        Txt { objectName: "fingerprint"; text: rv.info && rv.info.fingerprint ? "Code ends " + rv.info.fingerprint : ""; tone: "priv"; font.weight: Font.DemiBold }
    }
    Rectangle {
        visible: rv.payload !== ""
        Layout.fillWidth: true
        implicitHeight: 48
        radius: Theme.rRow
        color: Theme.surface2
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 6
            Txt { Layout.fillWidth: true; text: rv.priv ? rv.payload.substring(0, 36) + "…" : rv.payload; mono: true; font.pixelSize: 12; tone: "text2"; elide: Text.ElideMiddle }
            IconBtn { objectName: "copyReceive"; icon: "copy"; label: "Copy"; onClicked: rv.store.copy(rv.payload) }
        }
    }
    Btn { visible: rv.payload !== ""; Layout.fillWidth: true; large: true; tone: "ink"; icon: "copy"; text: rv.priv ? "Copy receive code" : "Copy address"; onClicked: rv.store.copy(rv.payload) }
    Txt { visible: rv.problem !== ""; Layout.fillWidth: true; text: rv.problem; tone: "danger"; wrapMode: Text.Wrap; font.pixelSize: 13 }
}
