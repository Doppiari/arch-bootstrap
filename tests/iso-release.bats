#!/usr/bin/env bats
# Real files, Git and GnuPG; fixture keys never use an existing keyring.

setup() {
	REPO=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
}

@test "download verification authenticates the complete set and refuses every damaged input" {
	python3 - "$REPO" "$BATS_TEST_TMPDIR" <<'PY'
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

repo, work = map(Path, sys.argv[1:])
files = work / 'download'
files.mkdir()
stem = 'fixture-1-x86_64'
names = [stem + ext for ext in ['.iso', '.packages.tsv', '.build.json', '.notices.tar', '.sources.tar']]
for name in names:
    (files / name).write_bytes(('fixture ' + name + '\n').encode())


def gpg(home, *args):
    return subprocess.run(['gpg', '--batch', '--pinentry-mode', 'loopback', '--passphrase', '', *args],
                          env=dict(os.environ, GNUPGHOME=str(home)), capture_output=True, text=True, check=True)


def key(name):
    home = work / name
    home.mkdir(mode=0o700)
    gpg(home, '--quick-gen-key', name + ' <fixture@invalid.example>', 'ed25519', 'sign', 'never')
    listing = gpg(home, '--with-colons', '--list-keys').stdout
    fpr = next(line.split(':')[9] for line in listing.splitlines() if line.startswith('fpr:'))
    return home, fpr


home, fingerprint = key('expected')
foreign, wrong_fingerprint = key('foreign')
public = files / 'release-key.asc'
public.write_text(gpg(home, '--armor', '--export', fingerprint).stdout)
foreign_public = work / 'foreign.asc'
foreign_public.write_text(gpg(foreign, '--armor', '--export', wrong_fingerprint).stdout)
sums = files / 'SHA256SUMS'
sig = files / 'SHA256SUMS.sig'


def sign(which=home):
    if sig.exists():
        sig.unlink()
    gpg(which, '--detach-sign', '--output', str(sig), str(sums))


def reset():
    sums.write_text(''.join(hashlib.sha256((files / n).read_bytes()).hexdigest() + '  ' + n + '\n' for n in names))
    sign()


def verify(expected=0, fpr=fingerprint, keyfile=public):
    result = subprocess.run([sys.executable, str(repo / 'iso/verify-download'), '--directory', str(files),
                             '--key', str(keyfile), '--fingerprint', fpr], capture_output=True, text=True)
    assert (result.returncode == 0) == (expected == 0), (result.returncode, result.stdout, result.stderr)


reset()
verify()
for name in names:
    path = files / name
    original = path.read_bytes()
    path.unlink()
    verify(1)
    path.write_bytes(original)
    verify()
    path.write_bytes(original + b'altered')
    verify(1)
    path.write_bytes(original)
    verify()
    print('R01-' + name + ': missing/altered red, restored green')
for name in ['SHA256SUMS', 'SHA256SUMS.sig']:
    path = files / name
    original = path.read_bytes()
    path.unlink()
    verify(1)
    path.write_bytes(original)
    verify()
    print('R02-' + name + ': red/restored green')
sig.write_bytes(b'bad signature')
verify(1)
reset()
verify(1, fpr=wrong_fingerprint)
verify(1, fpr=fingerprint[-16:])
verify(1, keyfile=foreign_public)
sign(foreign)
verify(1, keyfile=foreign_public)
reset()
for name in names:
    original = sums.read_text()
    sums.write_text(original.replace(next(line for line in original.splitlines(True) if line.endswith('  ' + name + '\n')), ''))
    sign()
    verify(1)
    reset()
    print('R03-omitted-checksum-' + name + ': red/restored green')
for content in [sums.read_text() + sums.read_text().splitlines()[0] + '\n',
                sums.read_text().replace(names[0], '../' + names[0]), '',
                sums.read_text().replace(names[0], '/tmp/' + names[0])]:
    sums.write_text(content)
    sign()
    verify(1)
    reset()
    verify()
    print('R04-checksum-names: red/restored green')
path = files / names[0]
original = path.read_bytes()
path.unlink()
external = work / 'external'
external.write_bytes(original)
path.symlink_to(external)
verify(1)
path.unlink()
path.write_bytes(original)
verify()
print('R05-redirected-artefact: red/restored green')
PY
}

