import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.Card {
    id: root

    property string componentType: "Unknown"
    property string rawPayload: ""

    Layout.fillWidth: true

    background: Rectangle {
        color: Kirigami.Theme.negativeBackgroundColor
        opacity: 0.15
        radius: Kirigami.Units.smallSpacing
        border.color: Kirigami.Theme.negativeTextColor
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "dialog-warning"
                color: Kirigami.Theme.negativeTextColor
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }

            Kirigami.Heading {
                level: 3
                text: "Unsupported Component: <" + root.componentType + ">"
                color: Kirigami.Theme.negativeTextColor
            }
        }

        QQC2.Label {
            text: "This component is not yet implemented in the Kirigami target."
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.TextArea {
            visible: root.rawPayload.length > 0
            text: root.rawPayload
            readOnly: true
            font.family: "monospace"
            font.pointSize: 9
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            background: Rectangle {
                color: Kirigami.Theme.backgroundColor
                opacity: 0.6
                radius: 4
            }
        }
    }
}