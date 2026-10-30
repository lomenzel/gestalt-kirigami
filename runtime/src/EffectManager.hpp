#pragma once

#include <functional>
#include <memory>
#include <string>
#include <QNetworkAccessManager>
#include <QSettings>
#include <QTimer>
#include <QMap>
#include "wechselbalg.hpp"

namespace Gestalt {

class EffectManager : public QObject {
    Q_OBJECT
public:
    using CallbackInvoker = std::function<void(const Value &callback, const Value &payload)>;

    explicit EffectManager(CallbackInvoker invoker, QObject *parent = nullptr);

    void execute(const Value &effect);

private:
    CallbackInvoker m_invoker;
    QNetworkAccessManager m_nam;
    QSettings m_settings;
    QMap<QString, QTimer*> m_timers;

    void executeTimer(const std::string &type, const Value &payload);
    void executeRandom(const std::string &type, const Value &payload);
    void executeStorage(const std::string &type, const Value &payload);
    void executeHttp(const std::string &type, const Value &payload);
    void executeVeilid(const std::string &type, const Value &effect);

    void handleUnsupported(const std::string &type, const Value &effect);
};

} // namespace Gestalt