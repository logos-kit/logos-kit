import QtQuick
import "../LogosKitUi"
import QtQuick.Layouts

// What a private account is, in one sheet, and the two steps test LGO takes
// to reach one (docs/design/ux-tokens-nfts.md §0 "Private"). Opened from the
// home screen's "How private accounts work" link, and from "Test LGO" on a
// private account, so the minutes of proving are known before they start.
ColumnLayout {
    id: pi
    property var store
    // Opened from "Test LGO" on a private account.
    property bool funding: false
    signal proceed()
    signal close()

    width: parent ? parent.width : 400
    spacing: 12

    readonly property string proofTime: store && store.state.proofTime ? store.state.proofTime : "a few minutes"

    Txt {
        text: pi.funding ? "Test LGO for a private account" : "Private accounts"
        font.pixelSize: 22
        font.weight: Font.Bold
    }
    Txt {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        tone: "text2"
        font.pixelSize: 14
        text: pi.funding
              ? "The faucet only pays public accounts, so this takes two steps."
              : "Only you can see a private account's balance and history. The network checks a proof instead of reading your account."
    }

    Repeater {
        model: pi.funding
            ? [["1", "The faucet pays your public account", "Public, and done in a few seconds."],
               ["2", "You approve moving it in privately", "One approval in this wallet."],
               ["3", "This computer builds a proof", "It takes " + pi.proofTime + " and up to about 4 GB of memory. You can keep using the wallet while it runs."]]
            : [["eye", "Balance and history", "Visible only to you, on this device."],
               ["arrowUp", "Sending from it", "This computer builds a proof first: " + pi.proofTime + "."],
               ["arrowDown", "Receiving", "Share your private receive code. Senders don't learn your balance."],
               ["shield", "Fees", "None for private transactions on the testnet."]]
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 12
            Rectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 32; implicitHeight: 32; radius: 16
                color: Theme.surface2
                Txt {
                    visible: modelData[0].length === 1
                    anchors.centerIn: parent
                    text: modelData[0]
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Glyph {
                    visible: modelData[0].length > 1
                    anchors.centerIn: parent
                    name: modelData[0]
                    width: 16; height: 16
                    color: Theme.text
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Txt { Layout.fillWidth: true; text: modelData[1]; font.pixelSize: 15; font.weight: Font.DemiBold; wrapMode: Text.Wrap }
                Txt { Layout.fillWidth: true; text: modelData[2]; tone: "text2"; font.pixelSize: 13; wrapMode: Text.Wrap }
            }
        }
    }

    Btn {
        objectName: pi.funding ? "privateFundsGo" : "privateInfoDone"
        Layout.fillWidth: true
        Layout.topMargin: 10
        large: true
        tone: "ink"
        icon: pi.funding ? "droplet" : ""
        text: pi.funding ? "Get test LGO" : "Got it"
        onClicked: pi.funding ? pi.proceed() : pi.close()
    }
    Btn {
        visible: pi.funding
        Layout.fillWidth: true
        text: "Cancel"
        onClicked: pi.close()
    }
}
