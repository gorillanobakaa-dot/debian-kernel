# Gorilla Kernel 7.0.5-ULTIMATE: Technical Manual

## 🦍 Overview
The **Gorilla Kernel** is a custom upstream Linux kernel build, specifically tuned for maximum throughput and minimum latency on modern amd64 hardware. It incorporates performance patches, security hardening, and a highly optimized `.config`.

---

## 🏗️ Technical Specifications
- **Version**: 7.0.5
- **Suffix**: 7.0.5+Gorilla.Unleashed.Ultimate.20Gbps
- **Architecture**: amd64
- **Optimization Level**: `-O3 -march=ivybridge -mtune=ivybridge`
- **Scheduler**: NO_HZ_IDLE, optimized for interactive desktop performance on 4-core mobile CPUs.
- **Storage**: AHCI + BFQ optimized for Kingston DC600M Enterprise SSD.

---

## 📂 Included Components
- **`linux-image-*.deb`**: The main kernel binary and modules.
- **`linux-headers-*.deb`**: Headers for compiling out-of-tree modules.
- **`ULTIMATE_GORILLA_KERNEL.sh`**: Master build and orchestration script for local recompilation, network tuning, and kernel bloat excision.

---

## 🛠️ Operational Commands
### Installation
```bash
sudo dpkg -i linux-image-7.0.5+Gorilla.Unleashed.Ultimate.20Gbps_*_amd64.deb
sudo dpkg -i linux-headers-7.0.5+Gorilla.Unleashed.Ultimate.20Gbps_*_amd64.deb
```

### Build & Auto-Tuning
Execute the master script to build the kernel and apply runtime optimizations:
```bash
bash ULTIMATE_GORILLA_KERNEL.sh
```

### Verification
Check the active kernel version:
```bash
uname -a
```
Expected output includes: `7.0.5+Gorilla.Unleashed.Ultimate.20Gbps`

---

## 🎯 Key Optimizations
1.  **Wayland & GPU**: Direct rendering (KMS) tuned for Intel HD 4000 and AMD Radeon HD 7670M.
2.  **I/O Scheduler**: BFQ scheduler specifically targeted for SATA SSD performance.
3.  **Network Stack (20Gbps)**: TCP BBR, FQ, CAKE, and XDP Sockets for massive throughput.
4.  **Memory Management**: Strict TCP memory bounds for 16GB RAM to prevent kernel OOM under heavy load.
5.  **Total Hybridization**: Combines Gorilla Defense-in-Depth with Gorilla Excision.

---

## ⚖️ License
- **Kernel Core**: GNU General Public License v2.0.
- **Project Wrapper/Scripts**: MIT License.