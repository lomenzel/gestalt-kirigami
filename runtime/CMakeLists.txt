cmake_minimum_required(VERSION 3.20)
project(gestalt_kirigami_runtime LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Network)
find_package(KF6Kirigami REQUIRED)

if(COMMAND qt_policy)
    qt_policy(SET QTP0001 NEW)
endif()

qt_add_library(gestalt_kirigami_runtime SHARED
    src/AppBridge.cpp
    src/AppBridge.hpp
    src/Runtime.cpp
    src/Runtime.hpp
    src/Diagnostics.cpp
    src/Diagnostics.hpp
    src/EffectManager.cpp
    src/EffectManager.hpp
    src/SubscriptionManager.cpp
    src/SubscriptionManager.hpp
    src/VeilidController.cpp
    src/VeilidController.hpp
)

target_include_directories(gestalt_kirigami_runtime PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

qt_add_qml_module(gestalt_kirigami_runtime
    URI Gestalt.Runtime
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    QML_FILES
        src/qml/Main.qml
        src/qml/GestaltNode.qml
        src/qml/UnsupportedComponent.qml
)

target_link_libraries(gestalt_kirigami_runtime PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Network
    KF6::Kirigami
)

install(TARGETS gestalt_kirigami_runtime DESTINATION lib)
install(DIRECTORY src/ DESTINATION include/gestalt FILES_MATCHING PATTERN "*.hpp")
install(DIRECTORY include/ DESTINATION include/gestalt FILES_MATCHING PATTERN "*.hpp")
install(FILES src/main.cpp DESTINATION share/gestalt)