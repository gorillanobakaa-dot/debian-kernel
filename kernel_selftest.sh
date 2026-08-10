#!/usr/bin/env bash
# =============================================================================
# GORILLA UNLEASHED KERNEL — SELF-TEST
# =============================================================================
# Checks that the things this kernel promises are actually true ON YOUR MACHINE.
#
#   ./kernel_selftest.sh          normal run
#   ./kernel_selftest.sh --raw    also print the raw command output for each check
#
# Design rules (they matter):
#   * Nothing here changes your system. It only reads.
#   * A check that CANNOT be performed says SKIP and why — it never says PASS.
#     "Couldn't look" and "looked and it's fine" must never print the same word.
#   * Works without sudo; checks needing root say so instead of failing.
#   * Safe on kernels other than this one — it reports what it finds.
# =============================================================================

RAW=0
[ "$1" = "--raw" ] && RAW=1

# /sbin and /usr/sbin are missing from many non-interactive PATHs. iw, rfkill and
# sysctl live there, and their absence from PATH looks exactly like "not
# installed" — a false alarm this project has already been burned by once.
export PATH="/sbin:/usr/sbin:$PATH"

pass=0; fail=0; skip=0
G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; B=$'\033[1m'; D=$'\033[2m'; N=$'\033[0m'
[ -t 1 ] || { G=; R=; Y=; B=; D=; N=; }

section() { printf '\n%s──── %s ────%s\n' "$B" "$1" "$N"; }
ok()   { printf '  %sPASS%s  %s\n' "$G" "$N" "$1"; pass=$((pass+1)); }
no()   { printf '  %sFAIL%s  %s\n' "$R" "$N" "$1"; fail=$((fail+1)); }
sk()   { printf '  %sSKIP%s  %s %s(%s)%s\n' "$Y" "$N" "$1" "$D" "$2" "$N"; skip=$((skip+1)); }
raw()  { [ "$RAW" = 1 ] && printf '%s        %s%s\n' "$D" "$1" "$N"; }

have() { command -v "$1" >/dev/null 2>&1; }
root() { [ "$(id -u)" = 0 ] || have sudo; }
# Read the running kernel's own embedded config — the only source that cannot lie
kconf() {
    if [ -r /proc/config.gz ]; then zcat /proc/config.gz
    elif [ -r "/boot/config-$(uname -r)" ]; then cat "/boot/config-$(uname -r)"
    else return 1; fi
}

printf '%s╔══════════════════════════════════════════════════════════════╗%s\n' "$B" "$N"
printf '%s║        GORILLA UNLEASHED KERNEL — SELF-TEST                  ║%s\n' "$B" "$N"
printf '%s╚══════════════════════════════════════════════════════════════╝%s\n' "$B" "$N"
printf '  kernel : %s\n  host   : %s\n  date   : %s\n' "$(uname -r)" "$(uname -n)" "$(date)"

# ─────────────────────────────────────────────────────────────────────────────
section "1. Kernel identity and integrity"

case "$(uname -r)" in
  *unleashed*) ok "running a Gorilla Unleashed kernel" ;;
  *) sk "not an Unleashed kernel — later checks describe THIS kernel, not ours" "uname: $(uname -r)" ;;
esac

t=$(cat /proc/sys/kernel/tainted 2>/dev/null)
if [ "$t" = "0" ]; then ok "kernel taint flag is 0 (nothing proprietary or forced loaded)"
elif [ -n "$t" ]; then no "kernel is tainted (flag=$t) — see 'Tainted' in dmesg"
else sk "cannot read taint flag" "/proc/sys/kernel/tainted unreadable"; fi

if kconf >/dev/null 2>&1; then
    ok "the kernel can show you its own config (IKCONFIG_PROC)"
    raw "try: zcat /proc/config.gz | grep CONFIG_HZ"
else
    sk "cannot read the running kernel's config" "no /proc/config.gz and no /boot/config-$(uname -r)"
fi

n=$(ls -1 /boot/vmlinuz-* 2>/dev/null | wc -l)
if [ "$n" -ge 2 ]; then ok "$n kernels installed — you have a fallback if one won't boot"
elif [ "$n" = 1 ]; then no "only ONE kernel in /boot — no fallback. Keep the previous one installed."
else sk "cannot inspect /boot" "no vmlinuz-* found (unusual layout?)"; fi

# ─────────────────────────────────────────────────────────────────────────────
section "2. Wi-Fi deregulation (the headline feature)"

