# Gorilla Unleashed: Optimized Linux Kernel 7.1.2

Welcome to the **Gorilla Unleashed Kernel** repository. This project distributes a highly optimized, custom-compiled Linux 7.1.2 kernel tailored for 2012-era Sony VAIO SVE14A3AJ hardware (and compatible systems).

This documentation is written in **dual-track language**:
*   **Section A: For the Layman** — Simple English, everyday analogies, and the project philosophy.
*   **Section B: For the Developer** — Exact code symbols, file mappings, registers, and technical rationale.

---

## Section A: For the Layman 🧸

### 1. The Core Philosophy
Computers are often shipped to users with artificial limits built into their software. These limits are designed to protect the "average case" or satisfy conservative government regulations. But your computer belongs to **you**. You should be able to run it at its full physical capacity.

The Gorilla Unleashed project is built on the belief that **sharing is caring** and that true open-source philosophy means making technology educational and accessible to everyone. We explain *how* and *why* things work in language that anyone's brain can process, giving power back to the user.

### 2. Chronological Overview & Real-Life Impact
We began our optimization journey on Kernel 7.0.9 and have successfully ported all features to the modern **Kernel 7.1.2** baseline. Here is the chronological development sequence and the real-world impact of each change on your machine:

1.  **Audio Amplifier Boost (Ear-Saver & Speaker Maximizer)**:
    *   *The Problem*: The Sony VAIO motherboard has an extremely quiet sound chip (ALC269). At the same time, Linux attenuates the volume at the driver level by -9dB (clamping the garden hose).
    *   *The Analogy*: Think of your audio stream as water flowing through a hose. The software volume slider is the faucet handle, and the kernel hardware ceiling is a clamp on the hose itself. Even with the faucet at 100%, you only get a trickle.
    *   *The Fix*: We "unclamped" the hose by overriding the physical sound chip's power limits. We also built a digital compressor (like a trampoline) that keeps quiet sounds (whispers) loud and clear while preventing loud sounds from rattling the laptop's plastic casing.
2.  **Wi-Fi Freedom & Speed Boost (The Traffic Bypass)**:
    *   *The Problem*: Regulations restrict Wi-Fi cards from using certain channels, limit their transmit volume (power), and force them to slow down to "be polite" to neighbors.
    *   *The Analogy*: Normally, if a neighbor's car is in the lane next to you, the computer forces you to drop from a two-lane highway to a one-lane road.
    *   *The Fix*: We configured the Wi-Fi card to ignore neighbor congestion and stay on the fast "two-lane highway" (40MHz channel bonding). We also turned up the Wi-Fi card's transmitter power to its absolute hardware maximum, meaning better range and no dropped connections through walls.
3.  **Wi-Fi & Bluetooth Harmony (Airtime Monopoly)**:
    *   *The Problem*: Wi-Fi and Bluetooth share the same 2.4GHz antenna. Normally, the system pauses Wi-Fi to let Bluetooth take a turn.
    *   *The Fix*: We declared **Wi-Fi is the boss**. The card will never pause Wi-Fi transmission for Bluetooth. Wi-Fi gets 255 out of 255 units of airtime, eliminating Wi-Fi stutter while gaming or streaming.
4.  **Instant Network Loading (Super-sized Data Pipes)**:
    *   *The Problem*: When downloading files, the computer stores data in small memory holding areas (buffers). Tiny buffers throttle your speed.
    *   *The Fix*: We replaced the default narrow buffer hoses with massive **16MB to 64MB water mains**. We also set initial packet bursts to **128 packets** instead of 10, meaning webpages load instantly.
5.  **Ultra-Fast Reflexes (The Short Stopwatch)**:
    *   *The Problem*: If a packet of data is lost, the kernel waits up to 2 seconds to try again, causing a freeze.
    *   *The Fix*: We shortened the stopwatch. The kernel now waits only **10 milliseconds** (0.01 seconds) to resend lost packets, making web browsing feel incredibly snappy.
6.  **Forced High-Performance Power Limit (Cooler running under load)**:
    *   *The Problem*: Sony motherboard defaults to a "balanced" profile that throttles the CPU speed aggressively to avoid heat.
    *   *The Fix*: We reprogrammed the driver to force-enable the motherboard's **Performance thermal profile** at startup, allowing fans to run aggressively and keeping the CPU from slowing down under load.
