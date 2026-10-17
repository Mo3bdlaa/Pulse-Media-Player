import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Layouts
import Pulse
import Pulse.Core

// 11 — Conversion Queue card.
Glass {
    id: root
    property bool scrolls: false
    radius: 16
    implicitHeight: col.implicitHeight + 36

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 18
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label { Layout.fillWidth: true; role: "section"; font.pixelSize: 17; text: qsTr("Conversion Queue (%1)").arg(Converter.active.count); Accessible.role: Accessible.Heading }
            PulseButton { visible: Converter.active.count > 0; iconName: "trash"; text: qsTr("Clear All"); onClicked: Converter.clearActive() }
            PulseButton {
                visible: Converter.active.count > 0
                variant: "primary"
                iconName: "play"
                text: Converter.running ? qsTr("Converting…") : qsTr("Start All")
                enabled: !Converter.running
                onClicked: Converter.startAll()
            }
        }
        ListView {
            id: jobs
            Layout.fillWidth: true
            Layout.fillHeight: root.scrolls
            Layout.preferredHeight: root.scrolls ? -1 : contentHeight
            interactive: root.scrolls
            clip: root.scrolls
            model: Converter.active
            delegate: JobRow { width: jobs.width }
            T.ScrollBar.vertical: T.ScrollBar { visible: root.scrolls }
        }
        Label {
            visible: Converter.active.count === 0
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.bottomMargin: 6
            secondary: true
            text: qsTr("Add files to convert. Originals are never changed.")
        }
    }
}
