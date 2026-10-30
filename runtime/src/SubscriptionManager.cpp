#include "SubscriptionManager.hpp"
#include "Diagnostics.hpp"
#include "VeilidController.hpp"
#include <QJsonDocument>
#include <QJsonObject>

namespace Gestalt {

SubscriptionManager::SubscriptionManager(Dispatcher dispatcher, QObject *parent)
    : QObject(parent), m_dispatcher(std::move(dispatcher)), m_activeSubs(Value::fromList({})) {

    connect(VeilidController::instance(), &VeilidController::eventReceived,
            this, &SubscriptionManager::handleVeilidUpdate);
}

void SubscriptionManager::reconcile(const Value &subscriptions) {
    subscriptions.force();
    if (!subscriptions.isList()) {
        m_activeSubs = Value::fromList({});
        return;
    }
    m_activeSubs = subscriptions;
}

void SubscriptionManager::handleVeilidUpdate(const QString &eventJson) {
    m_activeSubs.force();
    if (!m_activeSubs.isList()) return;

    QJsonDocument doc = QJsonDocument::fromJson(eventJson.toUtf8());
    QJsonObject obj = doc.object();
    QString kind = obj["kind"].toString().toLower();

    for (const auto &sub : m_activeSubs.asList()) {
        sub.force();
        if (!sub.isSet()) continue;

        std::string subKind = Diagnostics::getString(sub, "kind");
        QString norm = QString::fromStdString(subKind).remove(QRegularExpression("^Veilid\\.(on)?", QRegularExpression::CaseInsensitiveOption)).toLower();

        if (norm == kind) {
            Value cb = Diagnostics::getAttr(sub, "callback");
            if (cb.isNull()) cb = Diagnostics::getAttr(sub, "onMessage");
            if (cb.isNull()) cb = Diagnostics::getAttr(sub, "onNetwork");

            if (!cb.isNull() && m_dispatcher) {
                // Convert payload
                Value payload = Value::fromSet({
                    {"detail", Value::fromString(eventJson.toStdString())}
                });
                m_dispatcher(cb, payload);
            }
        }
    }
}

} // namespace Gestalt