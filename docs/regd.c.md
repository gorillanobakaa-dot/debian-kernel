# Patch Documentation: regd.c

**File:** `drivers/net/wireless/ath/regd.c`
**Subsystem:** Atheros (ath9k/ath) wireless regulatory layer
**Kernel:** Linux 7.1.2 (Gorilla Unleashed)
**Added:** Build 2 (2026-08-10). Pairs with the `reg.c` core patch.

---

## Why this file needs patching too (the "other half")

The `reg.c` patch strips regulatory restrictions at the **cfg80211 core**. But the
Atheros driver runs its *own* regulatory pass afterwards, in `regd.c`, and
**re-stamps** the restrictions the core patch just removed. So on an ath9k/ath
card, `reg.c` alone is undone. This patch completes the strip at the driver layer.

The stock driver re-applies restrictions in two places (both confirmed against
pristine upstream, then neutered):

| Function | Stock behaviour | After patch |
|---|---|---|
| `ath_force_no_ir_chan()` | `ch->flags \|= IEEE80211_CHAN_NO_IR` — forces "no transmit" on ch 12/13 (via `ath_reg_apply_ir_flags` default case) | `\|= 0` — never forces NO_IR |
| `ath_reg_apply_radar_flags()` | `ch->flags \|= IEEE80211_CHAN_RADAR \| IEEE80211_CHAN_NO_IR` on every 5 GHz DFS channel | `\|= 0` — DFS/indoor 5 GHz stays usable |

Method is identical to `reg.c`: replace the restriction-OR with `0`, GORILLA-
commented, so the diff against upstream is trivially auditable and the intent is
self-documenting in the source.

---

## 🧸 For the layman

Your government's radio rules are enforced by the operating system in two layers,
like two guards at a gate. We already told the first guard (`reg.c`) to wave
everyone through. But the second guard — the one specific to your Atheros Wi-Fi
chip — has his own copy of the rulebook and puts the barrier back down. This patch
tells that second guard to stand aside too. The result: your Wi-Fi card will use
channels and modes that a stock kernel blocks based on which country it thinks
it's in — including Japan's channel 14 and the 5 GHz "radar/indoor" channels.

**Why we do this.** This kernel is built to be *unleashed* — not throttled by a
region setting when the hardware is physically capable. For anyone who travels
across borders, a card that half-works because it guessed the wrong country is a
bug, not a safety feature. On a 2.4 GHz-only card the practical gain is a couple
of channels; on 5 GHz-capable hardware this is the difference between "some
channels" and "all of them."

**A word on responsibility:** radio rules exist partly for real reasons (not
jamming weather radar, mostly). Unleashing the card puts that judgement in *your*
hands instead of a lookup table's. Use the channels that are legal and sensible
where you actually are. The kernel now trusts you to know that.

---

## 💻 For the developer

- `ath_force_no_ir_chan()` is reached via `ath_reg_apply_ir_flags()`'s `default:`
  case (initiator not `COUNTRY_IE`/`USER`), which forces NO_IR on 2467/2472 MHz
  (ch 12/13). Neutering the helper makes those channels transmit-capable in every
  regdomain path.
- `ath_reg_apply_radar_flags()` iterates the 5 GHz band and ORs `RADAR | NO_IR`
  onto every `ath_is_radar_freq()` channel. Neutering the OR leaves DFS channels
  usable (no forced radar-wait, no passive-only).
- Both are invoked from `ath_reg_apply_world_flags()` / the `reg_notifier`, i.e.
  **after** cfg80211 core processing — which is why the `reg.c` strip is
  insufficient on its own.
- `regd.c` also defines `ATH_2GHZ_CH12_13` / `ATH_2GHZ_CH14` reg-rule macros with
  `NL80211_RRF_NO_IR`; those describe the *rule table*, not the applied flags, and
  are left intact — the flag application is what governs channel usability.
- **Verify at runtime** (do not assume from source): on a 5 GHz-capable card,
  `iw list` per-channel flags before/after, and confirm DFS channels lose the
  `no IR`/`radar detection` markers. Compiles clean (`make …/regd.o`, exit 0).

---

## Build 3 addendum (2026-08-10) — two more ath-side leashes

Runtime evidence, not source reasoning, drove these. Booted on Build 2 the kernel
still logged `ath: regdomain 0x833a dynamically updated by country element` and
`Country alpha2 being used: GB` four seconds after associating. Two more sites:

| Function | Stock behaviour | After patch |
|---|---|---|
| `ath_regd_init_wiphy()` | sets `REGULATORY_COUNTRY_IE_FOLLOW_POWER` — ath **opts in** to letting an AP's country IE dictate TX power | `\|= 0` — no opt-in |
| `__ath_reg_dyn_country()` | rejects a country-IE hint *only if we are **not** already in a world regdomain* | rejects **every** country-IE hint |

The second is worth dwelling on: stock logic treats "already in world regdomain"
as the one case where an AP **may** overwrite our regulatory state. For this
project that is exactly backwards — world regd is the state we want *preserved*.

Both are redundant behind the Build 3 `reg.c` change (which stops the hint ever
reaching the driver), and both are kept anyway so `regd.c` is correct standing
alone. Belt and braces on the file that already fooled two audits.

**Note the driver-coverage limit:** everything in this file is `ath`-only. The
ALFA AWUS036NH is `rt2800usb` and gets none of it — which is precisely why the
Build 3 country-IE strip was placed in cfg80211 (`reg.c`), where it covers every
driver. See `mlme.c.md` and `reg.c.md`.
