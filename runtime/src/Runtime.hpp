#pragma once

struct Value;

namespace Gestalt {
    int run(int argc, char *argv[], Value *meta);
    Value* getAppMeta();
}