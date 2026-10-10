#!/usr/bin/env python3
"""Generate unified .patch files for the Gorilla Unleashed 7.2.9 changes.

Diffs the PRISTINE upstream 7.2.9 source against our patched copy, one patch per
file, applicable from the kernel source root with `patch -p1`.

WHY THIS EXISTS
---------------
The installer copies whole files. That works, but a whole file hides intent: you
cannot see what we changed without diffing it yourself, and a reviewer cannot
audit 330 KB of upstream mlme.c to find our 15 lines. These patches make every
change visible.

THE BASELINE
------------
Resolved in this order: $BASELINE_DIR, the local vault (checked for GORILLA marks
first), then a throwaway extraction from linux-7.2.9.tar.xz with its sha256
verified. The tarball path is what lets this run on a bare clone and in CI, which
have no vault.

It is NEVER the *.orig_backup files. Those were taken from trees that had already
been patched, and diffing against them produced a completely wrong audit
conclusion -- the retracted "dropped 11 of 12 patches" finding. A baseline you
have not proven is pristine is worse than no baseline, because it yields a
confident wrong answer instead of an error.

Usage:  python3 make_patches.py [--check]
        --check  regenerate into a temp dir and report drift, writing nothing
"""
import subprocess, sys, pathlib, re, shutil, tempfile, os, atexit

HERE   = pathlib.Path(__file__).resolve().parent
KVER   = "7.2.9"
SHA    = ""  # linux-7.2.9.tar.xz from kernel.org sha256sums.asc: NOT YET FILLED (the 2026-10-10 cloud session could not reach kernel.org); with it empty every tarball is refused
OUT    = HERE / "patches"
CHECK  = "--check" in sys.argv
_TMP   = []   # temp dirs to clean up at exit
atexit.register(lambda: [shutil.rmtree(d, ignore_errors=True) for d in _TMP])


def find_tarball():
    for c in (os.environ.get("TARBALL_PATH"),
              HERE / f"linux-{KVER}.tar.xz",
              HERE.parent / "Kernel.Vault.Do.Not.Delete" / f"linux-{KVER}.tar.xz",
              HERE.parent / f"linux-{KVER}.tar.xz"):
        if c and pathlib.Path(c).is_file():
            return pathlib.Path(c)
    return None


def resolve_baseline(rels):
    """Return a directory holding pristine 7.2.9 sources for `rels`.

    Order: $BASELINE_DIR, the local vault, then a throwaway extraction from the
    tarball. The tarball path exists so this works on a bare clone and in CI,
    where there is no vault -- without it the --check drift gate could not run
    anywhere but the maintainer's laptop.
    """
    env = os.environ.get("BASELINE_DIR")
    if env and pathlib.Path(env).is_dir():
        return pathlib.Path(env), f"$BASELINE_DIR ({env})"

    vault = HERE.parent / "Kernel.Vault.Do.Not.Delete" / f"linux-{KVER}"
    if vault.is_dir():
        marks = subprocess.run(["grep", "-rl", "GORILLA", str(vault)],
                               capture_output=True, text=True).stdout.strip()
        if marks:
            sys.exit("ABORT: the vault contains GORILLA marks -- it is NOT pristine.\n"
                     "Re-extract it from the tarball before generating patches.\n" + marks[:400])
        return vault, f"vault ({vault})  [0 GORILLA marks -- pristine]"

    tb = find_tarball()
    if not tb:
        sys.exit(f"ABORT: no pristine baseline. Provide one of:\n"
                 f"  BASELINE_DIR=/path/to/pristine/linux-{KVER}\n"
                 f"  TARBALL_PATH=/path/to/linux-{KVER}.tar.xz\n"
                 f"  or place linux-{KVER}.tar.xz beside this script.")
    got = subprocess.run(["sha256sum", str(tb)], capture_output=True, text=True).stdout.split()[0]
    if got != SHA:
        sys.exit(f"ABORT: {tb} sha256 {got}\n  does not match pristine {SHA}\n"
                 f"  A wrong baseline produces wrong patches. Refusing.")
    tmp = pathlib.Path(tempfile.mkdtemp()); _TMP.append(tmp)
    members = [f"linux-{KVER}/{r}" for r in rels]
    subprocess.run(["tar", "-xJf", str(tb), "-C", str(tmp)] + members,
                   check=True, stderr=subprocess.DEVNULL)
    return tmp / f"linux-{KVER}", f"tarball extraction ({tb.name}, sha256 verified)"

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

reg = registry()
VAULT, how = resolve_baseline(sorted(reg.values()))
print(f"baseline : {how}")
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
        f"# Baseline: pristine linux-{KVER} (sha256 {SHA})\n"
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
print(f"total: +{total_p} / -{total_m} lines against pristine 7.2.9")
