import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import Gestalt.Runtime

Loader {
    id: rootLoader

    property var nodeData: ({})
    property var bridgeRef

    Layout.fillWidth: {
        var t = nodeData ? nodeData.type : "";
        return t === "ColumnLayout" || t === "RowLayout" || t === "TextInput" || t === "Button" || t === "Page" || t === "NavigationStack";
    }

    sourceComponent: {
        var t = nodeData ? nodeData.type : "";
        switch (t) {
            case "Page":            return compPage;
            case "NavigationStack": return compStack;
            case "ColumnLayout":    return compColumn;
            case "RowLayout":       return compRow;
            case "Text":            return compText;
            case "Button":          return compButton;
            case "TextInput":       return compTextInput;
            case "Checkbox":        return compCheckbox;
            default:                return compUnsupported;
        }
    }

    Component {
        id: compPage
        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            Layout.fillWidth: true

            Repeater {
                model: (rootLoader.nodeData && rootLoader.nodeData.children) ? rootLoader.nodeData.children : []
                Loader {
                    Layout.fillWidth: true
                    source: "GestaltNode.qml"
                    onLoaded: {
                        item.nodeData = modelData;
                        item.bridgeRef = rootLoader.bridgeRef;
                    }
                }
            }
        }
    }

    Component {
        id: compStack
        ColumnLayout {
            Layout.fillWidth: true

            Repeater {
                model: {
                    var pages = (rootLoader.nodeData && rootLoader.nodeData.pages) ? rootLoader.nodeData.pages : [];
                    return pages.length > 0 ? [pages[pages.length - 1]] : [];
                }
                Loader {
                    Layout.fillWidth: true
                    source: "GestaltNode.qml"
                    onLoaded: {
                        item.nodeData = modelData;
                        item.bridgeRef = rootLoader.bridgeRef;
                    }
                }
            }
        }
    }

    Component {
        id: compColumn
        ColumnLayout {
            spacing: (rootLoader.nodeData && rootLoader.nodeData.spacing !== undefined) 
                ? rootLoader.nodeData.spacing 
                : Kirigami.Units.smallSpacing
            Layout.fillWidth: true

            Repeater {
                model: (rootLoader.nodeData && rootLoader.nodeData.children) ? rootLoader.nodeData.children : []
                Loader {
                    Layout.fillWidth: true
                    source: "GestaltNode.qml"
                    onLoaded: {
                        item.nodeData = modelData;
                        item.bridgeRef = rootLoader.bridgeRef;
                    }
                }
            }
        }
    }

    Component {
        id: compRow
        RowLayout {
            spacing: (rootLoader.nodeData && rootLoader.nodeData.spacing !== undefined) 
                ? rootLoader.nodeData.spacing 
                : Kirigami.Units.smallSpacing
            Layout.fillWidth: true

            Repeater {
                model: (rootLoader.nodeData && rootLoader.nodeData.children) ? rootLoader.nodeData.children : []
                Loader {
                    source: "GestaltNode.qml"
                    onLoaded: {
                        item.nodeData = modelData;
                        item.bridgeRef = rootLoader.bridgeRef;
                    }
                }
            }
        }
    }

    Component {
        id: compText
        QQC2.Label {
            text: (rootLoader.nodeData && rootLoader.nodeData.text) ? rootLoader.nodeData.text : ""
            wrapMode: Text.WordWrap
        }
    }

    Component {
        id: compButton
        QQC2.Button {
            text: (rootLoader.nodeData && rootLoader.nodeData.text) ? rootLoader.nodeData.text : "Action"
            icon.name: (rootLoader.nodeData && rootLoader.nodeData.icon) ? rootLoader.nodeData.icon : ""
            enabled: !rootLoader.nodeData || rootLoader.nodeData.enabled !== false
            onClicked: {
                var cb = rootLoader.nodeData ? (rootLoader.nodeData.onClick || rootLoader.nodeData.callback) : null;
                if (cb && rootLoader.bridgeRef) rootLoader.bridgeRef.dispatch(cb);
            }
        }
    }

    Component {
        id: compTextInput
        QQC2.TextField {
            text: (rootLoader.nodeData && rootLoader.nodeData.value) ? rootLoader.nodeData.value : ""
            placeholderText: (rootLoader.nodeData && rootLoader.nodeData.placeholder) ? rootLoader.nodeData.placeholder : ""
            enabled: !rootLoader.nodeData || rootLoader.nodeData.enabled !== false
            Layout.fillWidth: true
            onTextEdited: {
                var cb = rootLoader.nodeData ? (rootLoader.nodeData.onInput || rootLoader.nodeData.callback) : null;
                if (cb && rootLoader.bridgeRef) rootLoader.bridgeRef.dispatch(cb, text);
            }
        }
    }

    Component {
        id: compCheckbox
        QQC2.CheckBox {
            text: (rootLoader.nodeData && rootLoader.nodeData.label) ? rootLoader.nodeData.label : ""
            checked: Boolean(rootLoader.nodeData && rootLoader.nodeData.checked)
            enabled: !rootLoader.nodeData || rootLoader.nodeData.enabled !== false
            onToggled: {
                var cb = rootLoader.nodeData ? (rootLoader.nodeData.onChange || rootLoader.nodeData.callback) : null;
                if (cb && rootLoader.bridgeRef) rootLoader.bridgeRef.dispatch(cb, checked);
            }
        }
    }

    Component {
        id: compUnsupported
        UnsupportedComponent {
            componentType: (rootLoader.nodeData && rootLoader.nodeData.type) ? rootLoader.nodeData.type : "Unknown"
            rawPayload: JSON.stringify(rootLoader.nodeData, null, 2)
        }
    }
}