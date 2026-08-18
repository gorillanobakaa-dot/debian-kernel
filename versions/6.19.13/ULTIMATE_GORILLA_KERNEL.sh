#!/usr/bin/env bash
# ==============================================================================
# 🦍 ULTIMATE GORILLA KERNEL MASTER SCRIPT (v6.0)
# ==============================================================================
# Target: Sony SVE14A3AJ (i7-3632QM | Radeon HD 7670M | ALC269)
# Features: Baked-In Drivers, BBR+FQ+CAKE, +15dB Sound Boost, -march=native
# ==============================================================================

set -euo pipefail

# --- CONFIGURATION ---
KERNEL_VER="6.19.13"
THREADS=$(nproc)
WORKSPACE="${HOME}/kernel_build"
SRC_DIR="${WORKSPACE}/linux-${KERNEL_VER}"
DOCS_DIR="${HOME}/Documents"
AUTO_DIR="${DOCS_DIR}/gorilla_kernel_automation"
COUNTER_FILE="${AUTO_DIR}/build_counter.txt"

# --- VERSIONING ---
if [ ! -f "$COUNTER_FILE" ]; then echo 1 > "$COUNTER_FILE"; fi
BUILD_NUM=$(cat "$COUNTER_FILE")
NEXT_NUM=$((BUILD_NUM + 1))
echo "$NEXT_NUM" > "$COUNTER_FILE"
BUILD_ID="gorilla-ultimate-v${NEXT_NUM}-$(date +%Y%m%d)"

echo "🚀 GORILLA KERNEL ENGINE: DEPLOYING BUILD ${BUILD_ID}"

# 1. PREREQUISITES & SOURCE
mkdir -p "${WORKSPACE}"
cd "${WORKSPACE}"

if [ ! -d "${SRC_DIR}" ]; then
    echo "📦 Extracting kernel source..."
    if [ ! -f "linux-${KERNEL_VER}.tar.xz" ]; then
        curl -L "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VER}.tar.xz" -o "linux-${KERNEL_VER}.tar.xz"
    fi
    tar -xf "linux-${KERNEL_VER}.tar.xz"
fi

cd "${SRC_DIR}"

# 2. APPLY SOUND BOOST PATCH (+15dB Gain for ALC269)
echo "🔊 Patching ALC269 driver for HD Sound Boost..."
ALC_FILE="sound/hda/codecs/realtek/alc269.c"

# Only patch if not already present
if ! grep -q "alc269_fixup_sony_sve14" "$ALC_FILE"; then
    # Add fixup function
    sed -i '/static void alc269_fixup_hweq/,/^}/ { /^}/ a \
\
static void alc269_fixup_sony_sve14(struct hda_codec *codec, \
				  const struct hda_fixup *fix, int action) \
{ \
	alc269_fixup_hweq(codec, fix, action); \
	if (action == HDA_FIXUP_ACT_PRE_PROBE) { \
		snd_hda_override_amp_caps(codec, 0x02, HDA_OUTPUT, \
					  (0x30 << AC_AMPCAP_OFFSET_SHIFT) | \
					  (0x40 << AC_AMPCAP_NUM_STEPS_SHIFT) | \
					  (0x03 << AC_AMPCAP_STEP_SIZE_SHIFT) | \
					  (0 << AC_AMPCAP_MUTE_SHIFT)); \
	} \
}' "$ALC_FILE"

    # Add to enum
    sed -i '/ALC269_FIXUP_SONY_VAIO,/ a \	ALC269_FIXUP_SONY_SVE14,' "$ALC_FILE"

    # Add to fixup table
    sed -i '/\[ALC269_FIXUP_SONY_VAIO\] = {/,/^	},/ { /^	},/ a \
	[ALC269_FIXUP_SONY_SVE14] = { \
		.type = HDA_FIXUP_FUNC, \
		.v.func = alc269_fixup_sony_sve14, \
		.chained = true, \
		.chain_id = ALC269_FIXUP_SONY_VAIO \
	},' "$ALC_FILE"

    # Add PCI quirk
    sed -i '/SND_PCI_QUIRK(0x104d, 0x9073/ i \	SND_PCI_QUIRK(0x104d, 0x6200, "Sony SVE14A3AJ", ALC269_FIXUP_SONY_SVE14),' "$ALC_FILE"
    echo "✅ Sound patch applied successfully."
else
    echo "ℹ️ Sound patch already present, skipping."
fi

# 3. KERNEL CONFIGURATION (BAKED-IN + PERFORMANCE)
echo "⚙️ Configuring kernel features..."
if [ -f "${AUTO_DIR}/performance_tuned.config" ]; then
    cp "${AUTO_DIR}/performance_tuned.config" .config
else
    cp "/boot/config-$(uname -r)" .config
fi

force_y() { ./scripts/config --set-val "$1" y; }

# Core Hardware
force_y CONFIG_DRM_I915
force_y CONFIG_DRM_RADEON
force_y CONFIG_SND_HDA_INTEL
force_y CONFIG_EXT4_FS

# Network Tuning (BBR/FQ/CAKE)
force_y CONFIG_TCP_CONG_BBR
./scripts/config --set-val CONFIG_DEFAULT_TCP_CONG "bbr"
force_y CONFIG_NET_SCH_FQ
force_y CONFIG_NET_SCH_CAKE

# Versioning
./scripts/config --set-str CONFIG_LOCALVERSION "-${BUILD_ID}"

# Firmware Embedding
FW_LIST="radeon/TURKS_mc.bin radeon/TURKS_me.bin radeon/TURKS_pfp.bin radeon/TURKS_smc.bin"
./scripts/config --set-val CONFIG_EXTRA_FIRMWARE "$FW_LIST"
./scripts/config --set-val CONFIG_EXTRA_FIRMWARE_DIR "/lib/firmware"

make olddefconfig

# 4. COMPILATION
echo "🛠️ Starting build with -march=native (ID: ${BUILD_ID})..."
export KCFLAGS="-march=native"
export KDEB_PKGVERSION="6.19.13-${NEXT_NUM}"

# Ask for build type
read -p "🚀 Full clean build or quick incremental build? (f/Q): " build_type
if [[ "$build_type" =~ ^[Ff]$ ]]; then
    make clean
fi

make -j"${THREADS}" bindeb-pkg

# 5. INSTALLATION
echo "✅ Build complete. Packages are in ${WORKSPACE}."
RELEASE_DIR="${DOCS_DIR}/KERNEL_RELEASE_${KERNEL_VER}_v${NEXT_NUM}_$(date +%Y%m%d)"
mkdir -p "${RELEASE_DIR}"
mv "${WORKSPACE}"/*.deb "${RELEASE_DIR}/"

echo "📂 Packages organized in ${RELEASE_DIR}."
read -p "💾 Install the new kernel now? (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    sudo dpkg -i "${RELEASE_DIR}/linux-image-${KERNEL_VER}-${BUILD_ID}_${KDEB_PKGVERSION}_amd64.deb" \
                "${RELEASE_DIR}/linux-headers-${KERNEL_VER}-${BUILD_ID}_${KDEB_PKGVERSION}_amd64.deb"
    echo "🏁 DONE. Please reboot to activate the Gorilla Kernel."
fi
