# 🦍 Gorilla Kernel Ultimate: Speed Restore Guide

## What is this?
Think of this as the **"Ultimate Engine"** for your Linux computer. This is a custom-built Linux Kernel (the core part of your operating system) that has been "supercharged" for maximum speed, security, and stability.

**Kernel Target Name**: `7.0.5+Gorilla.Unleashed.Ultimate.20Gbps+timestamp`

## What does it do for you?
Most kernels are built to be "one size fits all." The **Gorilla Kernel** is different:
1.  **Ultra-High Performance**: Optimized to make your computer feel faster and more responsive.
2.  **Ready-to-Install**: It comes as a simple package that you can install without knowing how to compile code.
3.  **Autonomous Tuning**: Includes scripts that automatically "tune" your system to get the most out of your hardware.

### ⚡ 7.0.5 Specific Hardware Tuning
- **AHCI & BFQ over NVMe**: The kernel optimizes I/O paths specifically for SATA AHCI and the BFQ scheduler, explicitly targeting the **Kingston DC600M SATA Enterprise SSD**. NVMe optimizations have been disabled.
- **NO_HZ_IDLE over NO_HZ_FULL**: We downgraded the tickless kernel configuration from `NO_HZ_FULL` to `NO_HZ_IDLE`. This was a necessary change to fix severe desktop latency and scheduling issues on the non-isolated 4-core mobile CPU (i7-3632QM).
- **16GB RAM Protection (TCP Memory Bounds)**: Implemented strict `tcp_mem` limits (`786432 1048576 1572864`) to prevent system lockups or crashes during extreme Deluge seeding alongside Wayland and heavy Web browser sessions (Telegram Web, WhatsApp Web).

## Why is it good to have?
- **Better Gaming/Work**: Lower latency means things happen exactly when you click.
- **Enhanced Security**: Hardened against common attacks.
- **Rock-Solid Stability**: Tested to ensure your system doesn't crash under heavy loads.

---

## 🚀 How to Install (One Command)
If you are using a Debian-based system (like the one this was built on), simply run the following command in this folder:

```bash
sudo dpkg -i linux-image-7.0.5+Gorilla.Unleashed.Ultimate.20Gbps_amd64.deb linux-headers-7.0.5+Gorilla.Unleashed.Ultimate.20Gbps_amd64.deb
```

After it finishes, **restart your computer**, and you will be running on the Gorilla Ultimate engine!
