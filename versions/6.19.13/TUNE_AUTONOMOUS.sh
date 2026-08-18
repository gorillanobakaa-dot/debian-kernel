#!/usr/bin/env bash
# ⚡ AUTONOMOUS ADVANCED TUNING PACK (2026 Edition)
# Hardware: Intel Core i7-3632QM | HD 4000 (IVB) | AMD 7670M | Kingston Enterprise SSD
# Target: Debian Trixie/Sid | GNOME 50 | Low-Latency Wayland

set -euo pipefail

# --- CONFIGURATION ---
KERNEL_VER="6.19.13"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VER}.tar.xz"
THREADS=$(nproc)
WORKSPACE="${HOME}/kernel_build"
DOCS_DIR="${HOME}/Documents"

echo "🚀 Starting Autonomous Tuning for Sony Vaio SVE14A3AJ..."

# --- 1. LOW-LATENCY DESKTOP STACK TUNING ---
echo "🧊 Tuning system for low-latency desktop responsiveness..."
sudo tee /etc/sysctl.d/99-latency.conf <<EOF
# Reduce swapping and reclaim cache aggressively for responsiveness
vm.swappiness=5
vm.vfs_cache_pressure=50
# Increase network backlog for high throughput
net.core.netdev_max_backlog=5000
# Optimize dirty ratios for SSD
vm.dirty_ratio=15
vm.dirty_background_ratio=5
EOF
sudo sysctl -p /etc/sysctl.d/99-latency.conf

# --- 2. GNOME + MUTTER GPU SCHEDULING ---
echo "🔥 Tuning GNOME/Mutter for maximum GPU scheduling performance..."
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/90-graphics.conf <<EOF
# Force GPU acceleration paths
CLUTTER_DEFAULT_FPS=60
MUTTER_DEBUG_FORCE_KMS_MODE=1
INTEL_DEBUG=nopreemption
GSK_RENDERER=ngl
EOF

# Disable animations for instant response
gsettings set org.gnome.desktop.interface enable-animations false

# --- 3. MONOLITHIC KERNEL COMPILATION ---
echo "🏗️ Building Monolithic Kernel ${KERNEL_VER} (NO MODULES)..."
cd "${WORKSPACE}"
if [ ! -f "linux-${KERNEL_VER}.tar.xz" ]; then
    curl -L "${KERNEL_URL}" -o "linux-${KERNEL_VER}.tar.xz"
fi
tar -xf "linux-${KERNEL_VER}.tar.xz"
cd "linux-${KERNEL_VER}"

# Use a highly tailored configuration for IVB GT2 and i7-3632QM
# We must include everything needed for boot as built-in (y)
make mrproper
cat > .config <<EOF
CONFIG_64BIT=y
CONFIG_X86_64=y
CONFIG_MCORE2=y
CONFIG_SMP=y
CONFIG_NR_CPUS=8
CONFIG_HZ_1000=y
CONFIG_HZ=1000
CONFIG_NO_HZ_FULL=y
CONFIG_PREEMPT_VOLUNTARY=n
CONFIG_PREEMPT=y
# --- MONOLITHIC: NO MODULES ---
CONFIG_MODULES=n
# --- HARDWARE DRIVERS (BUILT-IN) ---
CONFIG_SATA_AHCI=y
CONFIG_ATA=y
CONFIG_BLK_DEV_SD=y
CONFIG_EXT4_FS=y
CONFIG_FUSE_FS=y
CONFIG_DRM=y
CONFIG_DRM_I915=y
CONFIG_DRM_RADEON=y
CONFIG_DRM_AMDGPU=n
CONFIG_FB_RADEON=y
CONFIG_I2C=y
CONFIG_INPUT=y
CONFIG_INPUT_EVDEV=y
CONFIG_INPUT_KEYBOARD=y
CONFIG_INPUT_MOUSE=y
CONFIG_SND_HDA_INTEL=y
CONFIG_SND_HDA_CODEC_REALTEK=y
CONFIG_SND_HDA_CODEC_HDMI=y
CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE=y
CONFIG_X86_INTEL_PSTATE=y
# --- NETWORKING ---
CONFIG_NET=y
CONFIG_INET=y
CONFIG_UNIX=y
EOF

# Ensure all dependencies are met for our custom config
make olddefconfig

echo "🛠️ Compiling kernel as .deb packages with ${THREADS} threads..."
make -j"${THREADS}" bindeb-pkg

echo "✅ Kernel .deb packages generated in ${WORKSPACE}"

# Normally we'd install here, but we are just generating the success script for now.
# To install: sudo cp arch/x86/boot/bzImage /boot/vmlinuz-monolithic-${KERNEL_VER}

# --- 4. FFMPEG VA-API HARD TUNING ---
echo "🎥 Rebuilding FFmpeg for IVB GT2 (HD 4000) VA-API acceleration..."
cd "${WORKSPACE}"
if [ ! -d "FFmpeg" ]; then
    git clone --depth 1 https://github.com/FFmpeg/FFmpeg.git
fi
cd FFmpeg
./configure --prefix=/usr/local --enable-vaapi --enable-hwaccel=h264_vaapi --enable-hwaccel=mjpeg_vaapi \
            --enable-libx264 --enable-libx265 --enable-libvpx --enable-libfdk-aac --enable-libmp3lame --enable-libopus \
            --enable-nonfree --enable-gpl --arch=x86_64 --cpu=corei7
make -j"${THREADS}"
# Installation: sudo make install

echo "✅ SUCCESS: Autonomous Tuning and Build Complete."
cp "${WORKSPACE}/TUNE_AUTONOMOUS.sh" "${DOCS_DIR}/TUNE_AUTONOMOUS.sh"
chmod +x "${DOCS_DIR}/TUNE_AUTONOMOUS.sh"
echo "📄 Script copied to ${DOCS_DIR}/TUNE_AUTONOMOUS.sh"
