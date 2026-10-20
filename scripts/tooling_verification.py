#!/usr/bin/env python3
"""Preserve and verify complete unittest execution; no item/runtime authority."""
import argparse
import base64
import codecs
from collections import Counter
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import subprocess
import sys
import unittest
import zlib

SCHEMA = 'autotechno-tooling-original-execution.v1'
CHUNK_SCHEMA = 'autotechno-tooling-original-chunk.v1'
MAX_LOG = 32 * 1024 * 1024
MAX_RECORD = 48 * 1024 * 1024
IGNORED_INPUTS = (
    'docs/local/SYNTH_FX_DSP_RESEARCH_STUDY.md',
    'docs/local/roadmap-plans/AT-0039.md',
    'docs/local/roadmap-plans/AT-0039-current-acceptance.md',
    'docs/local/reports/source-citations/AT-0039.json',
)


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def strict(raw):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, 'duplicate JSON key')
            result[key] = value
        return result
    return json.loads(raw, object_pairs_hook=pairs,
                      parse_constant=lambda value: require(False, 'nonfinite JSON'))


def path_name(value):
    return (isinstance(value, str) and bool(value) and '\\' not in value and
            not PurePosixPath(value).is_absolute() and
            all(part not in ('', '.', '..') for part in value.split('/')))


def parse_output(raw, identities):
    """Reconcile every named terminal status, including intervening diagnostics."""
    require(isinstance(raw, bytes) and 0 < len(raw) <= MAX_LOG, 'bounded original unittest output')
    require(isinstance(identities, list) and identities and len(identities) <= 100000 and
            all(isinstance(name, str) and re.fullmatch(r'test_\w+(?:\.\w+){2,}', name)
                for name in identities) and len(set(identities)) == len(identities),
            'complete unique discovered unittest identities')
    text = raw.decode('utf-8')
    summary = re.search(r'\n-+\nRan (\d+) tests? in ([0-9.]+)s\n\nOK\n\Z', text)
    require(summary is not None and int(summary[1]) == len(identities),
            'complete original successful zero-skip unittest summary')
    headers = list(re.finditer(r'(?m)^(\w+) \(([^()\r\n]+)\) \.\.\. ', text[:summary.start()]))
    require(Counter(row[2] for row in headers) == Counter(identities),
            'every discovered test executed exactly once')
    for index, row in enumerate(headers):
        require(row[1] == row[2].rsplit('.', 1)[-1], 'named unittest method identity')
        end = headers[index + 1].start() if index + 1 < len(headers) else summary.start()
        body = text[row.end():end]
        statuses = re.findall(r'(?m)^(ok|FAIL|ERROR|skipped(?: [^\n]*)?|expected failure|unexpected success)$', body)
        require(statuses == ['ok'], 'one actual passing terminal status per discovered test')
    return dict(executedTests=len(identities), explicitlySkippedTests=0)


