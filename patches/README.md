# The patch set — Gorilla Unleashed 7.1.2

**14 patches · +196 / −103 lines against pristine Linux 7.1.2.**

That is the entire footprint of this project on the kernel source. Every line is
here, and every line is explained in [`../docs/`](../docs).

---

## Verify it yourself, before trusting a word of it

```bash
./verify_patches.sh
```

This does **not** check that the patches "look right". It:

1. extracts a fresh copy of the affected files **from `linux-7.1.2.tar.xz`**
   (sha256 `37198c93727be247c9fb5309bb86cd5e496c61e5322cd8c4eca9476bb0b5883f`),
2. applies every patch with `patch -p1`, and
3. compares the result **byte-for-byte** against the source files this repo ships.

Step 3 is the one that matters. "It applied" only proves the hunks fit. **Byte
identity proves the patch set is complete** — that nothing in the shipped sources
came from somewhere the patches don't describe. Current result: **14/14 PASS.**

The baseline is the **tarball**, never a directory. A directory can be quietly
patched and then mistaken for pristine; that is not hypothetical here — it is
precisely what happened, and it cost this project three wrong audit conclusions.
See [`../historical/README.md`](../historical/README.md).

## Apply them

```bash
cd /path/to/linux-7.1.2
while read -r p; do
    case "$p" in ''|\#*) continue ;; esac
    patch -p1 < /path/to/Kernel.7.1.2.Patches/patches/"$p"
done < /path/to/Kernel.7.1.2.Patches/patches/series
```

Or just run [`../recreate_success.sh`](../recreate_success.sh), which applies the
sources, injects the audited config change-set, builds with `-O3 -march=native`
and drops the `.deb`s in `Clean Output Binaries/`.

> **Note on the installer.** `universal_freedom_installer.py` does **not** apply
> these patches — it copies whole files listed in
> `PATCHED_FILES_PATH_REGISTRY.txt`. The patches exist so humans and reviewers can
> *see* the changes. Both routes produce identical trees; `verify_patches.sh` is
> what proves that.

---

## What's in them

| Patch | Lines | What it does |
|---|---|---|
| `reg.c.patch` | +87 −55 | cfg80211 regulatory core: strip restriction flags, never disable a channel, ignore the AP's 802.11d country IE, let hardware capability beat the regulatory table |
| `regd.c.patch` | +21 −6 | Atheros layer: stop re-stamping NO_IR/RADAR after the core strip; refuse country-IE re-regulation; drop the country-IE-follows-power opt-in |
| `mlme.c.patch` | +13 −0 | mac80211: ignore AP-advertised TX power (802.11h Power Constraint + Cisco DTPC) |
| `alc269.c.patch` | +27 −1 | Sony VAIO speaker fix (ALC269 EAPD) |
| `tcp.h.patch` | +12 −12 | TCP timing constants (initial window, RTO floor, TIME-WAIT) |
| `tcp.c.patch` | +7 −8 | matching TCP behaviour |
| `hw.c.patch` | +3 −3 | ath9k: 40 MHz CCA override, TX power ceiling |
| `init.c.patch` | +3 −3 | ath9k init: force max TX power |
| `gpio.c.patch` | +2 −2 | ath9k Bluetooth coexistence → Wi-Fi wins |
| `btcoex.c.patch` | +2 −2 | ditto |
| `sony-laptop.c.patch` | +7 −0 | VAIO platform/thermal |
| `intel_display_params.h.patch` | +2 −2 | i915 display parameters |
| `dell-pc.c.patch` | +8 −6 | Dell fleet support (config currently off) |
| `thinkpad_acpi.c.patch` | +2 −3 | ThinkPad fleet support (config currently off) |

The four regulatory patches are one feature in four places — the leash is applied
at four independent layers, and cutting three of them leaves the radio leashed.
That is written up in [`../docs/mlme.c.md`](../docs/mlme.c.md) and
[`../docs/regd.c.md`](../docs/regd.c.md).

## Regenerating

```bash
python3 make_patches.py           # rebuild from the pristine baseline
python3 make_patches.py --check   # CI-style: fail if patches drift from sources
```

`--check` writes nothing and exits non-zero if a source file has been edited
without regenerating its patch. Run it before publishing.

---

## 🧸 If you are not a kernel developer

A "patch" is a list of the exact lines someone changed — like tracked changes in a
document. Instead of asking you to trust a 330 KB file, it says *"on line 2843, we
replaced this with that, and here is why."*

There are 14 of them here, and together they change **196 lines and remove 103**
out of roughly 40 million in the Linux kernel. That is the whole project. You can
read all of it in an afternoon, and the script above proves the list is complete —
that we haven't changed anything we didn't tell you about.

That last part is the point. Anyone can publish a modified kernel and *claim* it
matches their description. This one can be checked, by you, with one command.
