# historical/ — preserved, superseded, **do not use**

Nothing in this directory is current. It is kept because provenance matters more
than tidiness: this project was once badly misled by stale artifacts, and deleting
them would erase the evidence of how that happened.

**If you are looking for the patches, they are in `../patches/`.**

---

## `patches-7.0.9-DO-NOT-APPLY/`

The original eight `.patch` files. Their headers say `linux-7.0.9` and **every hunk
fails against 7.1.2.**

These caused real damage. An audit tried to apply them, saw them fail, and
concluded the kernel was unpatched. It was not — the installer copies whole files
and never applies a `.patch` at all, so "the patch does not apply" carried no
information about whether the change was present. That misreading, combined with
`.orig_backup` files that had themselves been taken from already-patched trees,
produced the retracted claim that the port had "silently dropped 11 of 12 source
patches."

They are superseded by `../patches/`, which are generated against pristine 7.1.2
and **verified** to reproduce the shipped sources byte-for-byte
(`../verify_patches.sh`).

## `patched_sources-STALE-DO-NOT-USE/`

A second copy of the source files, added 2026-06-30. Ten of its twelve files were
byte-identical duplicates of the real ones; two had **silently diverged**:

| File | Status as of 2026-08-10 |
|---|---|
| `reg.c` | **32 lines short** — predates the Build 3 deregulation work |
| `alc269.c` | differs in content at the same line count |
| `kernel.config.modified` | differs from the live `kernel.config`; dated *after* the build it claims to describe |

A duplicate source tree is not redundancy, it is a **second answer to the same
question**, and the copies drift apart silently. Anyone who had patched from this
directory would have shipped a kernel with the regulatory leash still attached and
believed it was unleashed.

**There is exactly one source of truth per file: the top-level copy named in
`PATCHED_FILES_PATH_REGISTRY.txt`.**
