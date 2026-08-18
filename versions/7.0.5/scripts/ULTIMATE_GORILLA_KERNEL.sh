#!/usr/bin/env bash
# ==============================================================================
# 🦍 ULTIMATE GORILLA KERNEL MASTER SCRIPT (v6.1 - FIXED)
# ==============================================================================
# Target: Sony SVE14A3AJ (i7-3632QM | Radeon HD 7670M | ALC269)
# Features: Baked-In Drivers, BBR+FQ+CAKE, +40dB Sound Boost, -march=native
# Fixes: Resolved Implicit Declaration and Model Array Corruption
# ==============================================================================

set -euo pipefail

# --- CONFIGURATION ---
KERNEL_VER="7.0.5"
THREADS=$(nproc)
WORKSPACE="${HOME}/kernel_build"
SRC_DIR="${WORKSPACE}/linux-${KERNEL_VER}"
DOCS_DIR="${HOME}/Documents"
AUTO_DIR="${DOCS_DIR}/gorilla_kernel_automation"
COUNTER_FILE="${AUTO_DIR}/build_counter.txt"

# --- VERSIONING ---
mkdir -p "$AUTO_DIR"
if [ ! -f "$COUNTER_FILE" ]; then echo 1 > "$COUNTER_FILE"; fi
BUILD_NUM=$(cat "$COUNTER_FILE")
NEXT_NUM=$((BUILD_NUM + 1))
echo "$NEXT_NUM" > "$COUNTER_FILE"
BUILD_ID="7.0.5+gorilla-unleashed-ultimate-20gbps+$(date +%Y%m%d)"

echo "🚀 GORILLA KERNEL ENGINE: DEPLOYING BUILD ${BUILD_ID}"

# 1. PREREQUISITES & SOURCE
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

echo "📦 Checking and installing required dependencies..."
if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -yqq || true
    sudo apt-get install -yqq build-essential libncurses-dev bison flex libssl-dev libelf-dev bc rsync kmod cpio curl tar sccache || true
else
    echo "⚠️ apt-get not found. Please ensure kernel dependencies are installed."
fi

mkdir -p "${WORKSPACE}"
cd "${WORKSPACE}"

TAR_FILE="linux-${KERNEL_VER}.tar.xz"
if [ ! -d "${SRC_DIR}" ]; then
    echo "📦 Locating kernel source..."
    
    if [ -f "${SCRIPT_DIR}/${TAR_FILE}" ]; then
        echo "✅ Found in SCRIPT_DIR. Linking..."
        ln -sf "${SCRIPT_DIR}/${TAR_FILE}" "${WORKSPACE}/${TAR_FILE}"
    elif [ -f "${WORKSPACE}/${TAR_FILE}" ]; then
        echo "✅ Found in WORKSPACE."
    elif [ -f "${HOME}/Downloads/${TAR_FILE}" ]; then
        echo "✅ Found in Downloads. Linking..."
        ln -sf "${HOME}/Downloads/${TAR_FILE}" "${WORKSPACE}/${TAR_FILE}"
    elif [ -f "${HOME}/Documents/${TAR_FILE}" ]; then
        echo "✅ Found in Documents. Linking..."
        ln -sf "${HOME}/Documents/${TAR_FILE}" "${WORKSPACE}/${TAR_FILE}"
    else
        echo "🌐 Not found locally. Downloading..."
        curl -L "https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_VER%%.*}.x/${TAR_FILE}" -o "${TAR_FILE}"
    fi
    
    echo "📦 Extracting kernel source..."
    tar -xf "${TAR_FILE}"
fi

cd "${SRC_DIR}"

# 2. APPLY SOUND BOOST PATCH (+40dB Gain for ALC269)
echo "🔊 Patching ALC269 driver for 40dB HD Sound Boost..."
ALC_FILE="sound/hda/codecs/realtek/alc269.c"

# CLEANUP: Always restore from tarball first to fix potential previous corruption
echo "🧹 Restoring clean alc269.c from tarball to ensure surgical accuracy..."
tar -xf "${WORKSPACE}/${TAR_FILE}" -C "${WORKSPACE}" "linux-${KERNEL_VER}/${ALC_FILE}"

python3 -c '
import sys
f = sys.argv[1]
with open(f, "r") as file: content = file.read()

# 1. Insert function AFTER alc269_fixup_hweq to avoid implicit declaration error
func_code = """
static void alc269_fixup_sony_sve14(struct hda_codec *codec,
				  const struct hda_fixup *fix, int action)
{
	alc269_fixup_hweq(codec, fix, action);
	if (action == HDA_FIXUP_ACT_PRE_PROBE) {
		snd_hda_override_amp_caps(codec, 0x02, HDA_OUTPUT,
					  (0x7F << AC_AMPCAP_OFFSET_SHIFT) |
					  (0x7F << AC_AMPCAP_NUM_STEPS_SHIFT) |
					  (0x03 << AC_AMPCAP_STEP_SIZE_SHIFT) |
					  (0 << AC_AMPCAP_MUTE_SHIFT));
	}
}
"""
# Find the end of alc269_fixup_hweq definition
marker = "alc_update_coef_idx(codec, 0x1e, 0, 0x80);\n}"
if marker in content:
    content = content.replace(marker, marker + func_code)
