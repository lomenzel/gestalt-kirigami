#include "Runtime.hpp"
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include "AppBridge.hpp"
#include "wechselbalg.hpp"

namespace Gestalt {
    static Value* s_meta = nullptr;

    Value* getAppMeta() {
        return s_meta;
    }

    int run(int argc, char *argv[], Value *meta) {
        s_meta = meta;

        QGuiApplication app(argc, argv);

        if (s_meta) {
            s_meta->force();
            if (s_meta->hasAttr("name")) {
                const Value &nameVal = (*s_meta)["name"];
                nameVal.force();
                if (nameVal.isString()) {
                    app.setApplicationName(QString::fromStdString(nameVal.asString()));
                }
            }
        }

        QQmlApplicationEngine engine;

        QObject::connect(
            &engine,
            &QQmlApplicationEngine::objectCreationFailed,
            &app,
            []() { QCoreApplication::exit(-1); },
            Qt::QueuedConnection
        );

        engine.loadFromModule("Gestalt.Runtime", "Main");

        return app.exec();
    }
}