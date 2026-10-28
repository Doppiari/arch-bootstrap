# Minimal live profiles need matching hooks and first-boot policy

## A successful mkarchiso exit hid an initramfs error

The first real image build printed `binary not found: 'memdiskfind'` from
the `memdisk` hook, followed by `error: command failed to execute correctly`.
The pacman transaction and mkarchiso nevertheless returned success. An image
file was not proof that every initramfs hook succeeded.

The releng hook detects a disk supplied by Syslinux MEMDISK. Its install
script requires `memdiskfind`, which the official
[syslinux file list](https://archlinux.org/packages/core/x86_64/syslinux/files/)
places in `/usr/bin`. This UEFI CD-ROM profile excludes syslinux, BIOS and
MEMDISK boot. It now drops that unused hook instead of adding an excluded
package. The build also refuses reported initramfs/pacman errors even if
mkarchiso returns zero. Missing-firmware warnings remain expected for the
explicitly firmware-free profile; they do not become package admission.

## An unset timezone stopped the live login

The first UEFI VM reached systemd's Initial Setup screen and waited for a
timezone on the graphical console. The serial console never reached login.
A retained screen and serial transcript showed the stop. The profile
intentionally has no timezone, while systemd-firstboot runs on first boot
and prompts for an unset timezone before the login services start.

The profile now masks `systemd-firstboot.service` with exactly `/dev/null`.
It sets no timezone and enables no replacement entrypoint. The existing tty1
autologin still opens the root shell; bootstrap remains manual. The origin
inventory declares the new mask, and the validator requires its exact target.

`tests/iso-profile.bats` refuses reintroducing memdisk or removing the mask,
with restored controls. `tests/iso-release.bats` feeds the real observed error
records to the build-log guard and proves they refuse independently of the
process exit status. The explicit VM gate remains necessary to prove that
the resulting image actually reaches login.
