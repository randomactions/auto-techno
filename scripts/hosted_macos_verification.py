#!/usr/bin/env python3
"""AT-0039-only complete hosted macOS verification; no quality or runtime authority."""
import argparse
import codecs
import base64
import hashlib
import gzip
import io
import json
import os
from pathlib import Path
import platform
import re
import shlex
import subprocess
import sys
import zlib
from windows_test_plan import plan as native_plan
import tooling_verification as tooling
import native_build_provenance as native_build

SCHEMA = 'autotechno-hosted-macos-verification.v4'
EXECUTION_SCHEMA = 'autotechno-at0039-hosted-execution.v1'
BANKS = 16
MAX_LOG_BYTES = 64 * 1024 * 1024
ISOLATED_IDENTITIES = (
    'swift-testing:ModalSuccessorReportJoinTests/continuousCalibrationMembershipAndFitting()',
    'swift-testing:FoundationRhythmicRelationTests/algorithmicFullPhraseCompanionFaults()',
    'swift-testing:FoundationRhythmicRelationTests/algorithmicFullPhrasePumpBassFaults()',
)


def plan(discoveries, bank, banks):
    # The complete bank exceeded GitHub's six-hour limit while this native
    # fixtures shared a bank with other expensive tests. The pump-bass matrix
    # alone consumed 10271.424 seconds in the next timed-out bank. Isolate each;
    # retain every identity,
    # assertion, native rate, and all sixteen required successful receipts.
    return native_plan(discoveries, bank, banks, isolated_identities=ISOLATED_IDENTITIES)

WORKFLOW = '.github/workflows/windows-distribution.yml'
RETIRED_SKIPS = {
    'Legacy random mutation suppression': 'AutoTechnoCoreTests.GeneratedDSPTopologyTests/mutationSuppression()',
    'Legacy rejected random mutation': 'AutoTechnoCoreTests.GeneratedDSPTopologyTests/rejectedMutationClearsPriorMetadata()',
}


# Existing opt-in diagnostics require private historical inputs or their own
# optimized qualification run. Ordinary full-suite discovery includes them,
# but a skip supplies no evidence for their separate quality/resource gates.
DIAGNOSTIC_SKIPS = {
    'Inspect a single actual streamed chain without an ordinary reference or owner snapshots': 'AutoTechnoCoreTests.IterativeSuccessorPreparationTests/selectedStreamAllocationProcess()',
    'Retained continuous model exercises actual calibrated prepared admission': 'AutoTechnoCoreTests.ContinuousPrimaryPreparedAdmissionTests/retainedModelPreparedAdmission()',
    'Probe the actual native bootstrap through the same full-journey owner': 'AutoTechnoCoreTests.LongHorizonPolicyCalibrationIntegrationTests/probeSharedPreparedBootstrap()',
    'Reproduce the original native rejected-child prefix and recover through the shared owner': 'AutoTechnoCoreTests.LongHorizonPolicyCalibrationIntegrationTests/probeRejectedSuccessorRecovery()',
    'Probe actual native recovery past the frozen structural-debt refusal': 'AutoTechnoCoreTests.LongHorizonPolicyCalibrationIntegrationTests/probeNativeCoreRecovery()',
    'Export frozen calibrated continuation-chain resource observations': 'AutoTechnoCoreTests.PerformanceEnvelopeIntegrationTests/exportContinuousPreparationEnvelope()',
    'Export current shared preparation with exact owned-child replay': 'AutoTechnoCoreTests.PerformanceEnvelopeIntegrationTests/exportCurrentSharedPreparationEnvelope()',
    'Previous v32 native study cannot authorize the new dotted-rhythm policy': 'AutoTechnoCoreTests.ModalSuccessorReportJoinTests/verifyFreshNativePrimaryAndLiveReproducibility()',
}
ALLOWED_SKIPS = {**RETIRED_SKIPS, **DIAGNOSTIC_SKIPS}


def require(ok, reason):
    if not ok:
        raise ValueError(reason)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def strict_json(raw):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, 'duplicate JSON key')
            result[key] = value
        return result
    def invalid(value):
        raise ValueError('nonfinite JSON: ' + value)
    return json.loads(raw, object_pairs_hook=pairs, parse_constant=invalid)


