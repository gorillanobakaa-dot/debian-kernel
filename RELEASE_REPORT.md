## What is this

This is the Gorilla Unleashed kernel, moved up to Linux 7.2.9. The kernel is the part of a Linux computer that sits between the programs and the hardware: it decides how fast the Wi-Fi may transmit, how the speakers are driven, how network traffic is paced. The ordinary kernel is set up for the average machine and for the strictest rules anywhere in the world. This one is set up for older laptops, the Sony VAIO SVE first, and removes limits that cost those machines speed, range and volume.

Every change from the 7.1.2 release is still here, and none was added or taken away. The only differences are the newer Linux underneath and one dead setting removed.

## Should you download it

**Not yet, unless you are willing to be the first person to boot it.** This version has been built and checked in every way that does not need a real laptop, but it has **not been started on real hardware yet**. Wait for the maintainer to confirm it boots on the VAIO, or keep your current kernel installed beside it so you can go back.

Do **not** install it if:

- you are not running Debian or Ubuntu (the `.deb` packages), or Fedora and similar systems (the `.rpm` packages);
- you need your computer to obey the radio rules of your country exactly. This kernel ignores some of them on purpose (see "The Wi-Fi changes" below);
- you have no way to choose an older kernel when the computer starts.

## Why this matters

A fifteen-year-old laptop is not slow because it is old. It is slow partly because the software it runs was tuned for different machines, and for the most cautious settings everywhere at once. This kernel shows what the same hardware does without those settings. It is also built and checked by a set of tools (Gorilla Fieldkit) that do every step the same way every time and write down the evidence, so you do not have to take anyone's word for what is inside.
---
# In plain language: everything in this release

This is the complete explanation, not a summary of one. Nothing below is behind a link.

<!-- plain-language track: in full, on this page -->

### Should you run this

**Only if all of these are true:**

- your computer runs Debian or Ubuntu (use the `.deb` files), or Fedora or a similar system (use the `.rpm` files);
- you can pick an older kernel from the menu that appears when the computer starts (called GRUB on most of these systems);
- you accept that this kernel ignores some radio rules on purpose (described below).

**Wait, or do not run it, if:**

- you need the laptop for work tomorrow and cannot afford an evening of trouble. This version has **not been started on a real laptop yet**. It was built and checked on a build machine in the cloud;
- you must stay inside your country's radio rules (for example near an airport, or if your job depends on it);
- you are not sure what the start-up menu is. Read "The off switch" first.

### Worst case, honestly

The most likely bad outcome is that the computer does not finish starting with this kernel. You would see the start-up menu, choose the new kernel, and then the screen stops with text on it or goes black. Nothing is lost: you restart, choose your previous kernel in the start-up menu, and the computer is as it was. Your files are not touched by installing a kernel.

The second risk is the radio. This kernel lets the Wi-Fi card use channels and power levels that your country may not allow, and it does not step back when it hears radar. In most homes nobody notices. Near an airport, a weather radar or a harbour, a Wi-Fi card that does not step back can disturb equipment that relies on that channel being quiet. Whether this is allowed where you live is a question for your local radio authority, not for this document.

### What data this touches

- **What it changes:** the kernel itself, in the folder `/boot` and in `/lib/modules`. Installing it adds a new entry to the start-up menu. Your existing kernels stay.
- **What it reads:** nothing of yours. A kernel does not read your documents; programs do.
- **What it sends:** nothing. There is no code in this patch set that contacts anyone. The Wi-Fi and network changes make your connection behave differently; they do not send anything extra.
- **Settings it changes on your machine:** none by itself. The kernel starts with different built-in values for the Wi-Fi and network. Your saved settings in other programs are not touched.

### Before you trust it

