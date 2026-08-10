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

# 3. Inject the AUDITED Build-1 change-set (decontaminated injector)
echo -e "\n💉 [Step 3/4] Injecting audited Gorilla config change-set..."
python3 "$SCRIPT_DIR/kernel_config_injector.py" "$TARGET_SOURCE"
make -C "$TARGET_SOURCE" olddefconfig

# 4. Trigger the optimized GCC compilation package build
echo -e "\n🛠️ [Step 4/4] Starting kernel compilation (bindeb-pkg)..."
# Safe, timestamped, 64-char-guarded LOCALVERSION (was a hand-tuned string with
# no length guard — the old name was 63/64 chars, one from breaking).
BASE_VER="7.1.2"
# Feature tags = the DISTINCTIVE badge of this build (edit to taste; the namer
# enforces the 64-char limit and drops trailing tags if needed).
LVERSION=$(python3 "$SCRIPT_DIR/kernel_build_namer.py" localversion \
             --base "$BASE_VER" \
             --tags unleashed gorilla forensic eapd sdr bbr) || exit 1

export KCFLAGS="-O3 -march=native -mtune=native -pipe"
echo "  Optimizations enabled: $KCFLAGS"
echo "  LOCALVERSION:          $LVERSION"
echo "  CPUs utilized:        $(nproc)"
echo "  Starting compilation..."

# Capture the REAL compiler exit, not tee's (directive §2: never trust a piped exit).
make -C "$TARGET_SOURCE" LOCALVERSION="${LVERSION}" -j"$(nproc)" bindeb-pkg KDEB_PKGVERSION="1"
BUILD_RC=$?
if [ "$BUILD_RC" -ne 0 ]; then
    echo "❌ Build FAILED (exit $BUILD_RC). Not moving artifacts."; exit "$BUILD_RC"
fi

echo -e "\n📦 [Step 5/5] Moving compiled binaries to the output directory..."
PARENT_DIR="$(dirname "$TARGET_SOURCE")"
DEST_DIR="$SCRIPT_DIR/output_binaries"
mkdir -p "$DEST_DIR"
mv "$PARENT_DIR"/linux-*{.deb,.buildinfo,.changes} "$DEST_DIR/" 2>/dev/null || true
# Strip redundant duplicated version + the '_1' KDEB_PKGVERSION tag, lowercase.
python3 "$SCRIPT_DIR/kernel_build_namer.py" cleandeb --base "$BASE_VER" --dir "$DEST_DIR"
# Verify the artifact exists (§2), don't just trust the success banner.
ls -1 "$DEST_DIR"/linux-image-*.deb >/dev/null 2>&1 \
    && echo "  verified: linux-image .deb present in $DEST_DIR" \
    || { echo "❌ No linux-image .deb produced — build did not deliver."; exit 1; }

echo -e "\n======================================================================"
echo "✅ SUCCESS: Gorilla Unleashed Kernel 7.1.2 built successfully!"
echo "📂 Binaries saved to: $DEST_DIR"
echo "======================================================================"
