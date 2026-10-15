#!/usr/bin/env python3
"""Preserve exact CI Release bytes for local QA; never grants runtime qualification."""
import argparse
import gzip
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import platform
import re
import struct
import subprocess
import sys
import tarfile

SCHEMA = 'autotechno-macos-release-delivery.v1'
ARCHIVE_NAME = 'AutoTechno-macos-release.tar.gz'
ROOT_NAME = 'AutoTechno-macos-release'
BUNDLE_NAME = 'AutoTechno_AutoTechnoDSP.bundle'
PREFIX = 'AUTOTECHNO_RELEASE_DELIVERY '
MAX_BYTES = 1024 * 1024 * 1024
MAX_FILES = 64
CLAIMS = ('nativeSuiteQualification', 'qualityQualification', 'appLaunchQualified',
          'routeQualified', 'physicalOutputQualified', 'item39Complete')
FIELDS = {'schema', 'subject', 'source', 'sourceTree', 'repository', 'runId', 'runAttempt',
          'artifactName', 'architecture', 'macOSVersion', 'swiftVersion', 'buildConfiguration',
          'scope', 'archive', 'archiveBytes', 'archiveSHA256', 'files', 'claims'}


def require(ok, message):
    if not ok:
        raise ValueError(message)


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for data in iter(lambda: stream.read(64 * 1024), b''):
            h.update(data)
    return h.hexdigest()


def strict_json(raw):
    def pairs(rows):
        out = {}
        for key, value in rows:
            require(key not in out, 'duplicate JSON key')
            out[key] = value
        return out
    def invalid(value):
        raise ValueError('nonfinite JSON: ' + value)
    def number(value):
        parsed = float(value)
        require(math.isfinite(parsed), 'finite JSON number required')
        return parsed
    return json.loads(raw, object_pairs_hook=pairs, parse_constant=invalid, parse_float=number)


def bounded_file(path, maximum):
    require(path.is_file() and not path.is_symlink() and 0 < path.stat().st_size <= maximum,
            'bounded regular original file')
    with path.open('rb') as stream:
        raw = stream.read(maximum+1)
    require(0 < len(raw) <= maximum, 'bounded original bytes')
    return raw


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def architecture(header):
    require(len(header) >= 32 and header[:4] == b'\xcf\xfa\xed\xfe', 'native 64-bit Mach-O executable required')
    _, cpu, _, filetype, _, _, _, _ = struct.unpack('<IiiIIIII', header[:32])
    require(filetype == 2 and cpu in (0x100000c, 0x1000007), 'supported Mach-O executable required')
    return {0x100000c: 'arm64', 0x1000007: 'x86_64'}[cpu]


def artifact_name(source, run, attempt):
    return f'at0039-macos-release-{source}-{run}-{attempt}'


def member_name(path):
    require(isinstance(path, str) and 0 < len(path) <= 240 and '\\' not in path, 'bounded normalized member path')
    p = PurePosixPath(path)
    require(not p.is_absolute() and p.as_posix() == path and all(x not in ('', '.', '..') for x in p.parts), 'normalized member path')
    require(path == ROOT_NAME + '/AutoTechno' or path.startswith(ROOT_NAME + '/' + BUNDLE_NAME + '/'), 'release executable/resource ownership')
    return path


def git(root, *arguments):
    return subprocess.check_output(['git', '-c', 'core.fsmonitor=false', *arguments], cwd=root, text=True).strip()


def clean_source(root, source):
    require(git(root, 'rev-parse', 'HEAD') == source and
            not git(root, 'status', '--porcelain', '--untracked-files=all'), 'clean exact source required')