1. **Check the download is the one that was built.** Open a terminal (see "How to use this", step 1). Type `sha256sum` followed by a space and the name of the file you downloaded, then press Enter. The long string it prints must be exactly the one listed for that file in the developer part of this page, under "Package checksums". **Pass:** every character matches. **Fail:** any character differs; delete the file and do not install it.
2. **Check the patches are the whole story.** On the project page, the folder `patches` holds every change made to Linux, 13 small files. The developer part of this page says how they were checked: applied to an untouched copy of Linux 7.2.9, they rebuild the shipped source files exactly. **Pass:** the developer part says "14 of 14" byte for byte. **Fail:** any other number; do not install.
3. **After installing, check you are running it.** Restart, choose the new kernel, open a terminal, type `uname -r` and press Enter. **Pass:** it prints `7.2.9-unleashed.gorilla-eapd-bbr-26.10.10--13.28`. **Fail:** it prints anything else; you are still on your old kernel, which is safe.
4. **Ask whether it has been started on real hardware yet.** This page says it has not. If a later update to this page says the maintainer has booted it on the VAIO, that is the moment the main risk drops.

### The big picture

Think of the kernel as the engine management computer of a car. The car (your laptop) has the same engine whatever the computer says. But the factory computer is set up to suit every country and every driver at once, so it holds the engine back: lower top speed, gentler throttle, a quieter exhaust. This kernel is a different engine map for one particular car. It lets the Wi-Fi card transmit as strongly as its own hardware allows, makes the network start fast instead of carefully, and drives the speakers a little harder.

Moving to Linux 7.2.9 is like the car maker releasing a newer base engine. The Gorilla changes were carried over one by one. Twelve fitted exactly where they were before. One, the speaker boost, had to be moved, because the maker had added new parts around it. The change itself is the same, line for line.

### Key concepts

| Word | What it means | Like… |
|---|---|---|
| Kernel | The program that runs first and lets every other program use the hardware. | The engine management computer in a car. |
| Patch | A small file that lists exactly which lines of Linux were changed, and how. | A tailor's note: "take in 2 cm at the waist, let out 1 cm at the hem". |
| Migration | Carrying the same changes from an older Linux to a newer one. | Moving the same alterations onto a new suit of the same design. |
| Byte for byte | Two files are identical down to every single letter and space. | Two copies of a key that both open the same lock. |
| Package (.deb, .rpm) | One file that holds the kernel and installs it in the right places. | A flat-pack box with the instructions inside. |
| Checksum (sha256) | A long code calculated from a file; any change to the file changes the code. | The seal on a jar: broken means someone opened it. |
| Start-up menu (GRUB) | The list of kernels you can choose from when the computer starts. | Choosing which key to use when a car has two. |
| Regulatory rules | The limits a country puts on which radio channels and power Wi-Fi may use. | Speed limits that differ from country to country. |

### How it works

1. **The untouched Linux 7.2.9 was fetched.** Like buying the new suit off the rack before any alterations.
2. **The old changes were tried on it.** Twelve of thirteen fitted exactly, the same way a tailor's note fits when the pattern did not change.
3. **The one that did not fit was moved by hand.** Linux had added new lines around the speaker setting, so the change was placed at the same spot in the new layout. The changed lines are identical to before.
4. **The result was checked against the old one.** Every patch changes exactly the same lines as on 7.1.2, and applying the patches to untouched Linux rebuilds every shipped file exactly, like a key that opens the lock both times.
5. **The settings were applied and checked.** 248 settings must be on or off. All 248 were confirmed after Linux tidied the list. One old setting was removed because it no longer exists in Linux at all; it did nothing in 7.1.2 either.
6. **The kernel was built and packed twice**, once for Debian and Ubuntu and once for Fedora-type systems. Both packs hold the same kernel.

### Quirky things

- **The ThinkPad and Dell changes are carried but switched off.** They are in the patch set, and they move with every update, but the settings this kernel is built with do not include those drivers. On a ThinkPad or a Dell they do nothing. This was already true for 7.1.2.
- **The RPM and the .deb are not identical files.** Packing for Fedora-type systems re-stamped the kernel with a new build number and time. The working parts are the same; only that stamp differs.
- **"Linux 7.2.9" came from a copy on GitHub, not from kernel.org itself.** The build machine could not reach kernel.org. The same copy's older 7.1.2 matched the official 7.1.2 exactly for every file the patches touch, which is strong evidence it is faithful, but the official checksum for 7.2.9 has not been compared yet.
- **What this cannot do.** It cannot make a slow processor faster, add memory, or fix a failing disk. It does not make Wi-Fi faster if the router is the limit. It does not protect you from anything; it removes limits, it does not add guards. It has not been measured for speed, battery or heat on this version: every such number is "not measured".

### What this means for you

