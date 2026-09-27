import QtQuick

// A requesting app's icon from its installed metadata (Store.apps), else its
// initials. The sandbox loads no data: URLs or other modules' files, so the
// engine sends the icon as a small grid of #AARRGGBB cells; rectangles draw
// it. The icon is the app's own claim: callers show the module name too.
Rectangle {
    id: aa
    property var store
    property string requester: ""
    property int size: 44
    readonly property var info: store && store.apps[requester] ? store.apps[requester] : null
    readonly property var cells: info && info.icon ? info.icon : []
    readonly property int grid: Math.round(Math.sqrt(cells.length))
    readonly property bool hasIcon: grid > 0 && grid * grid === cells.length
    // Visible cells only (icons often have transparent corners).
    readonly property var shown: {
        var out = []
        if (!hasIcon) return out
        for (var i = 0; i < cells.length; i++)
            if (cells[i].substring(1, 3) !== "00") out.push(i)
        return out
    }
    implicitWidth: size; implicitHeight: size
    radius: Math.round(size * 0.32)
    color: hasIcon ? "transparent" : "#232329"
    border.width: hasIcon ? 0 : 1
    border.color: "#1affffff"
    Repeater {
        model: aa.shown
        Rectangle {
            readonly property int cx: modelData % aa.grid
            readonly property int cy: Math.floor(modelData / aa.grid)
            // Whole-pixel edges: neighbouring cells meet without seams.
            x: Math.round(cx * aa.size / aa.grid)
            y: Math.round(cy * aa.size / aa.grid)
            width: Math.round((cx + 1) * aa.size / aa.grid) - x
            height: Math.round((cy + 1) * aa.size / aa.grid) - y
            color: aa.cells[modelData]
            antialiasing: false
        }
    }
    Txt {
        visible: !aa.hasIcon
        anchors.centerIn: parent
        color: "#ffffff"
        font.pixelSize: Math.round(aa.size * 0.34)
        font.weight: Font.DemiBold
        text: aa.requester.substring(0, 2).toUpperCase()
    }
}