def verify(record, source):
    require(isinstance(record, dict) and set(record) == {
        'schema', 'source', 'implementationSHA256', 'python', 'identities',
        'trackedInputs', 'ignoredInputs', 'command', 'environment', 'exitCode', 'logSHA256', 'logBase64'},
        'original tooling execution fields')
    require(record['schema'] == SCHEMA and isinstance(source, str) and
            re.fullmatch('[0-9a-f]{40}', source) and record['source'] == source,
            'exact original tooling source')
    require(record['implementationSHA256'] == sha(Path(__file__).read_bytes()),
            'known original tooling execution/verifier implementation')
    require(isinstance(record['python'], str) and 0 < len(record['python']) <= 1024,
            'original Python runtime identity')
    require(type(record['exitCode']) is int and record['exitCode'] == 0, 'actual successful unittest exit')
    command = record['command']
    require(isinstance(command, list) and len(command) == 9 and
            isinstance(command[0], str) and Path(command[0]).is_absolute() and
            command[1:] == ['-m', 'unittest', 'discover', '-s', 'scripts',
                            '-p', 'test_*.py', '-v'],
            'exact complete standard unittest invocation without selection')
    require(record['environment'] == {'PYTHONDONTWRITEBYTECODE': '1', 'PYTHONUNBUFFERED': '1'},
            'original ordered output and bytecode-write controls')
    for key in ('trackedInputs', 'ignoredInputs'):
        values = record[key]
        require(isinstance(values, dict) and (bool(values) or key == 'ignoredInputs') and
                all(path_name(name) and isinstance(digest, str) and
                    re.fullmatch('[0-9a-f]{64}', digest) for name, digest in values.items()),
                'exact original tooling input hashes: ' + key)
    require(set(record['ignoredInputs']) <= set(IGNORED_INPUTS) and
            not set(record['trackedInputs']) & set(record['ignoredInputs']) and
            record['trackedInputs'].get('scripts/tooling_verification.py') == record['implementationSHA256'],
            'original implementation and only scoped ignored inputs')
    require(isinstance(record['identities'], list) and
            all(isinstance(name, str) and 'scripts/' + name.split('.')[0] + '.py' in
                record['trackedInputs'] for name in record['identities']),
            'each discovered test belongs to the original tracked source')
    encoded = record['logBase64']
    require(isinstance(encoded, str) and 0 < len(encoded) <= (MAX_LOG * 4 // 3 + 4),
            'bounded original log encoding')
    raw = base64.b64decode(encoded, validate=True)
    require(sha(raw) == record['logSHA256'], 'exact original unittest file bytes')
    counts = parse_output(raw, record['identities'])
    return dict(schema=SCHEMA, source=source, **counts,
                originalToolingOutputVerified=True, completeToolingTestsVerified=True,
                runtimeQualification=False, automatedQualityQualification=False, item39Complete=False)


def emit(record):
    raw = json.dumps(record, sort_keys=True, separators=(',', ':')).encode()
    require(len(raw) <= MAX_RECORD, 'bounded original tooling record')
    encoded = base64.b64encode(zlib.compress(raw)).decode()
    size = 4096
    for index, offset in enumerate(range(0, len(encoded), size)):
        print(json.dumps(dict(schema=CHUNK_SCHEMA, source=record['source'],
            index=index, chunks=(len(encoded)+size-1)//size, bytes=len(raw),
            sha256=sha(raw), payload=encoded[offset:offset+size])), flush=True)


def decode(log, source):
    chunks = []
    for line in log.splitlines():
        start = line.find('{')
        if start < 0:
            continue
        try:
            row = strict(line[start:])
        except ValueError:
            continue
        if isinstance(row, dict) and row.get('schema') == CHUNK_SCHEMA:
            chunks.append(row)
    require(0 < len(chunks) <= MAX_RECORD // 4096 + 1, 'original tooling chunks required')
    indices, common = set(), set()
    for row in chunks:
        require(set(row) == {'schema', 'source', 'index', 'chunks', 'bytes', 'sha256', 'payload'} and
                row['source'] == source and type(row['chunks']) is int and
                row['chunks'] == len(chunks), 'original tooling source and chunk count')
        require(type(row['index']) is int and 0 <= row['index'] < len(chunks) and
                row['index'] not in indices, 'unique original tooling chunk index')
        require(type(row['bytes']) is int and 0 < row['bytes'] <= MAX_RECORD and
                isinstance(row['sha256'], str) and re.fullmatch('[0-9a-f]{64}', row['sha256']) and
                isinstance(row['payload'], str) and 0 < len(row['payload']) <= 4096,
                'bounded original tooling chunk')
        indices.add(row['index']); common.add((row['bytes'], row['sha256']))
    require(len(common) == 1, 'one original tooling record')
    compressed = base64.b64decode(''.join(row['payload'] for row in
        sorted(chunks, key=lambda row: row['index'])), validate=True)
    decoder = zlib.decompressobj()
    raw = decoder.decompress(compressed, MAX_RECORD + 1)
    size, digest = next(iter(common))
    require(decoder.eof and not decoder.unconsumed_tail and not decoder.unused_data and
            len(raw) == size and sha(raw) == digest, 'complete exact original tooling bytes')
    return strict(raw)


def execute(root, output, source):
    """Run stdlib unittest discovery once; keep original failure output intact."""
    root = root.resolve()
    def git(*args):
        return subprocess.check_output(['git', '-c', 'core.fsmonitor=false', *args], cwd=root)
    require(re.fullmatch('[0-9a-f]{40}', source) and git('rev-parse', 'HEAD').decode().strip() == source and
            not git('status', '--porcelain', '--untracked-files=normal').strip(), 'clean exact tooling source')
    require(not output.exists() and not output.resolve().is_relative_to(root),
            'fresh tooling output outside immutable checkout')
    paths = git('ls-files').decode().splitlines()
    require(paths and all(path_name(name) and not (root/name).is_symlink() and
            (root/name).is_file() for name in paths), 'regular complete tracked input inventory')
    tracked = {name: sha((root/name).read_bytes()) for name in paths}
    require(all(sha(git('show', source+':'+name)) == digest for name, digest in tracked.items()),
            'every tooling input matches original exact Git bytes')
    require(tracked.get('scripts/tooling_verification.py') == sha(Path(__file__).read_bytes()),
            'executing original tracked tooling implementation')
    ignored = {name: sha((root/name).read_bytes()) for name in IGNORED_INPUTS if (root/name).is_file()}
    require(all(not (root/name).is_symlink() and (root/name).resolve().is_relative_to(root)
                for name in ignored), 'regular scoped ignored inputs')
    output.mkdir(parents=True)
    sys.dont_write_bytecode = True
    sys.path.insert(0, str(root/'scripts'))
    suite = unittest.TestLoader().discover(str(root/'scripts'), pattern='test_*.py')
    def flatten(value):
        for test in value:
            if isinstance(test, unittest.TestSuite):
                yield from flatten(test)
            else:
                yield test.id()
    identities = list(flatten(suite))
    require(identities and len(set(identities)) == len(identities), 'complete unique tooling discovery')
    log = output/'original-unittest.log'
    # Execute the unchanged complete stdlib discovery command in its own
    # process. Tee original combined stdout/stderr bytes, including subprocess
    # file-descriptor output, rather than redirecting only Python print calls.
    command = [sys.executable, '-m', 'unittest', 'discover', '-s', 'scripts',
               '-p', 'test_*.py', '-v']
    controls = dict(PYTHONDONTWRITEBYTECODE='1', PYTHONUNBUFFERED='1')
    environment = dict(os.environ, **controls)
    decoder = codecs.getincrementaldecoder('utf-8')(errors='replace')
    with log.open('xb') as stream, subprocess.Popen(command, cwd=root, env=environment,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT) as process:
        require(process.stdout is not None, 'actual unittest output pipe')
        while chunk := process.stdout.read1(64 * 1024):
            stream.write(chunk); stream.flush()
            sys.stdout.write(decoder.decode(chunk)); sys.stdout.flush()
        sys.stdout.write(decoder.decode(b'', final=True)); sys.stdout.flush()
        code = process.wait()
    raw = log.read_bytes()
    require(git('rev-parse', 'HEAD').decode().strip() == source and
            not git('status', '--porcelain', '--untracked-files=normal').strip() and
            git('ls-files').decode().splitlines() == paths and
            all(sha((root/name).read_bytes()) == digest for name, digest in {**tracked, **ignored}.items()),
            'tooling input inventory or bytes changed during execution')
    record = dict(schema=SCHEMA, source=source, implementationSHA256=sha(Path(__file__).read_bytes()),
        python=platform.python_implementation()+' '+sys.version, identities=identities,
        trackedInputs=tracked, ignoredInputs=ignored, command=command, environment=controls, exitCode=code,
        logSHA256=sha(raw), logBase64=base64.b64encode(raw).decode())
    (output/'original-execution.json').write_text(json.dumps(record, indent=2, sort_keys=True)+'\n')
    require(code == 0, 'actual complete tooling tests failed; original output preserved')
    verified = verify(record, source)
    (output/'verification.json').write_text(json.dumps(verified, indent=2, sort_keys=True)+'\n')
    emit(record)
    return verified


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    execute(Path(__file__).resolve().parents[1], args.output, args.source)
