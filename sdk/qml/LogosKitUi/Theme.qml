pragma Singleton
import QtQuick
import "../LogosKit/Tokens.js" as Tokens

// Tray tokens (D14, generated from @logos-kit/theme into LogosKit/Tokens.js)
// plus the font and motion rules: the same look as the Logos Kit wallet.
// Basecamp is dark; set `Theme.dark = false` for the light variant.
QtObject {
    id: theme

    property bool dark: true
    readonly property var t: dark ? Tokens.dark : Tokens.light

    readonly property color bg: t.bg
    readonly property color surface: t.surface
    readonly property color surface2: t.surface2
    readonly property color line: t.line
    readonly property color text: t.text
    readonly property color text2: t.text2
    readonly property color text3: t.text3
    readonly property color priv: t.private
    readonly property color privSoft: t.privateSoft
    readonly property color privText: t.privateText
    readonly property color action: t.action
    readonly property color actionText: t.actionText
    readonly property color ok: t.ok
    readonly property color warn: t.warn
    readonly property color danger: t.danger
    readonly property color island: "#000000"
    readonly property color scrim: dark ? "#b3000000" : "#73000000"

    readonly property int rSheet: t.rSheet
    readonly property int rCard: t.rCard
    readonly property int rRow: t.rRow

    // Onest (SIL OFL, fonts/OFL.txt), bundled: the sandbox loads nothing remote.
    readonly property FontLoader onest: FontLoader { source: Qt.resolvedUrl("fonts/Onest.ttf") }
    readonly property string font: onest.status === FontLoader.Ready ? onest.name : "Helvetica"
    readonly property string mono: Qt.platform.os === "osx" || Qt.platform.os === "ios" ? "Menlo" : "DejaVu Sans Mono"

    // Motion (brand.md): overshoot for sheets, a calm curve for height.
    property bool reducedMotion: false
    readonly property int dSheet: reducedMotion ? 0 : 300
    readonly property int dHeight: reducedMotion ? 0 : 200
    readonly property int dStep: reducedMotion ? 0 : 200
    readonly property int dPress: reducedMotion ? 0 : 120
    readonly property var overshoot: [0.15, 1.15, 0.6, 1, 1, 1]
    readonly property var calm: [0.25, 0.1, 0.25, 1, 1, 1]

    function soft(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
}
