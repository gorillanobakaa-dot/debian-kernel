# Verified measurements — Gorilla Unleashed 7.1.2

Numbers in this file were **observed on the machine**. Anything not listed here
must be written as "not measured" in generated documentation — never estimated,
never inferred, never rounded into existence.

Machine: Sony VAIO SVE14A3AJ · i7-3632QM (Ivy Bridge) · 16 GB · Kingston DC600M
SATA SSD · Atheros AR9485 (2.4 GHz only) · measured 2026-08-10.

## Kernel identity

| Item | Value |
|---|---|
| Running kernel | `7.x-unleashed.gorilla-*` (Build 3, tags: forensic·eapd·sdr·bbr) |
| Taint flag | `0` |
| Failed systemd units | `0` |
| Kernels in /boot | `4` |
| Kernel boot time | `4.116 s` (`systemd-analyze`) |
| Kernel error lines this boot | `0` beyond known ACPI/`db_root` firmware noise |
| Kernel warning lines this boot | `13` (was `40` on Build 2) |

## Wireless / regulatory

| Item | Value |
|---|---|
| `iw reg get` global | `country 00: DFS-UNSET` |
| AP-advertised country IE | `Country: GB Environment: Indoor/Outdoor` (present, ignored) |
| 2.4 GHz channels enabled | `14` (includes ch14 @ 2484 MHz) |
| Per-channel ceiling, Build 3 | `17.0 dBm` on all 14 channels |
| Per-channel ceiling, Build 2 | `20.0 dBm` on ch1–13, `17.0 dBm` on ch14 |
| AR9485 real calibrated ceiling | `17 dBm` (EEPROM; the 20 dBm figure was a regulatory-table value the silicon cannot reach) |
| `iw dev` configured txpower | `15.00 dBm` |
| "Limiting TX power" log lines | `0` this boot |
| "dynamically updated by country element" lines | `0` this boot |

**NOT MEASURED:** actual radiated RF power (no spectrum analyser); throughput or
range change from any regulatory patch; any Build-2 `iw dev txpower` reading for
comparison; the 802.11h power-constraint patch in a live scenario (no AP in range
advertised a Power Constraint IE).

## Audio

| Item | Value |
|---|---|
| Fixup loaded | `ALC269: VAIO EAPD (+5.5dB balanced offset) unleashed!` |
| Codec | Realtek ALC269, vendor ID `0x10ec0269` |

**NOT MEASURED:** the actual dB gain. The "+5.5 dB" string is the fixup's own
label; the amp offset is `0x14` (20 steps) and the step→dB mapping was never
measured on this hardware. Do not repeat "+5.5 dB" as a measured figure.

## Storage / CPU / network

| Item | Value |
|---|---|
| `sda` scheduler | `bfq` (rotational=0) |
| CPU governor | `schedutil` |
| Hottest core, idle | `52.0 °C` (crit threshold is 105 °C — not a reading) |
| TCP congestion control | `bbr` |
| Default qdisc | `fq_codel` |
| `tcp_rmem` / `tcp_wmem` max | `67108864` (64 MB, civilian profile) |
| Owner's measured link | `517.87 Mbps` (Ethernet speedtest, 2026-08-10) |

**NOT MEASURED:** any before/after throughput, latency or battery-life delta from
BBR, BFQ, `HZ=1000`, `NO_HZ_IDLE`, `mitigations=off`, or `-O3 -march=native`. No
A/B benchmark has been run on this machine. Every performance claim in the docs is
a *design rationale*, not a measurement.

## Build

| Item | Value |
|---|---|
| ccache, Build 3 | `213 hits / 20 misses` (91.42%) |
| ccache max size | `20 GB` (was the 5 GiB default; no config file existed) |
| Compiler flags | `-O3 -march=native -mtune=native -pipe` |
| Files patched | `14 / 14` |
| Compiler errors/warnings on patched files | `0` |
| Self-test result | `PASS 24 · FAIL 0 · SKIP 0` |
