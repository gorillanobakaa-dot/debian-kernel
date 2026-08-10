# kernel_config_injector.py — dual-track documentation

## 🧸 For the layman
Building a kernel means choosing thousands of yes/no options. This tool stamps
*our* chosen options onto a fresh configuration in one go, so a build is always
the deliberate Gorilla setup and never drifts back to defaults. The important
part of THIS version: the old one it replaces was quietly re-adding three broken
choices every time it ran — a made-up CPU setting that doesn't exist, the
"run the fan flat-out forever" power mode, and a server-only timer mode — which
would have silently undone all the careful tuning we did. This version has those
removed and the good, audited choices (including the Android EROFS filesystem
that was missing, and the crash-recovery key) put in. Run it, and the config is
correct on purpose.

## 💻 For the developer
Applies the audited **Build-1 change-set** (`BUILD1_CONFIG_CHANGESET.md`) to a
kernel `.config`: rewrites matching lines, appends missing flags, reports the
diff. Reuses the original injector's sound apply-logic; the change is the flag
set.

**Decontaminated vs the original `Kernel.7.1.2.Patches/config_injector.py`:**
- REMOVED `CONFIG_MIVYBRIDGE=y` (phantom — not a real symbol in this tree) and
  its `CONFIG_GENERIC_CPU=n` pair. The real arch selector `X86_NATIVE_CPU=y` stays.
- CHANGED governor default `PERFORMANCE` → `SCHEDUTIL` (the always-on-fan fix).
- CHANGED `NO_HZ_FULL=y` → `NO_HZ_IDLE=y` + `VIRT_CPU_ACCOUNTING_GEN=n` +
  `RCU_NOCB_CPU=n` (desktop tick, drop the per-syscall server tax).
- ADDED Build-1: IKCONFIG(+PROC), MAGIC_SYSRQ, PROC_KCORE, FORTIFY_SOURCE,
  HARDENED_USERCOPY, SLAB_FREELIST_RANDOM/HARDENED, EROFS_FS, MTD_NAND_NANDSIM,
  EFIVAR_FS=y, HW_RANDOM_INTEL=y, SND_USB_AUDIO/USB_ACM/USB_SERIAL+FTDI/CP210X/
  CH341/PL2303 = y (built-in per the integrity rule).
- KEPT the good perf tweaks: BBR, fq_codel, PREEMPT, ZRAM+zstd, MGLRU (LRU_GEN),
  THP, HDA patch-loader, SATA/BFQ, the forensic partition-tables + FS set.
- PRUNES the 141-module DVB/TV-tuner zoo (`=n`) while keeping the RTL-SDR chain
  (`DVB_RTL2832(+_SDR)`, `R820T/E4000/FC0012/13`) built in for RF forensics.

**247 flags total.** Self-verifies at the end: prints lines-changed/appended and
explicitly asserts the phantom `MIVYBRIDGE` is absent (§2 — verify the artifact).

**Usage:** `python3 kernel_config_injector.py <kernel_src_root>` then
`make -C <src> olddefconfig` (resolves deps EROFS/DVB pull in). Refuses if the
source or `.config` is absent (§3).
