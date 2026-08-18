# Previous kernel versions

Each directory here is a **complete, self-contained tree for an earlier kernel
release** — its patches, configs, build scripts and documentation exactly as
they were published, consolidated into this repository on 2026-08-18.

| Version | Was | Prebuilt packages |
|---|---|---|
| [`7.0.9/`](7.0.9/) | `kernel-7.0.9-unleashed` | [v7.0.9-unleashed](../../releases/tag/v7.0.9-unleashed) |
| [`7.0.5/`](7.0.5/) | `kernel-7.0.5-release` | [v7.0.5](../../releases/tag/v7.0.5) |
| [`6.19.13/`](6.19.13/) | `kernel-6.19.13-ultimate` | [v6.19.13-7-ULTIMATE](../../releases/tag/v6.19.13-7-ULTIMATE) |

**Not to be confused with [`../historical/`](../historical/)**, which holds
superseded material from the *current* 7.1.2 line and is marked
`DO-NOT-APPLY`. This directory is the opposite: each tree here was correct and
shipped for the version it names. It is simply not the current kernel.

## Why they are here

Four separate repositories meant four entries competing for six pinned slots,
and a kernel history scattered across four different naming schemes. They are
now one repository with one history.

Nothing was thrown away. The original repositories remain on GitHub, archived
and read-only, and every old link still resolves.

**One deliberate omission.** The 7.0.5 release carried a 905 MB debug-symbols
package (`linux-image-…-dbg`). It was not carried forward — it is 62% of the
entire kernel archive by size and is of use to almost nobody. It is still
downloadable from the archived `kernel-7.0.5-release` repository.
