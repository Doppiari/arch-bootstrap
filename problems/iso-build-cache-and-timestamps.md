# Equal package manifests do not make equal installer images

Two fresh disposable builders produced local development images from stage 1
`a68529ba116eff385c8a545e88e72ba6e3f3284e`, naming stage 2
`96ad3ad257a1ed4b24214e98868ce076e87d3a40`. Both used the 2026-10-25 archive,
archiso 91-1, keyring 20260909-1, empty build/package-cache directories and
SOURCE_DATE_EPOCH `1793200020`. Both build and verification commands succeeded.

The 150-package manifests have the same SHA-256:
`8de3b1f851321b34db2eed56687f1190bc2eceebdd484f05040c6a28eb509c16`.
The 473663488-byte images differ:

- first: `0ad4487932a12b5979b04aeb59ea0f8b21dcd336830fb08e8b385900cca90b11`;
- second: `4dae474612fd693618f3cca1eb01db56e6747cd7dee2f9407587e6f21d966edf`.

`iso/compare` returns 1 with `differences: ["image"]`, `equal: false` and
`signing_eligible: false`. Those results bind the actual files and records.

## Diagnosis

Inventories of the packed airootfs trees contain 41712 entries each and no
missing paths. Comparing file bytes after resolving tar hard-link references
finds one differing file: `var/cache/ldconfig/aux-cache`, a cache written during
the package transaction. Its hashes are:

- first: `eff3cf96343cb5dd80e7a017ad513c2824acae680e58817f4e9998531f48b2f4`;
- second: `ffa8fccd74f2fea6f4a6ac35f63451b978dd629c84e7b54f5af80c3fa82bfa45`.

There are also 3642 entry metadata differences. For example the identical
rendered `etc/motd` bytes have mtimes `1793200194` and `1793200232`; the cache
mtimes are `1793200232` and `1793200269`. The cache content and build-time
metadata enter squashfs, so the fixed epoch and identical package archives do
not make the root image identical. Pacman's `%INSTALLDATE%` for `base` is
already the fixed epoch in both builds; that field is not the observed cause.

The full inventories, binary diagnostic trees, build records, images and logs
are retained privately. Hard-link serialization alone was excluded from the
content comparison; it must not be reported as changed executable bytes.
No claim is made that every differing ISO byte was individually attributed.
The observed root-image differences suffice to reject reproducibility.

## Disposition and checks

This is a diagnosed development-only mismatch, as ADR 0001 permits. No
normalization fix or reproducible-build claim is included here. Signing stays
ineligible, independently of the unresolved package admission and source gates.
A future reproducibility change must produce equal actual digests from two new
clean builders; removing the auxiliary cache alone would not address the
observed timestamps.

The first image passed the UEFI VM gate: its development record matched C/S,
all 37 checked live commands resolved, cryptsetup supported Argon2id, and
closed-input bootstrap refused before selecting a disk in default dry-run
mode. The fresh 1 GiB scratch image had SHA-256
`49bc20df15e412a64472421e13fe86ff1c5165e18b2afccf160d4dc19fe68a14`
before and after shutdown. This is software evidence, not a physical boot or
installation result.

`tests/iso-release.bats` rejects changed images and manifests, including when a
caller updates a record's digest or claims equality. Signing recomputes that
comparison and refuses an unequal result. An explanation never turns a failed
comparison into signing eligibility.
