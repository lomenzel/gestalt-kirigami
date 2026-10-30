#pragma once

#include <memory>
#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>
#include "wechselbalg.hpp"
#include "EffectManager.hpp"
#include "SubscriptionManager.hpp"

class AppBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString appName READ appName CONSTANT)
    Q_PROPERTY(QString appAuthor READ appAuthor CONSTANT)
    Q_PROPERTY(QString appVersion READ appVersion CONSTANT)
    Q_PROPERTY(QVariantMap componentTree READ componentTree NOTIFY treeChanged)
    QML_ELEMENT

public:
    explicit AppBridge(QObject *parent = nullptr);
    ~AppBridge() override;

    QString appName() const;
    QString appAuthor() const;
    QString appVersion() const;
    QVariantMap componentTree() const;

    Q_INVOKABLE void dispatch(const QString &callbackId, const QVariant &payload = QVariant());

signals:
    void treeChanged();

private:
    Value m_currentState;
    Value m_viewFn;
    QVariantMap m_currentTree;

    std::unique_ptr<Gestalt::EffectManager> m_effects;
    std::unique_ptr<Gestalt::SubscriptionManager> m_subs;

    void renderApp();
    void applyStateUpdate(const Value &res);
    QVariantMap valueToComponent(const Value &node);
};