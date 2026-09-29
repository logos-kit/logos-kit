import QtQuick
import QtQuick.Layouts
import "../LogosKitUi"

// LogosKitUi v2 gallery: every component in its states, light and dark.
// `section` picks one page (the screenshot script walks them all);
// `dark` flips the theme. Run: python3 sdk/qml/gallery/shoot.py
Rectangle {
    id: g
    property string section: "foundations"
    property bool dark: true
    onDarkChanged: Theme.dark = dark
    Component.onCompleted: Theme.dark = dark
    width: 1200
    height: 820
    color: Theme.bg

    readonly property var sections: ["foundations", "loading", "pipeline", "feedback", "wallet", "onboarding", "overlays"]

    // Header
    RowLayout {
        id: head
        x: 36; y: 26
        width: g.width - 72
        spacing: 12
        LogosMark { size: 22; white: Theme.dark }
        Txt { text: "LogosKitUi"; font.pixelSize: 18; font.weight: Font.Bold }
        Txt { text: "v2 · " + g.section; tone: "text3"; font.pixelSize: 14 }
        Item { Layout.fillWidth: true }
        SegmentedControl {
            options: [{ label: "Dark", glyph: "moon" }, { label: "Light", glyph: "sun" }]
            currentIndex: g.dark ? 0 : 1
            onActivated: function (i) { g.dark = i === 0 }
        }
    }

    Loader {
        x: 36; y: 84
        width: g.width - 72
        height: g.height - 110
        sourceComponent: g.section === "foundations" ? foundations : g.section === "loading" ? loading
            : g.section === "pipeline" ? pipeline : g.section === "feedback" ? feedback
            : g.section === "wallet" ? wallet : g.section === "onboarding" ? onboarding : overlays
    }

    component Label: Txt { tone: "text3"; font.pixelSize: 11; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase; font.letterSpacing: 0.8 }

    // ---------------------------------------------------------------- foundations
    Component {
        id: foundations
        GridLayout {
            columns: 2
            columnSpacing: 28
            rowSpacing: 22
            Card {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                ColumnLayout {
                    width: parent.width
                    spacing: 14
                    Label { text: "Buttons" }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 10
                        Btn { text: "Approve"; tone: "ink"; large: true }
                        Btn { text: "Connect"; tone: "action"; large: true }
                        Btn { text: "Prove and send"; tone: "private"; icon: "lock"; large: true }
                        Btn { text: "Cancel" }
                        Btn { text: "Details"; tone: "ghost" }
                        Btn { text: "Remove"; tone: "danger" }
                        Btn { text: "Sending"; tone: "ink"; busy: true }
                        Btn { text: "Disabled"; tone: "ink"; enabled: false }
                    }
                    Label { text: "Icon buttons" }
                    Row { spacing: 8
                        IconButton { glyph: "x"; filled: true }
                        IconButton { glyph: "copy" }
                        IconButton { glyph: "sliders"; filled: true }
                        IconButton { glyph: "refresh" } }
                }
            }
            Card {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                ColumnLayout {
                    width: parent.width
                    spacing: 14
                    Label { text: "Badges and tags" }
                    Flow { Layout.fillWidth: true; spacing: 8
                        Badge { text: "Connected"; tone: "ok"; live: true }
                        Badge { text: "Syncing"; tone: "action"; live: true }
                        Badge { text: "Offline"; tone: "danger" }
                        Badge { text: "Private"; tone: "private" }
                        Badge { text: "LEZ preview"; tone: "neutral" }
                        Tag { text: "Included"; tone: "ok"; icon: "check" }
                        Tag { text: "Not confirmed"; tone: "unconfirmed" }
                        Tag { text: "Pending" } }
                    Label { text: "Segmented and toggles" }
                    RowLayout { spacing: 16
                        SegmentedControl { options: ["Public", "Private"]; currentIndex: 1 }
                        SegmentedControl { options: ["1D", "1W", "1M", "All"]; currentIndex: 2 }
                        Toggle { checked: true }
                        Toggle { checked: false } }
                    Label { text: "Address" }
                    RowLayout { spacing: 10
                        AddressChip { address: "8YtpjPUypDNoRTFEqyvFjZ4wNkgd5GjMv1Gaf6P7JG2x" }
                        AddressChip { address: "3ksne6QbqZHhaY3QfWGkjbgDVHWm64y9FNCtEsBDDK9Y"; label: "Savings"; done: true } }
                }
            }
            Card {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                Layout.columnSpan: 2
                ColumnLayout {
                    width: parent.width
                    spacing: 12
                    Label { text: "Inputs" }
                    RowLayout {
                        spacing: 16
                        Layout.fillWidth: true
                        Field { placeholderText: "Recipient address"; Layout.fillWidth: true }
                        Field { text: "not-an-address"; invalid: true; Layout.fillWidth: true }
                        Field { placeholderText: "Password"; echoMode: TextInput.Password; text: "hunter22"; Layout.fillWidth: true }
                    }
                    Notice { text: "The recipient is a private account: the transfer is proved on this device and takes a few minutes."; tone: "private" }
                    Notice { text: "Unsigned app: Basecamp can't confirm who published it."; tone: "warn" }
                }
            }
        }
    }

    // ---------------------------------------------------------------- loading
    Component {
        id: loading
        GridLayout {
            columns: 3
            columnSpacing: 24
            rowSpacing: 22
            Card { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop
                ColumnLayout { width: parent.width; spacing: 14
                    Label { text: "Balance skeleton" }
                    SkeletonCard { variant: "balance"; Layout.fillWidth: true } } }
            Card { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop
                ColumnLayout { width: parent.width; spacing: 14
                    Label { text: "Rows skeleton" }
                    SkeletonCard { variant: "row"; count: 3; Layout.fillWidth: true } } }
            Card { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop
                ColumnLayout { width: parent.width; spacing: 14
                    Label { text: "Card skeleton" }
                    SkeletonCard { variant: "card"; Layout.fillWidth: true } } }
            Card { Layout.fillWidth: true
                ColumnLayout { width: parent.width; spacing: 16
                    Label { text: "Live labels" }
                    ShimmerText { text: "Proving on this device…"; pixelSize: 17; weight: Font.DemiBold }
                    ShimmerText { text: "Checking the chain"; pixelSize: 14 }
                    RowLayout { spacing: 10; Dots {} Txt { text: "Waiting for the wallet"; tone: "text2" } }
                    RowLayout { spacing: 10; Spinner { size: 18 } Txt { text: "Syncing block 1,204"; tone: "text2"; num: true } } } }
            Card { Layout.fillWidth: true
                ColumnLayout { width: parent.width; spacing: 16
                    Label { text: "Progress rings" }
                    RowLayout { spacing: 18
                        ProgressRing { value: 0.25; size: 64; Txt { text: "25%"; num: true; font.pixelSize: 13; font.weight: Font.DemiBold } }
                        ProgressRing { value: 0.68; size: 64; color: Theme.priv; Txt { text: "4:12"; num: true; font.pixelSize: 13; font.weight: Font.DemiBold } }
                        ProgressRing { value: 1; size: 64; color: Theme.ok; Glyph { name: "check"; color: Theme.ok; width: 22; height: 22; stroke: 2.6 } }
                        ProgressRing { indeterminate: true; size: 64 } } } }
            Card { Layout.fillWidth: true
                ColumnLayout { width: parent.width; spacing: 16
                    Label { text: "Progress bars" }
                    ProgressBar { value: 0.3; Layout.fillWidth: true }
                    ProgressBar { value: 0.72; fillColor: Theme.priv; Layout.fillWidth: true }
                    ProgressBar { indeterminate: true; Layout.fillWidth: true }
                    ProgressBar { value: 1; fillColor: Theme.ok; Layout.fillWidth: true } } }
        }
    }

    // ---------------------------------------------------------------- pipeline
    Component {
        id: pipeline
        RowLayout {
            spacing: 24
            Card { Layout.fillWidth: true; Layout.alignment: Qt.AlignTop
                ColumnLayout { width: parent.width; spacing: 16
                    RowLayout { Layout.fillWidth: true
                        Txt { text: "Shield 5,000 LEZ"; font.pixelSize: 17; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        Badge { text: "Proving"; tone: "private"; live: true } }
                    Pipeline {
                        objectName: "livePipeline"
                        Layout.fillWidth: true
                        accent: Theme.priv
                        stages: [
                            { label: "Approved", detail: "You approved it in Logos Kit", status: "done", elapsed: "0:00" },
                            { label: "Proving on this device", detail: "Keeps the amount and recipient private. About 5 minutes.", status: "active", progress: 0.46, elapsed: "2:18" },
                            { label: "Signing", status: "pending" },
                            { label: "Submitted to LEZ preview", status: "pending" },
                            { label: "Included in a block", status: "pending" }
                        ]
                    } } }
            Card { Layout.fillWidth: true; Layout.alignment: Qt.AlignTop
                ColumnLayout { width: parent.width; spacing: 16
                    RowLayout { Layout.fillWidth: true
                        Txt { text: "Send 1,000 LEZ"; font.pixelSize: 17; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        Badge { text: "Included"; tone: "ok" } }
                    Pipeline {
                        Layout.fillWidth: true
                        stages: [
                            { label: "Approved", status: "done", elapsed: "0:00" },
                            { label: "Signed", status: "done", elapsed: "0:01" },
                            { label: "Submitted", status: "done", elapsed: "0:01" },
                            { label: "Included in block 61", detail: "Balance changed by exactly the amount.", status: "done", elapsed: "0:12" }
                        ]
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line }
                    RowLayout { Layout.fillWidth: true
                        Txt { text: "Post testimonial"; font.pixelSize: 17; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        Badge { text: "Failed"; tone: "danger" } }
                    Pipeline {
                        Layout.fillWidth: true
                        compact: true
                        stages: [
                            { label: "Approved", status: "done" },
                            { label: "Signed", status: "done" },
                            { label: "Rejected by the program", detail: "This account already posted a testimonial.", status: "failed" },
                            { label: "Included", status: "skipped" }
                        ]
                    }
                    RowLayout { spacing: 18
                        Stepper { steps: ["Create", "Back up", "Confirm"]; current: 1; Layout.fillWidth: true } } } }
        }
    }

    // ---------------------------------------------------------------- feedback
    Component {
        id: feedback
        GridLayout {
            columns: 3
            columnSpacing: 24
            rowSpacing: 22
            Card { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop
                ColumnLayout { width: parent.width
                    EmptyState { Layout.fillWidth: true; glyph: "inbox"; title: "No activity yet"; body: "Your sends, receives and approvals will show up here."; actionText: "Get test LEZ"; actionTone: "ink" } } }
            Card { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop
                ColumnLayout { width: parent.width
                    EmptyState { Layout.fillWidth: true; glyph: "search"; title: "No tokens match"; body: "Try the token's name or its definition address." } } }
            Card { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop
                ColumnLayout { width: parent.width; spacing: 10
                    SuccessCheck { objectName: "check"; Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 8 }
                    Txt { Layout.alignment: Qt.AlignHCenter; text: "Sent"; font.pixelSize: 20; font.weight: Font.Bold }
                    Txt { Layout.alignment: Qt.AlignHCenter; text: "1,000 LEZ to Savings · block 61"; tone: "text2"; num: true } } }
            ErrorCard {
                Layout.alignment: Qt.AlignTop
                Layout.columnSpan: 2
                title: "Can't reach the network"
                body: "LEZ preview didn't answer. Your funds are safe; nothing was sent. We'll keep retrying every 30 seconds."
                detail: "error sending request for url (https://lez.84.46.247.92.sslip.io/): connection timed out after 20s"
                secondaryText: "Switch network"
                showDetail: true
            }
            ErrorCard {
                Layout.alignment: Qt.AlignTop
                title: "Proof failed"
                body: "The device ran out of memory while proving. Close other apps and try again."
                retryText: "Prove again"
            }
        }
    }

    // ---------------------------------------------------------------- wallet
    Component {
        id: wallet
        RowLayout {
            spacing: 24
            Card { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop
                ColumnLayout { width: parent.width; spacing: 14
                    RowLayout { Layout.fillWidth: true
                        AccountSwitcher {
                            accounts: [{ id: "8YtpjPUypDNoRTFEqyvFjZ4wNkgd5GjMv1Gaf6P7JG2x", name: "Main", kind: "public", balance: "12,480" },
                                       { id: "4a94KmHEf3CGvVmXybiaHs9sut5GQdZ41sXEKMwyeX9R", name: "Vault", kind: "private", balance: "5,000" }]
                            currentId: "8YtpjPUypDNoRTFEqyvFjZ4wNkgd5GjMv1Gaf6P7JG2x"
                        }
                        Item { Layout.fillWidth: true }
                        Badge { text: "LEZ preview"; tone: "ok"; live: true } }
                    BalanceCard {
                        objectName: "balance"
                        Layout.fillWidth: true
                        value: "12,480"
                        privateLine: "5,000 LEZ private"
                        ActionTile { glyph: "arrowUp"; text: "Send"; tone: "ink" }
                        ActionTile { glyph: "arrowDown"; text: "Receive" }
                        ActionTile { glyph: "shield"; text: "Shield"; tone: "private" }
                        ActionTile { glyph: "droplet"; text: "Faucet" }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line }
                    TokenRow { name: "Logos"; symbol: "LEZ"; amount: "12,480"; amountSub: "Public" }
                    TokenRow { name: "Logos"; symbol: "LEZ"; amount: "5,000"; sub: "Private · 2 notes"; isPrivate: true }
                    TokenRow { name: "Kit Token"; symbol: "KIT"; definition: "He3w5dZRHnVUYMgn1xqZmSmij3wA43kHrLcFa5MJ8KEH"; amount: "999,740"; amountSub: "KIT"; chevron: true }
                    TokenRow { loading: true } } }
            ColumnLayout { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop; spacing: 20
                Card { Layout.fillWidth: true
                    ColumnLayout { width: parent.width; spacing: 6
                        Label { text: "Activity" }
                        ActivityRow { kind: "shield"; title: "Shielded"; sub: "Proving · 2:18"; amount: "5,000"; status: "pending"; isPrivate: true }
                        ActivityRow { kind: "send"; title: "Sent to Savings"; sub: "2 min ago"; amount: "1,000" }
                        ActivityRow { kind: "faucet"; title: "Test LEZ from the faucet"; sub: "Today, 20:46"; amount: "1" }
                        ActivityRow { kind: "testimonial"; title: "Testimonial posted"; sub: "Block 221" }
                        ActivityRow { kind: "send"; title: "Sent to 3kS…9Y"; sub: "Yesterday"; amount: "250"; symbol: "KIT"; status: "unconfirmed" }
                        ActivityRow { kind: "send"; title: "Send"; sub: "Yesterday"; amount: "40"; status: "failed" } } }
                Card { Layout.fillWidth: true
                    ColumnLayout { width: parent.width; spacing: 10
                        Label { text: "Amount" }
                        AmountField { Layout.fillWidth: true; text: "1250"; balance: "12,480"; tokenIcon: Component { TokenIcon { size: 24 } } }
                        AmountField { Layout.fillWidth: true; text: "99999"; symbol: "KIT"; invalid: true; errorText: "More than your 999,740 KIT"
                                      tokenIcon: Component { TokenIcon { size: 24; definition: "He3w5dZRHnVUYMgn1xqZmSmij3wA43kHrLcFa5MJ8KEH" } } } } } }
        }
    }

    // ---------------------------------------------------------------- onboarding
    Component {
        id: onboarding
        RowLayout {
            spacing: 24
            Card { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop
                ColumnLayout { width: parent.width; spacing: 16
                    Stepper { steps: ["Password", "Back up", "Confirm"]; current: 1; Layout.fillWidth: true }
                    Txt { text: "Write down your recovery phrase"; font.pixelSize: 20; font.weight: Font.Bold }
                    Txt { text: "It's the only way back into this wallet. Anyone with it can move your funds."; tone: "text2"; wrapMode: Text.Wrap; elide: Text.ElideNone; Layout.fillWidth: true }
                    PhraseGrid { Layout.fillWidth: true; revealed: true
                        words: ["orbit", "velvet", "canyon", "marble", "yield", "lantern", "cobalt", "ripple", "falcon", "meadow", "quartz", "harbor"] }
                    RowLayout { Layout.fillWidth: true; spacing: 10
                        AddressChip { address: "orbit velvet canyon marble yield lantern cobalt ripple falcon meadow quartz harbor"; identicon: false; head: 12; tail: 6 }
                        Item { Layout.fillWidth: true }
                        Btn { text: "I've saved it"; tone: "ink"; large: true } } } }
            ColumnLayout { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop; spacing: 20
                Card { Layout.fillWidth: true
                    ColumnLayout { width: parent.width; spacing: 12
                        Label { text: "Hidden until tapped" }
                        PhraseGrid { Layout.fillWidth: true; revealed: false
                            words: ["orbit", "velvet", "canyon", "marble", "yield", "lantern", "cobalt", "ripple", "falcon", "meadow", "quartz", "harbor"] } } }
                Card { Layout.fillWidth: true
                    ColumnLayout { width: parent.width; spacing: 12
                        Label { text: "Confirm: pick words 3, 7 and 11" }
                        PhraseGrid { Layout.fillWidth: true; revealed: true; blanks: [2, 6, 10]; filled: ({ 2: "canyon" })
                            words: ["orbit", "velvet", "canyon", "marble", "yield", "lantern", "cobalt", "ripple", "falcon", "meadow", "quartz", "harbor"] } } }
                Card { Layout.fillWidth: true
                    ColumnLayout { width: parent.width; spacing: 12
                        Label { text: "Password" }
                        Field { text: "Tray-wallet-7"; echoMode: TextInput.Password; Layout.fillWidth: true }
                        PasswordStrength { password: "Tray-wallet-7"; Layout.fillWidth: true } } }
            }
        }
    }

    // ---------------------------------------------------------------- overlays
    Component {
        id: overlays
        Item {
            id: ov
            RowLayout {
                anchors.fill: parent
                spacing: 24
                Card { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop
                    ColumnLayout { width: parent.width; spacing: 14
                        Label { text: "QR" }
                        QrCard { Layout.alignment: Qt.AlignHCenter; size: 230; text: "lez:preview:8YtpjPUypDNoRTFEqyvFjZ4wNkgd5GjMv1Gaf6P7JG2x"; caption: "Public account · Main" }
                        AddressChip { Layout.alignment: Qt.AlignHCenter; address: "8YtpjPUypDNoRTFEqyvFjZ4wNkgd5GjMv1Gaf6P7JG2x" } } }
                Item { Layout.fillWidth: true; Layout.preferredWidth: 1.4; Layout.fillHeight: true
                    Rectangle { id: stage; anchors.fill: parent; radius: Theme.rCard; color: Theme.surface2; clip: true
                        Txt { x: 20; y: 18; text: "Sheet, dialog and toasts render over this area"; tone: "text3"; font.pixelSize: 12 }
                        Sheet {
                            objectName: "sheet"
                            anchors.fill: parent
                            title: "Approve transaction"
                            opened: true
                            ColumnLayout { Layout.fillWidth: true; spacing: 12
                                RowLayout { spacing: 12
                                    Rectangle { implicitWidth: 44; implicitHeight: 44; radius: 14; color: "#1f7bff"
                                        LogosMark { anchors.centerIn: parent; size: 22; white: true } }
                                    ColumnLayout { spacing: 1
                                        Txt { text: "Logos Kit Testimonials"; font.pixelSize: 15; font.weight: Font.DemiBold }
                                        Txt { text: "logos_kit_testimonial"; mono: true; tone: "text3"; font.pixelSize: 12 } } }
                                Rectangle { Layout.fillWidth: true; implicitHeight: 68; radius: Theme.rRow; color: Theme.surface2
                                    RowLayout { anchors.fill: parent; anchors.margins: 14; spacing: 12
                                        TokenIcon { size: 38 }
                                        ColumnLayout { spacing: 0; Layout.fillWidth: true
                                            Txt { text: "− 1,000 LEZ"; num: true; font.pixelSize: 20; font.weight: Font.Bold }
                                            Txt { text: "From Main to Savings"; tone: "text2"; font.pixelSize: 12 } } } }
                                InfoRow { label: "Network fee"; value: "≤ 134,400,000 LEZ" }
                                InfoRow { label: "Program"; value: "native · verified" }
                                RowLayout { Layout.fillWidth: true; spacing: 10
                                    Btn { text: "Reject"; Layout.fillWidth: true; large: true }
                                    Btn { text: "Approve"; tone: "ink"; Layout.fillWidth: true; large: true } } } }
                        ToastHost {
                            objectName: "toasts"
                            anchors.fill: parent
                            Component.onCompleted: {
                                show({ title: "Copied", tone: "ok" })
                                show({ title: "Proving on this device", body: "About 5 minutes. You can keep using the wallet.", tone: "pending" })
                                show({ title: "Sent 1,000 LEZ", body: "Included in block 61", tone: "ok", action: "View" })
                            }
                        }
                    } }
            }
            Dialog {
                objectName: "dialog"
                anchors.fill: parent
                tone: "danger"
                title: "Remove this network?"
                message: "Accounts stay in your wallet. You can add the network again any time."
                confirmText: "Remove"
            }
        }
    }
}
