# Patch Documentation: gpio.c
**File:** `drivers/net/wireless/ath/ath9k/gpio.c`
**Subsystem:** Atheros ath9k GPIO and Bluetooth Coexistence Stomping
**Kernel:** Linux 7.1.2 (Gorilla Unleashed)

---

## Developer Track

### What This File Does (Upstream)
`gpio.c` manages general-purpose input/output (GPIO) pins on the Atheros chip, which are used to control LEDs, RF switches, and the physical lines for Bluetooth Coexistence (determining priority between the Wi-Fi and Bluetooth antennas sharing the 2.4GHz spectrum).

### What The Patch Changes

**Change — Force Stomp Type to None (`ATH_BTCOEX_STOMP_NONE`):**
```c
// Before (test_bit scan block):
stomp_type = btcoex->bt_stomp_type;
...
if (test_bit(BT_OP_SCAN, &btcoex->op_flags)) {
    stomp_type = ATH_BTCOEX_STOMP_ALL;
    timer_period = btcoex->btscan_no_stomp;
}

// After:
stomp_type = ATH_BTCOEX_STOMP_NONE; /* GORILLA: Wi-Fi is the BOSS. Never yield to BT. */
...
if (test_bit(BT_OP_SCAN, &btcoex->op_flags)) {
    stomp_type = ATH_BTCOEX_STOMP_NONE; /* GORILLA: Even during scan, Wi-Fi rules */
    timer_period = btcoex->btscan_no_stomp;
}
```
In the upstream driver, when Bluetooth requests the antenna (e.g. during active device scanning or low-latency audio transmission), the driver will "stomp" (suppress and delay) Wi-Fi packets to prevent collision and allow Bluetooth transmission.

This patch overrides the coexistence engine, forcing `stomp_type` to `ATH_BTCOEX_STOMP_NONE` in all main logic paths. Wi-Fi transmissions are never suppressed or delayed, giving Wi-Fi absolute priority over Bluetooth.

---

## Layman Track

### What Does `gpio.c` Normally Do?

Because Wi-Fi and Bluetooth operate on the same 2.4GHz frequency, they can easily jam each other. The `gpio.c` file is the **traffic cop** that coordinates between the Wi-Fi and Bluetooth radios inside your laptop.

Normally, the traffic cop is fair: if your Bluetooth mouse or headset needs to scan for connections, the cop tells the Wi-Fi card to **pause transmitting** (this is called "stomping" the Wi-Fi) to let Bluetooth have a turn.

### What The Patch Does

This patch **fires the traffic cop's sense of fairness**. It tells the Wi-Fi card: **"You are the boss. Never yield to Bluetooth."**

Even if Bluetooth is scanning or sending data, the Wi-Fi card will refuse to pause. It keeps sending Wi-Fi data at full speed.

### Trade-Offs

- **Wi-Fi benefit:** Your Wi-Fi speeds and ping times stay completely smooth and lag-free, even if you are scanning for Bluetooth devices.
- **Bluetooth downside:** If you are actively using a Bluetooth mouse, keyboard, or headphones, they might experience minor stuttering or latency spikes while Wi-Fi is doing heavy downloads, because Wi-Fi is taking the airtime by force.

---

**Status in 7.1.2:** Confirmed clean apply. Ready to port.
