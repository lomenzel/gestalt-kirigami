#include "EffectManager.hpp"
#include "Diagnostics.hpp"
#include "VeilidController.hpp"
#include <QDateTime>
#include <QJsonArray>      // <-- Add this
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRandomGenerator>
#include <QUuid>

namespace Gestalt {

static Value jsonToValue(const QJsonValue &jv) {
    if (jv.isNull() || jv.isUndefined()) return Value::null_();
    if (jv.isBool()) return Value::fromBool(jv.toBool());
    if (jv.isDouble()) return Value::fromFloat(jv.toDouble());
    if (jv.isString()) return Value::fromString(jv.toString().toStdString());
    if (jv.isArray()) {
        Value::List list;
        for (const auto &item : jv.toArray()) list.push_back(jsonToValue(item));
        return Value::fromList(std::move(list));
    }
    if (jv.isObject()) {
        Value::Set set;
        for (auto it = jv.toObject().begin(); it != jv.toObject().end(); ++it) {
            set[it.key().toStdString()] = jsonToValue(it.value());
        }
        return Value::fromSet(std::move(set));
    }
    return Value::null_();
}

EffectManager::EffectManager(CallbackInvoker invoker, QObject *parent)
    : QObject(parent), m_invoker(std::move(invoker)), m_settings("Gestalt", "Storage") {}

void EffectManager::execute(const Value &effect) {
    effect.force();
    if (effect.isNull() || !effect.isSet()) return;

    std::string type = Diagnostics::getString(effect, "type");
    if (type.empty() || type == "Noop") return;

    if (type == "Batch") {
        Value effects = Diagnostics::getAttr(Diagnostics::getAttr(effect, "payload"), "effects");
        effects.force();
        if (effects.isList()) {
            for (const auto &sub : effects.asList()) execute(sub);
        }
        return;
    }

    Value payload = Diagnostics::getAttr(effect, "payload");

    if (type.rfind("Timer.", 0) == 0 || type.rfind("Time.", 0) == 0) {
        executeTimer(type, payload);
    } else if (type.rfind("Random.", 0) == 0) {
        executeRandom(type, payload);
    } else if (type.rfind("Storage.", 0) == 0) {
        executeStorage(type, payload);
    } else if (type.rfind("Http.", 0) == 0) {
        executeHttp(type, payload);
    } else if (type.rfind("Veilid.", 0) == 0) {
        executeVeilid(type, effect);
    } else {
        handleUnsupported(type, effect);
    }
}

void EffectManager::executeTimer(const std::string &type, const Value &payload) {
    if (type == "Time.Now") {
        auto now = QDateTime::currentDateTimeUtc();
        Value res = Value::fromSet({
            {"timestampMs", Value::fromInt(now.toMSecsSinceEpoch())},
            {"isoString", Value::fromString(now.toString(Qt::ISODateWithMs).toStdString())}
        });
        if (m_invoker && Diagnostics::hasAttr(payload, "onSuccess")) {
            m_invoker(payload["onSuccess"], res);
        }
    } else if (type == "Timer.Delay") {
        int ms = static_cast<int>(Diagnostics::getInt(payload, "ms", 0));
        QString timerId = QString::fromStdString(Diagnostics::getString(payload, "timerId"));
        Value cb = Diagnostics::getAttr(payload, "onTimeout");

        QTimer::singleShot(ms, this, [this, timerId, cb]() {
            if (!timerId.isEmpty()) m_timers.remove(timerId);
            if (m_invoker) m_invoker(cb, Value::null_());
        });
    } else if (type == "Timer.Cancel") {
        QString timerId = QString::fromStdString(Diagnostics::getString(payload, "timerId"));
        if (m_timers.contains(timerId)) {
            m_timers[timerId]->stop();
            m_timers[timerId]->deleteLater();
            m_timers.remove(timerId);
        }
    }
}

void EffectManager::executeRandom(const std::string &type, const Value &payload) {
    if (type == "Random.Uuid") {
        QString uuid = QUuid::createUuid().toString(QUuid::WithoutBraces);
        Value res = Value::fromSet({{"uuid", Value::fromString(uuid.toStdString())}});
        if (m_invoker && Diagnostics::hasAttr(payload, "onSuccess")) {
            m_invoker(payload["onSuccess"], res);
        }
    } else if (type == "Random.Bytes") {
        int len = static_cast<int>(Diagnostics::getInt(payload, "length", 32));
        QByteArray bytes(len, 0);
        QRandomGenerator::securelySeeded().fillRange(
            reinterpret_cast<quint32*>(bytes.data()), len / 4
        );
        std::string encoding = Diagnostics::getString(payload, "encoding", "base64");
        QString out = (encoding == "hex") ? bytes.toHex() : bytes.toBase64();
        Value res = Value::fromSet({{"bytes", Value::fromString(out.toStdString())}});
        if (m_invoker && Diagnostics::hasAttr(payload, "onSuccess")) {
            m_invoker(payload["onSuccess"], res);
        }
    }
}

void EffectManager::executeStorage(const std::string &type, const Value &payload) {
    QString ns = QString::fromStdString(Diagnostics::getString(payload, "namespace", "default"));
    QString key = QString::fromStdString(Diagnostics::getString(payload, "key"));
    QString fullKey = ns + "/" + key;

    if (type == "Storage.Get") {
        if (m_settings.contains(fullKey)) {
            QByteArray json = m_settings.value(fullKey).toByteArray();
            QJsonDocument doc = QJsonDocument::fromJson(json);
            Value val = jsonToValue(doc.isObject() ? QJsonValue(doc.object()) : QJsonValue(doc.array()));
            Value res = Value::fromSet({{"value", val}});
            if (m_invoker && Diagnostics::hasAttr(payload, "onSuccess")) {
                m_invoker(payload["onSuccess"], res);
            }
        } else {
            if (m_invoker && Diagnostics::hasAttr(payload, "onError")) {
                m_invoker(payload["onError"], Value::fromSet({{"error", Value::fromString("Key not found")}}));
            }
        }
    } else if (type == "Storage.Set") {
        Value val = Diagnostics::getAttr(payload, "value");
        m_settings.setValue(fullKey, QString::fromStdString(val.toJSON()).toUtf8());
        if (m_invoker && Diagnostics::hasAttr(payload, "onSuccess")) {
            m_invoker(payload["onSuccess"], Value::null_());
        }
    } else if (type == "Storage.Delete") {
        m_settings.remove(fullKey);
        if (m_invoker && Diagnostics::hasAttr(payload, "onSuccess")) {
            m_invoker(payload["onSuccess"], Value::null_());
        }
    }
}

void EffectManager::executeHttp(const std::string &type, const Value &payload) {
    QUrl url(QString::fromStdString(Diagnostics::getString(payload, "url")));
    QString method = QString::fromStdString(Diagnostics::getString(payload, "method", "GET"));
    QNetworkRequest req(url);

    QNetworkReply *reply = (method == "POST") 
        ? m_nam.post(req, QString::fromStdString(Diagnostics::getString(payload, "body")).toUtf8())
        : m_nam.get(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply, payload]() {
        reply->deleteLater();
        if (reply->error() == QNetworkReply::NoError) {
            QByteArray data = reply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(data);
            Value body = doc.isNull() ? Value::fromString(data.toStdString()) : jsonToValue(doc.object());
            Value res = Value::fromSet({
                {"status", Value::fromInt(reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt())},
                {"body", body}
            });
            if (m_invoker && Diagnostics::hasAttr(payload, "onSuccess")) {
                m_invoker(payload["onSuccess"], res);
            }
        } else {
            if (m_invoker && Diagnostics::hasAttr(payload, "onError")) {
                m_invoker(payload["onError"], Value::fromSet({
                    {"error", Value::fromString(reply->errorString().toStdString())}
                }));
            }
        }
    });
}

