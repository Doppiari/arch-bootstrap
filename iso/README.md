# Local development installer image

The profile and four interfaces implement the software contracts of
[ADR 0001](../docs/adr/0001-iso-build-and-distribution.md), which remains
**Proposed**. Build and VM observations are recorded separately from offline
fixture tests. This is an unsigned local development image, with the working
name “HyperLab installer image”. No public download or release key exists.
No package in [admission.yml](admission.yml) is admitted for redistribution.

## Recorded development result

On 2026-10-28 two real fresh Arch builders completed stage-1 commit
`a68529ba116eff385c8a545e88e72ba6e3f3284e`, naming stage 2
`96ad3ad257a1ed4b24214e98868ce076e87d3a40`. Each installed and inventoried
150 packages. Their manifests match; their images differ, with the actual
cache and timestamp differences [diagnosed here](../problems/iso-build-cache-and-timestamps.md).
The first image's SHA-256 is
`0ad4487932a12b5979b04aeb59ea0f8b21dcd336830fb08e8b385900cca90b11`.
Both remain development-only, unsigned and ineligible for signing.

That first image passed the separate OVMF/QEMU gate: serial prompt and
motd, parsed C/S/mode, 37 live command lookups, Argon2id, closed-input default
dry-run refusal before disk selection, and identical scratch-disk hashes
after shutdown. Builders used KVM, three vCPUs and 6144 MiB each; the smoke VM
used two vCPUs and 4096 MiB, a read-only CD-ROM and one new 1 GiB file-backed
disk. No host disk or shared filesystem entered a VM. These are local software
observations, not CI, hardware qualification or permission to redistribute.
The image does not install or boot the finished HyperLab product.

The real build exposed and fixed [boot identity validation](../problems/iso-kernel-parameters-are-not-medium-identity.md)
and [an unused initramfs hook and first-boot prompt](../problems/iso-live-hooks-and-firstboot.md).
The profile now drops MEMDISK as well as PXE hooks, refuses reported build
errors even after a zero mkarchiso exit, and masks interactive first-boot
setup while keeping the timezone unset. The only autologin remains tty1's
root shell. The final input checks also [reject trailing line breaks,
repeated permissions and ignored mode flags](../problems/iso-exact-input-scalars.md).

The snapshot pins archiso 91-1, keyring 20260909-1 and packages from
2026-10-25. [build-inputs.yml](build-inputs.yml) names stage 2 by a full commit;
that pin is not a frozen release pair. The image carries `git archive C` of
stage 1 under `/root/arch-bootstrap`, with no stage-2 code or assets.

## Offline checks

```bash
bash verify.sh
python3 iso/build --check-profile
bats tests/iso-profile.bats tests/iso-release.bats
```

These run as an ordinary user, with Bash, ShellCheck, Bats, cryptsetup,
Python/PyYAML, Git, GnuPG and coreutils. They download nothing and use no VM
or privilege. Signature tests create disposable keyrings; they do not use
an existing signing identity. [The mutation catalogue](../tests/MUTATIONS.md)
names the controls and the checks that detect their removal.

## Explicit development gate

Prepare two separate disposable Arch VMs with no host devices, passthrough or
shared filesystem. Retain outputs outside the source checkout. A user-owned
QEMU VM can use KVM or TCG; record its complete argv, firmware and resources.
The existing nested-lab route additionally requires its real host isolation
prerequisite; a flag alone supplies no isolation.

Inside **each VM only**, use the archive server
`https://archive.archlinux.org/repos/2026/10/25/$repo/os/$arch` for core and
extra with `SigLevel = Required DatabaseOptional`. Install the pinned
archiso and keyring plus Git, Bats, ShellCheck and python-yaml, using the
snapshot's trusted package keys. Confirm with:

```bash
pacman -Q archiso archlinux-keyring
```

Expected: `archiso 91-1` and `archlinux-keyring 20260909-1`. An unsigned archive
database is accepted; package signatures remain mandatory. A foreign or
unsigned package refuses. The builder exercises that policy with real pacman
and throwaway signed packages before building.

Transfer the same reviewed clean Git revision to both VMs. Use a normal
verification account already present inside the VM. As root **inside the
VM**, from that checkout, with absolute, previously empty paths:

```bash
python3 iso/build --work /srv/build-work --output /srv/build-output --verify-user verifier
```

