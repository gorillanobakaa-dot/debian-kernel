#!/usr/bin/env python3
"""kernel_build_namer.py — safe, timestamped, 64-char-guarded kernel naming.

The naming convention was hand-crafted to fit Debian's 64-char uname/package
limit, lowercase (Debian dislikes caps), timestamped, and free of redundant
duplicated version tags. But nothing ENFORCED the 64-char limit — the running
kernel name is 63/64, one character from silently breaking. This tool makes the
convention real: it builds the LOCALVERSION, hard-checks the total length, and
degrades gracefully (drops trailing feature tags) instead of overflowing.

SUBCOMMANDS
  localversion  build a safe LOCALVERSION string for `make LOCALVERSION=...`
  cleandeb      rename built .deb/.changes/.buildinfo to strip redundant tags

USAGE
  # LOCALVERSION for a build (prints the string; exits nonzero if it can't fit):
  kernel_build_namer.py localversion --base 7.2.9 \
      --tags unleashed gorilla forensic eapd sdr bbr --year 2
  #  -> -<brand>-<tags>-<YY.MM.DD--HH.MM>   (brand prefix = "unleashed"+"gorilla")
  #  tags = the build's DISTINCTIVE badge (forensic/eapd/sdr...), not stock defaults

  # after the build, tidy the output dir:
  kernel_build_namer.py cleandeb --base 7.2.9 --dir ./output_binaries

RULES ENFORCED
  * total = len(base) + len(localversion) <= 64  (Debian/uname hard limit)
  * lowercase only; spaces/underscores -> '-'; no duplicated base-version tag
  * timestamp always included (uniqueness); YY (2-digit) or YYYY year
  * if too long: drop feature tags from the end, keep prefix + timestamp, WARN
"""
import argparse
import datetime
import os
import re
import sys

UNAME_LIMIT = 64
PREFIX_TAGS = ("unleashed", "gorilla")   # the fixed brand prefix, always first


def slug(s: str) -> str:
    s = s.lower().replace("_", "-").replace(" ", "-")
    s = re.sub(r"[^a-z0-9.-]", "", s)
    return re.sub(r"-{2,}", "-", s).strip("-")


def build_localversion(base: str, tags, year_digits: int) -> str:
    fmt = "%y.%m.%d--%H.%M" if year_digits == 2 else "%Y.%m.%d--%H.%M"
    ts = datetime.datetime.now().strftime(fmt)
    base = slug(base)
    tags = [slug(t) for t in tags if slug(t) and slug(t) != base]  # no dup version

    # feature tags = whatever the caller passed minus the fixed prefix ones
    prefix = [t for t in tags if t in PREFIX_TAGS] or list(PREFIX_TAGS)
    feats = [t for t in tags if t not in PREFIX_TAGS]

    def assemble(fs):
        parts = ".".join(prefix) + (("-" + "-".join(fs)) if fs else "")
        return f"-{parts}-{ts}"

    lv = assemble(feats)
    # Enforce the limit: total = base + localversion. Drop trailing feats to fit.
    while len(base) + len(lv) > UNAME_LIMIT and feats:
        dropped = feats.pop()
        sys.stderr.write(f"[namer] over {UNAME_LIMIT} chars — dropping tag '{dropped}'\n")
        lv = assemble(feats)
    total = len(base) + len(lv)
    if total > UNAME_LIMIT:
        sys.exit(f"[namer] cannot fit even prefix+timestamp in {UNAME_LIMIT} "
                 f"(got {total}). Shorten the brand prefix.")
    sys.stderr.write(f"[namer] uname will be '{base}{lv}' ({total}/{UNAME_LIMIT} chars)\n")
    return lv


def cleandeb(base: str, out_dir: str) -> int:
    if not os.path.isdir(out_dir):
        sys.exit(f"[namer] output dir '{out_dir}' not found (§3).")
    base = slug(base)
    n = 0
    for fn in os.listdir(out_dir):
        if not fn.endswith((".deb", ".changes", ".buildinfo")):
            continue
        clean = fn
        # strip redundant duplicated version + the KDEB_PKGVERSION '_1'
        for red in (f"_{base}_amd64", f"_{base}_all"):
            clean = clean.replace(red, red.replace(f"_{base}", ""))
        clean = clean.replace("_1_amd64", "_amd64").replace("_1_all", "_all")
        clean = clean.lower()
        if clean != fn:
            os.rename(os.path.join(out_dir, fn), os.path.join(out_dir, clean))
            print(f"  {fn}  ->  {clean}")
            n += 1
    print(f"[namer] cleaned {n} filename(s).")
    return n


def main():
    ap = argparse.ArgumentParser(description="Safe 64-char kernel naming.")
    sub = ap.add_subparsers(dest="cmd", required=True)
    lv = sub.add_parser("localversion")
    lv.add_argument("--base", required=True, help="kernel version, e.g. 7.2.9")
    lv.add_argument("--tags", nargs="+", required=True,
                    help="feature tags; 'unleashed gorilla' become the fixed prefix")
    lv.add_argument("--year", type=int, choices=(2, 4), default=2,
                    help="timestamp year digits (default 2 = shorter, more headroom)")
    cd = sub.add_parser("cleandeb")
    cd.add_argument("--base", required=True)
    cd.add_argument("--dir", required=True)
    a = ap.parse_args()
    if a.cmd == "localversion":
        print(build_localversion(a.base, a.tags, a.year))   # stdout = the string
    else:
        cleandeb(a.base, a.dir)


if __name__ == "__main__":
    main()
