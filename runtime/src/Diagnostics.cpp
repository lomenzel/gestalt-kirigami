#include "Diagnostics.hpp"

namespace Gestalt::Diagnostics {

void logInfo(const std::string &category, const std::string &message) {
    std::cout << "\033[34m[" << category << "]\033[0m " << message << std::endl;
}

void logWarn(const std::string &category, const std::string &message) {
    std::cerr << "\033[33m[" << category << " ⚠️]\033[0m " << message << std::endl;
}

void logError(const std::string &category, const std::string &message) {
    std::cerr << "\033[31;1m[" << category << " ❌]\033[0m " << message << std::endl;
}

bool hasAttr(const Value &val, const std::string &key) {
    val.force();
    return val.isSet() && val.hasAttr(key);
}

std::string getString(const Value &val, const std::string &key, const std::string &fallback) {
    val.force();
    if (!val.isSet() || !val.hasAttr(key)) return fallback;
    const Value &attr = val[key];
    attr.force();
    if (attr.isString()) return attr.asString();
    return attr.toString();
}

long long getInt(const Value &val, const std::string &key, long long fallback) {
    val.force();
    if (!val.isSet() || !val.hasAttr(key)) return fallback;
    const Value &attr = val[key];
    attr.force();
    if (attr.isInt()) return attr.asInt();
    return fallback;
}

bool getBool(const Value &val, const std::string &key, bool fallback) {
    val.force();
    if (!val.isSet() || !val.hasAttr(key)) return fallback;
    const Value &attr = val[key];
    attr.force();
    if (attr.isBool()) return attr.asBool();
    return fallback;
}

Value getAttr(const Value &val, const std::string &key) {
    val.force();
    if (!val.isSet() || !val.hasAttr(key)) return Value::null_();
    return val[key];
}

std::string formatValue(const Value &val) {
    try {
        val.force();
        return val.toJSON();
    } catch (...) {
        return "<Value type: " + val.typeOf() + ">";
    }
}

} // namespace Gestalt::Diagnostics