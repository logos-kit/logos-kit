import QtQuick
import "../LogosKitUi"
import QtQuick.Layouts
import "Fmt.js" as Fmt

// Receive (ux-spec §4) after Family's receive screen (Refero flow 2673): the
// account name and short address with copy, a large QR, one quiet note, one
// pill. Public address, or a private receive code with its fingerprint.
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

    Txt { text: rv.priv ? "Receive privately" : "Receive"; font.pixelSize: 24; font.weight: Font.Bold }

    // Who you are paying: name, then the short address (copy).
    ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 8
        spacing: 2
        Txt { Layout.alignment: Qt.AlignHCenter; text: rv.acct ? Fmt.accountName(rv.acct) : ""; font.pixelSize: 20; font.weight: Font.Bold }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4
            Txt { text: rv.payload !== "" ? Fmt.short(rv.payload) : ""; mono: true; tone: "text2"; font.pixelSize: 14 }
            IconButton { objectName: "copyReceive"; glyph: "copy"; size: 30; color: Theme.text2; label: "Copy"; onClicked: rv.store.copy(rv.payload) }
        }
    }
    Item {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 4
        implicitWidth: 280; implicitHeight: 280
        Rectangle { anchors.fill: parent; radius: 32; color: "#ffffff"; visible: rv.payload !== "" }
        QrCard { anchors.centerIn: parent; visible: rv.payload !== ""; text: rv.payload; low: rv.priv; size: 264 }
        Skeleton { anchors.fill: parent; radius: 32; visible: rv.payload === "" && rv.problem === "" }
    }
    RowLayout {
        visible: rv.priv && !!rv.info
        Layout.alignment: Qt.AlignHCenter
        spacing: 6
        Glyph { name: "lock"; color: Theme.text2; implicitWidth: 14; implicitHeight: 14 }
        Txt { objectName: "fingerprint"; text: rv.info && rv.info.fingerprint ? "Code ends " + rv.info.fingerprint : ""; tone: "text2"; font.weight: Font.DemiBold }
    }
    Txt {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        tone: "text3"; font.pixelSize: 13
        text: rv.priv ? "Senders need this code to pay you privately. It doesn't reveal your balance."
                      : "Anyone can send LGO to this address. Payments to it are public."
    }
    Btn { visible: rv.payload !== ""; Layout.fillWidth: true; Layout.topMargin: 6; large: true; tone: "ink"; icon: "copy"; text: rv.priv ? "Copy receive code" : "Copy address"; onClicked: rv.store.copy(rv.payload) }
    Btn {
        objectName: "receiveExplorer"
        visible: !rv.priv && rv.payload !== "" && !!rv.store.state.explorer
        Layout.fillWidth: true
        icon: "external"
        text: "View account in explorer"
        onClicked: rv.store.call("openExplorer", { chain: rv.store.zone.chain, account: rv.payload }, function (v, e) { if (e) rv.store.toast(Fmt.errorText(e), "danger") })
    }
    ErrorCard { visible: rv.problem !== ""; title: "Couldn't load your receive details"; body: rv.problem; onRetry: rv.load() }
}