else:
    print("❌ ERROR: Could not find alc269_fixup_hweq marker!")
    sys.exit(1)

# 2. Add to enum (surgical - matching the tab indentation to avoid array corruption)
if "\n\tALC269_FIXUP_SONY_VAIO," in content:
    content = content.replace("\n\tALC269_FIXUP_SONY_VAIO,", "\n\tALC269_FIXUP_SONY_VAIO,\n\tALC269_FIXUP_SONY_SVE14,")
else:
    # Fallback to 8 spaces if tabs are converted or missing
    content = content.replace("\n        ALC269_FIXUP_SONY_VAIO,", "\n        ALC269_FIXUP_SONY_VAIO,\n        ALC269_FIXUP_SONY_SVE14,")

# 3. Add to fixup table (surgical)
fixup_marker = "static const struct hda_fixup alc269_fixups[] = {"
fixup_entry = """
	[ALC269_FIXUP_SONY_SVE14] = {
		.type = HDA_FIXUP_FUNC,
		.v.func = alc269_fixup_sony_sve14,
		.chained = true,
		.chain_id = ALC269_FIXUP_SONY_VAIO
	},"""
if fixup_marker in content:
    content = content.replace(fixup_marker, fixup_marker + fixup_entry)

# 4. Add PCI Quirk
quirk_marker = "SND_PCI_QUIRK(0x104d, 0x9073"
if quirk_marker in content:
    content = content.replace(quirk_marker, "SND_PCI_QUIRK(0x104d, 0x6200, \"Sony SVE14A3AJ\", ALC269_FIXUP_SONY_SVE14),\n\t" + quirk_marker)

with open(f, "w") as file: file.write(content)
' "$ALC_FILE"
echo "✅ Surgical sound patch applied successfully (Fixed Implicit Declaration & Array Corruption)."

# 3. KERNEL CONFIGURATION (BAKED-IN + PERFORMANCE)
echo "⚙️ Configuring kernel features..."
if [ -f "${AUTO_DIR}/performance_tuned.config" ]; then
    cp "${AUTO_DIR}/performance_tuned.config" .config
else
    cp "/boot/config-$(uname -r)" .config
fi

force_y() { ./scripts/config --set-val "$1" y; }

# Core Hardware
force_y CONFIG_EXT4_FS
force_y CONFIG_SND_HDA_INTEL

# CPU / Scheduling
./scripts/config --disable GENERIC_CPU
./scripts/config --enable MIVYBRIDGE
./scripts/config --set-val NR_CPUS 8
./scripts/config --enable HZ_1000
./scripts/config --enable NO_HZ_IDLE
./scripts/config --disable NO_HZ_FULL
./scripts/config --enable PREEMPT_DYNAMIC
./scripts/config --enable TRANSPARENT_HUGEPAGE_ALWAYS

# Storage & Filesystems
./scripts/config --enable ATA
./scripts/config --enable SATA_AHCI
./scripts/config --enable IOSCHED_BFQ
./scripts/config --set-str DEFAULT_IOSCHED bfq
./scripts/config --module BLK_DEV_NVME
./scripts/config --enable XFS_FS
./scripts/config --enable HUGETLBFS
./scripts/config --enable COMPACTION

# Graphics
./scripts/config --enable DRM
./scripts/config --enable DRM_I915
./scripts/config --enable DRM_RADEON
./scripts/config --disable DRM_AMDGPU

# Power & Virtualization
./scripts/config --enable CPU_FREQ
./scripts/config --enable CPU_IDLE
./scripts/config --enable X86_INTEL_PSTATE
./scripts/config --enable KVM
./scripts/config --enable KVM_INTEL

# IRQ Handling
./scripts/config --enable IRQ_TIME_ACCOUNTING
./scripts/config --enable IRQ_FORCED_THREADING

# Networking & TLS
./scripts/config --enable NET
./scripts/config --enable INET
./scripts/config --enable TLS
./scripts/config --enable TLS_DEVICE
./scripts/config --enable TCP_CONG_ADVANCED
./scripts/config --enable TCP_CONG_BBR
./scripts/config --set-str DEFAULT_TCP_CONG bbr
./scripts/config --enable NET_SCH_FQ
./scripts/config --set-str DEFAULT_NET_SCH fq
./scripts/config --enable BPF
./scripts/config --enable BPF_JIT
./scripts/config --enable XDP_SOCKETS
./scripts/config --enable PAGE_POOL
./scripts/config --enable NET_RX_BUSY_POLL
./scripts/config --enable RPS
./scripts/config --enable RFS_ACCEL
./scripts/config --enable XPS
./scripts/config --enable BQL
./scripts/config --enable MPTCP
force_y CONFIG_NET_SCH_CAKE

