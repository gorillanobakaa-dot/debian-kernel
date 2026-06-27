#!/usr/bin/bash
# ==============================================================================
# GORILLA UNLEASHED KERNEL 7.1.2 — MASTER REBUILD SCRIPT
# ==============================================================================
# Automates the entire process:
#   1. Localizes and validates the target linux-7.1.2 source directory
#   2. Installs the custom Realtek sound, ath9k Wi-Fi, and TCP buffer patches
#   3. Injects the custom preemption, BBR, and hardware acceleration options
#   4. Compiles the kernel using optimized host flags (-O3 -march=native)
# ==============================================================================

set -e

# Default to parent directory source tree if not provided
TARGET_SOURCE="${1:-../linux-7.1.2}"
TARGET_SOURCE=$(readlink -f "$TARGET_SOURCE")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================================================"
echo "         🦍 GORILLA UNLEASHED KERNEL 7.1.2 AUTO-REBUILDER 🦍"
echo "======================================================================"
echo " Target Source Directory: $TARGET_SOURCE"
echo " Script Directory:        $SCRIPT_DIR"
echo "======================================================================"

if [ ! -d "$TARGET_SOURCE" ]; then
    echo "❌ Error: Target kernel source directory '$TARGET_SOURCE' not found."
    echo "Usage: ./recreate_success.sh [path_to_linux_source_root]"
    exit 1
fi

# 1. Apply code patches using universal_freedom_installer.py
echo -e "\n🚀 [Step 1/4] Applying custom source code patches..."
python3 "$SCRIPT_DIR/universal_freedom_installer.py" "$TARGET_SOURCE"

# 2. Check if .config exists. If not, copy our custom master config
echo -e "\n⚙️ [Step 2/4] Initializing kernel configuration..."
if [ ! -f "$TARGET_SOURCE/.config" ]; then
    if [ -f "$SCRIPT_DIR/kernel.config" ]; then
        echo "💾 Copying kernel.config to $TARGET_SOURCE/.config"
        cp "$SCRIPT_DIR/kernel.config" "$TARGET_SOURCE/.config"
    else
        echo "⚠️  No .config found and no kernel.config repository backup exists!"
        echo "Please copy your baseline configuration to $TARGET_SOURCE/.config before running."
        exit 1
    fi
fi

# 3. Inject mandatory optimization flags
echo -e "\n💉 [Step 3/4] Injecting mandatory Gorilla optimization flags..."
python3 "$SCRIPT_DIR/config_injector.py" "$TARGET_SOURCE"
make -C "$TARGET_SOURCE" olddefconfig

# 4. Trigger the optimized GCC compilation package build
echo -e "\n🛠️ [Step 4/4] Starting kernel compilation (bindeb-pkg)..."
TIMESTAMP=$(date +"%Y.%m.%d--%H.%M")
LVERSION="-unleashed.gorilla-+60db-bbr-fq-codel-${TIMESTAMP}"

export KCFLAGS="-O3 -march=native -mtune=native -pipe"
echo "  Optimizations enabled: $KCFLAGS"
echo "  CPUs utilized:        $(nproc)"
echo "  Starting compilation..."

make -C "$TARGET_SOURCE" LOCALVERSION="${LVERSION}" -j"$(nproc)" bindeb-pkg KDEB_PKGVERSION="7.1.2"

echo -e "\n======================================================================"
echo "✅ SUCCESS: Gorilla Unleashed Kernel 7.1.2 built successfully!"
echo "======================================================================"
