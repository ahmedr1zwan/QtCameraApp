cmake_minimum_required(VERSION 3.16)

project(QtCameraApp VERSION 0.1 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Multimedia QuickControls2)


qt_add_executable(appQtCameraApp
    main.cpp
    camerapermissionhelper.cpp
    camerapermissionhelper.h
    cameramanager.cpp
    cameramanager.h
    snapshothelper.cpp
    snapshothelper.h
    motiondetector.cpp
    motiondetector.h
    alertmanager.cpp
    alertmanager.h
    tripwiremanager.cpp
    tripwiremanager.h
)

qt_add_qml_module(appQtCameraApp
    URI QtCameraApp
    VERSION 1.0
    QML_FILES
        Main.qml
        CameraTile.qml
        FullScreenView.qml
        TripwireOverlay.qml
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appQtCameraApp PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appQtCameraApp
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appQtCameraApp
    PRIVATE Qt6::Quick Qt6::Multimedia Qt6::QuickControls2
)

include(GNUInstallDirs)
install(TARGETS appQtCameraApp
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
