import QtQuick

// Soft elevation without MultiEffect (not guaranteed in the Basecamp
// sandbox): a few concentric translucent rounded rects under the target,
// offset down like a key light. Place it as the first child of the element
// it shadows, or next to it with `anchors.fill: target`.
Item {
    id: sh
    property real radius: Theme.rCard
    property int level: 2          // 1 subtle, 2 card, 3 floating (sheets, toasts)
    property real strength: Theme.shadowStrength
    readonly property int rings: level === 1 ? 3 : level === 2 ? 5 : 7
    readonly property real spread: level === 1 ? 1.5 : level === 2 ? 2.5 : 4
    readonly property real drop: level === 1 ? 1 : level === 2 ? 3 : 8
    z: -1
    Repeater {
        model: sh.rings
        Rectangle {
            readonly property real k: index + 1
            x: -k * sh.spread
            y: -k * sh.spread + sh.drop
            width: sh.width + 2 * k * sh.spread
            height: sh.height + 2 * k * sh.spread
            radius: sh.radius + k * sh.spread
            color: Theme.soft(Theme.shadow, sh.strength * 0.16 / k)
        }
    }
}
