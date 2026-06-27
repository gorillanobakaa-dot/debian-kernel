# Patch Documentation: hw.c
**File:** `drivers/net/wireless/ath/ath9k/hw.c`
**Subsystem:** Atheros ath9k Wi-Fi Hardware Abstraction Layer
**Kernel:** Linux 7.1.2 (Gorilla Unleashed)

---

## Developer Track

### What This File Does (Upstream)
`hw.c` is the hardware abstraction layer for the Atheros ath9k Wi-Fi driver. It initialises hardware configuration registers, manages channel switching, and enforces transmit power limits by querying the card's EEPROM calibration data and the regulatory power cap.

### What The Patch Changes

**Change 1 — Force 40MHz Channel Width (`cwm_ignore_extcca`):**
```c
// Before:
ah->config.cwm_ignore_extcca = false;
// After:
ah->config.cwm_ignore_extcca = true; /* GORILLA: UNLEASHED - Force 40MHz, ignore neighbors */
```
`cwm_ignore_extcca` controls whether the Channel Width Management (CWM) system respects the secondary channel's Clear Channel Assessment (CCA) signal. When `false` (default), if a neighbour's signal is detected on the secondary 40MHz channel, the card drops back to 20MHz. When `true`, the card ignores neighbour activity and stays at 40MHz.

**Change 2 — Maximum Transmit Power:**
```c
// Before:
chan_pwr = min_t(int, channel->max_power * 2, MAX_COMBINED_POWER);
new_pwr  = min_t(int, chan_pwr, reg->power_limit);
// After:
chan_pwr = MAX_COMBINED_POWER; /* GORILLA: UNLEASHED POWER */
new_pwr  = MAX_COMBINED_POWER; /* GORILLA: No limits. */
```
Bypasses both the channel's regulatory power cap (`channel->max_power`) and the regulatory domain power limit (`reg->power_limit`). Sets both to `MAX_COMBINED_POWER` — the hardware's absolute maximum, as defined in the EEPROM calibration data. The card will transmit at the maximum power its silicon is rated for.

---

## Layman Track

### What Does `hw.c` Normally Do?

The `hw.c` file is the **direct communication line** between the Linux kernel and your Atheros Wi-Fi chip. It programs the chip with its settings when it starts up and controls things like how wide a channel to use and how loud (powerful) the signal should be.

Normally, the kernel sets two conservative limits here:
1. It checks what channel width neighbours are using and politely narrows down to match them
2. It caps your transmit power at whatever your country's regulations say is the maximum

### What The Patch Does

**Forcing 40MHz (the "Two-Lane Highway" setting):**

Wi-Fi channels can be either 20MHz wide (a single lane) or 40MHz wide (two lanes bonded together). Wider = faster.

The normal kernel behaviour is cautious: if it detects another Wi-Fi network using the second lane, it gives up the second lane and goes back to single-lane mode to "be polite."

This patch disables that politeness. Your card **keeps both lanes regardless** of what other networks are doing. On a 2012 laptop in a house, you are very unlikely to have neighbours whose networks would actually suffer from this — and your connection speed stays consistently higher.

**Removing the Power Cap (the "Full Volume" setting):**

Every Wi-Fi card has a maximum transmit power — the loudest it can physically shout. Regulations typically tell the kernel to cap this at a lower level.

This patch bypasses that cap and tells the card to transmit at its **absolute hardware maximum** — the loudest it physically can. A stronger signal means a more stable connection, better range, and less packet loss — especially useful on a 14-year-old antenna.

### Trade-Offs

- Transmitting at maximum power exceeds regulatory limits in most countries. Same responsibility caveat as `reg.c`.
- Ignoring neighbour CCA (`cwm_ignore_extcca`) can cause more interference with nearby 2.4GHz networks in densely populated areas. In a house, typically unnoticeable.

---

**Status in 7.1.2:** Confirmed clean apply. Ready to port.