- **Battery:** not measured for 7.2.9. Stronger Wi-Fi transmission uses more power than weaker transmission.
- **Processor and memory:** not measured.
- **Speed:** not measured for 7.2.9.
- **Privacy:** unchanged. Nothing in the patch set sends or collects anything.
- **Internet data use:** unchanged by the kernel. Downloading the packages costs about 40 MB for the Debian pair (image and headers) or about 46 MB for the RPM trio (not measured as downloads: the sums of the measured file sizes in docs/VERIFIED_MEASUREMENTS.md).

### The off switch

Restart the computer. In the start-up menu, choose your previous kernel (on Ubuntu, under "Advanced options"). That is all it takes to go back; nothing is changed until you choose this kernel again.

To remove it completely on Debian or Ubuntu, open a terminal and type the command below, then press Enter. It asks for your password.

```bash
sudo apt remove linux-image-7.2.9-unleashed.gorilla-eapd-bbr-26.10.10--13.28
```

Without the start-up menu there would be no way back from a kernel that does not start, short of a rescue disk. That is why this guide asks you to check the menu works before installing.

### How to use this

1. Open a terminal. On Ubuntu, press the Super key (the one with the Windows logo), type `Terminal`, and press Enter. A window with a blinking cursor opens.
2. Go to the folder where your browser saved the downloads. Type the line below and press Enter.

   ```bash
   cd ~/Downloads
   ```

3. Check each file, as in "Before you trust it", step 1. Type the line below and press Enter.

   ```bash
   sha256sum linux-image-7.2.9-unleashed.gorilla-eapd-bbr-26.10.10--13.28_7.2.9_amd64.deb
   ```

   **Pass:** it prints `0ae248ea4df86217e1fcea04e61fdaac807992ca0ee8bdf40b116c080d42604c` followed by the file name. **Fail:** a different code; stop here.
4. On Debian or Ubuntu, install the image and the headers (never `linux-libc-dev`). Type the line below and press Enter, then type your password and press Enter.

   ```bash
   sudo apt install ./linux-image-7.2.9-unleashed.gorilla-eapd-bbr-26.10.10--13.28_7.2.9_amd64.deb ./linux-headers-7.2.9-unleashed.gorilla-eapd-bbr-26.10.10--13.28_7.2.9_amd64.deb
   ```

   **Pass:** the last lines mention updating GRUB and no line starts with `E:`. **Fail:** a line starting with `E:`; nothing was installed.
5. On Fedora and similar systems, use the RPM instead. Type the line below and press Enter.

   ```bash
   sudo dnf install ./kernel-7.2.9_unleashed.gorilla_eapd_bbr_26.10.10__13.28-2.x86_64.rpm
   ```

6. Restart, choose the new kernel in the start-up menu, and check it as in "Before you trust it", step 3.

### If something goes wrong

- **The screen stops with text on it, or goes black, after choosing the new kernel.** The kernel did not start on your machine. Hold the power button to switch off, start again, choose your previous kernel. Report what you saw to the maintainer on the project page.
- **The new kernel is not in the start-up menu.** The install did not finish, or the menu is hidden. On Ubuntu, hold Shift (older machines) or tap Esc (newer machines) while starting to show it.
- **Wi-Fi does not connect on the new kernel.** Choose your previous kernel. The Wi-Fi changes are made for Atheros cards (the AR9485 in the VAIO); other cards are not tested.
- **`sha256sum` says "No such file or directory".** You are in the wrong folder, or the file name is different. Type `ls` and press Enter to see the files in the folder.

### Glossary

- **Kernel:** the core program that lets all other programs use the computer's hardware.
- **Patch:** a list of exact line changes made to a program's source.
- **Package:** a single file that installs a program in the right places.
- **Checksum:** a code calculated from a file, used to prove the file was not changed.
- **GRUB:** the menu shown when a Linux computer starts, where you pick a kernel.
- **Regulatory domain:** the set of radio rules for a country.
- **Byte for byte:** identical in every character.
- **Headers:** files some other programs need in order to build add-ons for this exact kernel.

---

# For developers: how it works, and how to check it

Written for someone who will audit, fork or change the code. It covers the same release as the plain-language part above; neither is a summary of the other.

<!-- developer track: in full, on this page -->

### Purpose and trust level