if have iw; then
    if root; then
        reg=$(sudo iw reg get 2>/dev/null | sed -n '2p')
        if printf '%s' "$reg" | grep -q "country 00"; then
            ok "regulatory domain is world (00) — no country is restricting you"
        else
            no "regulatory domain is '$reg' — something set a country. Expected 'country 00'."
        fi
        raw "$reg"

        # The real test: is an AP nearby TELLING us a country, and did we ignore it?
        adv=$(sudo iw dev "$(iw dev 2>/dev/null | awk '/Interface/{print $2; exit}')" scan dump 2>/dev/null \
              | grep -oiE 'Country: [A-Z]{2}' | sort -u | head -1)
        if [ -n "$adv" ]; then
            if printf '%s' "$reg" | grep -q "country 00"; then
                ok "an access point advertises '$adv' and we IGNORED it (this is the patch working)"
            else
                no "an access point advertises '$adv' and we appear to have obeyed it"
            fi
        else
            sk "no access point nearby advertises a country" "cannot prove the country-IE patch here; it is still compiled in"
        fi
    else
        sk "regulatory domain check needs root" "run with sudo, or: sudo iw reg get"
    fi

    phy=$(ls -1d /sys/class/ieee80211/* 2>/dev/null | head -1 | xargs -r basename)
    if [ -n "$phy" ] && root; then
        ch=$(sudo iw phy "$phy" info 2>/dev/null | grep -c '2[0-9]\{3\}\.0 MHz')
        c14=$(sudo iw phy "$phy" info 2>/dev/null | grep -c '2484.0 MHz')
        [ "$ch" -gt 0 ] && ok "$ch channels enabled on $phy" || sk "no 2.4 GHz channels listed" "5 GHz-only or unusual radio"
        [ "$c14" -gt 0 ] && ok "channel 14 (Japan) is enabled — normally blocked outside Japan" \
                         || sk "channel 14 not present" "hardware may not support 2484 MHz"
    else
        [ -n "$phy" ] || sk "no wireless device found" "nothing to test"
    fi
else
    sk "iw not found" "install with: sudo apt install iw    (note: it lives in /sbin)"
fi

if root && have journalctl; then
    if sudo journalctl -b -k --no-pager -q 2>/dev/null | grep -qi "Limiting TX power"; then
        no "an access point lowered your transmit power (mlme.c patch not effective)"
    else
        ok "no access point has lowered your transmit power this boot"
    fi
    if sudo journalctl -b -k --no-pager -q 2>/dev/null | grep -qi "dynamically updated by country"; then
        no "the regulatory domain was changed by an access point (reg.c patch not effective)"
    else
        ok "no access point has changed your regulatory domain this boot"
    fi
else
    sk "boot-log checks need root" "run with sudo"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "3. Audio (Sony VAIO speaker fix)"

if root && have journalctl && sudo journalctl -b -k --no-pager -q 2>/dev/null | grep -qi "VAIO EAPD"; then
    ok "the VAIO EAPD speaker fix loaded: $(sudo journalctl -b -k --no-pager -q | grep -o 'VAIO EAPD.*' | head -1)"
elif kconf 2>/dev/null | grep -q '^CONFIG_SND_HDA_CODEC_REALTEK=y'; then
    sk "Realtek codec support is built in, but no EAPD message seen" "not a Sony VAIO, or different codec"
else
    sk "cannot verify audio fix" "needs root and a Realtek/VAIO codec"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "4. Storage responsiveness (BFQ)"

found=0
for d in /sys/block/sd* /sys/block/nvme*; do
    [ -e "$d/queue/scheduler" ] || continue
    found=1
    dev=$(basename "$d"); s=$(cat "$d/queue/scheduler"); rot=$(cat "$d/queue/rotational" 2>/dev/null)
    sel=$(printf '%s' "$s" | grep -o '\[[a-z-]*\]' | tr -d '[]')
    case "$dev:$rot:$sel" in
        nvme*) ok "$dev uses '$sel' (NVMe is fast enough to need no scheduler)" ;;
        *:0:bfq) ok "$dev (SSD) uses BFQ — desktop stays responsive under disk load" ;;
        *:1:mq-deadline) ok "$dev (spinning disk) uses mq-deadline — correct" ;;
        *) no "$dev uses '$sel' (rotational=$rot) — expected bfq for SSD, mq-deadline for HDD" ;;
    esac
done
[ "$found" = 1 ] || sk "no block devices found to check" "unusual storage layout"

# ─────────────────────────────────────────────────────────────────────────────
section "5. Networking (BBR congestion control)"

cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
qd=$(sysctl -n net.core.default_qdisc 2>/dev/null)
[ "$cc" = "bbr" ] && ok "TCP uses BBR — better on lossy//slow links than the default" \
                  || { [ -n "$cc" ] && no "TCP uses '$cc', expected bbr" || sk "cannot read TCP settings" "sysctl unavailable"; }
case "$qd" in
  fq_codel|fq) ok "queue discipline is '$qd' — keeps things snappy while downloading" ;;
  "") sk "cannot read qdisc" "sysctl unavailable" ;;
  *) no "queue discipline is '$qd', expected fq_codel or fq" ;;
esac

# ─────────────────────────────────────────────────────────────────────────────
section "6. CPU behaviour (fan and battery)"

g=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
case "$g" in
  schedutil|ondemand|powersave) ok "CPU governor is '$g' — scales with load, fan stays quiet" ;;
  performance) no "CPU governor is 'performance' — pins clocks high, spins the fan, cooks the battery" ;;
  "") sk "no cpufreq governor exposed" "virtualised, or driver does its own scaling" ;;
  *) sk "CPU governor is '$g'" "not a value this test knows about" ;;
esac

if have sensors; then
    # Strip the "(high = +87.0°C, crit = +105.0°C)" tail FIRST. Without this the
    # threshold values get matched as if they were live readings and the test
    # cheerfully reports a 105°C CPU on a machine sitting at 53°C. Caught during
    # the first run of this script — a scary number that was pure parsing error.
    tmax=$(sensors 2>/dev/null | sed 's/(.*//' | grep -oE '\+[0-9]+\.[0-9]°C' \
           | tr -d '+°C' | sort -n | tail -1)
    if [ -n "$tmax" ]; then
        printf '  %sINFO%s  hottest sensor right now: %s°C ' "$D" "$N" "$tmax"
        case "${tmax%%.*}" in
            [0-9]|[1-6][0-9]) printf '(normal)\n' ;;
            [7-8][0-9])       printf '(warm — normal under load)\n' ;;
            *)                printf '(hot — check airflow/fan)\n' ;;
        esac
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
section "7. Forensics and recovery tools"