def decode_chunks(log, source, bank):
    chunks = []
    for line in log.splitlines():
        start = line.find('{')
        if start < 0: continue
        try: value = strict_json(line[start:])
        except ValueError: continue
        if isinstance(value, dict) and value.get('schema') == 'autotechno-hosted-receipt-chunk.v1':
            chunks.append(value)
    require(0 < len(chunks) <= 1024, 'bounded receipt chunk count')
    identities = set(); indices = set()
    for chunk in chunks:
        require(set(chunk) == {'schema','source','bank','index','chunks','sha256','bytes','payload'}, 'chunk fields')
        require(chunk['source'] == source and type(chunk['bank']) is int and chunk['bank'] == bank and
                type(chunk['chunks']) is int and chunk['chunks'] == len(chunks), 'chunk source and count')
        index = chunk['index']
        require(type(index) is int and 0 <= index < len(chunks) and index not in indices, 'unique chunk index')
        indices.add(index)
        require(type(chunk['bytes']) is int and 0 < chunk['bytes'] <= 32*1024*1024 and
                isinstance(chunk['sha256'], str) and re.fullmatch('[0-9a-f]{64}',chunk['sha256']) and
                isinstance(chunk['payload'], str) and 0 < len(chunk['payload']) <= 4096, 'bounded chunk data')
        identities.add((chunk['bytes'],chunk['sha256']))
    require(len(identities) == 1, 'common receipt identity')
    encoded = ''.join(c['payload'] for c in sorted(chunks,key=lambda c:c['index']))
    compressed = base64.b64decode(encoded,validate=True); decoder = zlib.decompressobj()
    raw = decoder.decompress(compressed,32*1024*1024+1)
    size,digest = next(iter(identities))
    require(decoder.eof and not decoder.unused_data and not decoder.unconsumed_tail and
            len(raw) == size and sha(raw) == digest, 'complete exact decoded receipt')
    return strict_json(raw)


def execution_errors(execution, subject, revision, gate, status):
    if not isinstance(execution, dict):
        return ['hosted execution must be an object']
    required = {'schema', 'environment', 'scope', 'revision', 'receipt', 'receiptSHA256'}
    valid = (set(execution) == required and subject == 'AT-0039' and
             gate == 'full-local-verification' and status == 'passed' and
             execution.get('schema') == EXECUTION_SCHEMA and
             execution.get('environment') == 'hosted-macos' and
             execution.get('scope') == 'complete-native-suites-and-release-build' and
             re.fullmatch('[0-9a-f]{40}', str(revision)) and execution.get('revision') == revision and
             execution.get('receipt') == 'docs/local/result-records/AT-0039-hosted-macos.json' and
             re.fullmatch('[0-9a-f]{64}', str(execution.get('receiptSHA256', ''))))
    return [] if valid else ['invalid AT-0039-only hosted full verification binding']


