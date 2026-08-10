#!/usr/bin/env python3
"""Generate unified .patch files for the Gorilla Unleashed 7.1.2 changes.

Diffs the PRISTINE upstream 7.1.2 source against our patched copy, one patch per
file, applicable from the kernel source root with `patch -p1`.

WHY THIS EXISTS
---------------
The installer copies whole files. That works, but a whole file hides intent: you
cannot see what we changed without diffing it yourself, and a reviewer cannot
audit 330 KB of upstream mlme.c to find our 15 lines. These patches make every
change visible.

The baseline is the VAULT, which is verified byte-identical to the pristine
linux-7.1.2 tarball. It is NEVER the *.orig_backup files -- those were taken from
already-patched trees and produced a completely wrong audit conclusion once
already (see docs/, and the KERNEL brain concept on .orig_backup impostors).

Usage:  python3 make_patches.py [--check]
        --check  regenerate into a temp dir and report drift, writing nothing
"""
import subprocess, sys, pathlib, re, shutil, tempfile, os

HERE   = pathlib.Path(__file__).resolve().parent
VAULT  = pathlib.Path("/home/gorilla/Documents/Debian.Kernel.Work/"
                      "Kernel.Vault.Do.Not.Delete/linux-7.1.2")
TARBALL= VAULT.parent / "linux-7.1.2.tar.xz"
OUT    = HERE / "patches"
CHECK  = "--check" in sys.argv

def registry():
    """filename -> path relative to the kernel source root."""
    reg, f = {}, HERE / "PATCHED_FILES_PATH_REGISTRY.txt"
    pat = re.compile(r'^([A-Za-z0-9_.\-]+)\s*->\s*(\S+)$')
    for line in f.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        m = pat.match(line)
        if m:
            reg[m.group(1)] = m.group(2)
    return reg

# ── sanity: the baseline must genuinely be pristine ──────────────────────────
if not VAULT.is_dir():
    sys.exit(f"ABORT: vault not found at {VAULT}")
marks = subprocess.run(["grep", "-rl", "GORILLA", str(VAULT)],
                       capture_output=True, text=True).stdout.strip()
if marks:
    sys.exit("ABORT: the vault contains GORILLA marks -- it is NOT pristine.\n"
             "Re-extract it from the tarball before generating patches.\n" + marks[:400])
print(f"baseline : {VAULT}  (0 GORILLA marks -- pristine)")
print(f"tarball  : {TARBALL}  {'present' if TARBALL.exists() else 'MISSING'}")

reg = registry()
print(f"registry : {len(reg)} file(s)\n")

dest = pathlib.Path(tempfile.mkdtemp()) if CHECK else OUT
dest.mkdir(parents=True, exist_ok=True)

made, skipped, drift = [], [], []
for fname, rel in sorted(reg.items()):
    ours  = HERE / fname
    orig  = VAULT / rel
    if not ours.exists():
        skipped.append((fname, "no patched copy in the repo")); continue
    if not orig.exists():
        skipped.append((fname, f"no pristine counterpart at {rel}")); continue

    # diff -u, labelled a/<rel> and b/<rel> so `patch -p1` works from the root.
    r = subprocess.run(
        ["diff", "-u", "--label", f"a/{rel}", "--label", f"b/{rel}", str(orig), str(ours)],
        capture_output=True, text=True)
    if r.returncode == 0:
        skipped.append((fname, "identical to pristine -- nothing to patch")); continue
    if r.returncode != 1:
        sys.exit(f"ABORT: diff failed on {fname}: {r.stderr}")

    body = r.stdout
    plus  = sum(1 for l in body.splitlines() if l.startswith("+") and not l.startswith("+++"))
    minus = sum(1 for l in body.splitlines() if l.startswith("-") and not l.startswith("---"))

    header = (
        f"# Gorilla Unleashed -- {rel}\n"
        f"# Baseline: pristine linux-7.1.2 (vault, verified against linux-7.1.2.tar.xz)\n"
        f"# Apply from the kernel source root:  patch -p1 < patches/{fname}.patch\n"
        f"# Rationale: docs/{fname}.md\n"
        f"# +{plus} / -{minus} lines\n"
    )
    out = dest / f"{fname}.patch"
    new = header + body
    if CHECK and (OUT / f"{fname}.patch").exists():
        cur = (OUT / f"{fname}.patch").read_text()
        if cur != new:
            drift.append(fname)
    out.write_text(new)
    made.append((fname, rel, plus, minus))

for fname, rel, p, m in made:
    print(f"  {fname:28s} +{p:<5d} -{m:<5d}  {rel}")
for fname, why in skipped:
    print(f"  {fname:28s} SKIP  ({why})")

if CHECK:
    shutil.rmtree(dest)
    if drift:
        print("\nDRIFT: patches out of date for: " + ", ".join(drift))
        sys.exit(1)
    print("\nno drift -- committed patches match the sources")
    sys.exit(0)

# ── series file, so the order is explicit and machine-readable ───────────────
(dest / "series").write_text(
    "# Apply in this order from the kernel source root:\n"
    "#   while read -r p; do [ \"${p#\\#}\" = \"$p\" ] || continue; \\\n"
    "#       patch -p1 < \"patches/$p\"; done < patches/series\n"
    + "".join(f"{f}.patch\n" for f, _, _, _ in made))

total_p = sum(p for _, _, p, _ in made)
total_m = sum(m for _, _, _, m in made)
print(f"\nwrote {len(made)} patch(es) + series to {dest}")
print(f"total: +{total_p} / -{total_m} lines against pristine 7.1.2")
