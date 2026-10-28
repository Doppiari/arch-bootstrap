#!/usr/bin/env bash
# shellcheck disable=SC2034
# Profile of the HyperLab installer image (working name), adapted from the
# archiso releng profile. Literal assignments only: iso/build reads this
# file with a parser and appends iso_version, derived from SOURCE_DATE_EPOCH,
# to its staged copy.

iso_name="hyperlab-installer"
iso_label="HYPERLAB_INSTALLER"
iso_publisher="HyperLab"
iso_application="HyperLab installer image (working name)"
install_dir="hyperlab"
arch="x86_64"
bootmodes=('uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
)
