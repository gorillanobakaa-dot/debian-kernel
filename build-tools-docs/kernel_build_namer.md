# kernel_build_namer.py — dual-track documentation

## 🧸 For the layman
Every kernel we build gets a name — and that name has rules: it must be lowercase
(Debian refuses capitals), it must fit in 64 characters (a hard limit the system
enforces on the kernel's name), it should carry a date-and-time stamp so two
builds never collide, and it must not repeat the version number in a clumsy way.
We always *followed* those rules by hand — and the current kernel's name is 63
characters, one single character away from breaking, with nothing watching it.
This tool makes the rule real: it builds the name, counts the characters, and if
it's about to go over the limit it trims the least-important labels and tells you,
instead of letting the build quietly produce a broken or truncated name. It also
tidies the finished package files so you never get "linux-image-7.1.2-7.1.2".

## 💻 For the developer
Two subcommands, no dependencies.

**`localversion`** — builds a `LOCALVERSION` for `make LOCALVERSION=…`:
- Always lowercases; maps `_`/space → `-`; drops any tag equal to the base
  version (no `7.1.2-…-7.1.2`).
- Always appends a timestamp (`%y.%m.%d--%H.%M` by default; `--year 4` for 4-digit).
  2-digit year is the default because it reclaims 2 chars toward the limit.
- **Hard-enforces `len(base)+len(localversion) ≤ 64`.** If over, it drops feature
  tags from the end (keeping the brand prefix + timestamp), emitting
  a warning per drop; if even prefix+timestamp won't fit, it exits nonzero.
- stdout = the LOCALVERSION string only (stderr carries the diagnostics), so it's
  safe to `LV=$(kernel_build_namer.py localversion …)`.

**`cleandeb`** — post-build, renames `*.deb/*.changes/*.buildinfo` in the output
dir to strip the redundant duplicated version and the `_1` `KDEB_PKGVERSION` tag,
lowercasing the result. Replaces the hardcoded `${base/_7.1.2_amd64/…}` sed hack
in the old `recreate_success.sh` with a version-parametric version.

**Example (Build 1).** Feature tags should be the DISTINCTIVE badge of the build
(what makes this kernel *this* kernel), not stock defaults — e.g. `forensic`,
`eapd` (the ALC269 audio fix), `sdr`, `bbr`. Keep them short; the guard trims to fit.
```sh
LV=$(python3 kernel_build_namer.py localversion --base 7.1.2 \
       --tags unleashed gorilla forensic eapd sdr bbr)   # <- your call; make it mean something
export KCFLAGS="-O3 -march=native -mtune=native -pipe"
make LOCALVERSION="$LV" -j"$(nproc)" bindeb-pkg KDEB_PKGVERSION=1
python3 kernel_build_namer.py cleandeb --base 7.1.2 --dir ./output_binaries
# uname form: 7.x-unleashed.gorilla-*  (concrete build appends the tags + a
#   YY.MM.DD--HH.MM stamp, always held <= 64 chars)
```