def verify(bundle, source, logs=None, *, compiled_git=None):
    require(isinstance(bundle, dict) and set(bundle) == {'schema', 'source', 'run', 'workflow', 'banks'}, 'bundle fields')
    require(bundle['schema'] == SCHEMA and bundle['source'] == source and
            re.fullmatch('[0-9a-f]{40}', str(source)), 'exact source')
    run = bundle['run']; workflow = bundle['workflow']
    require(isinstance(run, dict) and isinstance(workflow, dict), 'native run and workflow')
    require(type(run.get('id')) is int and run['id'] > 0 and
            type(run.get('run_attempt')) is int and run['run_attempt'] > 0 and run.get('head_sha') == source and
            run.get('status') == 'completed' and run.get('conclusion') == 'success' and
            run.get('event') == 'workflow_dispatch', 'successful exact-source workflow')
    require(workflow.get('path') == WORKFLOW and workflow.get('id') == run.get('workflow_id') and
            workflow.get('state') == 'active' and type(workflow.get('id')) is int, 'authorized workflow')
    require(run.get('repository', {}).get('full_name') == 'randomactions/auto-techno', 'repository binding')
    rows = bundle['banks']; require(isinstance(rows, list) and len(rows) == BANKS, 'all sixteen banks')
    require(isinstance(logs, dict) and all(type(bank) is int for bank in logs) and
            set(logs) == set(range(BANKS)), 'all sixteen original job logs required')
    seen = set(); discovered = set(); jobs = set(); digests = set(); skipped = 0; executed = 0
    tooling_result = None; build_bindings = {}
    for row in rows:
        require(isinstance(row, dict) and set(row) == {'job', 'receipt', 'originalLogSHA256'}, 'bank fields')
        job, receipt = row['job'], row['receipt']
        require(isinstance(job, dict) and isinstance(receipt, dict), 'bank objects')
        require(set(receipt) == {'schema', 'source', 'environment', 'bank', 'banks', 'discovery', 'plan', 'completedSlices', 'buildProvenanceSHA256'}, 'receipt fields')
        bank = receipt['bank']; require(type(bank) is int and 0 <= bank < BANKS and bank not in seen, 'unique bank')
        seen.add(bank)
        require(receipt['schema'] == 'autotechno-hosted-macos-bank.v2' and receipt['source'] == source and
                receipt['environment'] == 'hosted-macos' and receipt['banks'] == BANKS, 'native bank source/scope')
        require(type(job.get('id')) is int and job['id'] > 0 and job['id'] not in jobs and
                job.get('run_id') == run['id'] and type(job.get('run_attempt')) is int and
                job['run_attempt'] == run['run_attempt'] and job.get('head_sha') == source and
                job.get('status') == 'completed' and job.get('conclusion') == 'success' and
                job.get('name') == f'hosted-macos / Complete macOS bank {bank}', 'successful exact bank job')
        jobs.add(job['id'])
        raw = logs[bank]
        require(isinstance(raw, bytes) and 0 < len(raw) <= MAX_LOG_BYTES and
                sha(raw) == row['originalLogSHA256'], 'original bank job log digest')
        original, measured = parse_bank(raw, source, bank)
        require(original == receipt, 'bank receipt equals its original native stdout')
        build_record = native_build.decode(raw.decode('utf-8'), source)
        build_bindings[bank] = native_build.validate(build_record, source,
            build_record['trackedInputs'] if compiled_git is None else compiled_git)
        if bank == 0:
            tooling_result = tooling.verify(tooling.decode(raw.decode('utf-8'), source), source)
        for name in ['Verify macOS environment', 'Build all native tests', 'Execute complete native bank'] + (
                ['Run complete tooling tests', 'Build macOS Release app', 'Validate codebase map'] if bank == 0 else []):
            steps = [s for s in job.get('steps', []) if isinstance(s, dict) and s.get('name') == name]
            require(len(steps) == 1 and steps[0].get('status') == 'completed' and steps[0].get('conclusion') == 'success', 'required native step: ' + name)
        expected = plan(receipt['discovery'], bank, BANKS)
        require(receipt['plan'] == expected, 'recomputed complete native discovery plan')
        digests.add(expected['discoverySHA256'])
        completed = receipt['completedSlices']
        require(isinstance(completed, list) and len(completed) == len(expected['selected']), 'complete executed slices')
        bank_executed = 0; bank_skipped = 0
        for selection, result in zip(expected['selected'], completed):
            require(isinstance(result, dict) and set(result) == {'selection', 'reportedTests', 'explicitlySkippedTests', 'executedTests', 'skippedIdentifiers', 'exitCode', 'logSHA256'}, 'slice fields')
            count = len(selection['identifiers'])
            require(result['selection'] == selection and type(result['exitCode']) is int and result['exitCode'] == 0, 'exact successful slice')
            for key in ['reportedTests', 'explicitlySkippedTests', 'executedTests']:
                require(type(result[key]) is int and result[key] >= 0, 'integer native counts')
            require(result['reportedTests'] == count and result['executedTests'] + result['explicitlySkippedTests'] == count, 'native count and skip accounting')
            require(re.fullmatch('[0-9a-f]{64}', str(result['logSHA256'])), 'native log hash')
            allowed_skips = sorted(set(selection['identifiers']) & set(ALLOWED_SKIPS.values())) if selection['library'] == 'swift-testing' else []
            require(result['skippedIdentifiers'] == allowed_skips and result['explicitlySkippedTests'] == len(allowed_skips), 'only enumerated retired and separate diagnostic skips')
            skipped += result['explicitlySkippedTests']; executed += result['executedTests']
            bank_skipped += result['explicitlySkippedTests']; bank_executed += result['executedTests']
            for case in selection['identifiers']:
                key = selection['library'] + ':' + case
                require(key not in discovered, 'duplicate executed identity'); discovered.add(key)
        require(measured == dict(executedTests=bank_executed, explicitlySkippedTests=bank_skipped),
                'original per-bank native execution and skip totals')
    require(len(digests) == 1 and seen == set(range(BANKS)), 'common discovery and complete banks')
    require(sha('\n'.join(sorted(discovered)).encode()) == next(iter(digests)), 'exhaustive discovery union')
    require(tooling_result is not None, 'complete original tooling execution required')
    return dict(schema=SCHEMA, source=source, run=run['id'], runAttempt=run['run_attempt'], banks=BANKS,
                environment='hosted-macos', discoveredTests=len(discovered),
                executedTests=executed, explicitlySkippedTests=skipped, completeNativeSuitesAndReleaseBuild=True,
                originalJobLogsVerified=True, suiteFileHashesIndependentlyVerified=False,
                completeToolingTestsVerified=True,
                originalVerboseBuildBindingsVerified=True,
                compiledBuildClosureIndependentlyAuthenticated=compiled_git is not None,
                originalBuildBindings=build_bindings,
                originalToolingOutputVerified=True,
                toolingExecutedTests=tooling_result['executedTests'],
                localExecution=False, automatedQualityQualification=False, runtimeQualification=False, item39Complete=False)


