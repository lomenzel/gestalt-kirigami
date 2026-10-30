#pragma once

#include <string>
#include <QString>
#include <iostream>
#include "wechselbalg.hpp"

namespace Gestalt::Diagnostics {

// Console logging helpers with clear prefixes
void logInfo(const std::string &category, const std::string &message);
void logWarn(const std::string &category, const std::string &message);
void logError(const std::string &category, const std::string &message);

// Safe attribute readers that never panic
bool hasAttr(const Value &val, const std::string &key);
std::string getString(const Value &val, const std::string &key, const std::string &fallback = "");
long long getInt(const Value &val, const std::string &key, long long fallback = 0);
bool getBool(const Value &val, const std::string &key, bool fallback = false);
Value getAttr(const Value &val, const std::string &key);

// Formats a Value for debugging (JSON if possible, otherwise type name)
std::string formatValue(const Value &val);

} // namespace Gestalt::Diagnostics