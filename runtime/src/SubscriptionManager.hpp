#pragma once

#include <functional>
#include <string>
#include <QObject>
#include "wechselbalg.hpp"

namespace Gestalt {

class SubscriptionManager : public QObject {
    Q_OBJECT
public:
    using Dispatcher = std::function<void(const Value &callback, const Value &payload)>;

    explicit SubscriptionManager(Dispatcher dispatcher, QObject *parent = nullptr);

    void reconcile(const Value &subscriptions);

private:
    Dispatcher m_dispatcher;
    Value m_activeSubs;

    void handleVeilidUpdate(const QString &eventJson);
};

} // namespace Gestalt