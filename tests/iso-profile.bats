#!/usr/bin/env bats
# Parsed profile contracts. Each rejection is paired with a restored control.

setup() {
	REPO=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
	FIXTURE="$BATS_TEST_TMPDIR/source"
	mkdir -p "$FIXTURE"
	cp -a "$REPO/iso" "$FIXTURE/iso"
}

@test "the development profile passes the real static validator" {
	run python3 "$REPO/iso/build" --check-profile --root "$FIXTURE"
	[ "$status" -eq 0 ]
}

@test "every static profile invariant rejects its mutation and accepts restoration" {
	python3 - "$REPO" "$FIXTURE" <<'PY'
import copy
import pathlib
import runpy
import shutil
import sys

repo, root = map(pathlib.Path, sys.argv[1:])
api = runpy.run_path(str(repo / 'iso/build'))
assert api['check_profile'](root) == []
profile = root / 'iso/profile'


def case(name, relative, change):
    path = root / relative
    data = path.read_bytes()
    try:
        change(path)
        errors = api['check_profile'](root)
        assert errors, f'{name}: mutation stayed green'
        print(f'{name}: red ({errors[0]})')
    finally:
        path.write_bytes(data)
    assert api['check_profile'](root) == [], f'{name}: restoration failed'
    print(f'{name}: restored green')


def text(old, new):
    def change(path):
        source = path.read_text()
        assert old in source
        path.write_text(source.replace(old, new, 1))
    return change


pdef = 'iso/profile/profiledef.sh'
for name, old, new in [
    ('P01-boot', "'uefi.systemd-boot'", "'bios.syslinux'"),
    ('P02-arch', 'x86_64', 'aarch64'),
    ('P03-image', 'squashfs', 'erofs'),
    ('P04-compression', "'-comp' 'xz'", "'-comp' 'gzip'"),
    ('P05-config', 'pacman.conf', '/etc/pacman.conf'),
]:
    case(name, pdef, text(old, new))
values = api['parse_profiledef']((profile / 'profiledef.sh').read_text(), [])
for field in api['NAMING_FIELDS']:
    case('P06-name-' + field, pdef,
         text(f'{field}="{values[field]}"', f'{field}="ArchExample"'))
case('P07-title', 'iso/profile/efiboot/loader/entries/01-live.conf',
     text('HyperLab', 'ArchExample'))
case('P08-motd', 'iso/profile/airootfs/etc/motd', text('HyperLab', 'ArchExample'))
case('P09-snapshot', 'iso/profile/pacman.conf', text('archive.archlinux.org', 'example.invalid'))
for level in ['Never', 'Optional', 'PackageOptional', 'TrustAll', 'Required']:
    case('P10-siglevel-' + level, 'iso/profile/pacman.conf',
         text('Required DatabaseOptional', level))
case('P11-repo-siglevel', 'iso/profile/pacman.conf',
     text('[core]', '[core]\nSigLevel = Never'))
case('P12-short-S', 'iso/build-inputs.yml',
     text(api['load_yaml'](root / 'iso/build-inputs.yml')['stage2']['commit'], '1234567'))
case('P13-license', 'iso/profile/LICENSE', lambda p: p.write_text('MIT\n'))
case('P14-origin-missing', 'iso/profile/ORIGIN.tsv',
     lambda p: p.write_text('\n'.join(p.read_text().splitlines()[:-1]) + '\n'))
case('P15-origin-duplicate', 'iso/profile/ORIGIN.tsv',
     lambda p: p.write_text(p.read_text() + p.read_text().splitlines()[1] + '\n'))
case('P16-origin-type', 'iso/profile/ORIGIN.tsv', text('LICENSE\tfile\t-', 'LICENSE\tsymlink\t-'))
case('P17-autologin', 'iso/profile/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf',
     text('/usr/bin/agetty', '/root/arch-bootstrap/bootstrap'))
case('P18-hooks', 'iso/profile/airootfs/etc/mkinitcpio.conf.d/archiso.conf',
     text('archiso_loop_mnt', 'archiso_pxe_http'))
case('P19-duplicate-request', 'iso/profile/packages.x86_64',
     lambda p: p.write_text(p.read_text() + 'base\n'))


def yaml_case(name, relative, change):
    def edit(path):
        data = api['load_yaml'](path)
        change(data)
        path.write_text(api['yaml'].safe_dump(data, sort_keys=False))
    case(name, relative, edit)


yaml_case('P20-duplicate-admission', 'iso/admission.yml',
          lambda d: d['packages'].append(copy.deepcopy(d['packages'][0])))
yaml_case('P21-unversioned', 'iso/admission.yml',
          lambda d: d['packages'][0].update(version='latest'))
yaml_case('P22-absent-direct', 'iso/admission.yml',
          lambda d: d.update(packages=[p for p in d['packages'] if p['name'] != 'base']))
for name in ['openssh', 'cloud-init', 'reflector', 'syslinux', 'linux-firmware', 'intel-ucode']:
    case('P23-exclude-' + name, 'iso/profile/packages.x86_64',
         lambda p, name=name: p.write_text(p.read_text() + name + '\n'))
    yaml_case('P24-admission-exclude-' + name, 'iso/admission.yml',
              lambda d, name=name: d['packages'].append(
                  dict(name=name, version='1-1', decision='pending', audit='unreviewed')))
for rel in ['syslinux/test.cfg', 'splash.png', 'airootfs/root/.automated_script.sh',
            'airootfs/etc/ssh/sshd_config', 'airootfs/root/.bash_profile',
            'airootfs/etc/systemd/system/bootstrap.service']:
    path = profile / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('unwanted\n')
    try:
        assert api['check_profile'](root), rel
    finally:
        path.unlink()
    assert api['check_profile'](root) == [], rel
    print('P25-overlay-' + rel + ': red/restored green')
link = profile / 'airootfs/etc/resolv.conf'
target = link.readlink()
link.unlink()
link.symlink_to('../../../../outside')
try:
    assert api['check_profile'](root)
finally:
    link.unlink()
    link.symlink_to(target)
assert api['check_profile'](root) == []
print('P26-link-escape: red/restored green')
PY
}
