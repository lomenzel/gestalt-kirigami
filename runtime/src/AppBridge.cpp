#include "AppBridge.hpp"
#include "app_interface.hpp"
#include "Diagnostics.hpp"
#include "EffectManager.hpp"
#include "SubscriptionManager.hpp"
#include "VeilidController.hpp"
#include <QTimer>
#include <QJsonDocument>
#include <QJsonObject>

AppBridge::~AppBridge() = default;

static uint64_t s_cbCounter = 0;
static std::unordered_map<std::string, Value> s_callbacks;

static Value targetInfo() {
    return Value::fromSet({
        {"name", Value::fromString("kirigami")},
        {"uiComponents", Value::fromList({
            Value::fromString("Page"),
            Value::fromString("NavigationStack"),
            Value::fromString("ColumnLayout"),
            Value::fromString("RowLayout"),
            Value::fromString("Text"),
            Value::fromString("Button"),
            Value::fromString("TextInput"),
            Value::fromString("Checkbox"),
            Value::fromString("Action")
        })}
    });
}

// Tolerant value-to-QVariant converter (matches web converters.js)
static QVariant toNativeQVariant(const Value &v) {
    v.force();
    switch (v.type) {
        case Value::Type::Null:
            return QVariant();
        case Value::Type::Bool:
            return v.asBool();
        case Value::Type::Int:
            return static_cast<qint64>(v.asInt());
        case Value::Type::Float:
            return v.asFloat();
        case Value::Type::String:
            return QString::fromStdString(v.asString());
        case Value::Type::List: {
            QVariantList list;
            for (const auto &item : v.asList()) {
                list.append(toNativeQVariant(item));
            }
            return list;
        }
        case Value::Type::Set: {
            QVariantMap map;
            for (const auto &kv : v.asSet()) {
                map[QString::fromStdString(kv.first)] = toNativeQVariant(kv.second);
            }
            return map;
        }
        default:
            return QVariant();
    }
}

static QString safeString(const Value &val, const std::string &key, const QString &def = "") {
    val.force();
    if (!val.isSet() || !val.hasAttr(key)) return def;
    const Value &v = val[key];
    v.force();
    if (v.isString()) return QString::fromStdString(v.asString());
    if (v.isNull()) return def;
    return QString::fromStdString(v.toString());
}

AppBridge::AppBridge(QObject *parent) : QObject(parent) {
    // 1. Initialize Veilid with required program_name and namespace
    QJsonObject vConfig;
    vConfig["program_name"] = "gestalt";
    vConfig["namespace"] = "gestalt-kirigami";
    QJsonDocument doc(vConfig);
    VeilidController::instance()->init(doc.toJson(QJsonDocument::Compact));

    // 2. Setup effects and subscriptions
    auto invoker = [this](const Value &cb, const Value &payload) {
        if (!cb.isFunction()) return;
        Value res = payload.isNull() ? cb(m_currentState) : cb(payload)(m_currentState);
        applyStateUpdate(res);
    };

    m_effects = std::make_unique<Gestalt::EffectManager>(invoker, this);
    m_subs = std::make_unique<Gestalt::SubscriptionManager>(invoker, this);

    // 3. Resolve view and initialState
    if (&GestaltApp::initialState != nullptr) {
        m_currentState = GestaltApp::initialState;
    } else {
        m_currentState = Value::fromSet({});
    }

    if (&GestaltApp::view != nullptr && GestaltApp::view.isFunction()) {
        m_viewFn = GestaltApp::view;
    } else if (&GestaltApp::_view != nullptr && GestaltApp::_view.isFunction()) {
        m_viewFn = GestaltApp::_view;
    }

    renderApp();
}

QString AppBridge::appName() const {
    return safeString(GestaltApp::meta, "name", safeString(GestaltApp::meta, "title", "Gestalt App"));
}

QString AppBridge::appAuthor() const {
    return safeString(GestaltApp::meta, "author", safeString(GestaltApp::meta, "maintainer", "Unknown"));
}

QString AppBridge::appVersion() const {
    return safeString(GestaltApp::meta, "version", "0.1.0");
}

QVariantMap AppBridge::componentTree() const {
    return m_currentTree;
}

