# homebrew-virglrenderer

[![Build Status](https://img.shields.io/github/actions/workflow/status/startergo/homebrew-virglrenderer/bottle.yml?branch=master&label=bottle%20build&logo=github&style=flat-square)](https://github.com/startergo/homebrew-virglrenderer/actions/workflows/bottle.yml)

Homebrew tap for [virglrenderer](https://gitlab.freedesktop.org/virgl/virglrenderer) - A virtual 3D GPU for QEMU guests, built for macOS with ANGLE support.

## What is virglrenderer?

virglrenderer is a library that allows a QEMU guest to use the host's GPU through virtio-gpu. It translates OpenGL/GLES commands from the guest and renders them on the host GPU, enabling near-native graphics performance for virtual machines.

## Installation

```bash
# Tap the repository
brew tap startergo/virglrenderer

# Install virglrenderer (will also install startergo/angle/angle as dependency)
brew install startergo/virglrenderer/virglrenderer
```

## Usage

### With QEMU

virglrenderer is used by QEMU to enable GPU acceleration for virtual machines:

```bash
qemu-system-x86_64 \
  -display gtk,gl=on \
  -virtio-gpu-gl,present=on \
  -object virtio-gpu-pci ...
```

### Compile and link with pkg-config

```bash
# Compile
gcc -o myapp myapp.c $(pkg-config --cflags --libs virglrenderer)

# Or for CMake
find_package(PkgConfig REQUIRED)
pkg_check_modules(VIRGL REQUIRED virglrenderer)
include_directories(${VIRGL_INCLUDE_DIRS})
target_link_libraries(myapp ${VIRGL_LIBRARIES})
```

### Manual compile flags

```bash
# Include paths
-I$(brew --prefix virglrenderer)/include/virgl

# Library paths
-L$(brew --prefix virglrenderer)/lib

# Libraries
-lvirglrenderer
```

## What's Included

- **Shared library**: `libvirglrenderer.dylib`
- **Headers**: virglrenderer API headers
- **pkg-config file**: `virglrenderer.pc`
- **Render server**: `virgl_render_server` (for Venus)

## Build Configuration

This build is configured for macOS with ANGLE and MoltenVK backend:
- **OpenGL ES support via ANGLE**: Uses [startergo/angle](https://github.com/startergo/homebrew-angle) for OpenGL ES on macOS
- **EGL support**: Enabled through ANGLE
- **Venus support**: Modern virtio-gpu Vulkan transport via [MoltenVK](https://github.com/KhronosGroup/MoltenVK)
- **DRM support**: Auto-detected (disabled on macOS without libdrm)
- **Tests disabled** for faster builds
- Builds against upstream virglrenderer HEAD

## License

MIT

## Upstream

- **[virglrenderer](https://gitlab.freedesktop.org/virgl/virglrenderer)**: Virtual 3D GPU renderer for QEMU guests
- **[ANGLE](https://chromium.googlesource.com/angle/angle)**: OpenGL ES implementation for macOS (via [startergo/homebrew-angle](https://github.com/startergo/homebrew-angle))
- **[MoltenVK](https://github.com/KhronosGroup/MoltenVK)**: Vulkan implementation for macOS (via Homebrew core)

This tap builds against the latest upstream virglrenderer with macOS-specific patches to enable OpenGL ES support through ANGLE and Vulkan support through MoltenVK.
