# Kernel Build Pre-Flight — the way we do things

The canonical checklist for building a Gorilla Unleashed kernel. `recreate_success.sh`
runs the automatable parts itself (the `preflight()` block) and **refuses to build**
if a hard check fails — so no future build silently skips ccache or builds in the
vault. This doc is the human reference; the script is the enforcement.

## Hard checks (build ABORTS if any fail)
- [ ] **Build in the WORKSPACE, never the vault.** Target =
      `kernel-build-workspace/linux-7.1.2`. Building in `Kernel.Vault.Do.Not.Delete/`
      is forbidden (that's how the vault got contaminated). Script asserts the
      target path is not under the vault.
- [ ] **A pristine reference exists** to diff against: `Kernel.Vault…/linux-7.1.2.tar.xz`
      present and intact. (Verify patches against the TARBALL, never `.orig_backup`.)
- [ ] **Output dir resolvable:** `Clean Output Binaries/` (auto-found; `OUT_DIR` overrides).

## Standard settings (the recipe — script sets/verifies, warns if off)
- [ ] **ccache ON** — `CC="ccache gcc"`. Auto-detected; a full rebuild drops from
      ~an hour to minutes warm. Check with `ccache -s`.
- [ ] **Compiler flags** — `KCFLAGS="-O3 -march=native -mtune=native -pipe"`.
      `-march=native` = tuned for THIS Ivy Bridge (portable builds for the public
      track use `-march=<generic>` instead — see two-track plan).
- [ ] **Config via the DECONTAMINATED injector** — `kernel_config_injector.py`, then
      `make olddefconfig`. Never the old injector (it re-added phantom
      `CONFIG_MIVYBRIDGE` + performance-gov + `NO_HZ_FULL`).
- [ ] **No phantom flags** — grep the final `.config`: `MIVYBRIDGE` absent,
      `NO_HZ_IDLE` (not FULL), `schedutil` default, `X86_NATIVE_CPU=y`.
- [ ] **Used-hardware drivers `=y`, not `=m`** (monolithic-integrity rule).
- [ ] **Name:** timestamped, **≤64 chars (Debian limit)**, lowercase, no redundant
      version — via `kernel_build_namer.py`.

## Build + verify (never trust an exit code — §2)
- [ ] `make … bindeb-pkg` exit captured via `$BUILD_RC`/`${PIPESTATUS[0]}`, not tee's.
- [ ] **Artifact confirmed:** `linux-image-*.deb` exists in `Clean Output Binaries/`,
      size sane (~28 MB), name matches intent.
- [ ] **Do NOT ship/install `linux-libc-dev`** (clobbers userspace headers).

## Install (protect the fallback)
- [ ] Install **alongside** the current kernel — `dpkg -i` the new image+headers,
      **never remove the old kernel**. `update-grub` must list both.
- [ ] Reboot into the new one; if it won't boot, pick the old one in GRUB. No reinstall.

## Post-boot proof (prove settings landed — don't assert)
- [ ] `zcat /proc/config.gz | grep <FLAG>` — every intended change present in the
      RUNNING kernel's own config (IKCONFIG makes this possible).
- [ ] Boot log carries patch signatures (e.g. the EAPD codec line); `journalctl -b -k`.
- [ ] `cat /proc/sys/kernel/tainted` == 0; zero Oops/BUG/WARN this boot.
- [ ] Source-patch efficacy that needs runtime (regulatory, 40 MHz): verify with
      `iw list`/`iw reg get`, not from source.

## Userspace tuning ships + auto-applies (users won't have an agent)
- [ ] udev: `60-io-scheduler.rules` (SSD→bfq), `60-superdrive.rules`, `70-wifi-rename`.
- [ ] sysctl: the consolidated `99-gorilla-*.conf` (civilian or datacenter).
- [ ] **Gap to close for shipped users:** embed these in the package (postinst or a
      companion `gorilla-unleashed-config` .deb) so a plain `dpkg -i` is enough.