def bounded_regular(path, limit):
    require(path.is_file() and not path.is_symlink() and 0 < path.stat().st_size <= limit,
            'bounded regular original file required')
    with path.open('rb') as handle:
        raw = handle.read(limit + 1)
    require(0 < len(raw) <= limit, 'bounded original file bytes')
    return raw


def original_logs(directory):
    """Read bounded preserved originals; return compressed-byte stability bindings."""
    require(directory.is_dir() and not directory.is_symlink(), 'original log directory required')
    logs, digests = {}, {}
    for bank in range(BANKS):
        path = directory / f'bank-{bank}.log.gz'
        compressed = bounded_regular(path, MAX_LOG_BYTES)
        with gzip.GzipFile(fileobj=io.BytesIO(compressed), mode='rb') as handle:
            raw = handle.read(MAX_LOG_BYTES + 1)
        require(0 < len(raw) <= MAX_LOG_BYTES, 'bounded original decompressed bytes')
        logs[bank] = raw; digests[path] = sha(compressed)
    return logs, digests


def validate_bound_receipt(root, record, execution):
    errors = execution_errors(execution, record.get('subject'), record.get('revision'), 'full-local-verification', 'passed')
    if errors: return errors
    root = Path(root).resolve(); path = root / execution['receipt']
    try:
        require(path.resolve().is_relative_to(root), 'receipt escapes repository')
        raw = bounded_regular(path, 32 * 1024 * 1024)
        require(sha(raw) == execution['receiptSHA256'], 'hosted receipt digest mismatch')
        directory = path.parent / (path.stem + '-logs')
        require(directory.resolve().is_relative_to(root), 'original logs escape repository')
        logs, digests = original_logs(directory)
        verify(strict_json(raw), record['revision'], logs)
        require(not directory.is_symlink() and bounded_regular(path, 32 * 1024 * 1024) == raw and
                all(sha(bounded_regular(p, MAX_LOG_BYTES)) == digest for p,digest in digests.items()),
                'original receipt or bank archives changed during verification')
    except (OSError, ValueError, TypeError, KeyError, EOFError, zlib.error) as exc:
        return ['hosted verification receipt: ' + str(exc)]
    return []


