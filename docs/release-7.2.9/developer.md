# Gorilla Unleashed 7.2.9 — developer notes

## Purpose and trust level

A rebase of the Gorilla Unleashed patch set (13 patches, `+189 / -103` against pristine) from Linux 7.1.2 to 7.2.9, plus one config change-set fix, built as Debian and RPM packages. Trust level: **built and statically verified; not boot-tested**. No runtime measurement exists for 7.2.9; see `docs/VERIFIED_MEASUREMENTS.md` for what was measured and where.

## Baseline provenance

**Release packages** are built by the project's CI, which runs the Gorilla Fieldkit `debian-kernel` pipeline on a GitHub runner: its `fetch` stage downloads kernel.org's `linux-7.2.9.tar.xz` and checks it against kernel.org's `sha256sums.asc` before anything is built. The checksums of the packages a release carries are on its page under "Package checksums" and in its `SHA256SUMS` file.

**The migration itself** was done on a cloud machine that could not reach kernel.org (egress policy), so its pristine trees are the `v7.1.2` and `v7.2.9` tags of github.com/gregkh/linux, fetched shallow.

- The mirror's `v7.1.2` with the old patches reproduces all 14 shipped 7.1.2 files byte for byte. The shipped files were made from the sha256-verified kernel.org tarball (`37198c93…5883f`), so the mirror equals that tarball for every file the patch set touches.
- The sha256 of `linux-7.2.9.tar.xz` is `b4c5dfbe51a364a6c7f03869200f88c8e1f77403539005f14b7fc6bc91b8d8ba`, read from kernel.org's `sha256sums.asc` by a GitHub runner, whose download of the tarball matched it. It is in `make_patches.py` (`SHA`) and `verify_patches.sh` (`SHA_EXPECT`). The signature on `sha256sums.asc` was not checked.

## The rebase, file by file

`patch -p1 --dry-run --fuzz=0` against pristine 7.2.9:

| Patch | Result on 7.2.9 | Upstream change to the file, 7.1.2 → 7.2.9 |
|---|---|---|
| `reg.c` | applies, offset +3 on hunks 11–17 | `wdev_running()` refactor; new `NL80211_IFTYPE_PD` case in `reg_wdev_chan_valid()` |
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

## Configuration

- `kernel_config_injector.py`: `CONFIG_SCSI_MQ_DEFAULT` removed (commented). No Kconfig defines the symbol in 7.1.2 or 7.2.9, because blk-mq has been the only SCSI path since 5.0. `olddefconfig` drops it, so it never reached a 7.1.2 build either; the Fieldkit `config` stage's verify failed on it.
- Base config: the shipped 7.1.2 `kernel.config` + injector, then `make olddefconfig` on 7.2.9. Verified `248 / 248` in the tree and in the packaged `/boot/config-*`.
- Not compiled: `CONFIG_THINKPAD_ACPI` is not set and the Dell platform driver is off, so the `thinkpad_acpi.c` and `dell-pc.c` patches are carried but inert. This is unchanged from 7.1.2.

## Build

The first 7.2.9 build, on the cloud machine (the numbers below are that build's; a release's own build differs in its name's date and time and in its checksums). Pipeline: Gorilla Fieldkit `debian-kernel`, stages `deps → extract → config → build → rpm → collect`, on Ubuntu 24.04, gcc 13.3.0, 4 cores. `KCFLAGS="-O3 -pipe"`, `bindeb-pkg`, `KDEB_PKGVERSION=7.2.9`, then `binrpm-pkg` with `LOCALVERSION` read back from `include/config/kernel.release`.

- uname: `7.2.9-unleashed.gorilla-eapd-bbr-26.10.10--13.28` (48 / 64).
- `bindeb-pkg` wall time: about 16 minutes.
- The RPM kernel has the same config byte for byte as the `.deb` kernel. The decompressed images are 72,940,392 bytes each and differ in 69 bytes: `binrpm-pkg` re-links with build number `#2` and a new build timestamp.

Releases carry `linux-image` and `linux-headers` (.deb) and `kernel` and `kernel-devel` (.rpm). `linux-libc-dev` and the `kernel-headers` RPM are left out on purpose: they replace the system's userspace kernel headers.

## Reproduce

```bash
cd debian-kernel                                    # a clone of this repository
BASELINE_DIR=/path/to/pristine/linux-7.2.9 python3 make_patches.py --check   # no drift expected
# with Gorilla Fieldkit, kernel.workdir and kernel.project set in fieldkit.local.json:
fieldkit pipeline run debian-kernel --var version=7.2.9
```

## Known gaps and next actions

- **Not boot-tested.** Next action: install on the VAIO SVE14A3AJ beside the current kernel; record taint, failed units, `iw reg get`, per-channel TX ceiling and the ALC269 log line in `docs/VERIFIED_MEASUREMENTS.md`.
- **Build is not reproducible bit for bit across the .deb and .rpm** (build number and timestamp). Next action: set `KBUILD_BUILD_TIMESTAMP`, `KBUILD_BUILD_VERSION`, `KBUILD_BUILD_USER` and `KBUILD_BUILD_HOST` in both Fieldkit stages.
- **README.md and CHANGELOG.md history sections still describe 7.0.9 → 7.1.2.** They are history and remain accurate for that step.
