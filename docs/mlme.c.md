# Patch Documentation: mlme.c

**File:** `net/mac80211/mlme.c`
**Subsystem:** mac80211 — managed-mode (station) MLME
**Kernel:** Linux 7.1.2 (Gorilla Unleashed)
**Added:** Build 3 (2026-08-10). Completes the chain started by `reg.c` (Build 1)
and `regd.c` (Build 2).

---

## Why a third file — the leash we had missed

Builds 1 and 2 stripped regulatory restrictions at the cfg80211 core and at the
Atheros driver layer. The 2026-08-10 boot log proved that was still not enough.
Four seconds after associating, with both earlier patches live, the kernel logged:

```
Gorilla.WIFI: Limiting TX power to 20 (20 - 0) dBm as advertised by 5c:54:6d:9e:18:c0
```

That line comes from `ieee80211_handle_pwr_constr()` in this file. It is a
**third, independent** leash, and it is not a country lookup table — it is the
**access point** telling our radio how much power it may use, and mac80211
obeying. Two IEs feed it:

| Information Element | Origin | Stock behaviour |
|---|---|---|
| 802.11h Power Constraint | Any AP advertising spectrum management | Reduces our TX by the advertised amount |
| Cisco DTPC | Cisco APs (proprietary) | Sets our TX to the AP's dictated level |

The patch returns 0 before either is applied, so `link->ap_power_level` is never
set from the AP's frame and `__ieee80211_recalc_txpower()` keeps the
driver/regulatory figure instead.

The upstream logic below the early return is deliberately **retained but
unreachable**, so the original reasoning stays legible and the patch is trivial
to revert.

---

## 🧸 For the layman

Your Wi-Fi router does not just carry your traffic — it also broadcasts little
instruction slips about how the radios around it should behave. One of those
slips says *"nobody near me should transmit louder than this."* A stock Linux
kernel reads that slip and quietly turns your laptop's radio down, on the word of
a device you do not own and cannot inspect.

That is the setting this patch removes. Your laptop still cannot exceed what its
own hardware is physically built to do — that ceiling is burned into the card and
no software changes it. What changes is **who decides**: your machine, not
somebody else's router.

**Why it matters even though the number looked the same.** On this VAIO the AP
asked for 20 dBm and the AR9485's own ceiling is about 20 dBm anyway, so the
practical loss that day was nothing. But the *mechanism* is the point: any router
anywhere can send that slip with any number in it, including a much lower one,
and until this patch we would have complied without asking. On the ALFA
AWUS036NH, and on the 5 GHz family builds, the numbers stop matching and the
difference becomes real.

**A word on responsibility:** transmit power limits exist partly for genuine
reasons. Removing the AP's vote puts that judgement in *your* hands. Use what is
legal and sensible where you actually are.

---

## 💻 For the developer

- Patch point: first statement after the S1G-beacon early-out in
  `ieee80211_handle_pwr_constr()`, before `ieee80211_find_80211h_pwr_constr()`
  and `ieee80211_find_cisco_dtpc()` are consulted.
- Returning `0` (not `BSS_CHANGED_TXPOWER`) means the caller at the
  `ieee80211_handle_bss_capability`/beacon path performs no txpower recalc on
  this account. `link->ap_power_level` retains its initialised value.
- The locals below the return are still read by the retained code, so **no
  `-Wunused-variable` warnings**; GCC does not warn on unreachable code at W=0.
- This does **not** raise the ceiling. Final TX is still bounded by
  `chan->max_power` (see `reg.c`) and by the driver's own EEPROM calibration
  clamp (ath9k: `regulatory->power_limit`, `hw.c`).
- **Verify at runtime, do not assume from source:**
  - `sudo journalctl -b -k | grep -i "Limiting TX power"` → expect **no output**.
  - `sudo iw phy phy0 info` → per-channel dBm should follow the driver figure.
  - `sudo iw reg get` → the `global` block should stay at the world regdomain
    (`country 00`) rather than flipping to the AP's country. That part is the
    `reg.c` country-IE patch, not this one, but they are verified together.

---

## Provenance

Found by reading the Build 2 boot log rather than by reasoning about source: the
earlier audit had declared the deregulation complete after `regd.c`, and it was
not. Two prior conclusions were wrong for the same reason — they trusted a source
diff instead of the running machine. Verify at runtime.