void EffectManager::executeVeilid(const std::string &type, const Value &effect) {
    static uint64_t s_reqId = 0;
    uint64_t reqId = ++s_reqId;

    Value payload = Diagnostics::getAttr(effect, "payload");
    Value onSuccess = Diagnostics::getAttr(payload, "onSuccess");
    Value onError = Diagnostics::getAttr(payload, "onError");

    QString json = QString::fromStdString(effect.toJSON());

    auto conn = std::make_shared<QMetaObject::Connection>();
    *conn = connect(VeilidController::instance(), &VeilidController::responseReceived,
            this, [this, reqId, onSuccess, onError, conn](uint64_t id, const QString &respJson) {
        if (id != reqId) return;
        disconnect(*conn);

        QJsonDocument doc = QJsonDocument::fromJson(respJson.toUtf8());
        Value res = jsonToValue(doc.object());

        if (doc.object().contains("error") && !onError.isNull() && m_invoker) {
            m_invoker(onError, res);
        } else if (!onSuccess.isNull() && m_invoker) {
            m_invoker(onSuccess, res);
        }
    });

    VeilidController::instance()->dispatchEffect(reqId, json);
}

void EffectManager::handleUnsupported(const std::string &type, const Value &effect) {
    Diagnostics::logError("Gestalt Effect", "Unsupported effect '" + type + "'\n"
                          "   Payload: " + Diagnostics::formatValue(Diagnostics::getAttr(effect, "payload")));

    Value payload = Diagnostics::getAttr(effect, "payload");
    if (Diagnostics::hasAttr(payload, "onError") && m_invoker) {
        m_invoker(payload["onError"], Value::fromSet({
            {"error", Value::fromString("Unsupported effect in Kirigami target: " + type)}
        }));
    }
}

} // namespace Gestalt