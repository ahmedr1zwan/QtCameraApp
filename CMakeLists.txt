cmake_minimum_required(VERSION 3.16)

project(QtCameraApp VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Qt6 REQUIRED COMPONENTS Quick Multimedia QuickControls2)
find_package(OpenCV 4.5 REQUIRED COMPONENTS core dnn imgproc video)
qt_policy(SET QTP0001 NEW)

qt_add_executable(appQtCameraApp
    main.cpp
    camerapermissionhelper.cpp
    camerapermissionhelper.h
    cameramanager.cpp
    cameramanager.h
    snapshothelper.cpp
    snapshothelper.h
    analyticsengine.cpp
    analyticsengine.h
    alertmanager.cpp
    alertmanager.h
    tripwiremanager.cpp
    tripwiremanager.h
    configmanager.cpp
    configmanager.h
)

qt_add_qml_module(appQtCameraApp
    URI QtCameraApp
    VERSION 1.0
    RESOURCE_PREFIX /
    QML_FILES
        Main.qml
        CameraTile.qml
        FullScreenView.qml
        TripwireOverlay.qml
        DetectionOverlay.qml
    RESOURCES
        assets/coco.names
)

set_target_properties(appQtCameraApp PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER io.github.ahmedr1zwan.sentinelvision
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist
    WIN32_EXECUTABLE TRUE
    MACOSX_RPATH ON
)

target_link_libraries(appQtCameraApp
    PRIVATE
        Qt6::Quick
        Qt6::Multimedia
        Qt6::QuickControls2
        ${OpenCV_LIBS}
)

target_include_directories(appQtCameraApp PRIVATE ${OpenCV_INCLUDE_DIRS})

include(GNUInstallDirs)
install(TARGETS appQtCameraApp
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

include(CTest)
if(BUILD_TESTING)
    find_package(Qt6 REQUIRED COMPONENTS Test)
    qt_add_executable(QtCameraAppTests
        tests/test_core.cpp
        alertmanager.cpp
        alertmanager.h
        tripwiremanager.cpp
        tripwiremanager.h
    )
    target_include_directories(QtCameraAppTests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
    target_link_libraries(QtCameraAppTests PRIVATE Qt6::Core Qt6::Gui Qt6::Test)
    add_test(NAME core COMMAND QtCameraAppTests)
endif()
