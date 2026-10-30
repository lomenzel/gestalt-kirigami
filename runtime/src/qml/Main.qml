import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import Gestalt.Runtime

Kirigami.ApplicationWindow {
    id: root

    AppBridge {
        id: bridge
    }

    title: bridge.appName
    width: 720
    height: 520
    minimumWidth: 360
    minimumHeight: 280

    pageStack.initialPage: pageLoader

    Component {
        id: pageLoader
        Kirigami.ScrollablePage {
            id: curPage

            property var pageData: {
                var tree = bridge.componentTree;
                if (tree.type === "NavigationStack" && tree.pages && tree.pages.length > 0) {
                    return tree.pages[tree.pages.length - 1];
                }
                return tree;
            }

            title: pageData.title || bridge.appName

            // Dynamically instantiate Kirigami.Action items
            Instantiator {
                model: curPage.pageData.actions || []
                onObjectAdded: (index, object) => curPage.actions.push(object)
                onObjectRemoved: (index, object) => curPage.actions.splice(index, 1)

                Kirigami.Action {
                    text: modelData.text || modelData.label || ""
                    icon.name: modelData.icon || ""
                    enabled: modelData.enabled !== false
                    onTriggered: {
                        var cb = modelData.onClick || modelData.onTrigger || modelData.callback;
                        if (cb) bridge.dispatch(cb);
                    }
                }
            }

            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing
                Layout.fillWidth: true

                Repeater {
                    model: curPage.pageData.children || []
                    GestaltNode {
                        nodeData: modelData
                        bridgeRef: bridge
                    }
                }
            }
        }
    }
}