void AppBridge::dispatch(const QString &callbackId, const QVariant &payload) {
    auto it = s_callbacks.find(callbackId.toStdString());
    if (it == s_callbacks.end()) return;

    Value cb = it->second;
    Value arg = Value::null_();

    if (payload.userType() == QMetaType::Bool) {
        arg = Value::fromBool(payload.toBool());
    } else if (payload.userType() == QMetaType::QString) {
        arg = Value::fromString(payload.toString().toStdString());
    } else if (payload.userType() == QMetaType::Int || payload.userType() == QMetaType::LongLong) {
        arg = Value::fromInt(payload.toLongLong());
    }

    Value res = arg.isNull() ? cb(m_currentState) : cb(arg)(m_currentState);
    applyStateUpdate(res);
}

void AppBridge::applyStateUpdate(const Value &res) {
    res.force();
    if (res.isNull()) return;

    Value nextState = res;
    Value effect = Value::null_();

    if (res.isSet()) {
        if (res.hasAttr("state")) nextState = res["state"];
        if (res.hasAttr("effect")) effect = res["effect"];
    }

    m_currentState = nextState;
    renderApp();

    if (!effect.isNull()) {
        QTimer::singleShot(0, this, [this, effect]() {
            m_effects->execute(effect);
        });
    }
}

QVariantMap AppBridge::valueToComponent(const Value &node) {
    node.force();
    if (!node.isSet()) return {};

    QVariantMap map;
    map["type"] = safeString(node, "type", "Unknown");
    map["id"] = safeString(node, "id", "");

    // Resolve props
    Value props = Gestalt::Diagnostics::getAttr(node, "props");
    if (props.isNull() || !props.isSet()) props = node;

    // String attributes (null-safe)
    for (const auto &key : {"title", "text", "label", "value", "placeholder", "icon", "variant"}) {
        map[key] = safeString(props, key, "");
    }

    // Primitive attributes (null-safe)
    if (props.hasAttr("spacing")) {
        const Value &sp = props["spacing"];
        sp.force();
        if (sp.isInt()) map["spacing"] = static_cast<qint64>(sp.asInt());
    }

    if (props.hasAttr("enabled")) {
        const Value &en = props["enabled"];
        en.force();
        if (en.isBool()) map["enabled"] = en.asBool();
    }

    if (props.hasAttr("checked")) {
        const Value &ck = props["checked"];
        ck.force();
        if (ck.isBool()) map["checked"] = ck.asBool();
    }

    // Register event callbacks (null-safe)
    for (const auto &cbKey : {"onClick", "onInput", "onChange", "onTrigger", "onBack", "callback"}) {
        if (node.hasAttr(cbKey)) {
            const Value &cb = node[cbKey];
            cb.force();
            if (cb.isFunction()) {
                std::string id = "cb_" + std::to_string(++s_cbCounter);
                s_callbacks[id] = cb;
                map[cbKey] = QString::fromStdString(id);
            }
        }
    }

    // Children
    if (node.hasAttr("children")) {
        const Value &ch = node["children"];
        ch.force();
        if (ch.isList()) {
            QVariantList children;
            for (const auto &child : ch.asList()) {
                children.append(valueToComponent(child));
            }
            map["children"] = children;
        }
    }

    // NavigationStack pages
    if (node.hasAttr("pages")) {
        const Value &pg = node["pages"];
        pg.force();
        if (pg.isList()) {
            QVariantList pages;
            for (const auto &p : pg.asList()) {
                pages.append(valueToComponent(p));
            }
            map["pages"] = pages;
        }
    }

    // Actions
    if (node.hasAttr("actions")) {
        const Value &ac = node["actions"];
        ac.force();
        if (ac.isList()) {
            QVariantList actions;
            for (const auto &a : ac.asList()) {
                actions.append(valueToComponent(a));
            }
            map["actions"] = actions;
        }
    }

    return map;
}

void AppBridge::renderApp() {
    if (!m_viewFn.isFunction()) return;

    Value frame = m_viewFn(targetInfo())(m_currentState);
    frame.force();

    Value tree = Gestalt::Diagnostics::getAttr(frame, "componentTree");
    if (tree.isNull()) tree = frame;

    m_currentTree = valueToComponent(tree);
    emit treeChanged();

    // Reconcile subscriptions & initial effects
    Value subs = Gestalt::Diagnostics::getAttr(frame, "subscriptions");
    m_subs->reconcile(subs);

    Value initEffect = Gestalt::Diagnostics::getAttr(frame, "initialEffect");
    if (!initEffect.isNull()) {
        QTimer::singleShot(0, this, [this, initEffect]() {
            m_effects->execute(initEffect);
        });
    }
}