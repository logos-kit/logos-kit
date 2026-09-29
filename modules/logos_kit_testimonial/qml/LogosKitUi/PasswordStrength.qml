import QtQuick
import QtQuick.Layouts

// From 21st.dev ddoemonn/password-strength (id 23542, segmented bars on a
// spring + a live checklist): https://21st.dev/@ddoemonn/components/password-strength
// Scores `password` 0..4 and lists what would make it stronger. A hint,
// not a policy: the wallet's own minimum is enforced where it's set.
ColumnLayout {
    id: ps
    property string password: ""
    property int minLength: 10
    readonly property var checks: [
        { label: minLength + "+ characters", ok: password.length >= minLength },
        { label: "Upper and lower case", ok: /[a-z]/.test(password) && /[A-Z]/.test(password) },
        { label: "A number", ok: /[0-9]/.test(password) },
        { label: "A symbol", ok: /[^A-Za-z0-9]/.test(password) }
    ]
    readonly property int score: {
        if (password.length === 0) return 0
        var s = 0
        for (var i = 0; i < checks.length; i++) if (checks[i].ok) s++
        if (password.length >= minLength + 6) s = Math.min(4, s + 1)
        if (/^(.)\1+$/.test(password) || /^(password|123456|qwerty)/i.test(password)) s = 1
        return Math.max(1, Math.min(4, s))
    }
    readonly property var labels: ["", "Weak", "Fair", "Good", "Strong"]
    readonly property color tint: score <= 1 ? Theme.danger : score === 2 ? Theme.warn : score === 3 ? Theme.action : Theme.ok
    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: 4
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 5
                radius: 2.5
                color: Theme.surface2
                Rectangle {
                    height: parent.height; radius: parent.radius
                    color: ps.tint
                    width: index < ps.score ? parent.width : 0
                    Behavior on width { enabled: !Theme.reducedMotion; SpringAnimation { spring: 4; damping: 0.4; epsilon: 0.3 } }
                    Behavior on color { ColorAnimation { duration: Theme.dBase } }
                }
            }
        }
        Txt {
            Layout.preferredWidth: 52
            horizontalAlignment: Text.AlignRight
            text: ps.labels[ps.score]
            color: ps.tint
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }
    GridLayout {
        columns: 2
        columnSpacing: 16
        rowSpacing: 6
        visible: ps.password.length > 0
        Repeater {
            model: ps.checks
            RowLayout {
                spacing: 6
                Rectangle {
                    implicitWidth: 14; implicitHeight: 14; radius: 7
                    color: modelData.ok ? Theme.soft(Theme.ok, 0.18) : Theme.surface2
                    Behavior on color { ColorAnimation { duration: Theme.dFast } }
                    Glyph { anchors.centerIn: parent; name: "check"; color: Theme.ok; width: 9; height: 9; stroke: 3
                            scale: modelData.ok ? 1 : 0; Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } } }
                }
                Txt { text: modelData.label; tone: modelData.ok ? "text" : "text3"; font.pixelSize: 12 }
            }
        }
    }
}