if kconf >/dev/null 2>&1; then
    for pair in "CONFIG_MAGIC_SYSRQ:emergency keyboard rescue (SysRq)" \
                "CONFIG_IKCONFIG_PROC:kernel can show its own config" \
                "CONFIG_EROFS_FS:can mount modern Android system images" \
                "CONFIG_EXFAT_FS:can mount exFAT (cameras, big USB sticks)" \
                "CONFIG_NTFS3_FS:can read/write Windows NTFS drives" \
                "CONFIG_HFSPLUS_FS:can mount Mac HFS+ drives"; do
        f=${pair%%:*}; d=${pair#*:}
        if kconf | grep -qE "^${f}=(y|m)"; then ok "$d"
        else sk "$d — not enabled" "$f is off in this kernel"; fi
    done
    if kconf | grep -q '^CONFIG_PROC_KCORE=y'; then
        printf '  %sINFO%s  live kernel-memory access (PROC_KCORE) is ON — great for forensics,\n' "$D" "$N"
        printf '        %sintentionally left OUT of the public build. Root-only.%s\n' "$D" "$N"
    fi
else
    sk "cannot check kernel features" "no readable kernel config"
fi

sq=$(sysctl -n kernel.sysrq 2>/dev/null)
[ -n "$sq" ] && [ "$sq" != "0" ] && ok "SysRq rescue keys are armed (kernel.sysrq=$sq)" \
             || { [ "$sq" = "0" ] && no "SysRq is disabled — you lose the emergency rescue keys"; }

# ─────────────────────────────────────────────────────────────────────────────
section "8. Boot health"

if root && have journalctl; then
    e=$(sudo journalctl -b -k -p 3 --no-pager -q 2>/dev/null | grep -vciE 'ACPI|db_root')
    w=$(sudo journalctl -b -k -p 4..4 --no-pager -q 2>/dev/null | wc -l)
    [ "$e" = "0" ] && ok "no kernel errors this boot (beyond known harmless firmware noise)" \
                   || no "$e kernel error(s) this boot — check: sudo journalctl -b -k -p 3"
    printf '  %sINFO%s  %s kernel warning line(s) this boot — warnings are usually normal\n' "$D" "$N" "$w"
    f=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
    [ "$f" = "0" ] && ok "no failed system services" || no "$f failed service(s) — see: systemctl --failed"
else
    sk "boot health needs root" "run with sudo"
fi

# ─────────────────────────────────────────────────────────────────────────────
printf '\n%s══════════════════════════════════════════════════════════════%s\n' "$B" "$N"
printf '  %sPASS %d%s   %sFAIL %d%s   %sSKIP %d%s\n' "$G" "$pass" "$N" "$R" "$fail" "$N" "$Y" "$skip" "$N"
if [ "$fail" = 0 ]; then
    printf '  %sEverything this test could check, checked out.%s\n' "$G" "$N"
    [ "$skip" -gt 0 ] && printf '  %sSKIP is not PASS — those are things it could not look at.%s\n' "$D" "$N"
else
    printf '  %sSomething is off. A FAIL is not an emergency — your old kernel is still%s\n' "$R" "$N"
    printf '  %sin the boot menu. Reboot, hold SHIFT, and pick the previous one.%s\n' "$D" "$N"
fi
printf '%s══════════════════════════════════════════════════════════════%s\n' "$B" "$N"
exit 0
