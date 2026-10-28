# Installer image mutations

`tests/iso-profile.bats` invokes the real parsed validator on disposable
profile copies. P01–P26 cover boot mode, architecture, root-image format and
compression, profile configuration, all five identity fields, title and motd,
archive server, every weakened SigLevel and repository override, shortened S,
GPL text, absent/duplicate/wrong-type origin, autologin command, initramfs
hooks, duplicate requests, duplicated/unversioned/absent admission entries,
excluded direct/admission packages, autorun/SSH/artwork overlays and an
escaping symlink. Every mutation must refuse, followed by a passing restored
control. The authoritative case names and transformations live in the suite.

`tests/iso-release.bats` uses actual files, Git and throwaway GnuPG keys:

- R01–R05: each downloaded artefact missing or changed; missing sums/signature;
  wrong key/fingerprint or short fingerprint; each checksum omitted; duplicate,
  empty and traversal names; redirected artefact. Every restored set passes.
- R06–R07: image or manifest bytes altered without and with updated records;
  changed build inputs, C, S or environment. Equality binds the actual files.
- R08: an added unadmitted transitive dependency or changed version with the
  direct requests unchanged; development records each unresolved entry.
- R09: tracked and untracked dirt with clean Git controls.
- R10: notice selection must exclude code and bytecode names while retaining
  actual documentation and language-metadata notices.
- R11: signing refuses development, missing/altered/unequal comparison,
  unadmitted or mismatched closure, absent fingerprint, unavailable exact key,
  and missing frozen-pair/source evidence. Artefact bytes remain unchanged.

Implementation fault injections: remove the dirty-tree check (R09 turns
red), bypass closure/version judgement (R08), ignore comparison digest equality
(R06), bypass signature validation or primary fingerprint matching (R01–R05),
and bypass missing-download checks (R01–R03). Restore after each injection.
The independent controls prevent a refusal for an unrelated missing input
from being counted as the intended refusal.

The explicit disposable-builder gate additionally uses real pacman with an
unsigned database: a trusted signed package installs, an unsigned package and
a foreign-key package refuse. Mutating the profile's policy to `Never` must
make this behavioural gate fail. Ordinary CI does not run root pacman, build
an ISO or claim VM evidence. The VM scratch-disk digest is an independent
before/after oracle for unexpected writes.

P27 renders the actual development title/motd with full C/S and required
archiso kernel options. Restoring the defective whole-entry naming check
must reject this valid control. Identity checks still apply to the title
and motd, and template markers must all be resolved.

P28 reinserts the excluded MEMDISK hook; the UEFI CD-ROM hook contract must
refuse and accept its restoration. P29 removes the exact firstboot mask;
its restored `/dev/null` target passes again. The strict profile inventory
admits this one disabling overlay to prevent the observed timezone prompt.
R12 removes the build-log error guard: the observed missing-memdisk binary
and failed pacman hook records must then make the regression test fail.
Firmware warnings alone remain a passing control.
