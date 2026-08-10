#!/usr/bin/env python3
"""kernel_config_injector.py — apply the audited Build-1 change-set to a .config.

DECONTAMINATED 2026-08-10. The previous config_injector.py (Kernel.7.1.2.Patches)
re-injected the exact contamination this project's audit removed:
  - CONFIG_MIVYBRIDGE=y     : a PHANTOM flag that does not exist in this tree
  - CPU_FREQ_DEFAULT_GOV_PERFORMANCE=y : the always-on-fan governor (want schedutil)
  - NO_HZ_FULL=y            : server-only tick (want NO_HZ_IDLE on a desktop)
Running the old injector would silently UNDO the whole config audit. This version
applies the verified Build-1 change-set (see BUILD1_CONFIG_CHANGESET.md) and keeps
the genuinely-good perf tweaks (BBR, fq_codel, ZRAM+zstd, MGLRU, THP, HDA
patch-loader) plus the forensic-workstation feature set.

USAGE
    python3 kernel_config_injector.py <kernel_source_root>
    # then: make -C <src> olddefconfig   (resolves deps, e.g. EROFS)

DIRECTIVE NOTES
  - Anchored to the .config; refuses if the source/.config is absent (§3).
  - Reports the diff it made; verify the artifact, not the exit code (§2).
"""
import os
import sys

