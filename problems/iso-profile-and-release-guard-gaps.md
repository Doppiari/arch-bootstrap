# An enumerated overlay still needs its contents checked

A profile fixture replaced root's login shell with the embedded bootstrap.
The validator accepted it even though tty1's autologin would then launch the
installer. It checked the getty command and enumerated the passwd overlay,
but treated adapted upstream files as mutable without validating that account.
Adding another uid-0 account, changing the hostname or boot paths, adding
loader keys and making shadow world-readable also passed the old validator.

The profile now parses and requires exactly the intended root account and
hostname, the two loader settings, the kernel/initramfs paths and sort key,
and the shadow/root permission map. Each fixture changes one field and
restores a passing control through the real profile validator.

Existing builder refusals for tool pins, virtualization, the installed
closure and Argon2id were embedded in the privileged build flow. Offline
tests did not exercise them. They now use small pure guards shared by the
builder and normal-user fixtures. The fixtures disagree with the pins,
command status or independently collected closure evidence one at a time.
No fixture runs mkarchiso or a privileged host operation.

Release fixtures also exposed a comparison that accepted different notices
after updating their recorded digest. Equality now includes notices, tools
and the file stem. Signing checks both builds' successful verifier and
signature-policy results and explicit release eligibility, and applies the
same admission parser as the builder, including excluded-package refusal.
Every refusal preserves the output bytes. Signing still always refuses
until the independent frozen-pair and corresponding-source decisions exist.

The download test additionally changes a checksum without replacing the
previously valid signature: real GnuPG reports `BADSIG`, the download verifier
refuses at signature checking, and restoring the signed bytes passes.
The retained development images remain observations at their original commit;
these regression tests do not turn them into release candidates.
