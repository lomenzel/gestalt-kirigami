#include "VeilidController.hpp"
#include <QMetaObject>

VeilidController* VeilidController::instance() {
    static VeilidController s_instance;
    return &s_instance;
}

VeilidController::VeilidController(QObject *parent) : QObject(parent) {}

void VeilidController::onVeilidEvent(const char *json) {
    QString data = QString::fromUtf8(json);
    QMetaObject::invokeMethod(instance(), [data]() {
        emit instance()->eventReceived(data);
    }, Qt::QueuedConnection);
}

void VeilidController::onVeilidResponse(uint64_t id, const char *json) {
    QString data = QString::fromUtf8(json);
    QMetaObject::invokeMethod(instance(), [id, data]() {
        emit instance()->responseReceived(id, data);
    }, Qt::QueuedConnection);
}

void VeilidController::init(const QByteArray &configJson) {
    gestalt_veilid_init(configJson.constData(), &VeilidController::onVeilidEvent);
}

void VeilidController::dispatchEffect(uint64_t id, const QString &effectJson) {
    gestalt_veilid_run_effect(effectJson.toUtf8().constData(), &VeilidController::onVeilidResponse, id);
}