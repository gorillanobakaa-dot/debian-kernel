# Patch Documentation: reg.c
**File:** `net/wireless/reg.c`
**Subsystem:** Wireless Regulatory Enforcement
**Kernel:** Linux 7.1.2 (Gorilla Unleashed)

---

## Developer Track

### What This File Does (Upstream)
`reg.c` is the Linux kernel's wireless regulatory database enforcement engine. It reads regulatory domain rules (from CRDA or the built-in database) and translates them into channel flags that restrict what the Wi-Fi card is allowed to do — which channels it can use, at what power, and with which modulation modes.

### What The Patch Changes
The patch targets the `map_regdom_flags()` function and several channel update functions. In each case, it replaces a real channel restriction flag with `0` (a no-op), meaning the restriction is read from the regulatory database but never applied to the channel.

**Stripped flags in `map_regdom_flags()`:**

| Flag | Meaning | After Patch |
|---|---|---|
| `IEEE80211_CHAN_NO_IR` | No Initiating Radiation — passive scan only, no transmit | **Removed** |
| `IEEE80211_CHAN_RADAR` | DFS channel — requires 60s radar scan before use | **Removed** |
| `IEEE80211_CHAN_NO_OFDM` | Block OFDM modulation | **Removed** |
| `IEEE80211_CHAN_INDOOR_ONLY` | Indoor use only | **Removed** |
| `IEEE80211_CHAN_NO_HT40MINUS/PLUS` | Block 40MHz bonding | **Removed** |
| `IEEE80211_CHAN_NO_80MHZ` | Block 80MHz (Wi-Fi 5) | **Removed** |
| `IEEE80211_CHAN_NO_160MHZ` | Block 160MHz (Wi-Fi 6) | **Removed** |
| `IEEE80211_CHAN_NO_HE` | Block Wi-Fi 6 (High Efficiency) | **Removed** |
| `IEEE80211_CHAN_NO_320MHZ` | Block 320MHz (Wi-Fi 7) | **Removed** |
| `IEEE80211_CHAN_NO_EHT` | Block Wi-Fi 7 (EHT) | **Removed** |
| `IEEE80211_CHAN_DISABLED` | Channel completely disabled | **Removed** |
| `IEEE80211_CHAN_NO_6GHZ_VLP_CLIENT` | 6GHz VLP client restriction | **Removed** |
| `IEEE80211_CHAN_NO_6GHZ_AFC_CLIENT` | 6GHz AFC client restriction | **Removed** |
| `IEEE80211_CHAN_PSD` | Power Spectral Density limit | **Removed** |
| `IEEE80211_CHAN_NO_UHR` | Block Ultra High Rate (Wi-Fi 7) | **Removed** |

**DFS checks stripped** in 4 additional locations — the `if (chan->flags & IEEE80211_CHAN_RADAR)` blocks that trigger the CAC timer and radar avoidance logic now evaluate `& 0` (always false), permanently disabling the radar scan requirement.

**`CHAN_DISABLED` stripped** in 4 additional locations — channels that regulatory rules would disable are now left enabled.

### Hardware Notes
For the Atheros AR9485 (ath9k) in the Sony VAIO SVE14A3AJ: this card is 2.4GHz/5GHz only. Flags for 80/160/320MHz, Wi-Fi 6/7, and 6GHz bands are dead code — the hardware cannot use those modes regardless. The meaningful unlocks for this card are: **NO_IR removal** (transmit on passive channels), **DFS skip** (5GHz channels immediately available), and **NO_HT40 removal** (40MHz bonding always allowed).

---

## Layman Track

### What Does `reg.c` Normally Do?

Every country in the world has rules about Wi-Fi. These rules say things like:
- "You can only use certain frequencies in this country"
- "You must scan for radar signals before using this channel"
- "Your Wi-Fi card is only allowed to use a certain amount of power"

The `reg.c` file in the Linux kernel is the **rulebook enforcer**. When your Wi-Fi card starts up, this file reads the rules for your country and tells the card: "You are allowed to use these channels, but not those ones. You can use this much power, but no more."

Think of it like an airport security checkpoint — it decides what your Wi-Fi card is and isn't allowed to carry through.

### What The Patch Does

This patch **removes the security checkpoint**. It reads the country's rules (because it has to — the code still runs) but then silently **ignores them** when applying the restrictions to the card.

Every restriction that would normally be written onto a channel — "this channel is radar-only," "this channel is indoor-only," "this channel is disabled entirely" — gets replaced with a zero, which means **no restriction**.

The result: your Wi-Fi card can see and use every channel its radio hardware physically supports, without the kernel holding any of them back.

### The DFS/Radar Timer

One specific removal is worth explaining: the **DFS radar scan**.

On many 5GHz channels, the law requires your Wi-Fi router or card to spend **60 seconds silently listening** before it starts transmitting — to make sure it won't interfere with airport or weather radar. This is called a Channel Availability Check (CAC).

This patch disables that requirement. Your card skips the 60-second wait and starts using the channel immediately.

### Who Benefits

- **Modern hardware users** (Wi-Fi 5/6/7 cards): All channel width restrictions (40/80/160/320MHz) are removed, allowing the card to use its full bandwidth.
- **5GHz users**: No more 60-second DFS radar wait on 5GHz channels.
- **Any hardware**: Channels that your country's rules would normally disable are now available.

### Trade-Offs

- Transmitting on channels outside your country's permitted bands may be illegal. This is your responsibility to understand.
- Disabling the DFS radar scan means your Wi-Fi could theoretically interfere with radar installations. In practice, for home users far from airports, the risk is negligible.
- This is the same freedom that tools like `iw reg set BO` provide at runtime — we've just baked it in at the kernel level.

---

**Status in 7.1.2:** Confirmed clean apply. Ready to port.
