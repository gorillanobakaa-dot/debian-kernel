#!/usr/bin/env bash
set -euo pipefail

case "$1" in
  debian-x86_64)
    name=$(dpkg-deb --field "$FIELDKIT_INSTALLER" Package)
    if dpkg-query -W -f='${Status}\n' "$name" 2>/dev/null | grep -Fx 'install ok installed'; then exit 1; fi
    apt-get install -y "$FIELDKIT_INSTALLER"
    observed=$(dpkg-query -W -f='${Version}' "$name")
    [[ "$observed" == "$(dpkg-deb --field "$FIELDKIT_INSTALLER" Version)" ]]
    files=$(dpkg -L "$name")
    ;;
  rpm-x86_64)
    name=$(rpm -qp --qf '%{NAME}' "$FIELDKIT_INSTALLER")
    if rpm -q "$name"; then exit 1; fi
    dnf install -y "$FIELDKIT_INSTALLER"
    format='%{VERSION}-%{RELEASE}.%{ARCH}'
    [[ "$(rpm -q --qf "$format" "$name")" == "$(rpm -qp --qf "$format" "$FIELDKIT_INSTALLER")" ]]
    files=$(rpm -ql "$name")
    ;;
  *) exit 2 ;;
esac

mapfile -t images < <(printf '%s\n' "$files" | grep '^/boot/vmlinuz-')
((${#images[@]} == 1))
image=${images[0]}
release=${image#/boot/vmlinuz-}
[[ "$release" == "$FIELDKIT_VERSION"-unleashed* && -s "$image" ]]
[[ "$release" =~ ^[A-Za-z0-9_.+-]+$ ]]

# This small init process reports the kernel that actually booted, then powers the throwaway VM off.
root=$(mktemp -d)
mkdir "$root/fs" "$root/fs/dev"
mknod -m 600 "$root/fs/dev/console" c 5 1
gcc -static -O2 -x c -o "$root/fs/init" - <<'C'
#include <stdio.h>
#include <sys/reboot.h>
#include <sys/utsname.h>

int main(void) {
    struct utsname running;
    if (uname(&running) != 0) return 1;
    printf("FIELDKIT_BOOT %s\n", running.release);
    fflush(stdout);
    return reboot(RB_POWER_OFF);
}
C
(cd "$root/fs" && find . -print0 | cpio --null -o -H newc > "$root/initramfs")
timeout 240 qemu-system-x86_64 -m 1024 -smp 2 -display none -serial stdio -monitor none -no-reboot \
  -kernel "$image" -initrd "$root/initramfs" -append 'console=ttyS0 rdinit=/init panic=-1' | tee "$root/boot.log"
tr -d '\r' < "$root/boot.log" | grep -Fx "FIELDKIT_BOOT $release"
