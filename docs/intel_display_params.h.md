# Patch Documentation: intel_display_params.h
**File:** `drivers/gpu/drm/i915/display/intel_display_params.h`
**Subsystem:** Intel Graphics (i915) Display Parameters Configuration
**Kernel:** Linux 7.1.2 (Gorilla Unleashed)

---

## Developer Track

### What This File Does (Upstream)
`intel_display_params.h` defines the macros and configurations for the module parameters of the Intel i915 Graphics Driver's display controller subsystem (such as Frame Buffer Compression, Panel Self Refresh, and DPT/DSB controls).

### What The Patch Changes

The patch modifies the default values of two parameters inside the `INTEL_DISPLAY_PARAMS_FOR_EACH()` macro definition:

**1. Enable Frame Buffer Compression (`enable_fbc`):**
```c
// Before:
param(int, enable_fbc, -1, 0600) \
// After:
param(int, enable_fbc, 1, 0600) \
```
Changes the default value from `-1` (auto-detect/disabled on older platforms) to `1` (force-enabled). Frame Buffer Compression (FBC) compresses the final rendered frame in memory, reducing memory bandwidth usage during display refreshes, which yields memory speed and power-efficiency improvements.

**2. Enable Low-Latency Nuclear Pageflip (`nuclear_pageflip`):**
```c
// Before:
param(bool, verbose_state_checks, true, 0400) \
param(bool, nuclear_pageflip, false, 0400) \
// After:
param(bool, verbose_state_checks, true, 0400) \
param(bool, nuclear_pageflip, true, 0400) \
```
Changes the default value from `false` to `true`. Nuclear Pageflip allows display updates to occur in a single atomic commit at the hardware driver level, minimizing synchronization delay, reducing latency, and eliminating graphic screen tearing under Wayland (GNOME 48).

---

## Layman Track

### What Does `intel_display_params.h` Normally Do?

The Intel display parameters file sets the **default graphic performance options** for the integrated Intel HD 4000 graphics chip.

Normally, the driver sets conservative settings for older hardware:
1. It disables or leaves Frame Buffer Compression (FBC) to auto-detect.
2. It disables Nuclear Pageflip (atomic screen updates).

### What The Patch Changes

This patch **optimizes the graphics engine for Wayland and GNOME**:

1.  **Frame Buffer Compression (FBC) Enabled (Power & Bandwidth Saver):**
    Compresses the pictures drawn on the screen inside the graphics memory. This cuts down on the amount of data the computer has to constantly write to memory, saving bandwidth and leaving the memory free for applications.
2.  **Nuclear Pageflip Enabled (Low Latency Screen Refreshes):**
    Allows the desktop environment (Wayland/GNOME) to send updates to the screen in a single, coordinated block. This eliminates micro-stuttering and screen tearing, making animations and window dragging feel buttery smooth.

---

**Status in 7.1.2:** Staged and verified. Ready to compile.
