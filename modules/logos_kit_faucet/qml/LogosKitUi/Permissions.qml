import QtQuick
import QtQuick.Layouts

// What an app gets when it connects, in plain words: each line a check
// (granted) or a lock (never without you). `privateRead` adds the separate
// private-account consent line.
ColumnLayout {
    id: pm
    property bool privateRead: false
    spacing: 8
    readonly property var lines: {
        var out = [
            { ok: true, text: "See the accounts you choose and their public balances" },
            { ok: true, text: "Ask you to approve transactions" }
        ]
        if (pm.privateRead) out.push({ ok: true, priv: true, text: "Read the balance of the private accounts you tick" })
        out.push({ ok: false, text: "Move funds or sign anything without your approval" })
        return out
    }
    Repeater {
        model: pm.lines
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                implicitWidth: 22; implicitHeight: 22; radius: 11
                color: modelData.ok ? (modelData.priv ? Theme.privSoft : Theme.soft(Theme.ok, 0.14)) : Theme.surface2
                Glyph { anchors.centerIn: parent; name: modelData.ok ? "check" : "lock"; width: 12; height: 12; stroke: 2.6
                        color: modelData.ok ? (modelData.priv ? Theme.privText : Theme.ok) : Theme.text2 }
            }
            Txt {
                text: (modelData.ok ? "" : "Never: ") + modelData.text
                tone: modelData.ok ? "text" : "text2"
                font.pixelSize: 13
                wrapMode: Text.Wrap; elide: Text.ElideNone
                Layout.fillWidth: true
            }
        }
    }
}
