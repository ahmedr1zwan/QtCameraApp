# Qt Camera Surveillance — Multi-Camera Grid

Lightweight Qt6 desktop app for multi-camera monitoring:

- Displays 4 camera streams in a grid simultaneously
- Fullscreen per-camera view
- Motion / tripwire / ROI alerts
- Snapshot capture
- CSV/JSON logging
- Camera configuration management

## Prerequisites

- Qt 6 (Quick, QuickControls2, Multimedia) matching your compiler/toolchain (MSVC or MinGW)
- Qt Creator (optional, but recommended)
- CMake 3.16+

## Quick Build (Desktop)

Open Qt Creator and click on **Create a Project**.

Click on **Import Project** → **Git Clone**.

Enter `https://github.com/ahmedr1zwan/QtCameraApp` and click **Next** → **Finish**.

**Build:**

Configure → Run CMake → Build the `appQtCameraApp` target.

**Run:**

Launch from Qt Creator or run the produced executable.

## Project Layout (Important Files)

- `CMakeLists.txt` - Build configuration
- `main.cpp` - Application entry point
- `Main.qml` - Main UI layout
- `CameraTile.qml` - Camera tile component
- `motiondetector.h/cpp` - Motion detection
- `tripwiremanager.h/cpp` - Tripwire/ROI management
- `configmanager.h/cpp` - Camera configuration
- `alertmanager.h/cpp` - Alert logging

## Usage

- **Add Camera**: Click "Add Camera" on an empty tile
- **Motion Detection**: Click 🔴 button, adjust sensitivity slider
- **Tripwire**: Click ─ button, draw line across video
- **ROI**: Click ▢ button, draw polygon region
- **Config**: Click "Config" to save/load camera settings
- **Alerts**: Click "Alerts" to view and export logs