def summarize_log(raw, library, expected, identifiers):
    pattern = r'Executed (\d+) tests?, with 0 failures' if library == 'xctest' else r'Test run with (\d+) tests? passed'
    matches = re.findall(pattern, raw)
    require(matches and int(matches[-1]) == expected and expected > 0, 'missing or mismatched native test summary')
    skips = len(re.findall(r'Test Case .* skipped' if library == 'xctest' else r'Test ".*" skipped', raw))
    names = re.findall(r'Test "([^"\n]+)" skipped', raw) if library == 'swift-testing' else []
    require(all(name in ALLOWED_SKIPS for name in names), 'unexpected skipped test')
    skipped_ids = sorted(ALLOWED_SKIPS[name] for name in names)
    allowed = sorted(set(identifiers) & set(ALLOWED_SKIPS.values())) if library == 'swift-testing' else []
    require(skips <= expected and skips == len(skipped_ids) and skipped_ids == allowed, 'invalid skipped identity/count')
    return dict(reportedTests=expected, explicitlySkippedTests=skips, executedTests=expected-skips, skippedIdentifiers=skipped_ids)


def parse_bank(raw, source, bank):
    """Recompute execution counts from original stdout, never receipt JSON alone."""
    require(isinstance(raw, bytes) and 0 < len(raw) <= MAX_LOG_BYTES,
            'bounded original native log')
    require(isinstance(source, str) and re.fullmatch('[0-9a-f]{40}', source), 'exact native source')
    require(type(bank) is int and 0 <= bank < BANKS, 'native bank index')
    log = raw.decode('utf-8')
    receipt = decode_chunks(log, source, bank)
    require(isinstance(receipt, dict) and set(receipt) == {
        'schema', 'source', 'environment', 'bank', 'banks', 'discovery', 'plan', 'completedSlices', 'buildProvenanceSHA256'},
        'receipt fields')
    require(receipt['schema'] == 'autotechno-hosted-macos-bank.v2' and
            receipt['source'] == source and receipt['environment'] == 'hosted-macos' and
            type(receipt['bank']) is int and receipt['bank'] == bank and
            type(receipt['banks']) is int and receipt['banks'] == BANKS, 'native bank source/scope')
    expected = plan(receipt['discovery'], bank, BANKS)
    require(receipt['plan'] == expected, 'recomputed original native plan')
    completed = receipt['completedSlices']
    require(isinstance(completed, list) and len(completed) == len(expected['selected']),
            'complete original native slices')
    # The producer emits BEGIN before each native process and chunks only after
    # every process exits successfully. Bound the final body at that transport,
    # so later workflow summaries cannot replace missing native output.
    transport = None; offset = 0
    for line in log.splitlines(keepends=True):
        start = line.find('{')
        if start >= 0:
            try:
                value = strict_json(line[start:])
            except ValueError:
                value = None
            if isinstance(value, dict) and value.get('schema') == 'autotechno-hosted-receipt-chunk.v1':
                transport = offset
                break
        offset += len(line)
    require(transport is not None, 'native receipt transport required')
    markers = list(re.finditer(r'(?m)^(?:\d{4}-\d\d-\d\dT\S+ )?'
                              r'BEGIN native slice ([^\r\n]+)\r?\n', log))
    require(len(markers) == len(completed) and all(m.start() < transport for m in markers),
            'complete ordered original native boundaries')
    build_record = native_build.decode(log, source)
    digest = native_build.record_digest(build_record)
    require(receipt['buildProvenanceSHA256'] == digest, 'original bank/build provenance binding')
    begin = list(re.finditer(r'(?m)^(?:\d{4}-\d\d-\d\dT\S+ )?BEGIN native build binding ' + str(bank) + ':' + digest + r'\r?\n', log))
    end_binding = list(re.finditer(r'(?m)^(?:\d{4}-\d\d-\d\dT\S+ )?END native build binding ' + str(bank) + ':' + digest + r'\r?\n', log))
    # An empty assigned bank is permitted only by the unchanged exhaustive plan;
    # it still requires its complete original build and pre/post seals.
    require(len(begin) == len(end_binding) == 1 and begin[0].end() <= end_binding[0].start() < transport and
            all(begin[0].end() <= marker.start() < marker.end() <= end_binding[0].start() for marker in markers),
            'original pre/post native build bindings')
    chunks = [m.start() for m in re.finditer(re.escape(native_build.CHUNK_SCHEMA), log)]
    require(chunks and max(chunks) < begin[0].start(), 'original build provenance sealed before native execution')
    counts = dict(executedTests=0, explicitlySkippedTests=0)
    for index, (selection, result, marker) in enumerate(zip(expected['selected'], completed, markers)):
        require(isinstance(result, dict) and set(result) == {
            'selection', 'reportedTests', 'explicitlySkippedTests', 'executedTests',
            'skippedIdentifiers', 'exitCode', 'logSHA256'}, 'original native slice fields')
        require(result['selection'] == selection and type(result['exitCode']) is int and
                result['exitCode'] == 0, 'successful original native selection')
        require(marker.group(1) == f"{bank}:{selection['library']}:{selection['suite']}",
                'ordered original native execution')
        end = markers[index + 1].start() if index + 1 < len(markers) else transport
        measured = summarize_log(log[marker.end():end], selection['library'],
                                 len(selection['identifiers']), selection['identifiers'])
        for key, value in measured.items():
            require(result[key] == value and (key == 'skippedIdentifiers' or type(result[key]) is int),
                    'measured original native count: ' + key)
        require(re.fullmatch('[0-9a-f]{64}', str(result['logSHA256'])), 'native slice digest')
        # Actions timestamps transform stdout; do not claim to recompute the
        # producer's untransformed per-process file hash from this job log.
        for key in counts:
            counts[key] += measured[key]
    return receipt, counts


