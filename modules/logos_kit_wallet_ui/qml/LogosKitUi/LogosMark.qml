import QtQuick

// The official Logos mark, unmodified (assets/logos/logos, brand guidelines).
Image {
    property real size: 20
    property bool white: true
    source: Qt.resolvedUrl(white ? "assets/Logos-Mark-White.svg" : "assets/Logos-Mark-Black.svg")
    width: size
    height: size * 116 / 106
    sourceSize.width: size * 2
    sourceSize.height: size * 2 * 116 / 106
    fillMode: Image.PreserveAspectFit
    smooth: true
}