# ── Positive change-set: the flags we WANT on/off (decontaminated + Build-1) ──
MANDATORY_FLAGS = {
    # -- CPU arch (Ivy Bridge). The REAL selector, not the phantom MIVYBRIDGE. --
    "CONFIG_X86_NATIVE_CPU": "y",       # = -march=native = ivybridge here
    # (CONFIG_MIVYBRIDGE / CONFIG_GENERIC_CPU=n from the old injector are GONE.)

    # -- CPU governor: schedutil default (NOT performance — the fan fix) --
    "CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL": "y",
    "CONFIG_CPU_FREQ_GOV_SCHEDUTIL": "y",
    "CONFIG_CPU_FREQ_GOV_PERFORMANCE": "y",   # available, just not the default
    "CONFIG_CPU_FREQ_GOV_ONDEMAND": "y",
    # (CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE is intentionally omitted/left unset)

    # -- Timers: HZ=1000 + NO_HZ_IDLE (desktop), NOT NO_HZ_FULL (server) --
    "CONFIG_HZ_250": "n",
    "CONFIG_HZ_1000": "y",
    "CONFIG_HZ": "1000",
    "CONFIG_NO_HZ_COMMON": "y",
    "CONFIG_NO_HZ_IDLE": "y",
    "CONFIG_NO_HZ_FULL": "n",
    "CONFIG_VIRT_CPU_ACCOUNTING_GEN": "n",  # per-syscall tax that rode NO_HZ_FULL
    "CONFIG_RCU_NOCB_CPU": "n",             # only useful with NO_HZ_FULL

    # -- Preemption: low-latency desktop --
    "CONFIG_PREEMPT": "y",
    "CONFIG_PREEMPT_COUNT": "y",
    "CONFIG_PREEMPTION": "y",
    "CONFIG_PREEMPT_VOLUNTARY": "n",
    "CONFIG_PREEMPT_RT": "n",

    # -- Networking: BBR + fq_codel (compile defaults; sysctl profile layers on) --
    "CONFIG_TCP_CONG_BBR": "y",
    "CONFIG_DEFAULT_BBR": "y",
    "CONFIG_DEFAULT_TCP_CONG": '"bbr"',
    "CONFIG_NET_SCH_FQ": "y",
    "CONFIG_NET_SCH_FQ_CODEL": "y",
    "CONFIG_NET_SCH_DEFAULT": "y",
    "CONFIG_DEFAULT_FQ_CODEL": "y",
    "CONFIG_DEFAULT_NET_SCH": '"fq_codel"',
    "CONFIG_NET_RX_BUSY_POLL": "y",
    "CONFIG_NET_SCH_INGRESS": "y",
    "CONFIG_NET_SCH_HTB": "y",

    # -- Wireless regulatory: the config half of the deregulation --
    # CERTIFICATION_ONUS was already on; it is the gate that makes the relax
    # options selectable ("the onus of regulatory certification is on you").
    # REG_RELAX_NO_IR was left off, so the dependency was satisfied and the
    # feature unused: it relaxes the no-initiate-radiation restriction when an
    # interface is already associated on the channel — i.e. it stops the kernel
    # forbidding transmit on channels a peer is demonstrably already using.
    # Source-side counterparts live in reg.c / regd.c / mlme.c.
    "CONFIG_CFG80211_CERTIFICATION_ONUS": "y",
    "CONFIG_CFG80211_REG_RELAX_NO_IR": "y",

    # -- I/O: BFQ for the DC600M (effective via udev rule) --
    "CONFIG_IOSCHED_BFQ": "y",
    "CONFIG_BFQ_GROUP_IOSCHED": "y",
    "CONFIG_MQ_IOSCHED_KYBER": "y",
    "CONFIG_SCSI_MQ_DEFAULT": "y",
    "CONFIG_SATA_AHCI": "y",
    "CONFIG_ATA_PIIX": "y",
    "CONFIG_BLK_DEV_SD": "y",

    # -- Memory perf tricks (the surviving 'every trick in the book') --
    "CONFIG_LRU_GEN": "y",                 # MGLRU
    "CONFIG_LRU_GEN_ENABLED": "y",
    "CONFIG_ZRAM": "y",
    "CONFIG_ZRAM_BACKEND_ZSTD": "y",
    "CONFIG_ZRAM_DEF_COMP_ZSTD": "y",
    "CONFIG_ZRAM_DEF_COMP": '"zstd"',
    "CONFIG_ZSMALLOC": "y",
    "CONFIG_TRANSPARENT_HUGEPAGE": "y",
    "CONFIG_TRANSPARENT_HUGEPAGE_MADVISE": "y",
    "CONFIG_SCHED_AUTOGROUP": "y",

    # -- Audio: HDA + patch-loader (ALC269 EAPD path) --
    "CONFIG_SND_HDA_HWDEP": "y",
    "CONFIG_SND_HDA_RECONFIG": "y",
    "CONFIG_SND_HDA_PATCH_LOADER": "y",

    # -- Forensics / recovery flags (Build-1 additions) --
    "CONFIG_IKCONFIG": "y",
    "CONFIG_IKCONFIG_PROC": "y",           # /proc/config.gz
    "CONFIG_MAGIC_SYSRQ": "y",             # recover a hung/half-booted kernel
    "CONFIG_PROC_KCORE": "y",              # live kernel memory forensics

    # -- Cheap build-time hardening (compile-time; runtime posture stays open) --
    "CONFIG_FORTIFY_SOURCE": "y",
    "CONFIG_HARDENED_USERCOPY": "y",
    "CONFIG_SLAB_FREELIST_RANDOM": "y",
    "CONFIG_SLAB_FREELIST_HARDENED": "y",

    # -- Forensic filesystems: the EROFS GAP (AOSP) + raw-NAND dump mount --
    "CONFIG_EROFS_FS": "y",                # modern Android/AOSP system+vendor images

    # nandsim is a MODULE on purpose — the one documented exception to the
    # monolithic "=y" rule. That rule covers DRIVERS FOR HARDWARE WE USE;
    # nandsim is not a driver, it is a per-case forensic INSTRUMENT whose
    # geometry (first_id_byte/second_id_byte/parts/...) must match the dump
    # being examined and is set at load time.
    # Built in (=y, Builds 1-2) it self-instantiated at every boot: a permanent
    # useless 128 MiB fake "NAND simulator partition 0" in /proc/mtd, six
    # warning lines, three mtdblock nags — and, worse, unconfigurable, because
    # built-in code takes its parameters only from the kernel cmdline at boot.
    # As =m:  modprobe nandsim first_id_byte=0x2c second_id_byte=0xdc ...
    "CONFIG_MTD_NAND_NANDSIM": "m",        # mount a raw NAND flash dump (load per case)

    # -- Promote proven-used to built-in (integrity: no .ko to swap) --
    "CONFIG_EFIVAR_FS": "y",               # loaded every boot (UEFI vars)
    "CONFIG_HW_RANDOM_INTEL": "y",         # Intel hardware RNG

    # -- USB device drivers BUILT-IN (=y) per monolithic-integrity rule --
    "CONFIG_SND_USB_AUDIO": "y",           # USB DAC / headset / interface
    "CONFIG_USB_ACM": "y",                 # CDC-ACM serial (Arduino/3D printers/modems)
    "CONFIG_USB_SERIAL": "y",
    "CONFIG_USB_SERIAL_FTDI_SIO": "y",
    "CONFIG_USB_SERIAL_CP210X": "y",
    "CONFIG_USB_SERIAL_CH341": "y",
    "CONFIG_USB_SERIAL_PL2303": "y",

    # -- RTL-SDR (dual-use RF/wireless forensics) — built in, the DVB survivor --
    "CONFIG_MEDIA_DIGITAL_TV_SUPPORT": "y",
    "CONFIG_DVB_CORE": "y",
    "CONFIG_DVB_RTL2832": "y",
    "CONFIG_DVB_RTL2832_SDR": "y",
    "CONFIG_MEDIA_TUNER_R820T": "y",
    "CONFIG_MEDIA_TUNER_E4000": "y",
    "CONFIG_MEDIA_TUNER_FC0012": "y",
    "CONFIG_MEDIA_TUNER_FC0013": "y",

    # -- Boot/console essentials the old injector set (keep) --
    "CONFIG_BLK_DEV_INITRD": "y",
    "CONFIG_DEVTMPFS": "y",
    "CONFIG_DEVTMPFS_MOUNT": "y",
    "CONFIG_DRM_RADEON": "y",              # VAIO Radeon 7670M (dormant)
    "CONFIG_CHR_DEV_SG": "y",              # raw SCSI (forensic imaging)

    # -- Phone/Apple/WWAN + cluster/forensic FS (mount-anything mission) --
    "CONFIG_USB_IPHETH": "y",
    "CONFIG_USB_NET_QMI_WWAN": "y",
    "CONFIG_USB_NET_CDC_MBIM": "y",
    "CONFIG_USB_NET_RNDIS_HOST": "y",
    "CONFIG_HID_APPLEIR": "y",
    "CONFIG_APPLE_GMUX": "y",
    "CONFIG_NFS_V4_2": "y",
    "CONFIG_NFSD": "m",
    "CONFIG_9P_FS": "m",
    "CONFIG_CEPH_FS": "m",
    "CONFIG_OCFS2_FS": "m",
    "CONFIG_GFS2_FS": "m",
    "CONFIG_UBIFS_FS": "y",
    "CONFIG_DM_VERITY": "y",
    "CONFIG_BEFS_FS": "y",
    "CONFIG_VXFS_FS": "y",
    "CONFIG_LDM_PARTITION": "y",
    "CONFIG_MAC_PARTITION": "y",
    "CONFIG_BSD_DISKLABEL": "y",

    # -- Drop the wrong-vendor / absent-hardware bloat --
    "CONFIG_HW_RANDOM_AMD": "n",
    "CONFIG_HW_RANDOM_VIA": "n",
    "CONFIG_NVME_FABRICS": "n",
    "CONFIG_NVME_FC": "n",
    "CONFIG_NVME_TCP": "n",
    "CONFIG_MTD_NAND_DISKONCHIP": "n",

    # ── DVB/TV tuner zoo to disable (141 modules; RTL-SDR kept above) ──
    "CONFIG_DVB_A8293": "n",
    "CONFIG_DVB_AF9013": "n",
    "CONFIG_DVB_AF9033": "n",
    "CONFIG_DVB_ASCOT2E": "n",
    "CONFIG_DVB_ATBM8830": "n",
    "CONFIG_DVB_AU8522": "n",
    "CONFIG_DVB_AU8522_DTV": "n",
    "CONFIG_DVB_AU8522_V4L": "n",
    "CONFIG_DVB_BCM3510": "n",
    "CONFIG_DVB_CX22700": "n",
    "CONFIG_DVB_CX22702": "n",
    "CONFIG_DVB_CX24110": "n",
    "CONFIG_DVB_CX24116": "n",
    "CONFIG_DVB_CX24117": "n",
    "CONFIG_DVB_CX24120": "n",
    "CONFIG_DVB_CX24123": "n",
    "CONFIG_DVB_CXD2099": "n",
    "CONFIG_DVB_CXD2820R": "n",
    "CONFIG_DVB_CXD2841ER": "n",
    "CONFIG_DVB_DIB3000MB": "n",
    "CONFIG_DVB_DIB3000MC": "n",
    "CONFIG_DVB_DIB7000M": "n",
    "CONFIG_DVB_DIB7000P": "n",
    "CONFIG_DVB_DIB8000": "n",
    "CONFIG_DVB_DIB9000": "n",
    "CONFIG_DVB_DRX39XYJ": "n",
    "CONFIG_DVB_DRXD": "n",
    "CONFIG_DVB_DRXK": "n",
    "CONFIG_DVB_DS3000": "n",
    "CONFIG_DVB_EC100": "n",
    "CONFIG_DVB_HELENE": "n",
    "CONFIG_DVB_HORUS3A": "n",
    "CONFIG_DVB_ISL6405": "n",
    "CONFIG_DVB_ISL6421": "n",
    "CONFIG_DVB_ISL6423": "n",
    "CONFIG_DVB_IX2505V": "n",
    "CONFIG_DVB_L64781": "n",
    "CONFIG_DVB_LG2160": "n",
    "CONFIG_DVB_LGDT3305": "n",
    "CONFIG_DVB_LGDT3306A": "n",
    "CONFIG_DVB_LGDT330X": "n",
    "CONFIG_DVB_LGS8GL5": "n",
    "CONFIG_DVB_LGS8GXX": "n",
    "CONFIG_DVB_LNBH25": "n",
    "CONFIG_DVB_LNBH29": "n",
    "CONFIG_DVB_LNBP21": "n",
    "CONFIG_DVB_LNBP22": "n",
    "CONFIG_DVB_M88DS3103": "n",
    "CONFIG_DVB_M88RS2000": "n",
    "CONFIG_DVB_MB86A16": "n",
    "CONFIG_DVB_MB86A20S": "n",
    "CONFIG_DVB_MN88443X": "n",
    "CONFIG_DVB_MN88472": "n",
    "CONFIG_DVB_MN88473": "n",
    "CONFIG_DVB_MT312": "n",
    "CONFIG_DVB_MT352": "n",
    "CONFIG_DVB_MXL5XX": "n",
    "CONFIG_DVB_MXL692": "n",
    "CONFIG_DVB_NXT200X": "n",
    "CONFIG_DVB_NXT6000": "n",
    "CONFIG_DVB_OR51132": "n",
    "CONFIG_DVB_OR51211": "n",
    "CONFIG_DVB_PLL": "n",
    "CONFIG_DVB_RTL2830": "n",
    "CONFIG_DVB_S5H1409": "n",
    "CONFIG_DVB_S5H1411": "n",
    "CONFIG_DVB_S5H1420": "n",
    "CONFIG_DVB_S5H1432": "n",
    "CONFIG_DVB_S921": "n",
    "CONFIG_DVB_SI2165": "n",
    "CONFIG_DVB_SI2168": "n",
    "CONFIG_DVB_SI21XX": "n",
    "CONFIG_DVB_SP2": "n",
    "CONFIG_DVB_SP887X": "n",
    "CONFIG_DVB_STB0899": "n",
    "CONFIG_DVB_STB6000": "n",
    "CONFIG_DVB_STB6100": "n",
    "CONFIG_DVB_STV0288": "n",
    "CONFIG_DVB_STV0297": "n",
    "CONFIG_DVB_STV0299": "n",
    "CONFIG_DVB_STV0367": "n",
    "CONFIG_DVB_STV0900": "n",
    "CONFIG_DVB_STV090x": "n",
    "CONFIG_DVB_STV0910": "n",
    "CONFIG_DVB_STV6110": "n",
    "CONFIG_DVB_STV6110x": "n",
    "CONFIG_DVB_STV6111": "n",
    "CONFIG_DVB_TC90522": "n",
    "CONFIG_DVB_TDA10021": "n",
    "CONFIG_DVB_TDA10023": "n",
    "CONFIG_DVB_TDA10048": "n",
    "CONFIG_DVB_TDA1004X": "n",
    "CONFIG_DVB_TDA10071": "n",
    "CONFIG_DVB_TDA10086": "n",
    "CONFIG_DVB_TDA18271C2DD": "n",
    "CONFIG_DVB_TDA665x": "n",
    "CONFIG_DVB_TDA8083": "n",
    "CONFIG_DVB_TDA8261": "n",
    "CONFIG_DVB_TDA826X": "n",
    "CONFIG_DVB_TS2020": "n",
    "CONFIG_DVB_TUA6100": "n",
    "CONFIG_DVB_TUNER_CX24113": "n",
    "CONFIG_DVB_TUNER_DIB0070": "n",
    "CONFIG_DVB_TUNER_DIB0090": "n",
    "CONFIG_DVB_TUNER_ITD1000": "n",
    "CONFIG_DVB_VES1820": "n",
    "CONFIG_DVB_VES1X93": "n",
    "CONFIG_DVB_ZD1301_DEMOD": "n",
    "CONFIG_DVB_ZL10036": "n",
    "CONFIG_DVB_ZL10039": "n",
    "CONFIG_DVB_ZL10353": "n",
    "CONFIG_MEDIA_TUNER_IT913X": "n",
    "CONFIG_MEDIA_TUNER_M88RS6000T": "n",
    "CONFIG_MEDIA_TUNER_MAX2165": "n",
    "CONFIG_MEDIA_TUNER_MC44S803": "n",
    "CONFIG_MEDIA_TUNER_MT2060": "n",
    "CONFIG_MEDIA_TUNER_MT2063": "n",
    "CONFIG_MEDIA_TUNER_MT20XX": "n",
    "CONFIG_MEDIA_TUNER_MT2131": "n",
    "CONFIG_MEDIA_TUNER_MT2266": "n",
    "CONFIG_MEDIA_TUNER_MXL301RF": "n",
    "CONFIG_MEDIA_TUNER_MXL5005S": "n",
    "CONFIG_MEDIA_TUNER_MXL5007T": "n",
    "CONFIG_MEDIA_TUNER_QM1D1B0004": "n",
    "CONFIG_MEDIA_TUNER_QM1D1C0042": "n",
    "CONFIG_MEDIA_TUNER_QT1010": "n",
    "CONFIG_MEDIA_TUNER_SI2157": "n",
    "CONFIG_MEDIA_TUNER_SIMPLE": "n",
    "CONFIG_MEDIA_TUNER_TDA18212": "n",
    "CONFIG_MEDIA_TUNER_TDA18218": "n",
    "CONFIG_MEDIA_TUNER_TDA18250": "n",
    "CONFIG_MEDIA_TUNER_TDA18271": "n",
    "CONFIG_MEDIA_TUNER_TDA827X": "n",
    "CONFIG_MEDIA_TUNER_TDA8290": "n",
    "CONFIG_MEDIA_TUNER_TDA9887": "n",
    "CONFIG_MEDIA_TUNER_TEA5761": "n",
    "CONFIG_MEDIA_TUNER_TEA5767": "n",
    "CONFIG_MEDIA_TUNER_TUA9001": "n",
    "CONFIG_MEDIA_TUNER_XC2028": "n",
    "CONFIG_MEDIA_TUNER_XC4000": "n",
    "CONFIG_MEDIA_TUNER_XC5000": "n",}