def emit(value):
    raw = json.dumps(value, sort_keys=True, separators=(',', ':')).encode()
    encoded = base64.b64encode(zlib.compress(raw)).decode(); size = 4096
    for index, offset in enumerate(range(0, len(encoded), size)):
        print(json.dumps(dict(schema='autotechno-hosted-receipt-chunk.v1', source=value['source'],
              bank=value['bank'], index=index, chunks=(len(encoded)+size-1)//size,
              sha256=sha(raw), bytes=len(raw), payload=encoded[offset:offset+size])), flush=True)



def diagnose_crash(build_path, selector):
    """One bounded native debugger replay; never emits verification receipts."""
    require(platform.system() == 'Darwin' and os.environ.get('GITHUB_ACTIONS') == 'true' and
            os.environ.get('RUNNER_OS') == 'macOS', 'hosted native macOS required')
    require(isinstance(selector, str) and 0 < len(selector) <= 2048, 'bounded diagnostic selector')
    root = Path(__file__).resolve().parents[1]
    def output(command):
        return subprocess.check_output(command, cwd=root, text=True, timeout=60).strip()
    binary_dir = Path(output(['swift', 'build', '--build-path', str(build_path), '--show-bin-path']))
    binary = str(binary_dir / 'AutoTechnoPackageTests.xctest/Contents/MacOS/AutoTechnoPackageTests')
    compiler = Path(output(['xcrun', '--find', 'swift']))
    helper = str(compiler.parent / '../libexec/swift/pm/swiftpm-testing-helper')
    sdk = output(['xcrun', '--sdk', 'macosx', '--show-sdk-platform-path'])
    environment = os.environ.copy()
    for name, suffix in [('DYLD_FRAMEWORK_PATH', f'{sdk}/Developer/Library/Frameworks:{sdk}/Developer/Library/PrivateFrameworks'),
                         ('DYLD_LIBRARY_PATH', f'{sdk}/Developer/usr/lib')]:
        environment[name] = ':'.join(filter(None, [environment.get(name), suffix]))
    target_environment = ' '.join(shlex.quote(name + '=' + environment[name])
                                  for name in ['DYLD_FRAMEWORK_PATH', 'DYLD_LIBRARY_PATH'])
    command = ['xcrun', 'lldb', '--batch', '--no-lldbinit',
               '-o', 'settings set target.env-vars ' + target_environment,
               '-o', 'process launch --shell-expand-args false']
    for instruction in ['thread backtrace --count 40 all', 'register read sp fp pc x9',
                        'memory region $sp', 'disassemble --frame --count 12',
                        'frame select 1', 'disassemble --frame --count 24']:
        command.extend(['-k', instruction])
    command.extend(['--', helper, '--test-bundle-path', binary, '--no-parallel',
                    '--filter', selector, binary, '--testing-library', 'swift-testing'])
    print('Diagnostic replay only: no native verification or qualification receipt.', flush=True)
    return subprocess.run(command, cwd=root, env=environment, timeout=900).returncode



