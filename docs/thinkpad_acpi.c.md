# Patch Documentation: thinkpad_acpi.c
**File:** `drivers/platform/x86/lenovo/thinkpad_acpi.c`
**Subsystem:** Lenovo ThinkPad Platform ACPI Extras Driver
**Kernel:** Linux 7.1.2 (Gorilla Unleashed)

---

## Developer Track

### What This File Does (Upstream)
`thinkpad_acpi.c` interfaces with Lenovo's proprietary ACPI BIOS methods (SNC, SPIC, and DYTC Dynamic Thermal Control) to control Embedded Controller parameters (fan speeds, hotkeys, LEDs, and battery care thresholds).

### What The Patch Changes

The patch modifies the initialization function `tpacpi_dytc_profile_init()` to set the platform thermal profile to `PLATFORM_PROFILE_PERFORMANCE` by default on startup.

**Key Implementations:**

```c
// Before:
dytc_profile_refresh();

/* Workaround for https://bugzilla.kernel.org/show_bug.cgi?id=216347 */
if (dytc_capabilities & BIT(DYTC_FC_PSC))
    dytc_profile_set(NULL, PLATFORM_PROFILE_BALANCED);

// After:
dytc_profile_refresh();

/* GORILLA: Force performance thermal profile on boot for maximum power limits */
dytc_profile_set(NULL, PLATFORM_PROFILE_PERFORMANCE);
```

By bypassing the default power-saving / balanced profile settings during initialization, this patch forces the Lenovo Embedded Controller (EC) to configure Intel CPU thermal limits (PL1/PL2 thresholds) and fan cooling curves to maximum performance on boot.

---

## Layman Track

### What Does `thinkpad_acpi.c` Normally Do?

Your Lenovo ThinkPad has a specialized internal chip (Embedded Controller) that manages keyboard lighting, battery limits, and fan speeds.

Normally, when you boot your laptop, the system sets the **Balanced thermal profile**. To keep the laptop quiet and save battery, the controller throttles CPU power (slowing the processor down) before the fan has a chance to spin faster.

### What The Patch Changes

This patch is the **Forced ThinkPad Performance Mode on Boot**.

It overrides Lenovo's default startup settings and automatically configures the hardware to the **Performance profile** at boot.

This signals the Embedded Controller to unlock the processor's maximum power output limits and spin the cooling fan proactively when load begins, avoiding lag and thermal throttling on your Core i7 CPU.

---

**Status in 7.1.2:** Staged and verified. Ready to compile.