7.  **Smooth Display & Low-Latency Rendering (Wayland Optimization)**:
    *   *The Problem*: Screen refreshes and page flips have minor sync delays, causing visual lag and tearing.
    *   *The Fix*: We enabled **Frame Buffer Compression** to save memory speed, and force-enabled **Nuclear Pageflip** so Wayland renders display updates in a single atomic sweep, making animations feel buttery smooth.
8.  **Forced High-Performance Mode for Lenovo & Dell Laptops (Universal Power Optimization)**:
    *   *The Problem*: Lenovo and Dell systems default to a "balanced" profile that throttles CPU speeds aggressively under heavy tasks to control fan noise.
    *   *The Fix*: We reprogrammed the drivers to automatically select the **Performance thermal profile** at boot. This tells the Embedded Controller to unlock maximum CPU power limits (PL1/PL2 thresholds) and spin the fans proactively, preventing early thermal throttling.

---

## Section B: For the Developer 💻

### 1. Cohesive Tweak Catalog

This kernel applies a total of **11 modified file targets** with a strict set of custom enhancements:

#### 1. Audio Driver: [sound/hda/codecs/realtek/alc269.c](file:///sound/hda/codecs/realtek/alc269.c) (Clean / Reverted to Pristine)
*   **Architectural Change**: Reverted to clean upstream status. We removed the legacy hardcoded $+60\text{ dB}$ gain table hack to avoid speaker blowout and chassis buzzing.
*   **EAPD Power Fix**: Unlocking motherboard speaker output is instead achieved cleanly by configuring `CONFIG_SND_HDA_PATCH_LOADER=y` to force-power the physical motherboard amplifier (EAPD pin) on boot, paired with Firefox's software compand DSP.

#### 2. Wireless Regulatory Engine: [net/wireless/reg.c](file:///net/wireless/reg.c) (21 Tweaks)
*   **Flag Stripping (13 Tweaks)**: Disables regulatory flags by ORing with `0` instead of the restriction flags inside `map_regdom_flags()` (bypasses `NO_IR`, `DFS`, `INDOOR_ONLY`, `NO_HT40`, `NO_80MHZ`, `NO_160MHZ`, `NO_320MHZ`, `NO_HE`, `NO_EHT`, `PSD`, etc.).
*   **Radar Bypass (4 Tweaks)**: Strips DFS Dynamic Frequency Selection wait loops in 4 locations by bypassing `IEEE80211_CHAN_RADAR` checks.
*   **Disabled Channel Bypass (4 Tweaks)**: Strips `IEEE80211_CHAN_DISABLED` logic, forcing all physically supported channels to remain enabled.

#### 3. Wi-Fi Hardware Abstraction: [drivers/net/wireless/ath/ath9k/hw.c](file:///drivers/net/wireless/ath/ath9k/hw.c) (3 Tweaks)
*   **Force 40MHz**: Sets `ah->config.cwm_ignore_extcca = true` to force 40MHz channel bonding, ignoring secondary channel CCA.
*   **Max Combined Power**: Overrides target channel transmit power limits and configures both `chan_pwr` and `new_pwr` to `MAX_COMBINED_POWER`.

#### 4. Wi-Fi Driver Init: [drivers/net/wireless/ath/ath9k/init.c](file:///drivers/net/wireless/ath/ath9k/init.c) (3 Tweaks)
*   **Software Decryption Force**: Sets `ath9k_modparam_nohwcrypt = 1` by default to handle cryptography on the CPU, bypassing buggy Atheros hardware crypto engines.
*   **Forced Coexistence**: Sets `ath9k_btcoex_enable = 1` to ensure Bluetooth coexistence is enabled at startup.
*   **Startup TX Power**: Forces active startup transmit power limits to `MAX_COMBINED_POWER`.

