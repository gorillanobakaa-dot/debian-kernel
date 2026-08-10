# Your Kernel, Explained — a friendly tour of what we turned on and why

Welcome. You installed the Gorilla Unleashed kernel. This guide walks you through
what it actually *does*, in plain English, with the exact commands to see it for
yourself. You will not break anything by following along — every command here
just **reads** and **shows**. Nothing here changes your system unless the guide
literally says "this changes something," and even then it tells you how to undo it.

> **Two voices in this guide.** Each section has a 🧸 **plain-English** part
> (no jargon, promise) and a 💻 **developer** part (the facts, the risks, the
> config). Read one, both, or skip around. They're the same truth told twice.

A word before we start: you are about to type things into a black window called a
**terminal**. When output scrolls past, that is *normal*. When something says
`is not set`, that is *information*, not an error. You did not break it. You are
also — sorry — not a hacker yet. Reading your own settings is the computer
equivalent of checking your car's tyre pressure. Necessary, sensible, not
exactly *Mission: Impossible*. Put the balaclava away. 🙂

---

## 0. The one trick that powers this whole guide: look inside your own kernel

We built your kernel so it carries a copy of its own settings. You can read them.
Open a terminal and type:

```
$ zcat /proc/config.gz | grep CONFIG_HZ=
CONFIG_HZ=1000
```

🧸 **What just happened:** you asked the kernel "hey, what's your heartbeat set
to?" and it answered `1000`. That's it. `zcat` = "show me a zipped file",
`/proc/config.gz` = "the kernel's own settings", `grep` = "find just the line I
care about". If nothing comes back, the setting simply isn't in this kernel —
also a valid answer. Nobody exploded.

💻 **Why it exists:** `CONFIG_IKCONFIG_PROC=y`. Most distro kernels ship this; it
exposes the build config read-only at `/proc/config.gz`. It's how *we* verify a
build actually contains what we intended (we check the running kernel against its
own config, not against a file we hope matches). You can audit us the same way.

Keep this trick in your pocket — every section below, you can confirm with your
own eyes.

---

## 1. MAGIC_SYSRQ — the "talk straight to the kernel" key

```
$ cat /proc/sys/kernel/sysrq
438
```

🧸 **Plain English:** there's a secret handshake — hold **Alt + SysRq** (SysRq
is usually the **Print Screen** key) and press one more letter — that talks
*directly* to the kernel, even if everything on screen has frozen solid. The most
useful one to remember, if your machine ever locks up hard: the calm word
**"REISUB"** (some people remember it as "**BUSIER** backwards"). Tapping
Alt+SysRq and then, slowly, **R‑E‑I‑S‑U‑B**, tells the kernel to flush your files
to disk, unmount them safely, and reboot — instead of you yanking the power and
risking your data. It's a fire escape, not a party trick. The number `438` above
just means "the safe subset of these is switched on."

💻 **FACT.** `CONFIG_MAGIC_SYSRQ=y`. Provides low-level kernel commands via
Alt+SysRq+<key> (or the serial console, or `echo <key> > /proc/sysrq-trigger`)
regardless of userspace state: sync, remount-ro, terminate/kill tasks,
reboot/poweroff, dump state.

💻 **ASSESSMENT.** *Risk:* local/physical only — someone at your keyboard (or on a
serial console) could force a reboot or remount. It is **not** a remote hole.
*Gap:* fully enabled (`1`) it's a local denial-of-service / debug-bypass toy.

💻 **MITIGATION / CONFIG.** We ship a **restricted bitmask, not `1`**. The live
value `438` enables: log‑level control, keyboard SAK, **sync**, **remount‑ro**,
**reboot/poweroff**, RT‑nice — and deliberately **omits** the memory/register
dump bits. See it decoded:

```
# The bitmask, if you're curious what 438 actually permits:
#   2 log-level · 4 keyboard(SAK) · 16 sync · 32 remount-ro · 128 reboot · 256 nice
# NOT set: 8 (memory/task dumps).  Safe recovery set, no info-dump.
```
To go stricter (sync only) or off entirely, as root:
`echo 16 > /proc/sys/kernel/sysrq`  (sync only) or `echo 0 …` (off). Persist it in
`/etc/sysctl.d/`. We think `438` is the right balance for a recovery-first kernel.

---

## 2. Your fan should be quieter now — the CPU governor

