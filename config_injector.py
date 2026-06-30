#!/usr/bin/env python3
import os
import sys
import shutil

# 🦍 GORILLA CONFIG INJECTOR — VERSION 3.0
# PORTABLE, AUTOMATED, FORCED
# NO HARDCODED PATHS

MANDATORY_FLAGS = {
    # Congestion Control & Queueing
    "CONFIG_BBR_CONGESTION_CONTROL": "y",
    "CONFIG_TCP_CONG_BBR": "y",
    "CONFIG_DEFAULT_BBR": "y",
    "CONFIG_DEFAULT_TCP_CONG": '"bbr"',
    "CONFIG_NET_SCH_FQ": "y",
    "CONFIG_NET_SCH_FQ_CODEL": "y",
    "CONFIG_NET_RX_BUSY_POLL": "y",
    
    # Kernel Preemption
    "CONFIG_PREEMPT_VOLUNTARY": "n",
    "CONFIG_PREEMPT": "y",
    "CONFIG_PREEMPT_COUNT": "y",
    "CONFIG_PREEMPTION": "y",
    "CONFIG_PREEMPT_RT": "n",
    
    # Critical Boot Framebuffer & Display Console
    "CONFIG_BLK_DEV_INITRD": "y",
    "CONFIG_DEVTMPFS": "y",
    "CONFIG_DEVTMPFS_MOUNT": "y",
    "CONFIG_FB": "y",
    "CONFIG_SYSFB_SIMPLEFB": "y",
    "CONFIG_DRM_SIMPLEDRM": "y",
    "CONFIG_DRM_EFIDRM": "y",
    "CONFIG_DRM_VESADRM": "y",
    "CONFIG_DRM_FBDEV_EMULATION": "y",
    "CONFIG_FRAMEBUFFER_CONSOLE": "y",
    
    # GPU / DRM Drivers
    "CONFIG_DRM_RADEON": "y",  # VAIO SVE14A3AJ Radeon GPU
    
    # Filesystem & Storage / SSD
    "CONFIG_EXT4_FS": "y",
    "CONFIG_BLK_DEV_SD": "y",
    "CONFIG_SATA_AHCI": "y",
    "CONFIG_ATA_PIIX": "y",
    "CONFIG_SCSI_MQ_DEFAULT": "y",
    "CONFIG_MQ_IOSCHED_KYBER": "y",
    "CONFIG_IOSCHED_BFQ": "y",
    "CONFIG_BFQ_GROUP_IOSCHED": "y",
    
    # CPU/Processor Performance & Native Tuning
    "CONFIG_X86_NATIVE_CPU": "y",
    "CONFIG_GENERIC_CPU": "n",
    "CONFIG_MIVYBRIDGE": "y",
    "CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE": "y",
    "CONFIG_CPU_FREQ_GOV_PERFORMANCE": "y",
    "CONFIG_CPU_FREQ_GOV_SCHEDUTIL": "y",
    "CONFIG_SCHED_AUTOGROUP": "y",
    
    # Tickless & HZ Tuning
    "CONFIG_HZ_250": "n",
    "CONFIG_HZ_1000": "y",
    "CONFIG_HZ": "1000",
    "CONFIG_NO_HZ_FULL": "y",
    "CONFIG_NO_HZ": "y",
    "CONFIG_NO_HZ_COMMON": "y",

    # High Definition Audio (HDA) dynamic patch loading & troubleshooting
    "CONFIG_SND_HDA_HWDEP": "y",
    "CONFIG_SND_HDA_RECONFIG": "y",
    "CONFIG_SND_HDA_PATCH_LOADER": "y",
    
    # Memory/RAM Tuning (MGLRU / ZRAM / THP)
    "CONFIG_LRU_GEN": "y",
    "CONFIG_LRU_GEN_ENABLED": "y",
    "CONFIG_ZRAM": "y",
    "CONFIG_ZRAM_BACKEND_LZ4": "y",
    "CONFIG_ZRAM_BACKEND_ZSTD": "y",
    "CONFIG_ZRAM_DEF_COMP_ZSTD": "y",
    "CONFIG_ZRAM_DEF_COMP_LZ4": "n",
    "CONFIG_ZRAM_DEF_COMP_LZORLE": "n",
    "CONFIG_ZRAM_DEF_COMP": '"zstd"',
    "CONFIG_ZSMALLOC": "y",
    "CONFIG_TRANSPARENT_HUGEPAGE": "y",
    "CONFIG_TRANSPARENT_HUGEPAGE_MADVISE": "y",
    
    # Wi-Fi Cryptography & Systemd Sysctl Fixes
    "CONFIG_BASE_SMALL": "n",
    "CONFIG_CRYPTO_SHA1": "y",
    "CONFIG_KEY_DH_OPERATIONS": "y",
    
    # HID & Input Devices
    "CONFIG_INPUT_KEYBOARD": "y",
    "CONFIG_INPUT_MOUSE": "y",
    "CONFIG_HID_GENERIC": "y",
    "CONFIG_USB_HID": "y",
    
    # SCSI Generic and EFI Framebuffer
    "CONFIG_CHR_DEV_SG": "y",
    "CONFIG_FB_EFI": "y",
    
    # Default FQ_CoDel Packet Scheduler
    "CONFIG_NET_SCH_DEFAULT": "y",
    "CONFIG_DEFAULT_NET_SCH": '"fq_codel"',
    "CONFIG_DEFAULT_FQ_CODEL": "y",
    "CONFIG_NET_SCH_INGRESS": "y",
    "CONFIG_NET_SCH_HTB": "y",
    
    # RNDIS Host USB Tethering
    "CONFIG_USB_NET_RNDIS_HOST": "y",
    
    # HugeTLB FS and cgroups
    "CONFIG_HUGETLBFS": "y",
    "CONFIG_CGROUP_HUGETLB": "y",
    
    # Ext4 for legacy Ext2
    "CONFIG_EXT2_FS": "n",
    "CONFIG_EXT4_USE_FOR_EXT2": "y",
    
    # NFS client
    "CONFIG_NFS_FS": "y",
    "CONFIG_NFS_V3": "y",
    "CONFIG_NFS_V4": "y",
    "CONFIG_NFS_V4_2": "y",
    
    # Modular network and cluster filesystems
    "CONFIG_NFSD": "m",
    "CONFIG_NFSD_V4": "y",
    "CONFIG_9P_FS": "m",
    "CONFIG_9P_FS_POSIX_ACL": "y",
    "CONFIG_CEPH_FS": "m",
    "CONFIG_CEPH_FS_POSIX_ACL": "y",
    "CONFIG_OCFS2_FS": "m",
    "CONFIG_OCFS2_FS_O2CB": "y",
    "CONFIG_OCFS2_FS_USERSPACE_CLUSTER": "y",
    "CONFIG_GFS2_FS": "m",
    
    # UBIFS Flash Filesystem Support
    "CONFIG_UBIFS_FS": "y",
    "CONFIG_UBIFS_FS_ADVANCED_COMPR": "y",
    
    # USB & Phone/Tethering / Apple Device Support
    "CONFIG_USB_IPHETH": "y",
    "CONFIG_USB_NET_QMI_WWAN": "y",
    "CONFIG_USB_NET_CDC_MBIM": "y",
    "CONFIG_USB_NET_CDC_EEM": "y",
    "CONFIG_USB_NET_HUAWEI_CDC_NCM": "y",
    "CONFIG_HID_APPLEIR": "y",
    "CONFIG_BACKLIGHT_APPLE": "y",
    "CONFIG_MOUSE_APPLETOUCH": "y",
    "CONFIG_USB_APPLEDISPLAY": "y",
    "CONFIG_APPLE_GMUX": "y",
    
    # Forensic Recovery & Extended Filesystems Support
    "CONFIG_SQUASHFS_XATTR": "y",
    "CONFIG_SQUASHFS_LZ4": "y",
    "CONFIG_SQUASHFS_COMP_CACHE_FULL": "y",
    "CONFIG_LDM_PARTITION": "y",
    "CONFIG_MAC_PARTITION": "y",
    "CONFIG_SOLARIS_X86_PARTITION": "y",
    "CONFIG_SUN_PARTITION": "y",
    "CONFIG_BSD_DISKLABEL": "y",
    "CONFIG_UNIXWARE_DISKLABEL": "y",
    "CONFIG_BLK_DEV_NBD": "y",
    "CONFIG_DM_CACHE": "y",
    "CONFIG_DM_VERITY": "y",
    "CONFIG_BEFS_FS": "y",
    "CONFIG_VXFS_FS": "y",
}