The source must have no modified or untracked files. Generated files go to
those separate directories. The build validates the profile, versions and
virtual-machine context, runs `bash verify.sh` as the normal account at `C`,
embeds `git archive C`, fixes the epoch/environment and runs mkarchiso. It
checks the installed pacman database against package-file identities and
archiso's package list, records exact package-file SHA-256 values, and probes
the live cryptsetup for Argon2id. A full closure, including transitive
packages, is checked against admission. Development records every unadmitted
package; a release candidate refuses.

Each output directory contains the `*-dev-unsigned.iso`, `.packages.tsv`,
`.build.json`, `.notices.tar`, `SHA256SUMS` and `logs/`. Notices are selected
from the installed file lists, including documentation outside
`/usr/share/licenses`; `index.json` in the notices archive records packages
with missing evidence. Finding a file is not a legal approval. Corresponding
source is not produced: U5 is unresolved, and no such build can be published.

Retain both directories and compare the actual files:

```bash
python3 iso/compare /retained/one/IMAGE.build.json /retained/two/IMAGE.build.json --output /retained/comparison.json
```

Use the actual generated basenames in place of `IMAGE`. Exit 0 requires
identical inputs, image digests and package-manifest digests. Exit 1 means
refusal or inequality. A comparison cannot be turned into evidence by editing
its `equal` field: signing recomputes it. An explained image mismatch may
finish the development gate but never permits signing. SOURCE_DATE_EPOCH is
an input, not proof of bit-for-bit reproducibility.

Boot a retained image with OVMF as a read-only CD-ROM and one new scratch
image, without host disks or shared filesystems. Keep the serial console
transcript, QEMU argv and scratch SHA-256 before and after shutdown. Observe
the development motd and shell; enter root explicitly on the serial login
(the sole autologin is tty1). Read:

```bash
cat /usr/local/share/hyperlab-installer/release.json
cryptsetup --help
bash /root/arch-bootstrap/bootstrap </dev/null
```

Match `C`, `S` and development mode against the build record. Enumerate the
live commands used by the embedded `bootstrap` and `installer` with
`command -v`. Cryptsetup must list `argon2id`. The closed-input bootstrap must
fail before selecting a disk, with default dry-run enabled, no completion
marker and no scratch-disk change. Keep the actual commands and status with
the transcript. The image supplies no firmware or microcode, SSH server,
cloud-init, artwork or automatic installer entrypoint. Its supported boot
route is x86_64 with 64-bit UEFI; Secure Boot must be disabled or signed by
the user. Firmware signing and download signing are independent.

## Authentication of a future release

The complete fixture download set is `IMAGE.iso`, `IMAGE.packages.tsv`,
`IMAGE.build.json`, `IMAGE.notices.tar`, `IMAGE.sources.tar`, `SHA256SUMS`,
`SHA256SUMS.sig` and `release-key.asc`. The source archive is a fixture format,
not an accepted source-delivery arrangement. Before a public release the
operator must decide that arrangement and record a frozen campaign pair.
Today `iso/sign-release` refuses all builds: development mode, comparison,
admission, fingerprint and secret-key checks precede the unresolved freeze
and source gates. It creates no signature or partial output on refusal:

```bash
python3 iso/sign-release /retained/IMAGE.build.json --comparison /retained/comparison.json
```

No production fingerprint is recorded. For a future authenticated download,
obtain the full primary-key fingerprint through two agreeing channels, one
independent of the download host/account. After downloading the **complete**
set into one directory:

```bash
python3 iso/verify-download --directory /downloads/IMAGE --key /downloads/IMAGE/release-key.asc --fingerprint FULL_40_HEX_FINGERPRINT
```

It imports the supplied public key into an empty temporary keyring, checks
the actual OpenPGP signature and primary fingerprint, rejects duplicate or
unsafe filenames, requires every artefact's checksum, and runs
`sha256sum --check --strict` without ignoring missing files. Hashes alone do
not authenticate a development image.

## Qualification still pending

Package admission, source delivery, public naming/rights, production signing
key and hosting remain operator decisions. Physical boot and clean-install
gates remain pending on Nitro and Predator. CI proves software contracts;
it does not perform the build/VM gate or qualify hardware or redistribution.
The [upstream medium and Ansible route](../README.md#first-boot) remains the
second way. See [release gates](../docs/release-gates.md).

The [trademark policy](https://terms.archlinux.org/docs/trademark-policy/),
version 2021-04-18, was read in full on 2026-10-28. The profile has no Arch
medium identity or artwork; factual package names and upstream notices
remain. Profile origins and exact upstream hashes are in
[ORIGIN.tsv](profile/ORIGIN.tsv), against archiso v91 commit
`723da192226e1c9d5def9168f13332793c82a85e`. Its GPL-3.0-or-later licence stays
separate from the root MIT licence.