#### 5. Wi-Fi Coexistence Decisions: [drivers/net/wireless/ath/ath9k/gpio.c](file:///drivers/net/wireless/ath/ath9k/gpio.c) (2 Tweaks)
*   **No Stomping**: Overrides `stomp_type` decisions inside `ath_btcoex_decide_stomp()` and active scanning loops, forcing them to `ATH_BTCOEX_STOMP_NONE` so Wi-Fi never yields to Bluetooth signals.

#### 6. Wi-Fi Airtime Configuration: [drivers/net/wireless/ath/ath9k/btcoex.c](file:///drivers/net/wireless/ath/ath9k/btcoex.c) (2 Tweaks)
*   **Airtime Priority**: Configures `wl_active_time` and `wl_qc_time` hardware registers to `0xFF` (maximum) to guarantee Wi-Fi gets maximum priority in the coexistence scheduler.

#### 7. TCP Buffers: [net/ipv4/tcp.c](file:///net/ipv4/tcp.c) (5 Tweaks)
*   **Congestion Window Clamp**: Sets `snd_cwnd_clamp` to `65535` packets on startup.
*   **Buffer Expansion**: Sets system-wide TCP default write/read buffer size (`sysctl_tcp_wmem[1]` & `sysctl_tcp_rmem[1]`) to **16MB** (`16777216`) and maximum bounds to **64MB** (`67108864`).

#### 8. TCP Timers: [include/net/tcp.h](file:///include/net/tcp.h) (11 Tweaks)
*   **RTO & Retries**: Caps maximum Retransmission Timeout (`TCP_RTO_MAX_SEC`) at 3 seconds, sets min RTO (`TCP_RTO_MIN`) to `HZ/100` (10ms), and initial RTO (`TCP_TIMEOUT_INIT`) to `HZ/10` (100ms).
*   **Port Reuse**: Sets `TCP_TIMEWAIT_LEN` to `1*HZ` (1 second) to recycle local ports instantly.
*   **Delayed ACK acceleration**: Lowers `TCP_DELACK_MAX` to `HZ/50` (20ms) and sets minimums to 2 jiffies.
*   **Initial CWND**: Increases `TCP_INIT_CWND` to 128 packets.

#### 9. Sony Motherboard Extras: [drivers/platform/x86/sony-laptop.c](file:///drivers/platform/x86/sony-laptop.c) (1 Tweak)
*   **Forced Performance Thermal Mode**: Overrides default startup SNC thermal profile to force-set performance mode (`mode = 2`) if it is listed in the BIOS capability mask.

#### 10. Intel GPU Display Parameters: [drivers/gpu/drm/i915/display/intel_display_params.h](file:///drivers/gpu/drm/i915/display/intel_display_params.h) (2 Tweaks)
*   **Frame Buffer Compression**: Changes `enable_fbc` default value to `1` (forced enabled).
*   **Nuclear Pageflip**: Changes `nuclear_pageflip` default value to `true` (forced enabled).

#### 11. Lenovo ThinkPad Extras: [drivers/platform/x86/lenovo/thinkpad_acpi.c](file:///drivers/platform/x86/lenovo/thinkpad_acpi.c) (1 Tweak)
*   **Forced Performance Profile**: Overrides initialization phase to automatically set the thermal profile to performance mode (`PLATFORM_PROFILE_PERFORMANCE`) on startup.

#### 12. Dell Laptop Extras: [drivers/platform/x86/dell/dell-pc.c](file:///drivers/platform/x86/dell/dell-pc.c) (1 Tweak)
*   **Forced Performance Profile**: Overrides the probe phase to automatically force the Dell PC thermal mode to performance (`DELL_PERFORMANCE`) at startup if supported.

---

## Build and Install

### Local One-Click Build
Run the master build script to automatically patch the source and trigger the optimized GCC compilation:
```bash
chmod +x recreate_success.sh
./recreate_success.sh /path/to/linux-7.1.2
```

### GitHub Actions Auto-Builder
This repository includes a `.github/workflows/build-kernel.yml` workflow. On every push to the `main` branch, the workflow:
1.  Fetches upstream pristine kernel 7.1.2 sources.
2.  Applies our custom patches using `universal_freedom_installer.py`.
3.  Injects the configuration using `config_injector.py`.
4.  Compiles the kernel.
5.  Publishes a **GitHub Release** with pre-compiled `.deb` binary assets attached.
