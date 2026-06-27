# Patch Documentation: tcp.c
**File:** `net/ipv4/tcp.c`
**Subsystem:** Core TCP Protocol Implementation
**Kernel:** Linux 7.1.2 (Gorilla Unleashed)

---

## Developer Track

### What This File Does (Upstream)
`tcp.c` is the core implementation file for the TCP transport layer protocol in the Linux kernel. It manages connection setup, socket allocation, and system-wide default TCP buffer memory allocation buffers.

### What The Patch Changes

**Change 1 — Set `snd_cwnd_clamp` limit to 65535:**
```c
// Before:
tp->snd_cwnd_clamp = ~0;
// After:
tp->snd_cwnd_clamp = 65535;
```
Restricts the maximum congestion window size clamp to `65535` instead of infinity (`~0`). This caps the amount of unacknowledged data on high-speed connections to prevent excessive bufferbloat and latency spikes under congestion.

**Change 2 — Massively Expand Read and Write Buffers:**
```c
// Before:
init_net.ipv4.sysctl_tcp_wmem[0] = PAGE_SIZE;
init_net.ipv4.sysctl_tcp_wmem[1] = 16*1024;
init_net.ipv4.sysctl_tcp_wmem[2] = max(64*1024, max_wshare);

init_net.ipv4.sysctl_tcp_rmem[0] = PAGE_SIZE;
init_net.ipv4.sysctl_tcp_rmem[1] = 131072;
init_net.ipv4.sysctl_tcp_rmem[2] = max(131072, max_rshare);

// After:
init_net.ipv4.sysctl_tcp_wmem[0] = 4096;
init_net.ipv4.sysctl_tcp_wmem[1] = 16777216; /* GORILLA: 16MB Default Write Buffer */
init_net.ipv4.sysctl_tcp_wmem[2] = 67108864; /* GORILLA: 64MB Max Write Buffer */

init_net.ipv4.sysctl_tcp_rmem[0] = 4096;
init_net.ipv4.sysctl_tcp_rmem[1] = 16777216; /* GORILLA: 16MB Default Read Buffer */
init_net.ipv4.sysctl_tcp_rmem[2] = 67108864; /* GORILLA: 64MB Max Read Buffer */
```
The patch overwrites the default TCP read (`rmem`) and write (`wmem`) buffer arrays.
Upstream defaults are conservative: 16KB default write, 128KB default read. These scale dynamically up to 4MB/32MB depending on system RAM.

The patch initializes a massive **16MB default starting buffer** and allows scaling up to a **64MB maximum buffer** for both sending and receiving. This ensures that high-bandwidth, high-latency streams (like TCP BBR) never experience window starvation.

---

## Layman Track

### What Does `tcp.c` Normally Do?

Whenever you download a file, load a webpage, or watch a video, the data is broken up into packets and sent over a protocol called TCP.

To keep data flowing smoothly, the Linux kernel sets up **holding zones in memory** called "buffers."
- The **Write Buffer** holds data you are sending (uploading).
- The **Read Buffer** holds incoming data (downloading).

If these buffers are too small, your network speed drops because the sender has to pause and wait for the receiver to clear out the memory holding zone.

Normally, Linux starts with tiny buffers (16 Kilobytes to 128 Kilobytes) and slowly resizes them.

### What The Patch Does

This patch **widens the pipes to maximum capacity**.

It sets the starting size for both reading and writing buffers to **16 Megabytes**, and allows them to expand to **64 Megabytes**.

Think of it like replacing a narrow garden hose with a massive water main. Data can flow in huge bursts instantly without having to wait for the system to slowly scale up the buffer sizes.

### Who Benefits

Users with high-speed internet connections (fiber, gigabit) or those transferring files on local networks (LAN) will see their download/upload speeds ramp up to max capacity almost instantly.

### Trade-Offs

- **Memory Usage:** Since buffers start at 16MB, each active TCP connection will consume slightly more RAM than normal. On a system with multiple gigabytes of memory, this is negligible.

---

**Status in 7.1.2:** Confirmed clean apply. Ready to port.