```
$ cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
schedutil
```

🧸 **Plain English:** the "governor" is how your laptop decides how fast to run
the engine. The old setup pinned it to **maximum, always** — which is why your
15‑year‑old fan sounded like it was preparing for take‑off. We switched it to
**schedutil**, which means "run fast when there's real work, calm down when
there isn't." Same speed when you need it, much less noise and heat when you're
just reading this. If you ever *want* the fan-blasting always‑max mode back (say,
for a heavy render): `sudo cpupower frequency-set -g performance`.

💻 **FACT.** `CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y`. schedutil drives P‑states
from the scheduler's real load signal — near-instant ramp, no polling lag.
`performance` and `ondemand` are also compiled in if you prefer them.

---

## 3. Your internet, tuned: BBR + fq_codel

```
$ cat /proc/sys/net/ipv4/tcp_congestion_control
bbr
```

🧸 **Plain English:** **BBR** is a smarter way of deciding how hard to push data
onto the network. The old default (`cubic`) basically speeds up until something
*breaks*, then backs off — fine on a perfect wire, clumsy on Wi‑Fi. BBR instead
*measures* how fast your connection really is and fills it smoothly. Paired with
**fq_codel**, which stops one big download from adding lag to your video call,
the practical result is: pages feel snappier and calls stay smooth even while
something's downloading. You don't have to do anything — it's already on.

💻 **FACT.** `tcp_congestion_control=bbr`, `default_qdisc=fq_codel`
(`CONFIG_TCP_CONG_BBR=y`, `CONFIG_NET_SCH_FQ_CODEL=y`). BBR is model-based
(bandwidth×RTT), far better than loss-based cubic on lossy/wireless links;
fq_codel is the anti-bufferbloat AQM. Alternatives present:

```
$ cat /proc/sys/net/ipv4/tcp_available_congestion_control
reno bbr cubic
```

