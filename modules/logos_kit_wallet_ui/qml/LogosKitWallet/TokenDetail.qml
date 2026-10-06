import QtQuick
import "../LogosKitUi"
import QtQuick.Layouts
import "Fmt.js" as Fmt
import "../LogosKitUi/Units.js" as Units

// Token details (docs/design/ux-tokens-nfts.md §2.5; layout: lp0001-screens.md
// §5, Glow's token sheet). Big balance, Send and Receive, this token's
// activity, then the facts: Token ID, where it's held, decimals and where
// they came from, supply, metadata (only for Verified and Added tokens), and
// a trust panel in plain words.
ColumnLayout {
    id: td
    property var store
    property string definition: ""
    signal send(string definition)
    signal receive()
    signal close()

    width: parent ? parent.width : 400
    spacing: 12

    // The current account's view of the token (balance, tier, decimals).
    readonly property var row: {
        var rows = store.tokenRows(store.current)
        for (var i = 0; i < rows.length; i++) if (rows[i].definition === definition) return rows[i]
        return null
    }
    // The engine's lookup: supply, metadata, list, lookalike.
    property var preview: null
    property string problem: ""
    property bool loading: false
    function load() {
        preview = null; problem = ""
        if (definition === "") return
        loading = true
        store.call("lookupToken", { id: definition }, function (v, e) {
            td.loading = false
            if (e) { td.problem = Fmt.errorText(e); return }
            if (v.token) td.preview = v.token
            else td.problem = v.message || "Couldn't read this token."
        }, 30000)
    }
    onDefinitionChanged: if (visible) load()
    onVisibleChanged: if (visible) load()

    readonly property var t: row || (preview ? { definition: definition, name: preview.name, symbol: preview.symbol || "",
                                                  decimals: preview.decimals, tier: preview.tier, pinned: preview.pinned,
                                                  amount: "0", holders: [] } : null)
    readonly property string tier: t ? t.tier : ""
    readonly property var activity: store.activity.filter(function (s) { return s.token === td.definition })

    function act(method, params, toastText) {
        store.call(method, params, function (v, e) {
            if (e) { store.toast(Fmt.errorText(e), "danger"); return }
            if (toastText) store.toast(toastText, "ok")
            store.refreshAll()
            td.load()
        })
    }

    // -- header -------------------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        TokenIcon {
            definition: td.definition
            source: td.store.tokenLogo(td.t)
            label: td.store.tokenLabel(td.t)
            warn: td.tier === "unknown" || td.tier === "spam"
            size: 48
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            RowLayout {
                spacing: 6
                Txt { objectName: "tokenName"; text: td.t ? (td.t.name || Fmt.short(td.definition)) : ""; font.pixelSize: 20; font.weight: Font.Bold; Layout.maximumWidth: td.width - 160 }
                Glyph { visible: td.tier === "verified"; name: "check"; color: Theme.action; width: 16; height: 16; stroke: 2.6 }
            }
            Txt {
                text: td.tier === "verified" ? "Verified" : td.tier === "added" ? "Added by you"
                    : td.tier === "hidden" ? "Hidden" : td.tier === "spam" ? "Hidden as spam" : "Unverified"
                tone: td.tier === "unknown" || td.tier === "spam" ? "warn" : "text2"
                font.pixelSize: 13
            }
        }
    }
    Skeleton { visible: td.loading && !td.t; Layout.fillWidth: true; implicitHeight: 48; radius: Theme.rRow }

    // -- balance + actions ------------------------------------------------------------
    ColumnLayout {
        visible: !!td.t
        Layout.fillWidth: true
        spacing: 2
        Txt { text: "Your balance"; tone: "text2"; font.pixelSize: 13 }
        RowLayout {
            spacing: 8
            Txt { objectName: "tokenBalance"; text: td.t ? td.store.tokenAmount(td.t) : ""; font.pixelSize: 36; font.weight: Font.Bold; num: true }
            Txt { text: td.t ? (td.t.symbol || "") : ""; tone: "text2"; font.pixelSize: 20 }
        }
        Tag { visible: !!td.t && (td.t.decimals === undefined || td.t.decimals === null); text: "decimals unknown"; tone: "unconfirmed" }
    }
    RowLayout {
        visible: !!td.t
        Layout.fillWidth: true
        spacing: 8
        ActionTile { objectName: "tokenSend"; Layout.fillWidth: true; glyph: "arrowUp"; text: "Send"; tone: "ink"; enabled: !!td.row && td.row.amount !== "0"; opacity: enabled ? 1 : 0.4; onClicked: td.send(td.definition) }
        ActionTile { objectName: "tokenReceive"; Layout.fillWidth: true; glyph: "arrowDown"; text: "Receive"; onClicked: td.receive() }
    }

    // -- trust ------------------------------------------------------------------------------
    Notice {
        objectName: "tokenTrust"
        visible: !!td.t
        Layout.fillWidth: true
        tone: td.tier === "unknown" || td.tier === "spam" ? "warn" : "info"
        text: td.tier === "verified" ? "On the " + (td.preview && td.preview.listedIn ? td.preview.listedIn : "Logos Kit token list") + ". This isn't an endorsement."
            : td.tier === "added" ? "You added this token. It isn't on the Logos Kit list."
            : td.tier === "spam" ? (td.row && td.row.spamReason ? td.row.spamReason + ". " : "") + "Logos Kit hid this automatically."
            : td.tier === "hidden" ? "You hid this token. Nothing was deleted."
            : "Unverified. Anyone can create a token with any name. Don't follow links in its name or metadata."
    }
    Notice {
        visible: !!td.preview && !!td.preview.imitates
        Layout.fillWidth: true
        tone: "warn"
        text: td.preview && td.preview.imitates ? "This looks like " + td.preview.imitates.name + " but isn't."
              + (td.preview.imitates.definition ? " The real " + td.preview.imitates.name + " is " + Fmt.short(td.preview.imitates.definition) + "." : "") : ""
    }
    RowLayout {
        visible: td.tier === "unknown" || td.tier === "spam" || td.tier === "hidden"
        Layout.fillWidth: true
        spacing: 8
        Btn {
            objectName: "tokenAddFromDetail"
            visible: td.tier !== "hidden"
            Layout.fillWidth: true
            text: "Add to my tokens"
            onClicked: td.act("addToken", { definition: td.definition }, "Added")
        }
        Btn {
            objectName: "tokenShowHide"
            Layout.fillWidth: true
            text: td.tier === "hidden" ? "Show again" : td.tier === "spam" ? "Show anyway" : "Hide"
            onClicked: td.tier === "spam" ? td.act("addToken", { definition: td.definition }, "Shown. This doesn't mean it's safe.")
                     : td.act("setTokenHidden", { definition: td.definition, on: td.tier !== "hidden" }, td.tier === "hidden" ? "Shown again" : "Hidden")
        }
    }

    // -- activity ----------------------------------------------------------------------------
    SectionTitle { text: "Activity"; Layout.topMargin: 8 }
    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: -12
        Layout.rightMargin: -12
        spacing: 0
        Repeater {
            model: td.activity.slice(0, 8)
            TxRow { tx: modelData; store: td.store }
        }
    }
    Txt { visible: td.activity.length === 0; text: "No activity with this token yet."; tone: "text3"; font.pixelSize: 13 }

    // -- details -------------------------------------------------------------------------------
    SectionTitle { text: "Details"; Layout.topMargin: 8 }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            InfoRow { Layout.fillWidth: true; label: "Token ID"; value: Fmt.short(td.definition); mono: true }
            IconButton { glyph: "copy"; label: "Copy Token ID"; onClicked: td.store.copy(td.definition) }
            IconButton { visible: !!td.store.state.explorer; glyph: "external"; label: "Open in explorer"; onClicked: td.store.call("openExplorer", { chain: td.store.zone.chain, account: td.definition }, null) }
        }
        Repeater {
            model: td.row ? td.row.holders : []
            InfoRow {
                Layout.fillWidth: true
                label: modelData.via === "ata" ? "Your token account" : "Held in"
                value: Fmt.short(modelData.holder) + " · " + td.store.tokenAmount(td.t, modelData.amount)
                mono: true
            }
        }
        InfoRow {
            Layout.fillWidth: true
            label: "Decimals"
            value: !td.t || td.t.decimals === undefined || td.t.decimals === null ? "Unknown"
                 : td.t.decimals + (td.row && td.row.decimalsSource === "list" ? " · from the Logos Kit list" : td.row && td.row.decimalsSource === "you" ? " · set by you" : "")
        }
        InfoRow {
            Layout.fillWidth: true
            visible: !!td.preview
            label: "Supply"
            value: td.preview ? td.store.tokenAmount(td.t, td.preview.totalSupply) + " · the creator can mint more" : ""
        }
        InfoRow {
            Layout.fillWidth: true
            visible: !!td.preview
            label: "Metadata"
            value: !td.preview ? "" : td.preview.metadata ? td.preview.metadata.standard + " · " + td.preview.metadata.uri
                 : td.preview.metadataId ? (td.tier === "verified" || td.tier === "added" ? "Couldn't read it" : "Not loaded for unknown tokens") : "None"
        }
    }
    RowLayout {
        visible: td.tier === "verified" || td.tier === "added"
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 8
        Btn {
            objectName: "tokenPin"
            Layout.fillWidth: true
            text: td.t && td.t.pinned ? "Unpin" : "Pin to the top"
            onClicked: td.act("setTokenPinned", { definition: td.definition, on: !(td.t && td.t.pinned) }, null)
        }
        Btn {
            objectName: "tokenHide"
            Layout.fillWidth: true
            icon: "eyeOff"
            text: "Hide"
            onClicked: td.act("setTokenHidden", { definition: td.definition, on: true }, "Hidden")
        }
    }
    Notice { visible: td.problem !== ""; Layout.fillWidth: true; tone: "danger"; text: td.problem }
}
