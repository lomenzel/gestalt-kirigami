#pragma once
#include <QObject>
#include <QString>
#include "gestalt_veilid.h"

class VeilidController : public QObject {
    Q_OBJECT
public:
    static VeilidController* instance();
    
    void init(const QByteArray &configJson = "{}");

    void dispatchEffect(uint64_t id, const QString &effectJson);

signals:
    void eventReceived(const QString &eventJson);
    void responseReceived(uint64_t id, const QString &responseJson);

private:
    explicit VeilidController(QObject *parent = nullptr);
    static void onVeilidEvent(const char *json);
    static void onVeilidResponse(uint64_t id, const char *json);
};