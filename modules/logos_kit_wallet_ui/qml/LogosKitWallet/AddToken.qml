import QtQuick
import "../LogosKitUi"
import QtQuick.Layouts
import "Fmt.js" as Fmt

// Add a token by its ID (docs/design/ux-tokens-nfts.md §2.4; layout: Family's
// Add Address tray, lp0001-screens.md §3). Paste, look it up, see exactly
// what it is, set decimals if the list doesn't know them, add. A token that
// imitates a verified one (or LGO) needs an explicit tick.
ColumnLayout {
    id: at
    property var store
    property string tokenId: ""
    signal added(string definition)
    signal openToken(string definition)

    width: parent ? parent.width : 400
    spacing: 12

    property var preview: null
    property string problem: ""
    property var problemData: null
    property bool looking: false
    property bool busy: false
    property bool imitationOk: false

    function reset() { tokenId = ""; preview = null; problem = ""; problemData = null; imitationOk = false; decimalsIn.text = "" }
    onTokenIdChanged: { preview = null; problem = ""; problemData = null; imitationOk = false; lookupTimer.restart() }
    property Timer lookupTimer: Timer {
        interval: 350
        onTriggered: {
            var q = at.tokenId.trim()
            if (q === "") return
            if (!/^[1-9A-HJ-NP-Za-km-z]{32,44}$/.test(q)) { at.problem = "That isn't a valid ID."; return }
            at.looking = true
            at.store.call("lookupToken", { id: q }, function (v, e) {
                if (q !== at.tokenId.trim()) return
                at.looking = false
                if (e) { at.problem = Fmt.errorText(e); return }
                if (v.token) {
                    at.preview = v.token
                    decimalsIn.text = v.token.decimals !== undefined && v.token.decimals !== null ? String(v.token.decimals) : ""
                } else { at.problem = v.message; at.problemData = v.problem }
            }, 30000)
        }
    }
    readonly property bool decimalsKnown: !!preview && preview.decimalsSource === "list"
    readonly property bool decimalsValid: decimalsIn.text === "" || (/^[0-9]{1,2}$/.test(decimalsIn.text) && parseInt(decimalsIn.text) <= 36)
    readonly property bool canAdd: !!preview && !preview.alreadyAdded && decimalsValid && (!preview.imitates || imitationOk) && !busy

    function add() {
        busy = true
        var p = { definition: preview.definition }
        if (!decimalsKnown && decimalsIn.text !== "") p.decimals = parseInt(decimalsIn.text)
        store.call("addToken", p, function (v, e) {
            at.busy = false
            if (e) { at.problem = Fmt.errorText(e); return }
            at.store.toast((at.preview.symbol || at.preview.name) + " added", "ok")
            at.store.refreshAll()
            var d = at.preview.definition
            at.reset()
            at.added(d)
        })
    }

    Txt { text: "Add a token"; font.pixelSize: 20; font.weight: Font.Bold }
    Txt { Layout.fillWidth: true; wrapMode: Text.Wrap; tone: "text2"; font.pixelSize: 13; text: "Paste the token's ID (its definition account). Names aren't unique on LEZ; the ID is." }
    Field {
        id: idField
        objectName: "addTokenId"
        Layout.fillWidth: true
        mono: true
        placeholderText: "Token ID"
        text: at.tokenId
        onTextChanged: at.tokenId = text
        invalid: at.problem !== ""
    }

    // Looking it up.
    SkeletonCard { visible: at.looking; Layout.fillWidth: true; implicitHeight: 64; variant: "row" }

    // Why it isn't a token, plainly, with the one useful next step.
    Notice { objectName: "addTokenProblem"; visible: at.problem !== "" && !at.looking; Layout.fillWidth: true; tone: "danger"; text: at.problem }
    Btn {
        visible: !!at.problemData && at.problemData.problem === "holding"
        Layout.fillWidth: true
        text: "Use its token"
        onClicked: { idField.text = at.problemData.definition }
    }

    // The exact match.
    ColumnLayout {
        visible: !!at.preview && !at.looking
        Layout.fillWidth: true
        spacing: 8
        Txt { text: "Exact match"; tone: "text2"; font.pixelSize: 12; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase; font.letterSpacing: 0.8 }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            TokenIcon {
                definition: at.preview ? at.preview.definition : ""
                source: at.preview && at.preview.tier === "verified" ? Qt.resolvedUrl("logos/" + at.preview.definition + ".png") : ""
                label: at.preview ? (at.preview.symbol || at.preview.name) : ""
                warn: !!at.preview && (at.preview.tier === "unknown" || at.preview.tier === "spam")
                size: 44
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    spacing: 6
                    Txt { objectName: "addTokenName"; text: at.preview ? at.preview.name : ""; font.pixelSize: 16; font.weight: Font.DemiBold }
                    Glyph { visible: !!at.preview && at.preview.tier === "verified"; name: "check"; color: Theme.action; width: 14; height: 14; stroke: 2.6 }
                }
                Txt { text: at.preview ? "Token · " + Fmt.short(at.preview.definition) : ""; tone: "text2"; font.pixelSize: 12; mono: true }
            }
        }
        InfoRow { Layout.fillWidth: true; label: "Supply"; value: at.preview ? at.store.tokenAmount(at.preview, at.preview.totalSupply) : "" }
        InfoRow { Layout.fillWidth: true; label: "You hold"; value: at.preview ? at.store.tokenAmount(at.preview, at.preview.yourBalance) : "" }
        InfoRow {
            Layout.fillWidth: true
            label: "Status"
            value: !at.preview ? "" : at.preview.tier === "verified" ? "On the Logos Kit list" : at.preview.tier === "added" ? "Already added"
                 : at.preview.tier === "spam" ? "Looks like spam: " + (at.preview.spamReason || "") : at.preview.tier === "hidden" ? "Hidden by you" : "Not on the list"
            tone: !!at.preview && (at.preview.tier === "spam" || at.preview.tier === "unknown") ? "warn" : "text"
        }
    }

    // Decimals: LEZ stores none.
    ColumnLayout {
        visible: !!at.preview && !at.preview.alreadyAdded && !at.looking
        Layout.fillWidth: true
        spacing: 4
        Txt { text: "Decimals"; tone: "text2"; font.pixelSize: 12; font.weight: Font.DemiBold }
        Field {
            id: decimalsIn
            objectName: "addTokenDecimals"
            Layout.fillWidth: true
            enabled: !at.decimalsKnown
            placeholderText: "0"
            invalid: !at.decimalsValid
        }
        Txt {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            tone: "text3"; font.pixelSize: 12
            text: at.decimalsKnown ? "From the Logos Kit list." : "Not stored on chain. Ask the token's creator, or leave it at 0 (amounts then show in whole units)."
        }
    }

    // Warnings.
    Notice {
        visible: !!at.preview && !at.preview.alreadyAdded && at.preview.tier !== "verified" && !at.preview.imitates
        Layout.fillWidth: true
        tone: "warn"
        text: "Anyone can create a token, including fake copies of real ones."
    }
    Notice {
        objectName: "addTokenImitation"
        visible: !!at.preview && !!at.preview.imitates
        Layout.fillWidth: true
        tone: "warn"
        text: at.preview && at.preview.imitates ? "This looks like " + at.preview.imitates.name + " but isn't."
              + (at.preview.imitates.definition ? " The real " + at.preview.imitates.name + " is " + Fmt.short(at.preview.imitates.definition) + "." : "") : ""
    }
    CheckRow {
        objectName: "addTokenImitationOk"
        visible: !!at.preview && !!at.preview.imitates
        Layout.fillWidth: true
        controlled: true
        checked: at.imitationOk
        text: at.preview && at.preview.imitates ? "I understand this isn't " + at.preview.imitates.name : ""
        onToggled: function (c) { at.imitationOk = c }
    }

    Btn {
        objectName: "addTokenGo"
        visible: !(!!at.preview && at.preview.alreadyAdded)
        Layout.fillWidth: true
        large: true
        tone: "ink"
        text: "Add"
        busy: at.busy
        enabled: at.canAdd
        onClicked: at.add()
    }
    Btn {
        visible: !!at.preview && at.preview.alreadyAdded
        Layout.fillWidth: true
        large: true
        text: "You already have this token · Open"
        onClicked: at.openToken(at.preview.definition)
    }
}
