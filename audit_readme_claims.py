#!/usr/bin/env python3
"""Check every code-level claim in the README's developer sections against the
SHIPPED SOURCE. Not against another document. Not from memory."""
import re, pathlib, subprocess

P = pathlib.Path(__file__).resolve().parent          # the shipped sources sit next to this script

# (README section, file, human claim, regex that must match the shipped source)
CLAIMS = [
 ("#1 reg.c", "reg.c", "map_regdom_flags neuters NO_IR",            r"NL80211_RRF_NO_IR_ALL\)\s*\n\s*channel_flags \|= 0"),
 ("#1 reg.c", "reg.c", "map_regdom_flags neuters DFS/RADAR",        r"NL80211_RRF_DFS\)\s*\n\s*channel_flags \|= 0"),
 ("#1 reg.c", "reg.c", "CHAN_DISABLED stripped",                    r"GORILLA_UNLEASHED: CHAN_DISABLED stripped"),
 ("#1 reg.c", "reg.c", "NO_HT40MINUS neutered",                     r"NL80211_RRF_NO_HT40MINUS\)\s*\n\s*channel_flags \|= 0"),
 ("#1 reg.c", "reg.c", "NO_80MHZ neutered",                         r"NL80211_RRF_NO_80MHZ\)\s*\n\s*channel_flags \|= 0"),
 ("#1 reg.c", "reg.c", "NO_160MHZ neutered",                        r"NL80211_RRF_NO_160MHZ\)\s*\n\s*channel_flags \|= 0"),
 ("#1 reg.c", "reg.c", "NO_HE neutered",                            r"NL80211_RRF_NO_HE\)\s*\n\s*channel_flags \|= 0"),
 ("#1 reg.c", "reg.c", "NO_EHT neutered",                           r"NL80211_RRF_NO_EHT\)\s*\n\s*channel_flags \|= 0"),
 ("#1 reg.c", "reg.c", "NO_UHR neutered",                           r"NL80211_RRF_NO_UHR\)\s*\n\s*channel_flags \|= 0"),
 ("#1 reg.c", "reg.c", "NO_320MHZ neutered",                        r"NL80211_RRF_NO_320MHZ\)\s*\n\s*channel_flags \|= 0"),

 ("#2 hw.c",  "hw.c",  "cwm_ignore_extcca = true",                  r"cwm_ignore_extcca\s*=\s*true"),
 ("#2 hw.c",  "hw.c",  "chan_pwr = MAX_COMBINED_POWER",             r"chan_pwr\s*=\s*MAX_COMBINED_POWER"),
 ("#2 hw.c",  "hw.c",  "new_pwr = MAX_COMBINED_POWER",              r"new_pwr\s*=\s*MAX_COMBINED_POWER"),

 ("#3 btcoex","btcoex.c","wl_active_time = 0xFF",                   r"wl_active_time\s*=\s*0x[fF][fF]"),
 ("#3 btcoex","btcoex.c","wl_qc_time = 0xFF",                       r"wl_qc_time\s*=\s*0x[fF][fF]"),

 ("#4 gpio",  "gpio.c","stomp_type = ATH_BTCOEX_STOMP_NONE",        r"stomp_type\s*=\s*ATH_BTCOEX_STOMP_NONE"),

 ("#5 init.c","init.c","ath9k_modparam_nohwcrypt = 1",              r"ath9k_modparam_nohwcrypt\s*=\s*1"),
 ("#5 init.c","init.c","ath9k_btcoex_enable = 1",                   r"ath9k_btcoex_enable\s*=\s*1"),
 ("#5 init.c","init.c","cur_chan->txpower = MAX_COMBINED_POWER",    r"cur_chan->txpower\s*=\s*MAX_COMBINED_POWER"),

 ("#7 tcp.h", "tcp.h","TCP_INIT_CWND 128",                          r"#define\s+TCP_INIT_CWND\s+128"),
 ("#7 tcp.h", "tcp.h","TCP_RTO_MIN = HZ/100 (10ms)",                r"#define\s+TCP_RTO_MIN\s+\(\(unsigned\)\(HZ\s*/\s*100\)\)"),
 ("#7 tcp.h", "tcp.h","TCP_RTO_MAX = 3s",                           r"TCP_RTO_MAX_SEC\s+3|#define\s+TCP_RTO_MAX\s+\(\(unsigned\)\(3\s*\*\s*HZ\)\)"),
 ("#7 tcp.h", "tcp.h","TCP_TIMEOUT_INIT = HZ/10 (100ms)",           r"#define\s+TCP_TIMEOUT_INIT\s+\(\(unsigned\)\(HZ\s*/\s*10\)\)"),
 ("#7 tcp.h", "tcp.h","TCP_DELACK_MAX = HZ/50 (20ms)",              r"#define\s+TCP_DELACK_MAX\s+\(\(unsigned\)\(HZ\s*/\s*50\)\)"),
 ("#7 tcp.h", "tcp.h","TCP_DELACK_MIN = 2U",                        r"#define\s+TCP_DELACK_MIN\s+\(\(unsigned\)\(2U?\)\)|#define\s+TCP_DELACK_MIN\s+2U"),
 ("#7 tcp.h", "tcp.h","TCP_ATO_MIN = 2U",                           r"#define\s+TCP_ATO_MIN\s+\(?\(?2U?\)?\)?"),
 ("#7 tcp.h", "tcp.h","TCP_TIMEWAIT_LEN = 1*HZ",                    r"#define\s+TCP_TIMEWAIT_LEN\s+\(1\s*\*\s*HZ\)"),
 ("#7 tcp.h", "tcp.h","TCP_SYN_RETRIES 3",                          r"#define\s+TCP_SYN_RETRIES\s+3"),
 ("#7 tcp.h", "tcp.h","TCP_SYNACK_RETRIES 3",                       r"#define\s+TCP_SYNACK_RETRIES\s+3"),
 ("#7 tcp.h", "tcp.h","TCP_RETR2 8",                                r"#define\s+TCP_RETR2\s+8"),
 ("#7 tcp.h", "tcp.h","TCP_KEEPALIVE_TIME = 15min",                 r"#define\s+TCP_KEEPALIVE_TIME\s+\(15\s*\*\s*60\s*\*\s*HZ\)"),

 ("#8 tcp.c", "tcp.c","tcp_wmem/rmem default 16777216",             r"16777216"),
 ("#8 tcp.c", "tcp.c","tcp_wmem/rmem max 67108864",                 r"67108864"),
 ("#8 tcp.c", "tcp.c","snd_cwnd_clamp = 65535 in tcp_init_sock",    r"snd_cwnd_clamp\s*=\s*65535"),
]

rows, bad = [], 0
for sec, fname, claim, rx in CLAIMS:
    src = (P / fname)
    if not src.exists():
        rows.append((sec, claim, "NO FILE")); bad += 1; continue
    text = src.read_text(errors="ignore")
    ok = re.search(rx, text) is not None
    rows.append((sec, claim, "OK" if ok else "NOT FOUND"))
    if not ok:
        bad += 1

w = max(len(c) for _, c, _ in rows)
cur = None
for sec, claim, verdict in rows:
    if sec != cur:
        print(f"\n{sec}"); cur = sec
    mark = "  ok  " if verdict == "OK" else "  ??  "
    print(f"{mark}{claim:<{w}}  {'' if verdict=='OK' else verdict}")

print(f"\n{'='*70}\n  {len(rows)-bad}/{len(rows)} claims verified in the shipped source"
      f"{'' if bad==0 else f'  —  {bad} NOT FOUND, investigate each'}")