def inject(kernel_src_path):
    if not os.path.isdir(kernel_src_path):
        print(f"❌ Error: Target kernel source path '{kernel_src_path}' is not a directory.")
        return False
        
    config_path = os.path.join(kernel_src_path, ".config")
    if not os.path.isfile(config_path):
        print(f"❌ Error: .config not found in '{kernel_src_path}'. Please configure the kernel source first.")
        return False

    print(f"🦍 Injecting mandatory flags into {config_path}...")
    
    with open(config_path, 'r') as f:
        lines = f.readlines()

    new_lines = []
    seen = set()

    for line in lines:
        matched = False
        for flag, value in MANDATORY_FLAGS.items():
            if line.startswith(f"{flag}=") or line.startswith(f"# {flag} is not set"):
                if value == "n":
                    new_lines.append(f"# {flag} is not set\n")
                else:
                    new_lines.append(f"{flag}={value}\n")
                seen.add(flag)
                matched = True
                break
        if not matched:
            new_lines.append(line)

    for flag, value in MANDATORY_FLAGS.items():
        if flag not in seen:
            if value == "n":
                new_lines.append(f"# {flag} is not set\n")
            else:
                new_lines.append(f"{flag}={value}\n")

    with open(config_path, 'w') as f:
        f.writelines(new_lines)

    print("✅ Injection complete.")
    
    # Maintain a copy in the active Kernel_Config_Files subdirectory relative to script
    script_dir = os.path.dirname(os.path.realpath(__file__))
    target_dir = os.path.join(script_dir, "Kernel_Config_Files")
    if os.path.isdir(target_dir):
        shutil.copy2(__file__, os.path.join(target_dir, "config_injector.py"))
        print(f"✅ Self-copy saved to {os.path.join(target_dir, 'config_injector.py')}")
        
    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 config_injector.py <path_to_kernel_source_directory>")
        sys.exit(1)
    else:
        success = inject(sys.argv[1])
        sys.exit(0 if success else 1)