# High-Speed Network Cards (20Gbps / Mellanox / Intel 10G/40G)
./scripts/config --enable E1000E
./scripts/config --enable IXGBE
./scripts/config --enable I40E
./scripts/config --enable MLX4_EN
./scripts/config --enable MLX5_CORE

# IPsec & Crypto
./scripts/config --enable XFRM
./scripts/config --enable INET_ESP
./scripts/config --enable INET_ESP_OFFLOAD
./scripts/config --enable CRYPTO_AES_NI_INTEL
./scripts/config --enable CRYPTO_CHACHA20_X86_64

# Security / Debugging
./scripts/config --enable STACKPROTECTOR
./scripts/config --enable STACKPROTECTOR_STRONG
./scripts/config --disable DEBUG_KERNEL
./scripts/config --disable KASAN
./scripts/config --disable UBSAN
./scripts/config --disable KCSAN
./scripts/config --disable FTRACE
./scripts/config --disable MITIGATE_SPECTRE_BRANCH_HISTORY

# Versioning
./scripts/config --set-str CONFIG_LOCALVERSION "-${BUILD_ID}"

# Firmware Embedding
FW_LIST="radeon/TURKS_mc.bin radeon/TURKS_me.bin radeon/TURKS_pfp.bin radeon/TURKS_smc.bin"
./scripts/config --set-str CONFIG_EXTRA_FIRMWARE "$FW_LIST"
./scripts/config --set-str CONFIG_EXTRA_FIRMWARE_DIR "/lib/firmware"

make olddefconfig

# 3.5. SYSCTL CONFIGURATION FOR 20Gbps
echo "🔧 Generating sysctl configuration for 20Gbps..."
cat << 'EOF' > "${WORKSPACE}/99-gorilla-20gbps.conf"
net.ipv4.tcp_mem = 786432 1048576 1572864 
net.ipv4.tcp_rmem = 8192 87380 268435456
net.ipv4.tcp_wmem = 8192 65536 268435456
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.core.optmem_max = 67108864
net.netfilter.nf_conntrack_max = 2000000
net.core.netdev_max_backlog = 250000
net.core.dev_weight = 64
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_notsent_lowat = 131072
net.ipv4.tcp_adv_win_scale = 1
net.ipv4.tcp_window_scaling = 1
EOF

# 4. COMPILATION
echo "🛠️ Starting build with -march=ivybridge (ID: ${BUILD_ID})..."
export KCFLAGS="-O3 -march=ivybridge -mtune=ivybridge"
export KDEB_PKGVERSION="${KERNEL_VER}-${NEXT_NUM}"
export KBUILD_BUILD_USER="gorilla"
export KBUILD_BUILD_HOST="gorilla-systems"

# Determine Compiler Cache (Force sccache)
COMPILER_PREFIX=""
if command -v sccache >/dev/null 2>&1; then
    echo "⚡ Detected sccache. Enabling compilation caching."
    COMPILER_PREFIX="sccache "
else
    echo "⚠️ sccache not found. Compilation will be slower."
fi

# Fully Autonomous execution (no prompts)
if [ "${1:-}" == "--clean" ]; then
    echo "🧹 Clean build requested..."
    make clean
fi

make -j8 CC="${COMPILER_PREFIX}gcc" bindeb-pkg

# 5. PACKAGING & SEPARATION
echo "✅ Build complete. Organising kernel packages separately."
RELEASE_DIR="${SCRIPT_DIR}/KERNEL_RELEASE_${KERNEL_VER}_v${NEXT_NUM}_$(date +%Y%m%d)"
mkdir -p "${RELEASE_DIR}"
mv "${WORKSPACE}"/*.deb "${RELEASE_DIR}/"
cp "${WORKSPACE}/99-gorilla-20gbps.conf" "${RELEASE_DIR}/"

# Create a 1-click install script inside the release folder
cat << 'EOF_INSTALL' > "${RELEASE_DIR}/INSTALL_GORILLA_KERNEL.sh"
#!/usr/bin/env bash
set -euo pipefail
echo "🦍 Gorilla Kernel 1-Click Installer"
echo "===================================="
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
cd "${SCRIPT_DIR}"
echo "📦 Installing Kernel Packages separately..."
sudo dpkg -i *.deb
echo "🔧 Applying 20Gbps Network Tunings..."
sudo cp 99-gorilla-20gbps.conf /etc/sysctl.d/
sudo sysctl --system
echo "🏁 DONE. Please reboot your machine to activate the Gorilla Kernel."
EOF_INSTALL
chmod +x "${RELEASE_DIR}/INSTALL_GORILLA_KERNEL.sh"

echo "📂 Packages and Installer organized in ${RELEASE_DIR}."
echo "💾 Auto-installing the new kernel and sysctl config..."
sudo dpkg -i "${RELEASE_DIR}"/linux-image-*.deb "${RELEASE_DIR}"/linux-headers-*.deb
sudo cp "${RELEASE_DIR}/99-gorilla-20gbps.conf" /etc/sysctl.d/
sudo sysctl --system
echo "🏁 DONE. Please reboot to activate the Gorilla Kernel."
