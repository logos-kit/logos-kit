import QtQuick
import QtQuick.Layouts

// From 21st.dev jshguo/skeleton (id 11894) and animbits/loaders-skeleton
// (id 19999): https://21st.dev/@jshguo/components/skeleton
// Shaped placeholders that match the real layout so content doesn't jump:
//   row     avatar + two lines + trailing amount (token / activity rows)
//   balance label + big figure + two pill actions (the balance hero)
//   card    title, three lines, a media block
//   lines   `lines` text lines
ColumnLayout {
    id: sc
    property string variant: "row"
    property int count: 1
    property int lines: 3
    spacing: variant === "row" ? 14 : 12
    Repeater {
        model: sc.variant === "row" ? sc.count : 0
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Skeleton { implicitWidth: 40; implicitHeight: 40; radius: 20 }
            ColumnLayout {
                spacing: 8
                Layout.fillWidth: true
                Skeleton { implicitWidth: 120 - index * 14; implicitHeight: 12 }
                Skeleton { implicitWidth: 76 + index * 10; implicitHeight: 10; opacity: 0.7 }
            }
            Item { Layout.fillWidth: true }
            ColumnLayout {
                spacing: 8
                Skeleton { implicitWidth: 64; implicitHeight: 12; Layout.alignment: Qt.AlignRight }
                Skeleton { implicitWidth: 40; implicitHeight: 10; opacity: 0.7; Layout.alignment: Qt.AlignRight }
            }
        }
    }
    ColumnLayout {
        visible: sc.variant === "balance"
        spacing: 12
        Layout.fillWidth: true
        Skeleton { implicitWidth: 90; implicitHeight: 12 }
        Skeleton { implicitWidth: 210; implicitHeight: 40; radius: 12 }
        RowLayout {
            spacing: 12
            Repeater { model: 4; Skeleton { implicitWidth: 52; implicitHeight: 52; radius: 26 } }
        }
    }
    ColumnLayout {
        visible: sc.variant === "card"
        spacing: 10
        Layout.fillWidth: true
        Skeleton { implicitWidth: 160; implicitHeight: 16 }
        Skeleton { Layout.fillWidth: true; implicitHeight: 11 }
        Skeleton { Layout.fillWidth: true; Layout.rightMargin: 40; implicitHeight: 11 }
        Skeleton { Layout.fillWidth: true; Layout.rightMargin: 90; implicitHeight: 11 }
        Skeleton { Layout.fillWidth: true; implicitHeight: 96; radius: Theme.rRow; Layout.topMargin: 4 }
    }
    Repeater {
        model: sc.variant === "lines" ? sc.lines : 0
        Skeleton {
            Layout.fillWidth: true
            Layout.rightMargin: index === sc.lines - 1 ? 60 : 0
            implicitHeight: 11
        }
    }
}
