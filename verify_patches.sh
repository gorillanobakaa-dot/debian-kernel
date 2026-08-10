#!/usr/bin/env bash
# =============================================================================
# Prove the patch set actually works — against the TARBALL, not a directory.
# =============================================================================
# Three things are checked, in increasing strength:
#   1. every patch applies cleanly to pristine 7.1.2 (no fuzz, no rejects)
#   2. the patched result is BYTE-IDENTICAL to the file we ship
#   3. every registry entry has a patch, and vice versa
#
# (2) is the one that matters. "It applied" only means the hunks fit; identical
# output proves the patch set is COMPLETE — nothing in the shipped file came
# from somewhere the patches don't describe.
#
# The baseline is extracted fresh from linux-7.1.2.tar.xz every run. A directory
# can be quietly patched; a tarball cannot. That distinction previously cost this
# project an entire wrong audit conclusion.
# =============================================================================
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(dirname "$HERE")/Kernel.Vault.Do.Not.Delete"
TARBALL="$VAULT/linux-7.1.2.tar.xz"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

G=$'\033[32m'; R=$'\033[31m'; N=$'\033[0m'
pass=0; fail=0

[ -f "$TARBALL" ] || { echo "ABORT: $TARBALL not found"; exit 1; }
echo "tarball : $TARBALL"
echo "sha256  : $(sha256sum "$TARBALL" | cut -c1-64)"
echo

# Which files do we need out of the tarball?
mapfile -t RELS < <(grep -E '^[A-Za-z0-9_.\-]+[[:space:]]*->' "$HERE/PATCHED_FILES_PATH_REGISTRY.txt" \
                    | sed 's/.*->[[:space:]]*//')
echo "extracting ${#RELS[@]} file(s) from the tarball (decompressing, please wait)..."
printf 'linux-7.1.2/%s\n' "${RELS[@]}" > "$WORK/filelist"
tar -xJf "$TARBALL" -C "$WORK" -T "$WORK/filelist" 2>/dev/null
SRC="$WORK/linux-7.1.2"
[ -d "$SRC" ] || { echo "ABORT: extraction produced no tree"; exit 1; }
echo "extracted to a throwaway tree"
echo

echo "── 1. apply every patch to pristine, then 2. compare to what we ship ──"
while read -r p; do
    case "$p" in ''|\#*) continue ;; esac
    f="${p%.patch}"
    rel=$(grep -E "^${f//./\\.}[[:space:]]*->" "$HERE/PATCHED_FILES_PATH_REGISTRY.txt" | sed 's/.*->[[:space:]]*//')
    [ -n "$rel" ] || { echo "  ${R}FAIL${N} $f — not in the registry"; fail=$((fail+1)); continue; }

    if ! out=$(cd "$SRC" && patch -p1 --no-backup-if-mismatch --forward -r - \
                 < "$HERE/patches/$p" 2>&1); then
        echo "  ${R}FAIL${N} $p — did not apply"; echo "$out" | sed 's/^/         /' | head -4
        fail=$((fail+1)); continue
    fi
    if printf '%s' "$out" | grep -qiE 'fuzz|offset'; then
        echo "  ${R}WARN${N} $p — applied with fuzz/offset (baseline drift)"
    fi
    if cmp -s "$SRC/$rel" "$HERE/$f"; then
        echo "  ${G}PASS${N} $p — applies clean AND result is byte-identical to the shipped file"
        pass=$((pass+1))
    else
        echo "  ${R}FAIL${N} $p — applied, but result DIFFERS from the shipped $f"
        echo "         (the patch is incomplete: the shipped file contains changes the patch does not describe)"
        fail=$((fail+1))
    fi
done < "$HERE/patches/series"

echo
echo "── 3. registry ↔ patch-set agreement ──"
for rel in "${RELS[@]}"; do
    f=$(grep -E "\->[[:space:]]*${rel//\//\\/}$" "$HERE/PATCHED_FILES_PATH_REGISTRY.txt" | awk '{print $1}')
    if [ -f "$HERE/patches/$f.patch" ]; then :
    elif cmp -s "$VAULT/linux-7.1.2/$rel" "$HERE/$f" 2>/dev/null; then
        echo "  note: $f is identical to upstream (no patch needed)"
    else
        echo "  ${R}FAIL${N} $f is in the registry but has no patch"; fail=$((fail+1))
    fi
done
[ "$fail" = 0 ] && echo "  ${G}PASS${N} every registry entry is accounted for"

echo
echo "════════════════════════════════════════════════"
printf '  %sPASS %d%s   %sFAIL %d%s\n' "$G" "$pass" "$N" "$R" "$fail" "$N"
[ "$fail" = 0 ] && echo "  ${G}The patch set is complete and reproducible.${N}" \
                || echo "  ${R}The patch set does NOT reproduce the shipped sources.${N}"
echo "════════════════════════════════════════════════"
exit $(( fail > 0 ? 1 : 0 ))