def require_native_success(result, raw, library, build_path, selector):
    if result.returncode == 0:
        return
    if library == 'swift-testing' and b'Exited with unexpected signal code' in raw:
        try:
            diagnose_crash(build_path, selector)
        except (OSError, ValueError, subprocess.SubprocessError) as exc:
            print('Crash diagnostic unavailable: ' + str(exc), flush=True)
    # A debugger pass, crash or timeout must never replace the original failure.
    raise ValueError('native slice failed')


def run_logged_native(command, root, log, *, console=True):
    """Keep exact receipt bytes and expose progress before the child completes."""
    decoder = codecs.getincrementaldecoder('utf-8')(errors='replace')
    with log.open('wb') as stream, subprocess.Popen(command, cwd=root,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT) as process:
        require(process.stdout is not None, 'native output pipe required')
        while chunk := process.stdout.read1(64 * 1024):
            stream.write(chunk)
            stream.flush()
            if console:
                sys.stdout.write(decoder.decode(chunk))
                sys.stdout.flush()
        if console:
            sys.stdout.write(decoder.decode(b'', final=True))
            sys.stdout.flush()
        return subprocess.CompletedProcess(command, process.wait())


def run_bank(bank, build_path, output, build_provenance=None):
    require(platform.system() == 'Darwin' and os.environ.get('GITHUB_ACTIONS') == 'true' and
            os.environ.get('RUNNER_OS') == 'macOS', 'hosted native macOS required')
    root = Path(__file__).resolve().parents[1]
    def git(*args): return subprocess.check_output(['git', *args], cwd=root, text=True).strip()
    source = git('rev-parse', 'HEAD'); require(source == os.environ.get('GITHUB_SHA'), 'checkout source binding')
    require(not git('status', '--porcelain', '--untracked-files=normal'), 'clean immutable source')
    require(build_provenance is not None, 'original pre-execution build provenance required')
    record = native_build.strict(bounded_regular(build_provenance, native_build.MAX_METADATA))
    require(record['source'] == source and Path(record['buildPath']) == build_path, 'same original native build source/path')
    native_build.validate(record, source, native_build.git_source_files(str(root), source))
    native_build.guard(record, root)
    digest = native_build.record_digest(record)
    print(f'BEGIN native build binding {bank}:{digest}', flush=True)
    output.mkdir(parents=True, exist_ok=False)
    libraries = {'xctest': ['--enable-xctest', '--disable-swift-testing'],
                 'swift-testing': ['--disable-xctest', '--enable-swift-testing']}
    discoveries = {}
    for library, flags in libraries.items():
        discoveries[library] = subprocess.check_output(native_build.test_command(record,
            'list', '--skip-build', *flags), cwd=root, text=True)
        native_build.guard(record, root)
    selection = plan(discoveries, bank, BANKS); results = []
    for ordinal, selected in enumerate(selection['selected']):
        native_build.guard(record, root)
        print(f'BEGIN native slice {bank}:{selected["library"]}:{selected["suite"]}', flush=True)
        log = output / f'{ordinal}.log'
        result = run_logged_native(native_build.test_command(record, '--skip-build',
            '--no-parallel', *libraries[selected['library']], '--filter', selected['selector']), root, log)
        raw = log.read_bytes()
        require_native_success(result, raw, selected['library'], build_path, selected['selector'])
        native_build.guard(record, root)
        counts = summarize_log(raw.decode(), selected['library'], len(selected['identifiers']), selected['identifiers'])
        results.append(dict(selection=selected, **counts, exitCode=result.returncode, logSHA256=sha(raw)))
    require(git('rev-parse', 'HEAD') == source and not git('status', '--porcelain', '--untracked-files=normal'), 'source changed during tests')
    native_build.guard(record, root)
    print(f'END native build binding {bank}:{digest}', flush=True)
    emit(dict(schema='autotechno-hosted-macos-bank.v2', source=source, environment='hosted-macos',
              bank=bank, banks=BANKS, discovery=discoveries, plan=selection, completedSlices=results,
              buildProvenanceSHA256=digest))


