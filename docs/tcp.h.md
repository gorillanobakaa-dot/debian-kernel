# Patch Documentation: tcp.h
**File:** `include/net/tcp.h`
**Subsystem:** Core TCP Protocol Headers & Timing Parameters
**Kernel:** Linux 7.1.2 (Gorilla Unleashed)

---

## Developer Track

### What This File Does (Upstream)
`tcp.h` contains the core definitions, structures, macros, and configuration constants for the TCP protocol stack in the Linux kernel. It governs timeout thresholds, retransmission counts, Keepalive frequencies, and initial congestion window settings.

### What The Patch Changes

The patch modifies several timing constants to optimize for low latency, rapid packet loss recovery, and fast port recycling:

**1. Retransmission and SYN/SYNACK Retries:**
- `TCP_RETR2`: Reduced from 15 to 8. Accelerates connection abort on unacknowledged active connections.
- `TCP_SYN_RETRIES` & `TCP_SYNACK_RETRIES`: Reduced to 3. Speeds up connection failure reporting to the application if the remote host is offline.

**2. TIME-WAIT Reduction:**
- `TCP_TIMEWAIT_LEN` & `TCP_FIN_TIMEOUT`: Reduced from 60 seconds (`60*HZ`) to 1 second (`1*HZ`). Frees closed sockets and local ports instantly, preventing port exhaustion.

**3. Delayed ACK Tuning:**
- `TCP_DELACK_MAX`: Reduced from HZ/5 (200ms) to HZ/50 (20ms). Force-sends delayed ACKs much faster, speeding up the round-trip feedback loop.
- `TCP_DELACK_MIN` & `TCP_ATO_MIN`: Capped at 2 jiffies (`2U`) instead of HZ/25.

**4. Retransmission Timeout (RTO) Tuning:**
- `TCP_RTO_MAX_SEC`: Reduced from 120 seconds to 3 seconds. The maximum wait time before retransmitting a lost packet is capped at 3s.
- `TCP_RTO_MIN`: Reduced from HZ/5 (200ms) to HZ/100 (10ms). Unlocks sub-millisecond retransmission loops.
- `TCP_TIMEOUT_INIT`: Reduced from 1 second (`1*HZ`) to 100 milliseconds (`HZ/10`).

**5. Keepalive Timing:**
- `TCP_KEEPALIVE_TIME`: Reduced from 2 hours (`120*60*HZ`) to 15 minutes (`15*60*HZ`).

**6. Initial Congestion Window (CWND):**
- `TCP_INIT_CWND`: Boosted from 10 to 128 packets. Allows a client to burst 128 packets instantly on connection startup before receiving an ACK.

---

## Layman Track

### What Does `tcp.h` Normally Do?

The `tcp.h` file contains the **timer settings** for your network connection.

If you lose connection to a server or a packet of data is lost, the kernel doesn't give up immediately. It waits a set amount of time (Retransmission Timeout) and tries again. If a socket is closed, it waits a full 60 seconds (TIME-WAIT) to make sure no late packets arrive.

Upstream settings are extremely conservative (written for slow, unstable networks decades ago) — they wait up to 2 hours to detect a dead connection, wait 60 seconds to clean up closed ports, and wait up to 2 minutes before giving up on a lost packet.

### What The Patch Does

This patch **re-tunes the timers for the modern, fast internet**.

**Key Improvements:**
- **Instant Response to Data Loss:** If a packet is lost, the kernel now waits only **10 milliseconds** (0.01 seconds) instead of 200 milliseconds to retransmit.
- **Fast Startup:** When opening a new webpage or connection, your browser can send **128 packets of data instantly** instead of the default 10, meaning pages start loading much faster.
- **Fast Cleanup:** Closed ports are freed up in **1 second** instead of 60, preventing your system from running out of available ports.
- **Fast Detection of Dead Sockets:** If a server goes offline, your connection aborts in 15 minutes instead of 2 hours.

### Who Benefits

Web browsing, local file transfers, and gaming will feel significantly more responsive, especially on connections that experience minor packet drops (like Wi-Fi), because the operating system recovers from those drops instantly instead of freezing for several seconds.

---

**Status in 7.1.2:** Confirmed clean apply. Ready to port.