def inject(kernel_src_path):
    if not os.path.isdir(kernel_src_path):
        sys.exit(f"injector: source '{kernel_src_path}' is not a directory (§3).")
    config_path = os.path.join(kernel_src_path, ".config")
    if not os.path.isfile(config_path):
        sys.exit(f"injector: no .config in '{kernel_src_path}' — configure the tree first (§3).")

    with open(config_path) as f:
        lines = f.readlines()

    changed, added = [], []
    out, seen = [], set()
    for line in lines:
        hit = None
        for flag, value in MANDATORY_FLAGS.items():
            if line.startswith(f"{flag}=") or line.startswith(f"# {flag} is not set"):
                hit = (flag, value); break
        if hit:
            flag, value = hit
            newline = (f"# {flag} is not set\n" if value == "n" else f"{flag}={value}\n")
            if newline != line:
                changed.append(flag)
            out.append(newline)
            seen.add(flag)
        else:
            out.append(line)
    for flag, value in MANDATORY_FLAGS.items():
        if flag not in seen:
            out.append(f"# {flag} is not set\n" if value == "n" else f"{flag}={value}\n")
            added.append(flag)

    with open(config_path, "w") as f:
        f.writelines(out)

    # Verify the artifact, not the exit code (§2): report what actually changed.
    print(f"injector: {config_path}")
    print(f"  flags total in change-set : {len(MANDATORY_FLAGS)}")
    print(f"  lines modified            : {len(changed)}")
    print(f"  flags appended (new)      : {len(added)}")
    poison = [f for f in ("CONFIG_MIVYBRIDGE",) if any(f in l for l in out)]
    print(f"  phantom MIVYBRIDGE present : {'YES — BUG' if poison else 'no (clean)'}")
    print("  NEXT: make -C <src> olddefconfig  (resolve deps, then verify with diff)")
    return True


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("usage: kernel_config_injector.py <kernel_source_root>")
    inject(os.path.realpath(sys.argv[1]))
