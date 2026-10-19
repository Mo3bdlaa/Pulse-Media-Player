cmake_minimum_required(VERSION 3.21)

project(Pulse VERSION 0.1.0 DESCRIPTION "Play anything. Feel more." LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(PULSE_BUILD_TESTS "Build the Pulse tests" ON)

find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Quick QuickControls2 Svg OpenGL)
qt_standard_project_setup()

# The playback core: libVLC 4 built from this repository's untouched upstream
# sources (tools/build-libvlc.sh) or provided by the platform SDK.
include(GNUInstallDirs)
find_package(PkgConfig REQUIRED)
pkg_check_modules(LIBVLC REQUIRED IMPORTED_TARGET libvlc>=4.0.0)

# --- engine adapter: the only code that talks to libVLC -----------------------
add_library(pulse_engine STATIC
    src/engine/engine.cpp src/engine/engine.hpp
    src/engine/player.cpp src/engine/player.hpp
    src/engine/mediainspector.cpp src/engine/mediainspector.hpp
    src/engine/mediaprobe.cpp src/engine/mediaprobe.hpp
    src/engine/thumbnailer.cpp src/engine/thumbnailer.hpp
    src/engine/transcoder.cpp src/engine/transcoder.hpp
    src/engine/videooutput.cpp src/engine/videooutput.hpp
)
target_include_directories(pulse_engine PUBLIC src)
target_link_libraries(pulse_engine
    PUBLIC Qt6::Core Qt6::Gui Qt6::Quick Qt6::OpenGL
    PRIVATE PkgConfig::LIBVLC)

# --- app services ----------------------------------------------------------------
add_library(pulse_app STATIC
    src/app/appinfo.hpp
    src/app/convertqueue.cpp src/app/convertqueue.hpp
    src/app/iconprovider.cpp src/app/iconprovider.hpp
    src/app/library.cpp src/app/library.hpp
    src/app/mediainfo.cpp src/app/mediainfo.hpp
    src/app/mediainput.cpp src/app/mediainput.hpp
    src/app/playlists.cpp src/app/playlists.hpp
    src/app/playqueue.cpp src/app/playqueue.hpp
    src/app/preferences.cpp src/app/preferences.hpp
    src/app/recentmedia.cpp src/app/recentmedia.hpp
)
target_include_directories(pulse_app PUBLIC src)
target_link_libraries(pulse_app PUBLIC pulse_engine Qt6::Core Qt6::Gui Qt6::Quick Qt6::Svg)

# --- application -----------------------------------------------------------------
qt_add_executable(pulse WIN32 MACOSX_BUNDLE src/main.cpp)
target_compile_definitions(pulse PRIVATE PULSE_VERSION="${PROJECT_VERSION}")
target_link_libraries(pulse PRIVATE pulse_engine pulse_app Qt6::QuickControls2)
set_target_properties(pulse PROPERTIES
    OUTPUT_NAME pulse
    MACOSX_BUNDLE_BUNDLE_NAME Pulse
    MACOSX_BUNDLE_GUI_IDENTIFIER org.pulse.Player
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION})

# Conversion helper: runs one job per process so an encoder fault cannot take
# the player down (see src/app/convertqueue.hpp).
if(NOT ANDROID AND NOT IOS)
    add_executable(pulse-convert src/convert_main.cpp)
    target_compile_definitions(pulse-convert PRIVATE PULSE_VERSION="${PROJECT_VERSION}")
    target_link_libraries(pulse-convert PRIVATE pulse_engine)
    set_target_properties(pulse-convert PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
    if(APPLE)
        # Inside the bundle, next to the main executable.
        add_custom_command(TARGET pulse POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:pulse-convert> $<TARGET_FILE_DIR:pulse>)
        add_dependencies(pulse pulse-convert)
    endif()
    install(TARGETS pulse-convert RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
endif()

set_source_files_properties(qml/theme/Theme.qml qml/details/MediaFormat.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

file(GLOB PULSE_ICONS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} CONFIGURE_DEPENDS assets/icons/*.svg)
file(GLOB PULSE_FONTS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} CONFIGURE_DEPENDS assets/fonts/*.ttf)

qt_add_qml_module(pulse
    URI Pulse
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    QML_FILES
        qml/Main.qml
        qml/theme/Theme.qml
        qml/components/AccentGlow.qml
        qml/components/Card.qml
        qml/components/DashedFrame.qml
        qml/components/Dropdown.qml
        qml/components/Glass.qml
        qml/components/HeroScene.qml
        qml/components/FocusRing.qml
        qml/components/IconButton.qml
        qml/components/InfoChip.qml
        qml/components/PulseBars.qml
        qml/components/PageBanner.qml
        qml/components/PillTabs.qml
        qml/components/PromptDialog.qml
        qml/components/PulseMenu.qml
        qml/components/PulseMenuItem.qml
        qml/components/SearchField.qml
        qml/components/UnderlineTabs.qml
        qml/components/SettingRow.qml
        qml/components/SettingsCard.qml
        qml/components/Kbd.qml
        qml/components/Label.qml
        qml/components/Logo.qml
        qml/components/MediaThumb.qml
        qml/components/NavItem.qml
        qml/components/PulseButton.qml
        qml/components/PulseIcon.qml
        qml/components/PulseSlider.qml
        qml/components/PulseSwitch.qml
        qml/components/Segmented.qml
        qml/components/Toast.qml
        qml/shell/BottomNav.qml
        qml/shell/CommandPalette.qml
        qml/shell/MiniPlayer.qml
        qml/shell/OpenUrlDialog.qml
        qml/shell/PlaylistPicker.qml
        qml/shell/ResizeHandles.qml
        qml/shell/Sidebar.qml
        qml/shell/TitleBar.qml
        qml/screens/ConvertScreen.qml
        qml/screens/EditorScreen.qml
        qml/screens/HomeScreen.qml
        qml/screens/LibraryScreen.qml
        qml/screens/MediaDetailsScreen.qml
        qml/screens/NetworkScreen.qml
        qml/screens/PlannedScreen.qml
        qml/screens/PlaylistsScreen.qml
        qml/screens/QueueScreen.qml
        qml/screens/SettingsScreen.qml
        qml/details/DetailCard.qml
        qml/details/FactRow.qml
        qml/details/MediaFormat.qml
        qml/details/TrackRow.qml
        qml/editor/CropOverlay.qml
        qml/library/EmptyLibrary.qml
        qml/library/LibraryOverview.qml
        qml/library/LibraryRow.qml
        qml/library/PosterTile.qml
        qml/playlists/PlaylistCover.qml
        qml/playlists/PlaylistDetail.qml
        qml/playlists/PlaylistSidePanel.qml
        qml/convert/CompletedList.qml
        qml/convert/JobRow.qml
        qml/convert/PresetTile.qml
        qml/convert/QueueCard.qml
        qml/player/NowPlayingPanel.qml
        qml/player/PlayerScreen.qml
        qml/player/QueueList.qml
        qml/player/Timeline.qml
        qml/player/ToolsPanel.qml
    RESOURCES
        assets/logo/pulse-mark.svg
        assets/logo/pulse-mark-mono.svg
        assets/fx/ember.png
        assets/fx/soft.png
        ${PULSE_ICONS}
        ${PULSE_FONTS}
)

install(TARGETS pulse BUNDLE DESTINATION . RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
if(UNIX AND NOT APPLE AND NOT ANDROID)
    install(FILES packaging/linux/org.pulse.Player.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
    install(FILES assets/logo/pulse-mark.svg DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps RENAME org.pulse.Player.svg)
endif()

if(PULSE_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