def collect(run_id, source, output):
    """Fetch terminal GitHub evidence; never construct native success locally."""
    require(type(run_id) is int and run_id > 0 and
            re.fullmatch('[0-9a-f]{40}', source), 'run and exact source required')
    require(not output.exists(), 'new evidence directory required')
    prefix = 'repos/randomactions/auto-techno/actions/'
    def api(suffix, raw=False):
        data = subprocess.check_output(['gh', 'api', prefix + suffix], timeout=120)
        require(len(data) <= 64 * 1024 * 1024, 'bounded native response')
        return data if raw else strict_json(data)
    run = api(f'runs/{run_id}')
    require(run.get('head_sha') == source and run.get('status') == 'completed' and
            run.get('conclusion') == 'success', 'terminal exact-source success required')
    workflow = api(f'workflows/{run["workflow_id"]}')
    listing = api(f'runs/{run_id}/jobs?per_page=100&filter=latest')
    require(type(listing.get('total_count')) is int and listing['total_count'] <= 100 and
            len(listing.get('jobs', [])) == listing['total_count'], 'complete job listing')
    jobs = [job for job in listing['jobs'] if
            re.fullmatch(r'hosted-macos / Complete macOS bank [0-9]+', job.get('name', ''))]
    require(len(jobs) == BANKS, 'all native bank jobs required')
    rows = []; logs = {}
    for job in sorted(jobs,key=lambda j:j['name']):
        bank = int(job['name'].rsplit(' ', 1)[1])
        raw = api(f'jobs/{job["id"]}/logs', raw=True)
        receipt, _ = parse_bank(raw, source, bank)
        rows.append(dict(job=job, receipt=receipt, originalLogSHA256=sha(raw))); logs[bank] = raw
    bundle = dict(schema=SCHEMA,source=source,run=run,workflow=workflow,banks=rows)
    result = verify(bundle,source,logs)
    refreshed = api(f'runs/{run_id}')
    require(all(refreshed.get(key) == run.get(key) for key in
                ['id','head_sha','status','conclusion','run_attempt','workflow_id']), 'run changed during collection')
    output.mkdir(parents=True,exist_ok=False)
    for bank, raw in logs.items(): (output/f'bank-{bank}.log.gz').write_bytes(gzip.compress(raw,mtime=0))
    (output/'receipt.json').write_text(json.dumps(bundle,indent=2,sort_keys=True)+'\n')
    (output/'verification.json').write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bank', type=int)
    parser.add_argument('--build-path', type=Path)
    parser.add_argument('--run', type=int)
    parser.add_argument('--source')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--diagnostic-filter')
    parser.add_argument('--prepare-native-build', action='store_true')
    parser.add_argument('--build-provenance', type=Path)
    args = parser.parse_args()
    if args.prepare_native_build:
        require(platform.system() == 'Darwin' and os.environ.get('GITHUB_ACTIONS') == 'true' and
                os.environ.get('RUNNER_OS') == 'macOS', 'original hosted native build required')
        require(args.bank is args.run is args.source is args.diagnostic_filter is args.build_provenance is None and
                args.build_path is not None and args.output is not None, 'exclusive original native build arguments')
        root = Path(__file__).resolve().parents[1]
        require(native_build.inventory(root)['source'] == os.environ.get('GITHUB_SHA'), 'original build checkout source')
        try:
            record = native_build.prepare(root, args.build_path, args.output,
                lambda command, cwd, log: run_logged_native(command, cwd, log, console=False))
        except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as exc:
            native_build.preserve_failure(args.output, os.environ['GITHUB_SHA'], exc)
            raise
        native_build.emit(record)
        raise SystemExit(0)
    if args.diagnostic_filter is not None:
        require(args.build_path is not None and args.run is None and args.bank is None and
                args.source is None and args.output is None and args.build_provenance is None, 'diagnostic-only arguments')
        raise SystemExit(diagnose_crash(args.build_path, args.diagnostic_filter))
    require(args.output is not None, 'verification output required')
    if args.run is not None:
        require(args.source and args.bank is None and args.build_path is None and args.build_provenance is None, 'collection arguments')
        print(json.dumps(collect(args.run,args.source,args.output),sort_keys=True))
    else:
        require(args.bank is not None and args.build_path is not None and args.source is None, 'native bank arguments')
        run_bank(args.bank,args.build_path,args.output,args.build_provenance)