def inventory(root, binary_directory):
    binary = binary_directory / 'AutoTechno'
    bundle = binary_directory / BUNDLE_NAME
    require(binary.is_file() and not binary.is_symlink() and os.access(binary, os.X_OK), 'original Release executable required')
    require(bundle.is_dir() and not bundle.is_symlink(), 'original SwiftPM runtime bundle required')
    with binary.open('rb') as stream:
        arch = architecture(stream.read(32))
    paths = [binary]
    for index, item in enumerate(bundle.rglob('*'), 1):
        require(index <= MAX_FILES*4, 'bounded runtime resource tree')
        require(not item.is_symlink() and (item.is_file() or item.is_dir()), 'regular runtime resource tree required')
        if item.is_file():
            require(len(paths) < MAX_FILES, 'bounded runtime file inventory')
            paths.append(item)
    require(1 < len(paths) <= MAX_FILES, 'bounded complete Release inventory')
    sources = root / 'Sources/AutoTechnoDSP/Resources'
    tracked = git(root, 'ls-files', '--', 'Sources/AutoTechnoDSP/Resources').splitlines()
    expected = {}
    for name in tracked:
        p = root / name
        require(p.is_file() and not p.is_symlink() and p.parent == sources and p.suffix == '.json', 'tracked derived JSON resource ownership')
        expected[p.name] = sha(p)
    require(expected, 'current source resources required')
    actual = {}
    for item in paths[1:]:
        relative = item.relative_to(bundle).as_posix()
        if relative in ('Info.plist', 'Contents/Info.plist'):
            require(item.stat().st_size <= 64 * 1024, 'bounded generated bundle metadata')
            continue
        require(item.name in expected and item.name not in actual, 'exact source resource inventory')
        actual[item.name] = sha(item)
    require(actual == expected, 'runtime resource bytes differ from current source')
    files = []
    for path in paths:
        name = ROOT_NAME + '/' + path.relative_to(binary_directory).as_posix()
        member_name(name)
        size = path.stat().st_size
        require(0 < size <= MAX_BYTES, 'bounded nonempty Release file')
        files.append(dict(path=name, bytes=size, sha256=sha(path), mode=0o755 if path == binary else 0o644))
    require(sum(row['bytes'] for row in files) <= MAX_BYTES, 'bounded total Release payload')
    return arch, sorted(files, key=lambda row: row['path'])


