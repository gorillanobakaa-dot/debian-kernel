# Case study: the TX power "regression" that wasn't

**Date:** 2026-08-10 · **Build:** 3 (`…26.08.10--11.20`) · **Hardware:** Atheros AR9485, Sony VAIO SVE14A3AJ

This document is not about a patch. It is about **how to think when a number moves
the wrong way** — written up because the reasoning is reusable and the conclusion
was the opposite of the first answer given.

Short version: after removing the kernel's obedience to a router's country
instruction, reported Wi-Fi transmit power fell from **20.0 dBm to 17.0 dBm**.
That was reported as a regression. It was not a regression. It was the number
becoming **honest**, and the proof was hiding in data collected *before* the
change.

---

## 🧸 For the layman

### What happened, in plain terms

Your Wi-Fi card has a real, physical maximum shouting volume. It is set at the
factory, burned into the card, and no software on earth can raise it.

Separately, your **router** broadcasts little instruction slips. One says *"we are
in Great Britain."* Linux normally reads that slip and looks up Britain's radio
rulebook to decide what your laptop is allowed to do. This kernel was changed to
stop obeying those slips — the whole point of the project is that **your machine
decides, not somebody else's router**.

Right after that change, the reported power dropped from 20 to 17. In this units
system that is *half the power*. It looked like the change had broken something.

### The thing that cracked it open

Here is the part worth remembering. **The answer was in the OLD measurements, not
the new ones.**

Before the change, thirteen of the fourteen channels reported 20. But **channel 14
reported 17** — and nobody had thought about why.

Channel 14 sits at 2484 MHz. The British rulebook covers 2400–2483 MHz. Channel 14
is *one megahertz outside it*. So channel 14 was the only channel Britain's rules
never touched — which means **17 was the card's own native number, and 20 was the
number the router's rulebook had painted over the top of it.**

After the change, all fourteen channels report 17, because nothing is painting
over anything any more.

So the card was never capable of 20. It could always only do 17. For a while it
was *claiming* 20 because a router told it a rulebook that said so.

### The genuinely surprising bit

The router's instruction slip was **not only a restriction — it was also a
permission**. On a British router it *raised* our stated ceiling above what the
hardware could actually deliver. Permissions and restrictions arrive down the same
pipe. Refusing the pipe means refusing both.

And the real-world radio output? Unchanged. A separate part of this kernel already
tells the hardware "give me everything you have" no matter what limit it is
handed. The 20-versus-17 argument was always about paperwork, not about radio.

### Why this matters to you, the person running this kernel

- A number going **down** is not automatically damage.
- A number going **up** is not automatically a win — sometimes it is a fiction
  somebody else supplied.
- **When something looks broken, hunt for the measurement that does not fit the
  pattern, and explain THAT before you touch anything.** One channel out of
  fourteen disagreeing with its neighbours was enough to unravel the whole thing.

We publish our wrong turns on purpose. A project that only shows you polished
conclusions is teaching you to trust conclusions. We would rather teach you to
check them — including ours.

---

## 💻 For the developer

### The method, in the order it has to happen

**1 · State the suspicion, then suspend it.**
Say "this looks like a regression" out loud, then refuse to act until the number
is explained. Naming a fear is not the same as believing it. The cheapest wrong
move available here was reverting a correct change on the strength of an
unexplained number.

**2 · Interrogate the OLD data for non-uniformity.**
The Build 2 reading was not uniform: `ch1–13 = 20.0 dBm`, `ch14 = 17.0 dBm`.
A uniform explanation ("the card does 20") cannot produce a non-uniform result.
**One value disagreeing with thirteen neighbours is a free experiment somebody
already ran for you.**

**3 · Ask what is structurally different about the outlier.**
ch14 = 2484 MHz. The GB reg rule spans 2400–2483 MHz. ch14 falls outside it, so it
was never overwritten by the GB table. That identifies which number is the
intruder: **17 native, 20 imported**.

**4 · Only now open the source — with a falsifiable hypothesis.**
Reading code first invites you to find a story that fits your fear. Reading it
after you have a claim means the code confirms or destroys it. It confirmed:

```c
/* drivers/net/wireless/ath/ath9k/init.c:813 */
ath9k_hw_set_txpowerlimit(ah, MAX_COMBINED_POWER, true);   /* test = true */
```

```c
/* hw.c — with test=true, max_power is seeded from EEPROM calibration */
if (test)
        channel->max_power = DIV_ROUND_UP(reg->max_power_level, 2);
```

`reg->max_power_level` is what the EEPROM calibration **actually achieved**. In
Build 2 the country IE triggered `wiphy_update_regulatory()` → `handle_channel*()`,
which overwrote that with the GB table's 20 dBm. In Build 3 no country-IE hint is
ever queued, so nothing overwrites the driver value.

**5 · Invert the verdict if the evidence inverts it — in writing.**
The honest conclusion contradicted the report already given to the owner. Saying
so costs one sentence. Not saying so costs the project a wrong revert.

**6 · Ship the caveat with the conclusion.**
This is a **source-and-arithmetic argument, not an RF measurement.** No spectrum
analyser was used. No Build-2 `iw dev txpower` reading exists to compare against
Build 3's `15.00 dBm`. Those gaps are stated, not papered over.

### Consequence for this project

**Do not "fix" the 17 dBm** by raising the power figure in `ath`'s world
regdomain rules. That would restore the fiction — a declared ceiling the silicon
cannot reach — while changing nothing about radiated power, since
`ath9k_hw_apply_txpower()` already forces:

```c
chan_pwr = MAX_COMBINED_POWER; /* GORILLA: UNLEASHED POWER */
new_pwr  = MAX_COMBINED_POWER; /* GORILLA: No limits. */
```

The binding constraint is EEPROM calibration. That is silicon, and it is not
negotiable by software. 17 dBm is the truth; publish the truth.

### Reusable checklist

When a metric moves the wrong way after your change:

| Step | Question |
|---|---|
| a | Is the **old** data uniform? Non-uniformity in the baseline is usually the answer. |
| b | What is structurally different about the outlier? |
| c | Do you have a falsifiable hypothesis **before** opening the source? |
| d | If the evidence inverts your verdict, did you invert it in writing? |
| e | Did the caveat ship with the conclusion? |

This is project directive §2 — *verify the artifact, not the exit code* —
generalised: **verify the number, not the direction it moved.**

### Commands used

```bash
sudo iw phy phy0 info | grep MHz          # per-channel ceiling (chan->max_power)
sudo iw dev <iface> info | grep txpower   # currently configured power
sudo iw reg get                           # global + per-phy regulatory domain
sudo iw dev <iface> scan dump | grep -i Country   # what the AP actually advertises
```

Note: on Debian these live in `/sbin`, which is frequently absent from a
non-interactive `PATH`. `command -v iw` returning nothing means **check `dpkg -l`
before concluding anything is missing** — that exact false negative was recorded
the same day.

---

## Provenance

Found while verifying Build 3's deregulation patches on the running machine rather
than by reading a diff. Recorded in the KERNEL brain as
`A number that went DOWN is not automatically a regression — how to tell`, and the
corrected TX-power scoping is in
`Wi-Fi deregulation is a FOUR-layer chain — cutting three leaves it leashed`.
