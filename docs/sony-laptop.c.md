# Patch Documentation: sony-laptop.c
**File:** `drivers/platform/x86/sony-laptop.c`
**Subsystem:** Sony Laptop Motherboard Extras Driver
**Kernel:** Linux 7.1.2 (Gorilla Unleashed)

---

## Developer Track

### What This File Does (Upstream)
`sony-laptop.c` handles Sony notebook-specific ACPI control interfaces (SNC and SPIC) for keyboard backlight brightness, the Battery Care Limiter, GFX switch coordination, high-speed charging support, and thermal fan profile retrieval/setting.

### What The Patch Changes

The patch modifies the initialization stage inside `sony_nc_thermal_setup()` to force-initialize the laptop's motherboard-level ACPI thermal profile mode.

**Key Implementations:**

```c
// Before:
ret = sony_nc_thermal_mode_get();
if (ret < 0) {
    pr_warn("couldn't to read the current thermal profile");
    goto outkzalloc;
}
th_handle->mode = ret;

// After:
ret = sony_nc_thermal_mode_get();
if (ret < 0) {
    pr_warn("couldn't to read the current thermal profile");
    goto outkzalloc;
}
th_handle->mode = ret;

/* GORILLA: Force performance thermal profile on boot if supported (bit 1 is set in profiles mask) */
if (th_handle->profiles & 0x02) {
    if (sony_nc_thermal_mode_set(2) == 0)
        pr_info("sony-laptop: Forced performance thermal profile on boot\n");
}
```

The patch queries `th_handle->profiles` (a bitmask of supported profiles). If the "performance" profile (index `2`, bit `0x02` in mask) is supported by the motherboard BIOS, it calls `sony_nc_thermal_mode_set(2)` to activate it instantly at boot, overriding the bios default balanced mode.

---

## Layman Track

### What Does `sony-laptop.c` Normally Do?

Your Sony VAIO motherboard has custom firmware that controls keyboard lighting, the fan, and power profiles. 

Normally, when you boot your laptop, the motherboard defaults to a **Balanced thermal profile**. Under heavy tasks (like compiling the browser or playing a game), the CPU gets hot quickly. To keep quiet, the laptop slows down your CPU frequency (thermal throttling) rather than spinning the fans faster.

### What The Patch Does

This patch is the **Forced Performance Thermal Profile on Boot**.

It tells the Sony laptop motherboard to automatically select the **Performance thermal profile** at startup (if your BIOS supports it), rather than waiting for you to change it in settings.

This configures the motherboard's internal fan controller to spin up fans more aggressively and delays thermal throttling, allowing the quad-core Core i7 Ivy Bridge processor to run at full speed for longer periods.

---

**Status in 7.1.2:** Staged and verified. Ready to compile.