A rebase of the Gorilla Unleashed patch set (13 patches, `+189 / -103` against pristine) from Linux 7.1.2 to 7.2.9, plus one config change-set fix, built as Debian and RPM packages. Trust level: **built and statically verified; not boot-tested**. No runtime measurement exists for 7.2.9; see `docs/VERIFIED_MEASUREMENTS.md` for what was measured and where.

### Baseline provenance

kernel.org was unreachable from the build machine (egress policy), so the pristine trees are the `v7.1.2` and `v7.2.9` tags of github.com/gregkh/linux, fetched shallow.

- The mirror's `v7.1.2` with the old patches reproduces all 14 shipped 7.1.2 files byte for byte. The shipped files were made from the sha256-verified kernel.org tarball (`37198c93…5883f`), so the mirror equals that tarball for every file the patch set touches.
- The sha256 of `linux-7.2.9.tar.xz` is **not filled in**. `make_patches.py` (`SHA`) and `verify_patches.sh` (`SHA_EXPECT`) carry an empty value, which makes both refuse every tarball until it is filled from kernel.org's `sha256sums.asc`. This fails closed by design.

### The rebase, file by file

`patch -p1 --dry-run --fuzz=0` against pristine 7.2.9:

| Patch | Result on 7.2.9 | Upstream change to the file, 7.1.2 → 7.2.9 |
|---|---|---|
| `reg.c` | applies, offset +3 on hunks 11–15 | `wdev_running()` refactor; new `NL80211_IFTYPE_PD` case in `reg_wdev_chan_valid()` |
| `regd.c` | applies | none |
| `mlme.c` | applies, offset +364 | +884 / -282; `ap_power_level` is still written only by the function our `return 0` short-circuits (`mlme.c` ≈3693) |
| `hw.c` | applies, offset +3 on hunk 2 | +26 / -23, not in the patched lines |
| `init.c` | applies | `devm_kcalloc`, nvmem cell get/put; not in the patched lines |
| `gpio.c`, `btcoex.c` | apply | none |
| `tcp.c` | applies, offsets -1 / -6 | +20 / -26, not in the patched lines |
| `tcp.h` | applies | +47 / -49, not in the patched defines |
| `thinkpad_acpi.c` | applies | +40 / -2, not in the patched lines |
| `dell-pc.c`, `intel_display_params.h` | apply | none |
| `alc269.c` | **3 of 3 hunks fail** | +249 / -6: four enum entries after `ALC245_FIXUP_HP_ENVY_X360_15_FH0XXX`, `alc287_fixup_lenovo_yoga_book_9i()` before the fixups table, a Star Labs vendor quirk |

`alc269.c` was ported by anchor, not by fuzz:

1. `ALC269_FIXUP_VAIO_EAPD_5DB` appended at the end of the enum (after `ALC274_FIXUP_HP_VERBS`). It was the last entry on 7.1.2 too.
2. `alc269_fixup_vaio_eapd_5db()` inserted immediately before `static const struct hda_fixup alc269_fixups[]`.
3. The `[ALC269_FIXUP_VAIO_EAPD_5DB]` table entry inserted immediately before `[ALC269_FIXUP_SONY_VAIO]`, which it chains to. Designated initialisers make the order irrelevant to the compiler.
4. `SND_PCI_QUIRK_VENDOR(0x104d, "Sony VAIO", …)` re-pointed from `ALC269_FIXUP_SONY_VAIO` to `ALC269_FIXUP_VAIO_EAPD_5DB`. That line is unchanged upstream.

**Equivalence check:** for each of the 13 patches, the sorted multiset of `+`/`-` lines is identical between the 7.1.2 and 7.2.9 versions (13 of 13). Patches were regenerated with `make_patches.py` (`BASELINE_DIR` = pristine 7.2.9 checkout). Applying them to pristine 7.2.9 reproduces all 14 registry files byte for byte; `sony-laptop.c` is identical to pristine and has no patch, as on 7.1.2.

**Earlier figure corrected:** the 7.1.2 `patches/README.md` said "14 patches · +196 / −103". The patch files themselves add up to 13 patches and `+189 / -103`.

### Configuration