def validate_record(record, source, repository, run, attempt):
    require(isinstance(record, dict) and set(record) == FIELDS, 'exact delivery fields')
    require(re.fullmatch('[0-9a-f]{40}', source or '') and record['source'] == source and
            record['schema'] == SCHEMA and record['subject'] == 'AT-0039', 'exact delivery source and scope')
    require(isinstance(record['sourceTree'], str) and re.fullmatch('[0-9a-f]{40}', record['sourceTree']) and
            re.fullmatch('[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository) and
            record['repository'] == repository, 'source tree/repository binding')
    require(type(run) is int and 0 < run < 2**64 and type(attempt) is int and 0 < attempt < 2**64 and
            type(record['runId']) is int and record['runId'] == run and
            type(record['runAttempt']) is int and record['runAttempt'] == attempt, 'exact run attempt')
    require(record['artifactName'] == artifact_name(source, run, attempt) and
            record['archive'] == ARCHIVE_NAME and record['buildConfiguration'] == 'release' and
            record['scope'] == 'compiled-executable-and-runtime-resource-byte-delivery', 'delivery artifact identity')
    require(record['architecture'] in ('arm64', 'x86_64') and
            all(isinstance(record[k], str) and 0 < len(record[k]) <= 4096 for k in ('macOSVersion', 'swiftVersion')), 'bounded original platform/toolchain')
    require(isinstance(record['claims'], dict) and set(record['claims']) == set(CLAIMS) and
            all(value is False for value in record['claims'].values()), 'delivery must not grant qualification')
    require(type(record['archiveBytes']) is int and 0 < record['archiveBytes'] <= MAX_BYTES and
            isinstance(record['archiveSHA256'], str) and re.fullmatch('[0-9a-f]{64}', record['archiveSHA256']), 'bounded archive digest')
    files = record['files']
    require(isinstance(files, list) and 1 < len(files) <= MAX_FILES, 'bounded exact file inventory')
    names = []
    for row in files:
        require(isinstance(row, dict) and set(row) == {'path', 'bytes', 'sha256', 'mode'}, 'exact file fields')
        name = member_name(row['path'])
        require(type(row['bytes']) is int and 0 < row['bytes'] <= MAX_BYTES and
                isinstance(row['sha256'], str) and re.fullmatch('[0-9a-f]{64}', row['sha256']) and type(row['mode']) is int and
                row['mode'] == (0o755 if name == ROOT_NAME + '/AutoTechno' else 0o644), 'file byte and mode bounds')
        names.append(name)
    require(names == sorted(set(names)) and ROOT_NAME + '/AutoTechno' in names and
            any(name.endswith('.json') for name in names) and
            sum(row['bytes'] for row in files) <= MAX_BYTES, 'complete unique executable/resource inventory')


def receipt_from_log(raw):
    require(isinstance(raw, bytes) and 0 < len(raw) <= 64 * 1024 * 1024, 'bounded original delivery job log')
    records = []
    for line in raw.decode('utf-8').splitlines():
        line = re.sub(r'^\d{4}-\d\d-\d\dT\S+ ', '', line)
        if line.startswith(PREFIX):
            require(len(line) <= 64 * 1024, 'bounded emitted delivery receipt')
            records.append(strict_json(line[len(PREFIX):]))
    require(len(records) == 1, 'exactly one original emitted delivery receipt')
    return records[0]


def verify_payload(archive, record, source, repository, run, attempt, original_log, extract=None):
    validate_record(record, source, repository, run, attempt)
    require(receipt_from_log(original_log) == record, 'original job stdout delivery binding')
    require(archive.is_file() and not archive.is_symlink() and archive.stat().st_size == record['archiveBytes'] and
            sha(archive) == record['archiveSHA256'], 'complete archive bytes')
    require(extract is None or (extract.is_absolute() and not extract.exists() and not extract.is_symlink()), 'absent absolute extraction directory')
    expected = {row['path']: row for row in record['files']}
    def read(extract_root=None):
        seen, consumed = set(), 0
        with gzip.open(archive, 'rb') as stream:
            while True:
                block = stream.read(512)
                require(len(block) == 512, 'complete tar header')
                consumed += 512
                if block == bytes(512):
                    require(stream.read(512) == bytes(512), 'complete tar terminator')
                    consumed += 512
                    padding = stream.read(tarfile.RECORDSIZE + 1)
                    require(len(padding) == (-consumed) % tarfile.RECORDSIZE and not padding.strip(b'\0'), 'bounded canonical trailing padding')
                    break
                info = tarfile.TarInfo.frombuf(block, 'utf-8', 'strict')
                require(info.type == tarfile.REGTYPE and not info.linkname and info.name in expected and
                        info.name not in seen and info.uid == info.gid == info.mtime == 0, 'regular exact nonduplicate tar member')
                row = expected[info.name]
                require(info.size == row['bytes'] and info.mode == row['mode'], 'exact archived size and mode')
                seen.add(info.name)
                remaining, digest, header = info.size, hashlib.sha256(), b''
                output = None
                if extract_root is not None:
                    relative = PurePosixPath(info.name).relative_to(ROOT_NAME)
                    destination = extract_root.joinpath(*relative.parts)
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    output = destination.open('xb')
                try:
                    while remaining:
                        chunk = stream.read(min(remaining, 64 * 1024))
                        require(chunk, 'complete tar file bytes')
                        digest.update(chunk)
                        if len(header) < 32:
                            header += chunk[:32-len(header)]
                        if output:
                            output.write(chunk)
                        remaining -= len(chunk)
                finally:
                    if output:
                        output.close()
                require(digest.hexdigest() == row['sha256'], 'exact archived file hash')
                if info.name == ROOT_NAME + '/AutoTechno':
                    require(architecture(header) == record['architecture'], 'original executable architecture')
                if extract_root is not None:
                    destination.chmod(row['mode'])
                padding = stream.read((-info.size) % 512)
                require(padding == bytes((-info.size) % 512), 'canonical member padding')
                consumed += info.size + len(padding)
            require(seen == set(expected), 'complete archived inventory')
    read()
    if extract is not None:
        extract.mkdir(parents=True, exist_ok=False)
        read(extract)
    require(sha(archive) == record['archiveSHA256'], 'archive unchanged through verification')
    return dict(schema=SCHEMA, source=source, runId=run, runAttempt=attempt,
                fileCount=len(expected), deliveryBytesVerified=True,
                claims={name: False for name in CLAIMS})


def verify_job(job, source, repository, run, attempt):
    require(isinstance(job, dict) and type(job.get('id')) is int and 0 < job['id'] < 2**64 and
            type(job.get('run_id')) is int and job['run_id'] == run and
            type(job.get('run_attempt')) is int and job['run_attempt'] == attempt and
            job.get('head_sha') == source and job.get('status') == 'completed' and
            job.get('conclusion') == 'success', 'successful exact original delivery job required')
    require(job.get('name') in ('Complete macOS bank 0', 'hosted-macos / Complete macOS bank 0') and
            job.get('url') == f'https://api.github.com/repos/{repository}/actions/jobs/{job["id"]}' and
            job.get('html_url') == f'https://github.com/{repository}/actions/runs/{run}/job/{job["id"]}',
            'official original bank-zero delivery job identity')
    steps = job.get('steps')
    require(isinstance(steps, list) and all(isinstance(step, dict) for step in steps), 'original job steps required')
    order = []
    for name in ('Build all native tests', 'Execute complete native bank', 'Run complete tooling tests',
                 'Build macOS Release app', 'Validate codebase map',
                 'Package macOS Release validation artifact', 'Upload macOS Release validation artifact'):
        found = [step for step in steps if step.get('name') == name]
        require(len(found) == 1 and found[0].get('status') == 'completed' and
                found[0].get('conclusion') == 'success', 'successful original delivery step: '+name)
        require(type(found[0].get('number')) is int and found[0]['number'] > 0, 'original ordered job step')
        order.append(found[0]['number'])
    require(order == sorted(set(order)), 'original build/check/package/upload step order')


def verify_delivery(archive, record, source, repository, run, attempt, original_log, job, extract=None):
    verify_job(job, source, repository, run, attempt)
    result = verify_payload(archive, record, source, repository, run, attempt, original_log, extract)
    return dict(**result, originalBankZeroJobId=job['id'], originalJobDeliveryVerified=True)


def pack(root, binary_directory, output, environment):
    require(platform.system() == 'Darwin' and environment.get('GITHUB_ACTIONS') == 'true', 'hosted macOS build required')
    source = environment.get('GITHUB_SHA', '')
    require(re.fullmatch('[0-9a-f]{40}', source), 'published exact build source')
    repository = environment.get('GITHUB_REPOSITORY', '')
    run, attempt = int(environment.get('GITHUB_RUN_ID', '0')), int(environment.get('GITHUB_RUN_ATTEMPT', '0'))
    temporary = Path(environment['RUNNER_TEMP']).resolve()
    require(binary_directory.is_absolute() and binary_directory.resolve().is_relative_to(temporary) and
            output.is_absolute() and output.resolve().is_relative_to(temporary) and
            not output.exists() and not output.is_symlink(), 'isolated runner build/output paths')
    clean_source(root, source)
    arch, files = inventory(root, binary_directory)
    require(arch == platform.machine(), 'builder-native executable architecture')
    output.mkdir(parents=True, exist_ok=False)
    archive = output / ARCHIVE_NAME
    with archive.open('xb') as raw, gzip.GzipFile(filename='', fileobj=raw, mode='wb', mtime=0) as compressed:
        with tarfile.open(fileobj=compressed, mode='w', format=tarfile.USTAR_FORMAT) as tar:
            for row in files:
                original = binary_directory / PurePosixPath(row['path']).relative_to(ROOT_NAME)
                info = tarfile.TarInfo(row['path'])
                info.size, info.mode, info.mtime = row['bytes'], row['mode'], 0
                with original.open('rb') as stream:
                    tar.addfile(info, stream)
    record = dict(schema=SCHEMA, subject='AT-0039', source=source, sourceTree=git(root, 'rev-parse', 'HEAD^{tree}'),
        repository=repository, runId=run, runAttempt=attempt, artifactName=artifact_name(source, run, attempt),
        architecture=arch, macOSVersion=platform.mac_ver()[0],
        swiftVersion=subprocess.check_output(['swift', '--version'], text=True).strip(),
        buildConfiguration='release', scope='compiled-executable-and-runtime-resource-byte-delivery',
        archive=ARCHIVE_NAME, archiveBytes=archive.stat().st_size, archiveSHA256=sha(archive), files=files,
        claims={name: False for name in CLAIMS})
    validate_record(record, source, repository, run, attempt)
    raw = canonical(record)
    verify_payload(archive, record, source, repository, run, attempt, PREFIX.encode()+raw+b'\n')
    require(inventory(root, binary_directory) == (arch, files), 'original Release bytes changed while packaging')
    clean_source(root, source)
    (output / 'delivery.json').write_bytes(raw+b'\n')
    print(PREFIX+raw.decode(), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subs = parser.add_subparsers(dest='mode', required=True)
    build = subs.add_parser('pack')
    build.add_argument('--bin-directory', type=Path, required=True)
    build.add_argument('--output', type=Path, required=True)
    check = subs.add_parser('verify')
    check.add_argument('--directory', type=Path, required=True)
    check.add_argument('--source', required=True)
    check.add_argument('--repository', default='randomactions/auto-techno')
    check.add_argument('--run-id', type=int, required=True)
    check.add_argument('--run-attempt', type=int, required=True)
    check.add_argument('--original-job-log', type=Path, required=True)
    check.add_argument('--original-job-record', type=Path, required=True)
    check.add_argument('--extract-to', type=Path)
    args = parser.parse_args()
    try:
        if args.mode == 'pack':
            pack(Path(__file__).resolve().parents[1], args.bin_directory, args.output, os.environ)
        else:
            receipt = args.directory / 'delivery.json'
            require(receipt.is_file() and not receipt.is_symlink() and receipt.stat().st_size <= 64*1024, 'bounded regular delivery receipt')
            job = args.original_job_record
            require(job.is_file() and not job.is_symlink() and job.stat().st_size <= 1024*1024, 'bounded original job record')
            result = verify_delivery(args.directory/ARCHIVE_NAME, strict_json(bounded_file(receipt, 64*1024)), args.source,
                args.repository, args.run_id, args.run_attempt, bounded_file(args.original_job_log, 64*1024*1024),
                strict_json(bounded_file(job, 1024*1024)), args.extract_to)
            print(json.dumps(result, sort_keys=True))
    except (ValueError, OSError, KeyError, tarfile.TarError, subprocess.SubprocessError) as exc:
        parser.exit(1, 'Release delivery failed: '+str(exc)+'\n')


if __name__ == '__main__':
    main()
