# Patch Documentation: dell-pc.c
**File:** `drivers/platform/x86/dell/dell-pc.c`
**Subsystem:** Dell Laptop Platform Extras Driver (Thermal Management)
**Kernel:** Linux 7.1.2 (Gorilla Unleashed)

---

## Developer Track

### What This File Does (Upstream)
`dell-pc.c` coordinates laptop thermal profiles and fan modes on standard Dell architectures (like the Inspiron 7373) by routing kernel-level controls to Dell's System Management Mode (SMM) / SMBIOS class interfaces.

### What The Patch Changes

The patch modifies the initialization and probe phase in `thermal_platform_profile_probe()` to force the system's thermal mode to `DELL_PERFORMANCE` if it is supported by the SMBIOS layout.

**Key Implementations:**

```c
// Before:
/* Make sure that ACPI is in sync with the profile set by USTT */
current_mode = thermal_get_mode();
if (current_mode < 0)
    return current_mode;

thermal_set_mode(current_mode);

// After:
/* GORILLA: Force performance thermal profile on boot if supported */
if (supported_modes & DELL_PERFORMANCE) {
    thermal_set_mode(DELL_PERFORMANCE);
} else {
    current_mode = thermal_get_mode();
    if (current_mode >= 0)
        thermal_set_mode(current_mode);
}
```

If the Dell motherboard reports that it supports the high-performance thermal profile (indicated by `DELL_PERFORMANCE` set in `supported_modes`), the driver forces it active on startup. This configures the Dell SMM table to permit maximum CPU power limits and aggressive fan mapping.

---

## Layman Track

### What Does `dell-pc.c` Normally Do?

Your Dell Inspiron contains a System Management Mode (SMM) driver that manages cooling and fan speeds at the hardware level.

Normally, when you boot your laptop, the system synchronizes with whatever power mode was last requested, which usually defaults to a **Balanced power mode**. Under load, the 15W Core i7 processor heats up instantly, causing the system to throttle CPU clock speeds down to avoid loud fan noise.

### What The Patch Changes

This patch is the **Forced Dell Performance Mode on Boot**.

It tells the system to query the motherboard at startup, and if the **Performance thermal profile** is supported, it forces it active.

This overrides the conservative default, allowing the fan to react quickly to heat and permitting the CPU to draw full power without throttling early.

---

**Status in 7.1.2:** Staged and verified. Ready to compile.
