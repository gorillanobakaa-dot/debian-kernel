# Patch Documentation: btcoex.c
**File:** `drivers/net/wireless/ath/ath9k/btcoex.c`
**Subsystem:** Atheros ath9k Bluetooth Coexistence Timing Control
**Kernel:** Linux 7.1.2 (Gorilla Unleashed)

---

## Developer Track

### What This File Does (Upstream)
`btcoex.c` handles the hardware register timing configurations for the 2-wire/3-wire Bluetooth Coexistence interface on the Atheros chip. It defines active/quiet airtime windows for both Wi-Fi (WLAN) and Bluetooth (BT) to prevent signal collision.

### What The Patch Changes

**Change — Maximize WLAN Active Airtime Registers:**
```c
// Before:
.wl_active_time = 0x20,
.wl_qc_time = 0x20,

// After:
.wl_active_time = 0xFF, /* GORILLA: Wi-Fi is the BOSS. Max airtime reserved for WLAN. */
.wl_qc_time = 0xFF,     /* GORILLA: Max Quiet Collision time for WLAN */
```
The patch targets the default `ath_bt_config` struct initialization parameters.
- `wl_active_time`: Increased from `0x20` (32 units) to `0xFF` (255 units, the absolute register maximum). This maximizes the scheduling window during which the hardware transceiver is locked to WLAN.
- `wl_qc_time` (WLAN Quiet Collision Time): Increased from `0x20` to `0xFF`. This overrides the collision resolution window parameters, giving WLAN maximum transmission preference in the hardware scheduler.

---

## Layman Track

### What Does `btcoex.c` Normally Do?

If `gpio.c` is the traffic cop, `btcoex.c` is the **stopwatch** that the cop uses to divide up the airtime.

Normally, the stopwatch is configured to slice the antenna time into equal shares (setting Wi-Fi time to `0x20` or 32 units). If both Wi-Fi and Bluetooth are active, they switch back and forth rapidly so both work.

### What The Patch Does

This patch **reprograms the stopwatch**.

It changes the Wi-Fi active time from the default 32 units to **255 units (the absolute maximum)**. This gives the Wi-Fi card a virtual monopoly over the antenna's airtime, leaving Bluetooth with only the microsecond crumbs.

### Trade-Offs

- **Wi-Fi benefit:** Maximizes Wi-Fi throughput and eliminates any latency spikes caused by Bluetooth sharing.
- **Bluetooth downside:** Same as `gpio.c` — if Wi-Fi is extremely busy, Bluetooth devices may lag or experience dropped packets. If Wi-Fi is idle, Bluetooth works normally.

---

**Status in 7.1.2:** Confirmed clean apply. Ready to port.