@test "comparison binds the actual files and every pinned input" {
	python3 - "$REPO" "$BATS_TEST_TMPDIR" <<'PY'
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys

repo, work = map(Path, sys.argv[1:])
records = []
for directory in [work / 'one', work / 'two']:
    directory.mkdir()
    stem = 'fixture-dev-unsigned'
    record = dict(schema_version=1, mode='development', signed=False, release_eligible=False,
                  stem=stem, arch_bootstrap=dict(commit='a' * 40, source_date_epoch=1),
                  stage2=dict(repository='https://example.invalid/stage2', commit='b' * 40),
                  inputs=dict(mode='development', archive_date='2026-10-25'),
                  environment=dict(LC_ALL='C.UTF-8', TZ='UTC', umask='022', SOURCE_DATE_EPOCH=1))
    for field, ext in [('image', '.iso'), ('manifest', '.packages.tsv'), ('notices', '.notices.tar')]:
        path = directory / (stem + ext)
        path.write_bytes(b'identical fixture\n')
        record[field] = dict(file=path.name, sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    path = directory / (stem + '.build.json')
    path.write_text(json.dumps(record))
    records.append(path)


def compare(expected):
    result = subprocess.run([sys.executable, str(repo / 'iso/compare'), *map(str, records)],
                            capture_output=True, text=True)
    assert (result.returncode == 0) == (expected == 0), result.stderr
    return json.loads(result.stdout) if result.stdout else None


assert compare(0)['equal'] is True
for relative in ['fixture-dev-unsigned.iso', 'fixture-dev-unsigned.packages.tsv']:
    path = records[1].parent / relative
    original = path.read_bytes()
    path.write_bytes(b'different\n')
    compare(1)
    record = json.loads(records[1].read_text())
    field = 'image' if relative.endswith('.iso') else 'manifest'
    record[field]['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
    records[1].write_text(json.dumps(record))
    assert compare(1)['equal'] is False
    path.write_bytes(original)
    record[field]['sha256'] = hashlib.sha256(original).hexdigest()
    records[1].write_text(json.dumps(record))
    compare(0)
    print('R06-' + field + ': altered bytes and altered record red/restored green')
original = records[1].read_bytes()
for field in ['inputs', 'arch_bootstrap', 'stage2', 'environment']:
    record = json.loads(original)
    record[field]['unexpected'] = 'different'
    records[1].write_text(json.dumps(record))
    compare(1)
    records[1].write_bytes(original)
    compare(0)
    print('R07-' + field + ': red/restored green')
PY
}

@test "admission checks the installed closure and exact versions independently of requests" {
	python3 - "$REPO" "$BATS_TEST_TMPDIR" <<'PY'
import json
from pathlib import Path
import subprocess
import sys
import yaml

repo, work = map(Path, sys.argv[1:])
admission = work / 'admission.yml'
manifest = work / 'packages.tsv'
entries = [dict(name='base', version='3-3', decision='admitted', audit='fixture only')]
admission.write_text(yaml.safe_dump(dict(schema_version=1, packages=entries)))
header = 'name\tversion\tarch\tfilename\tsha256\n'
row = 'base\t3-3\tany\tbase-3-3-any.pkg.tar.zst\t' + '0' * 64 + '\n'
manifest.write_text(header + row)


def check(mode, expected):
    result = subprocess.run([sys.executable, str(repo / 'iso/build'), '--check-admission', '--mode', mode,
                             '--manifest', str(manifest), '--admission', str(admission)], capture_output=True, text=True)
    assert (result.returncode == 0) == (expected == 0), result.stderr
    return json.loads(result.stdout) if result.stdout else None


check('release-candidate', 0)
for data in [header + row + 'transitive\t1-1\tany\ttransitive.pkg.tar.zst\t' + '1' * 64 + '\n',
             header + row.replace('3-3', '3-4')]:
    manifest.write_text(data)
    check('release-candidate', 1)
    assert check('development', 0)['unadmitted']
    manifest.write_text(header + row)
    check('release-candidate', 0)
    print('R08-closure-version: red/restored green')
entries[0]['decision'] = 'pending'
admission.write_text(yaml.safe_dump(dict(schema_version=1, packages=entries)))
check('release-candidate', 1)
assert check('development', 0)['unadmitted']
PY
}

@test "a dirty or untracked source refuses before any build output" {
	python3 - "$REPO" "$BATS_TEST_TMPDIR" <<'PY'
from pathlib import Path
import runpy
import subprocess
import sys

repo, work = map(Path, sys.argv[1:])
identity = ['-c', 'user.name=' + subprocess.check_output(['git', '-C', str(repo), 'log', '-1', '--format=%an'], text=True).strip(),
            '-c', 'user.email=' + subprocess.check_output(['git', '-C', str(repo), 'log', '-1', '--format=%ae'], text=True).strip()]
source = work / 'git-source'
source.mkdir()
subprocess.run(['git', 'init', '-q', str(source)], check=True)
(source / 'tracked').write_text('clean\n')
subprocess.run(['git', '-C', str(source), 'add', 'tracked'], check=True)
subprocess.run(['git', '-C', str(source), *identity, '-c', 'commit.gpgsign=false', 'commit', '-qm', 'Create fixture'], check=True)
api = runpy.run_path(str(repo / 'iso/build'))
commit = api['clean_commit'](source)
assert len(commit) == 40
for name in ['tracked', 'untracked']:
    path = source / name
    path.write_text('dirty\n')
    try:
        api['clean_commit'](source)
    except api['Refusal'] as error:
        assert 'dirty' in str(error)
    else:
        raise AssertionError('R09: dirty source accepted')
    if name == 'tracked':
        path.write_text('clean\n')
    else:
        path.unlink()
    assert api['clean_commit'](source) == commit
    print('R09-' + name + ': red/restored green')
PY
}

@test "signing refuses every ineligible fixture without creating any output" {
	python3 - "$REPO" "$BATS_TEST_TMPDIR" <<'PY'
import hashlib
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import yaml

repo, work = map(Path, sys.argv[1:])
identity = ['-c', 'user.name=' + subprocess.check_output(['git', '-C', str(repo), 'log', '-1', '--format=%an'], text=True).strip(),
            '-c', 'user.email=' + subprocess.check_output(['git', '-C', str(repo), 'log', '-1', '--format=%ae'], text=True).strip()]
home = work / 'keys'
home.mkdir(mode=0o700)
env = dict(os.environ, GNUPGHOME=str(home))
gpg = ['gpg', '--batch', '--pinentry-mode', 'loopback', '--passphrase', '']
subprocess.run(gpg + ['--quick-gen-key', 'Fixture <fixture@invalid.example>', 'ed25519', 'sign', 'never'],
               env=env, capture_output=True, check=True)
listing = subprocess.run(gpg + ['--with-colons', '--list-keys'], env=env, capture_output=True, text=True, check=True)
fpr = next(line.split(':')[9] for line in listing.stdout.splitlines() if line.startswith('fpr:'))
source = work / 'source'
(source / 'iso').mkdir(parents=True)
subprocess.run(['git', 'init', '-q', str(source)], check=True)
entries = [dict(name='base', version='3-3', decision='admitted', audit='fixture only')]
inputs = dict(release_key_fingerprint=fpr)


def commit():
    (source / 'iso/admission.yml').write_text(yaml.safe_dump(dict(schema_version=1, packages=entries)))
    (source / 'iso/build-inputs.yml').write_text(yaml.safe_dump(inputs))
    subprocess.run(['git', '-C', str(source), 'add', 'iso'], check=True)
    subprocess.run(['git', '-C', str(source), *identity, '-c', 'commit.gpgsign=false', 'commit', '--allow-empty', '-qm', 'Update fixture'], check=True)
    return subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()


records = []
for name in ('one', 'two'):
    directory = work / name
    directory.mkdir()
    stem = 'fixture-rc'
    record = dict(schema_version=1, mode='release-candidate', signed=False, release_eligible=False,
                  stem=stem, arch_bootstrap=dict(commit='a' * 40, source_date_epoch=1),
                  stage2=dict(commit='b' * 40), inputs=dict(mode='release-candidate'), environment={})
    for field, ext in [('image', '.iso'), ('manifest', '.packages.tsv'), ('notices', '.notices.tar')]:
        path = directory / (stem + ext)
        data = b'fixture\n'
        if field == 'manifest':
            data = ('name\tversion\tarch\tfilename\tsha256\nbase\t3-3\tany\tbase.pkg.tar.zst\t' + '0' * 64 + '\n').encode()
        path.write_bytes(data)
        record[field] = dict(file=path.name, sha256=hashlib.sha256(data).hexdigest())
    (directory / (stem + '.sources.tar')).write_bytes(b'fixture source\n')
    path = directory / (stem + '.build.json')
    path.write_text(json.dumps(record))
    records.append(path)
api = runpy.run_path(str(repo / 'iso/compare'))
comparison = work / 'comparison.json'


def prepare(mode='release-candidate'):
    c = commit()
    for path in records:
        record = json.loads(path.read_text())
        record['mode'] = mode
        record['arch_bootstrap']['commit'] = c
        path.write_text(json.dumps(record))
        names = [p for p in path.parent.iterdir() if p.name != 'SHA256SUMS']
        (path.parent / 'SHA256SUMS').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + p.name + '\n' for p in sorted(names)))
    comparison.write_text(json.dumps(api['comparison'](*records)))


def refused(reason, use_comparison=True):
    argv = [sys.executable, str(repo / 'iso/sign-release'), str(records[0]), '--root', str(source)]
    if use_comparison:
        argv += ['--comparison', str(comparison)]
    before = {str(p): p.read_bytes() for d in (records[0].parent, records[1].parent) for p in d.iterdir()}
    result = subprocess.run(argv, env=env, capture_output=True, text=True)
    assert result.returncode != 0 and reason in result.stderr, result.stderr
    after = {str(p): p.read_bytes() for d in (records[0].parent, records[1].parent) for p in d.iterdir()}
    assert before == after, 'signing refusal wrote output'
    print('R11-sign-' + reason + ': refused, output unchanged')


prepare('development')
refused('development')
prepare()
refused('missing', use_comparison=False)
supplied = json.loads(comparison.read_text())
supplied['equal'] = False
comparison.write_text(json.dumps(supplied))
refused('altered or unequal')
prepare()
entries[0]['decision'] = 'pending'
prepare()
refused('not admitted')
entries[0]['decision'] = 'admitted'
entries[0]['version'] = '3-4'
prepare()
refused('not admitted')
entries[0]['version'] = '3-3'
inputs['release_key_fingerprint'] = None
prepare()
refused('no release-key fingerprint')
inputs['release_key_fingerprint'] = 'A' * 40
prepare()
refused('unavailable')
inputs['release_key_fingerprint'] = fpr
prepare()
refused('no frozen campaign pair')
PY
}

@test "notice inventory classifies texts without counting source or bytecode filenames" {
	python3 - "$REPO" <<'PY'
from pathlib import Path
import runpy
import sys
api = runpy.run_path(str(Path(sys.argv[1]) / 'iso/build'))
paths = ['usr/share/doc/dosfstools/COPYING', 'usr/share/licenses/sample/LICENSE',
         'usr/lib/python/site-packages/example.dist-info/licenses/COPYING',
         'usr/lib/python/site-packages/license.py', 'usr/lib/python/site-packages/license.pyc',
         'usr/lib/python/site-packages/NOTICE.yml', 'usr/share/doc/example/']
assert api['notice_paths']({'files': paths}) == paths[:3]
PY
}
