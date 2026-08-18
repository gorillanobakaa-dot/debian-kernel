# 🧠 Technical Deep Dive: Gorilla Kernel 6.19.13-7-ULTIMATE

This document explains exactly what was modified in this kernel build, the implications of the optimizations used, and how to adapt this project for different hardware.

---

## 🛠️ Step-by-Step Build Logic

The build process follows these specific phases:

### 1. Source & Environment Preparation
- **Kernel Base**: Standard Upstream Linux 6.19.13.
- **Environment**: Compiled on Debian Trixie/Sid using `gcc`.

### 2. Hardware-Specific Patching (ALC269 Sound Boost)
The script `ULTIMATE_GORILLA_KERNEL.sh` performs a surgical injection into the kernel source:
- **File**: `sound/hda/codecs/realtek/alc269.c`
- **Action**: Injects a custom fixup function `alc269_fixup_sony_sve14`.
- **Effect**: Overrides amplifier capabilities (`snd_hda_override_amp_caps`) on Node `0x02` to provide a **+15dB Gain Boost**. This fixes the notoriously quiet speakers on Sony Vaio SVE series laptops.

### 3. Networking & Congestion Control (BBR + CAKE)
Instead of using standard Cubic or Reno as modules, this kernel bakes high-performance logic directly into the binary:
- **TCP BBR**: Google's "Bottleneck Bandwidth and Round-trip propagation time" congestion control is set as the default (`CONFIG_TCP_CONG_BBR=y`).
- **FQ & CAKE**: The "Fair Queuing" and "Common Applications Kept Enhanced" (CAKE) schedulers are built-in (`CONFIG_NET_SCH_CAKE=y`). This significantly reduces "bufferbloat" and improves latency under load.

### 4. Monolithic Drivers & Firmware Embedding
- **Built-in Graphics**: `CONFIG_DRM_I915` and `CONFIG_DRM_RADEON` are set to `y` (Built-in) rather than `m` (Module).
- **Baked-in Firmware**: To ensure the GPU initializes instantly without waiting for an initrd, the Radeon firmware (`TURKS_mc.bin`, etc.) is embedded directly into the kernel image via `CONFIG_EXTRA_FIRMWARE`.

---

## ⚠️ The `-march=native` Warning

**CRITICAL**: This specific build was compiled with the flag `KCFLAGS="-march=native"`.

### What does this mean?
When using `-march=native`, the compiler (GCC) detects the exact instruction set of the processor performing the build (in this case, an **Intel i7-3632QM Ivy Bridge**). It then optimizes the code specifically for that chip, utilizing instructions like AVX, F16C, and specific pipeline timings.

### The Risk
If you try to install these `.deb` packages on a different processor (e.g., an AMD Ryzen or a newer/older Intel chip), the kernel may **Kernel Panic** or exhibit illegal instruction errors immediately upon boot because it tries to use hardware features that don't exist or behave differently on your CPU.

---

## 🛠️ How to Adapt for YOUR Processor

If you want to replicate this build for your own hardware, follow these steps:

### 1. Modify `ULTIMATE_GORILLA_KERNEL.sh`
Open the script and locate the **Compilation** section (around line 105).

**Change this:**
```bash
export KCFLAGS="-march=native"
```
**To your specific architecture:**
- For generic compatibility: `export KCFLAGS="-march=x86-64-v3"` (Works on most modern CPUs).
- For your own machine: Keep it as `native` but **run the script on your target machine**.

### 2. Update Firmware (If not using Radeon)
If you do not have a Radeon GPU, you should comment out or update the firmware list to avoid build errors.
**Locate:**
```bash
FW_LIST="radeon/TURKS_mc.bin radeon/TURKS_me.bin radeon/TURKS_pfp.bin radeon/TURKS_smc.bin"
./scripts/config --set-val CONFIG_EXTRA_FIRMWARE "$FW_LIST"
```
**Action**: If you have an NVIDIA or Intel-only setup, comment these lines out or replace them with your specific microcode/firmware.

### 3. Disable the Sound Patch (If not a Sony Vaio)
If you are not using a Sony SVE14 laptop, the sound patch will not harm you (it's triggered by a PCI Subsystem ID check), but it's cleaner to remove it.
**Action**: Comment out the "APPLY SOUND BOOST PATCH" block (Section 2 in the script).

### 4. Adjust the Config Base
The script looks for `performance_tuned.config`. If your hardware is significantly different:
1. Run `make localmodconfig` first to detect your modules.
2. Use that as your base `.config` instead of the one provided in this package.
