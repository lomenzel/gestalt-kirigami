#include "Runtime.hpp"
#include "app_interface.hpp"

int main(int argc, char *argv[]) {
    return Gestalt::run(argc, argv, &GestaltApp::meta);
}