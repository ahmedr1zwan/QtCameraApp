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
    configmanager.cpp
    configmanager.h
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
    MACOSX_RPATH ON
)

# Set rpath to use Qt from the build system, not Homebrew
# This prevents the app from loading Qt 6.9.3 from Homebrew when built with Qt 6.10.0
if(APPLE)
    # Find Qt6 installation path
    get_target_property(QT_QMAKE_EXECUTABLE Qt6::qmake IMPORTED_LOCATION)
    if(QT_QMAKE_EXECUTABLE)
        execute_process(
            COMMAND ${QT_QMAKE_EXECUTABLE} -query QT_INSTALL_PREFIX
            OUTPUT_VARIABLE QT_INSTALL_PREFIX
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        if(QT_INSTALL_PREFIX)
            # Set rpath to Qt installation (for frameworks)
            # Use @loader_path for relative paths within the bundle
            set_target_properties(appQtCameraApp PROPERTIES
                INSTALL_RPATH "@loader_path/../Frameworks;${QT_INSTALL_PREFIX}/lib"
                BUILD_WITH_INSTALL_RPATH TRUE
            )
            # Set build rpath (for running from build directory)
            set(CMAKE_BUILD_RPATH "${CMAKE_BUILD_RPATH};${QT_INSTALL_PREFIX}/lib")
            # Also set MACOSX_RPATH to use @rpath
            set_target_properties(appQtCameraApp PROPERTIES
                MACOSX_RPATH ON
            )
            message(STATUS "Qt installation path: ${QT_INSTALL_PREFIX}")
            message(STATUS "Setting rpath to: ${QT_INSTALL_PREFIX}/lib")
            
            # Note: The rpath is set above, but if Homebrew Qt is in system paths,
            # you may need to set DYLD_FRAMEWORK_PATH in Qt Creator's run settings.
            
            # Post-build step: Fix library paths to use absolute paths to Qt 6.10.0
            # This prevents macOS from loading Homebrew Qt 6.9.3
            # Only execute if QT_INSTALL_PREFIX is successfully determined
            add_custom_command(TARGET appQtCameraApp POST_BUILD
                COMMAND install_name_tool -change @rpath/QtCore.framework/Versions/A/QtCore ${QT_INSTALL_PREFIX}/lib/QtCore.framework/Versions/A/QtCore $<TARGET_FILE:appQtCameraApp>
                COMMAND install_name_tool -change @rpath/QtQuick.framework/Versions/A/QtQuick ${QT_INSTALL_PREFIX}/lib/QtQuick.framework/Versions/A/QtQuick $<TARGET_FILE:appQtCameraApp>
                COMMAND install_name_tool -change @rpath/QtMultimedia.framework/Versions/A/QtMultimedia ${QT_INSTALL_PREFIX}/lib/QtMultimedia.framework/Versions/A/QtMultimedia $<TARGET_FILE:appQtCameraApp>
                COMMAND install_name_tool -change @rpath/QtQuickControls2.framework/Versions/A/QtQuickControls2 ${QT_INSTALL_PREFIX}/lib/QtQuickControls2.framework/Versions/A/QtQuickControls2 $<TARGET_FILE:appQtCameraApp>
                COMMENT "Fixing Qt library paths to use Qt 6.10.0"
            )
        endif()
    endif()
endif()

target_link_libraries(appQtCameraApp
    PRIVATE Qt6::Quick Qt6::Multimedia Qt6::QuickControls2
)

include(GNUInstallDirs)
install(TARGETS appQtCameraApp
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
