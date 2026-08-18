#!/bin/bash
# ==============================================================================
# 🦍 GORILLA UNLEASHED - One-Click Kernel Rebuilder
# ==============================================================================
# This script downloads, patches, configures, and compiles the custom 
# Linux 7.0.9-unleashed kernel from scratch.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_VER="7.0.9"
KERNEL_DIR="linux-${KERNEL_VER}"
KERNEL_TAR="${KERNEL_DIR}.tar.xz"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v7.x/${KERNEL_TAR}"
TIMESTAMP=$(date +"%Y.%m.%d--%H.%M")
LVERSION="-unleashed.gorilla-+60db-bbr-fq-codel-${TIMESTAMP}"

echo "===================================================================="
echo "🦍 GORILLA UNLEASHED: One-Click Kernel Builder"
echo "===================================================================="
echo "Working directory: ${SCRIPT_DIR}"
echo "Target version:    Linux ${KERNEL_VER}"
echo "===================================================================="

# 1. Install prerequisites if needed (for Debian/Ubuntu)
echo "📦 Checking and installing dependencies..."
if command -v apt-get &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y build-essential libncurses-dev bison flex libssl-dev libelf-dev \
        bc git rsync curl xz-utils kmod cpio libssl-dev dpkg-dev debhelper
else
    echo "⚠️  System is not Debian-based. Please ensure build dependencies are installed manually."
fi

# 2. Download Kernel Source
if [ ! -d "${SCRIPT_DIR}/${KERNEL_DIR}" ]; then
    if [ ! -f "${SCRIPT_DIR}/${KERNEL_TAR}" ]; then
        echo "🌐 Downloading Linux kernel ${KERNEL_VER} source..."
        curl -L -o "${SCRIPT_DIR}/${KERNEL_TAR}" "${KERNEL_URL}"
    fi
    echo "📦 Extracting kernel sources..."
    tar -xf "${SCRIPT_DIR}/${KERNEL_TAR}" -C "${SCRIPT_DIR}"
else
    echo "✅ Kernel source directory already exists."
fi

# 3. Apply Patches
echo "🚀 Applying Braveheart patches to the kernel tree..."
python3 "${SCRIPT_DIR}/universal_freedom_installer.py" "${SCRIPT_DIR}/${KERNEL_DIR}"

# 4. Apply Custom Configuration
echo "⚙️  Applying custom kernel configuration (.config)..."
if [ -f "${SCRIPT_DIR}/kernel.config" ]; then
    cp "${SCRIPT_DIR}/kernel.config" "${SCRIPT_DIR}/${KERNEL_DIR}/.config"
else
    echo "❌ Error: kernel.config not found in ${SCRIPT_DIR}!"
    exit 1
fi

# 5. Build Kernel Packages
echo "🛠️  Starting compilation (Optimized for host CPU)..."
cd "${SCRIPT_DIR}/${KERNEL_DIR}"

# Clean build environment
make clean

# Enable CPU-native optimizations
export KCFLAGS="-O3 -march=native -mtune=native -pipe"

# Compile debian packages
CORES=$(nproc)
echo "🔥 Compiling using ${CORES} CPU cores..."
make LOCALVERSION="${LVERSION}" -j"${CORES}" bindeb-pkg KDEB_PKGVERSION="${KERNEL_VER}"

echo "===================================================================="
echo "🎉 Build complete! The new kernel packages (.deb) are located at:"
echo "   ${SCRIPT_DIR}"
echo "===================================================================="
