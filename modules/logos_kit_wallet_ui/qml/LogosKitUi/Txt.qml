import QtQuick

// Text with the wallet's font and PLAIN TEXT by default: dApp names, labels,
// memos and token names are untrusted, and LogosText auto-detects rich text.
Text {
    property string tone: "text"    // text | text2 | text3 | priv | action | ok | warn | danger
    property bool num: false        // tabular figures for amounts
    property bool mono: false
    textFormat: Text.PlainText
    color: tone === "text2" ? Theme.text2 : tone === "text3" ? Theme.text3
         : tone === "priv" ? Theme.privText : tone === "action" ? Theme.action
         : tone === "ok" ? Theme.ok : tone === "warn" ? Theme.warn
         : tone === "danger" ? Theme.danger : Theme.text
    font.family: mono ? Theme.mono : Theme.font
    font.pixelSize: 14
    font.features: num ? { "tnum": 1 } : ({})
    wrapMode: Text.NoWrap
    elide: Text.ElideRight
    linkColor: Theme.action
}
