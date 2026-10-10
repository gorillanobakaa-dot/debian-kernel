## What is this

This is the Gorilla Unleashed kernel, moved up to Linux 7.2.9. The kernel is the part of a Linux computer that sits between the programs and the hardware: it decides how fast the Wi-Fi may transmit, how the speakers are driven, how network traffic is paced. The ordinary kernel is set up for the average machine and for the strictest rules anywhere in the world. This one is set up for older laptops, the Sony VAIO SVE first, and removes limits that cost those machines speed, range and volume.

Every change from the 7.1.2 release is still here, and none was added or taken away. The only differences are the newer Linux underneath and one dead setting removed.

## Should you download it

**Not yet, unless you are willing to be the first person to boot it.** This version has been built and checked in every way that does not need a real laptop, but it has **not been started on real hardware yet**. Wait for the maintainer to confirm it boots on the VAIO, or keep your current kernel installed beside it so you can go back.

Do **not** install it if:

- you are not running Debian or Ubuntu (the `.deb` packages), or Fedora and similar systems (the `.rpm` packages);
- you need your computer to obey the radio rules of your country exactly. This kernel ignores some of them on purpose (see "The Wi-Fi changes" below);
- you have no way to choose an older kernel when the computer starts.

## Why this matters

A fifteen-year-old laptop is not slow because it is old. It is slow partly because the software it runs was tuned for different machines, and for the most cautious settings everywhere at once. This kernel shows what the same hardware does without those settings. It is also built and checked by a set of tools (Gorilla Fieldkit) that do every step the same way every time and write down the evidence, so you do not have to take anyone's word for what is inside.