- `kernel_config_injector.py`: `CONFIG_SCSI_MQ_DEFAULT` removed (commented). No Kconfig defines the symbol in 7.1.2 or 7.2.9, because blk-mq has been the only SCSI path since 5.0. `olddefconfig` drops it, so it never reached a 7.1.2 build either; the Fieldkit `config` stage's verify failed on it.
- Base config: the shipped 7.1.2 `kernel.config` + injector, then `make olddefconfig` on 7.2.9. Verified `248 / 248` in the tree and in the packaged `/boot/config-*`.
- Not compiled: `CONFIG_THINKPAD_ACPI` is not set and the Dell platform driver is off, so the `thinkpad_acpi.c` and `dell-pc.c` patches are carried but inert. This is unchanged from 7.1.2.

### Build

Pipeline: Gorilla Fieldkit `debian-kernel`, stages `deps → extract → config → build → rpm → collect`, on Ubuntu 24.04, gcc 13.3.0, 4 cores. `KCFLAGS="-O3 -pipe"`, `bindeb-pkg`, `KDEB_PKGVERSION=7.2.9`, then `binrpm-pkg` with `LOCALVERSION` read back from `include/config/kernel.release`.

- uname: `7.2.9-unleashed.gorilla-eapd-bbr-26.10.10--13.28` (48 / 64).
- `bindeb-pkg` wall time: about 16 minutes.
- The RPM kernel has the same config byte for byte as the `.deb` kernel. The decompressed images are 72,940,392 bytes each and differ in 69 bytes: `binrpm-pkg` re-links with build number `#2` and a new build timestamp.

#### Package checksums

```
0ae248ea4df86217e1fcea04e61fdaac807992ca0ee8bdf40b116c080d42604c  linux-image-7.2.9-unleashed.gorilla-eapd-bbr-26.10.10--13.28_7.2.9_amd64.deb
2a92b899c5b2f3a866b4e992a56f365bcc5285e6383c2bb1afa750b347019c9e  linux-headers-7.2.9-unleashed.gorilla-eapd-bbr-26.10.10--13.28_7.2.9_amd64.deb
737456ae9bf0e02a110f55ccb4614d03c6018fd2104c89adff415aa7aea708d2  linux-libc-dev_7.2.9_amd64.deb
19b558faff79d9e81796f3ff85d027ecc52351c8222e58d83109a8f4e3c75e37  kernel-7.2.9_unleashed.gorilla_eapd_bbr_26.10.10__13.28-2.x86_64.rpm
a942c8ba1d8bc39448444a86274440ab6214e82499b4c7219263b5b6f4c02b66  kernel-devel-7.2.9_unleashed.gorilla_eapd_bbr_26.10.10__13.28-2.x86_64.rpm
20b96749a38d35b4f88c5341f0d0ac9ed2d03f6d9629aa032ae7d6d60dd05121  kernel-headers-7.2.9_unleashed.gorilla_eapd_bbr_26.10.10__13.28-2.x86_64.rpm
```

Install `linux-image` and `linux-headers` only; never `linux-libc-dev` (it replaces the system's userspace kernel headers).

### Reproduce

```bash
cd debian-kernel                                    # a clone of this repository
BASELINE_DIR=/path/to/pristine/linux-7.2.9 python3 make_patches.py --check   # no drift expected
# with Gorilla Fieldkit, kernel.workdir and kernel.project set in fieldkit.local.json:
fieldkit pipeline run debian-kernel --var version=7.2.9
```

### Known gaps and next actions

- **Not boot-tested.** Next action: install on the VAIO SVE14A3AJ beside the current kernel; record taint, failed units, `iw reg get`, per-channel TX ceiling and the ALC269 log line in `docs/VERIFIED_MEASUREMENTS.md`.
- **sha256 of `linux-7.2.9.tar.xz` missing.** Next action: fill `SHA` and `SHA_EXPECT` from kernel.org, then run `verify_patches.sh` against the real tarball.
- **Build is not reproducible bit for bit across the .deb and .rpm** (build number and timestamp). Next action: set `KBUILD_BUILD_TIMESTAMP`, `KBUILD_BUILD_VERSION`, `KBUILD_BUILD_USER` and `KBUILD_BUILD_HOST` in both Fieldkit stages.
- **README.md and CHANGELOG.md history sections still describe 7.0.9 → 7.1.2.** They are history and remain accurate for that step.