*(Full network buffer tuning — and why the numbers are what they are — is its own
illustrated guide: see `Network.Tuning.Profiles/README.md`, the "trucks on a
motorway" one.)*

---

## 4. A snappier desktop: 1000 Hz + tickless-when-idle

🧸 **Plain English:** the kernel has a "heartbeat" — how often per second it
checks in on things. We set it to **1000 times a second** (higher = a more
responsive, smoother-feeling desktop and tighter audio). But when nothing's
happening, it goes **quiet** ("tickless idle") so it isn't waking the CPU for no
reason and draining your battery. Best of both: responsive when busy, calm when
not. Check it yourself:

```
$ zcat /proc/config.gz | grep -E "CONFIG_HZ=|CONFIG_NO_HZ_IDLE"
CONFIG_HZ=1000
CONFIG_NO_HZ_IDLE=y
```

💻 **FACT.** `CONFIG_HZ_1000=y` + `CONFIG_NO_HZ_IDLE=y`. We deliberately did **not**
use `NO_HZ_FULL` (a server/HPC mode that adds a per-syscall accounting cost and
needs a `nohz_full=` CPU list to do anything) — it was in the old config doing
nothing but taxing every system call. Removed.

---

## 5. Disk fairness: BFQ

🧸 **Plain English:** when several programs hit your SSD at once, a "scheduler"
decides who goes first. **BFQ** keeps the desktop feeling responsive — so a big
file copy in the background doesn't make your browser stutter. Check what your
disk is using:

```
$ cat /sys/block/sda/queue/scheduler
[none] mq-deadline kyber bfq
```

The word in `[brackets]` is the active one. **BFQ is built into your kernel** (you
can see it offered in that list). If it doesn't show `[bfq]` yet, it just hasn't
been *selected* — that's a one-line rule, and the maintainer note at the end of
this guide covers turning it on. Nothing's wrong; the tool is there, it just needs
switching to.

💻 **FACT.** `CONFIG_IOSCHED_BFQ=y` + `CONFIG_BFQ_GROUP_IOSCHED=y`. Selection is a
udev rule (`ATTR{queue/scheduler}="bfq"` for `rotational=0` SATA). Kingston DC600M
is SATA (queue-depth 32), where BFQ's interactivity beats `none`.

---

## 6. "Wait, why can I read all this? Is that safe?" — an honest word

You may have noticed you can peek at a *lot* of your kernel's internals. That's on
purpose, and it's worth being honest about the trade.

🧸 **Plain English:** this kernel is tuned to be **fast and open on a machine you
physically own and control** — your laptop, your keyboard, your call. That means
some safety belts that matter on a shared server are deliberately loosened here to
give an old machine back its speed. The catch is simple and fair: **the openness
assumes nobody hostile is sitting at your keyboard or has already broken in.** For
a personal laptop you carry, that's a sensible bargain. If you were running this
as a public server, you'd want the belts tightened — and the shipped "standard"
build does exactly that.

💻 **FACT / ASSESSMENT.** Runtime posture is intentionally open on the personal
build: `mitigations=off` (biggest speed win on Ivy Bridge, which has no PCID and
pays the highest KPTI tax), `lockdown=none`, no module signing, `dmesg_restrict=0`,
`kptr_restrict=0`. **All of these require local/root access to abuse** — none is a
remote hole. Build-time hardening stays **ON** regardless: `RANDOMIZE_BASE` (KASLR),
`STACKPROTECTOR_STRONG`, `STRICT_KERNEL_RWX`, `FORTIFY_SOURCE`, `HARDENED_USERCOPY`,
AppArmor. **The honest one-liner: hardened at compile time; runtime deliberately
open for speed on a machine you control.** The public/generic build re-tightens
the runtime dials and drops `PROC_KCORE` (a live kernel-memory window that a normal
user never needs).

---

## 7. The Wi-Fi unleashing — the one this kernel is named for

```
$ sudo iw reg get
global
country 00: DFS-UNSET
	(2402 - 2472 @ 40), (N/A, 20), (N/A)
	(2474 - 2494 @ 20), (N/A, 20), (N/A), NO-OFDM, PASSIVE-SCAN
```

The two characters that matter are **`country 00`**. That means *world* — no
country's rulebook is being applied to your radio.

🧸 **Plain English:** your Wi-Fi card is a radio, and radios are regulated
differently in every country. Normally Linux works out which country you're in
and applies that rulebook — which channels you may use, how loud you may
transmit. Sounds sensible. Here's the part most people never find out: **it often
works that out by asking your router.** Your router broadcasts a little slip
saying "we're in Great Britain," and a stock kernel simply believes it.

This kernel doesn't. It reads the slip and ignores it. **You own the laptop; your
router doesn't get a vote on what your hardware is allowed to do.**

You can watch this happening. If a router near you is advertising a country, the
self-test in section 8 will literally tell you it saw the claim and ignored it:

```
PASS  regulatory domain is world (00) — no country is restricting you
PASS  an access point advertises 'Country: GB' and we IGNORED it
PASS  channel 14 (Japan) is enabled — normally blocked outside Japan
```

**And no — you are not a hacker yet.** You just told your own laptop to stop
taking instructions from a stranger's router. That is the whole trick.

Why anyone would want this: channel 14 only exists in Japan. Several 5 GHz
channels are indoor-only in Europe and fine elsewhere. If you travel, a card that
half-works because it guessed the wrong country is a **bug**, not a safety
feature. This kernel hands that judgement to you.

💻 **FACT.** Four separate layers re-impose regulatory limits, and all four are
cut: (1) `map_regdom_flags()` + `handle_channel*()` in `net/wireless/reg.c` —
restriction flags and `CHAN_DISABLED`; (2) `ath_force_no_ir_chan()` +
`ath_reg_apply_radar_flags()` in `drivers/net/wireless/ath/regd.c` — the Atheros
driver re-stamping what the core just stripped; (3)
`__reg_process_hint_country_ie()` in `reg.c` — the AP's 802.11d country IE, cut in
**cfg80211** rather than in `ath` so it covers every driver including the
rt2800usb ALFA adapters; (4) `ieee80211_handle_pwr_constr()` in
`net/mac80211/mlme.c` — the AP's 802.11h power-constraint and Cisco DTPC IEs.
Plus `CONFIG_CFG80211_REG_RELAX_NO_IR=y`.

💻 **ASSESSMENT.** This does **not** and **cannot** make your radio transmit
beyond its physical capability — the ceiling is burned into the card's EEPROM
calibration at the factory and no software raises it. On this VAIO's AR9485 that
real ceiling is **17 dBm**. (If you ever saw it report 20 dBm, that was a
regulatory *table* value the silicon could never actually reach — see
`case-study-txpower-drop.md`, which is worth reading purely as an example of how
to tell a real regression from a number that merely moved.) What changes is
**who decides**, not how loud the radio can physically shout.

💻 **MITIGATION / your responsibility.** Radio rules exist partly for real
reasons — chiefly not sitting on top of weather radar. Unleashing the card moves
that judgement from a lookup table to **you**. Use channels that are legal and
sensible where you actually are. We say this once, plainly, and then trust you:
the kernel is a tool, and the operator is accountable for how it's pointed. If
you want the stock behaviour back, boot the standard build — the deregulation is
specific to the Unleashed one.

---

## 8. One command that checks all of it

You don't have to take any of this on faith, and you don't need us:

```
$ ./kernel_selftest.sh
```

It reads — **never changes** — your system, and prints a plain-English PASS/FAIL
for everything in this guide. Real output from the machine this was written on:

```
  PASS  kernel taint flag is 0 (nothing proprietary or forced loaded)
  PASS  4 kernels installed — you have a fallback if one won't boot
  PASS  regulatory domain is world (00) — no country is restricting you
  PASS  the VAIO EAPD speaker fix loaded
  PASS  sda (SSD) uses BFQ — desktop stays responsive under disk load
  PASS  TCP uses BBR — better on lossy/slow links than the default
  PASS  CPU governor is 'schedutil' — scales with load, fan stays quiet
  INFO  hottest sensor right now: 52.0°C (normal)

  PASS 24   FAIL 0   SKIP 0
```

🧸 **A word about `SKIP`.** If a check says **SKIP**, it means the test *could not
look* — a tool was missing, or it needed admin rights. **SKIP is not PASS.** We
built it that way on purpose: "I checked and it's fine" and "I couldn't check"
must never print the same word, because a tool that quietly turns "don't know"
into "fine" is worse than no tool at all.

**Nothing here needs setting up.** The disk scheduler rule, the network profile
and the audio fix all ship with the kernel package and apply themselves at boot.
This guide exists so you can *understand* your machine — not so you have to
configure it.

---

## 9. If a new kernel doesn't boot — don't panic, and don't reinstall

This is the section we most hope you never need, so it's the one we made
impossible to get wrong.

🧸 **Plain English:** installing this kernel **does not remove your old one.**
Both sit in the boot menu. If a new kernel misbehaves:

1. Restart the machine.
2. As it starts, hold **SHIFT** (or tap **Esc**) to bring up the boot menu.
3. Choose **"Advanced options"**, then pick the **previous** kernel in the list.
4. Press Enter. You're back on the old one. Nothing was lost.

That's it. No reinstall, no live USB, no reformatting. **A kernel that won't boot
is an inconvenience, not a disaster** — as long as you keep the old one, which is
why the installer never deletes it and why the self-test warns you if you're ever
down to a single kernel.

If the screen fills with fast-scrolling text on the way up: that's just the kernel
being chatty, **it is not an error and nothing is broken.** You can quiet it by
removing `ignore_loglevel` from `GRUB_CMDLINE_LINUX_DEFAULT` in
`/etc/default/grub` and running `sudo update-grub`.

---

## Maintainer note (skip if you're just here to learn)

- **BFQ now applies itself.** `/etc/udev/rules.d/60-io-scheduler.rules` ships with
  the kernel and selects `bfq` for non-rotational `sd*`, `mq-deadline` for
  rotational, `none` for NVMe — on every boot, no user action. (Earlier revisions
  of this note asked the reader to create that rule by hand; that was a gap, and
  the standing rule is that **most users will not have an agent walking them
  through anything**, so anything requiring manual setup is a bug in the package,
  not a step for the docs.)
- Everything in this guide is verifiable with `zcat /proc/config.gz | grep <FLAG>`,
  or in one shot with `./kernel_selftest.sh`.
- Keep the previous known-good kernel installed. If a new build won't boot, pick
  the older one in the GRUB menu — no reinstall needed (section 9).
- `PROC_KCORE` is ON in the personal/dev build and deliberately **dropped from the
  public build**; `IKCONFIG_PROC` and a tuned `MAGIC_SYSRQ` bitmask are kept in
  both. Rationale in the project `CLAUDE.md`.
- Per-patch reasoning lives beside this file: `reg.c.md`, `regd.c.md`, `mlme.c.md`,
  `hw.c.md`, `alc269.c.md`, `tcp.h.md`, and the method write-up
  `case-study-txpower-drop.md`.
