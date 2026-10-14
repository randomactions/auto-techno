#!/usr/bin/env python3
"""AT-0039-only complete hosted macOS verification; no quality or runtime authority."""
import argparse
import codecs
import base64
import hashlib
import gzip
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

SCHEMA = 'autotechno-hosted-macos-verification.v1'
EXECUTION_SCHEMA = 'autotechno-at0039-hosted-execution.v1'
BANKS = 16
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
    'Retained continuous model exercises actual calibrated prepared admission': 'AutoTechnoCoreTests.ContinuousPrimaryPreparedAdmissionTests/retainedModelPreparedAdmission()',
    'Probe the actual native bootstrap through the same full-journey owner': 'AutoTechnoCoreTests.LongHorizonPolicyCalibrationIntegrationTests/probeSharedPreparedBootstrap()',
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


def verify(bundle, source):
    require(isinstance(bundle, dict) and set(bundle) == {'schema', 'source', 'run', 'workflow', 'banks'}, 'bundle fields')
    require(bundle['schema'] == SCHEMA and bundle['source'] == source and
            re.fullmatch('[0-9a-f]{40}', str(source)), 'exact source')
    run = bundle['run']; workflow = bundle['workflow']
    require(isinstance(run, dict) and isinstance(workflow, dict), 'native run and workflow')
    require(type(run.get('id')) is int and run['id'] > 0 and run.get('head_sha') == source and
            run.get('status') == 'completed' and run.get('conclusion') == 'success' and
            run.get('event') == 'workflow_dispatch', 'successful exact-source workflow')
    require(workflow.get('path') == WORKFLOW and workflow.get('id') == run.get('workflow_id') and
            workflow.get('state') == 'active' and type(workflow.get('id')) is int, 'authorized workflow')
    require(run.get('repository', {}).get('full_name') == 'randomactions/auto-techno', 'repository binding')
    rows = bundle['banks']; require(isinstance(rows, list) and len(rows) == BANKS, 'all sixteen banks')
    seen = set(); discovered = set(); jobs = set(); digests = set(); skipped = 0; executed = 0
    for row in rows:
        require(isinstance(row, dict) and set(row) == {'job', 'receipt'}, 'bank fields')
        job, receipt = row['job'], row['receipt']
        require(isinstance(job, dict) and isinstance(receipt, dict), 'bank objects')
        require(set(receipt) == {'schema', 'source', 'environment', 'bank', 'banks', 'discovery', 'plan', 'completedSlices'}, 'receipt fields')
        bank = receipt['bank']; require(type(bank) is int and 0 <= bank < BANKS and bank not in seen, 'unique bank')
        seen.add(bank)
        require(receipt['schema'] == 'autotechno-hosted-macos-bank.v1' and receipt['source'] == source and
                receipt['environment'] == 'hosted-macos' and receipt['banks'] == BANKS, 'native bank source/scope')
        require(type(job.get('id')) is int and job['id'] > 0 and job['id'] not in jobs and
                job.get('run_id') == run['id'] and job.get('head_sha') == source and
                job.get('status') == 'completed' and job.get('conclusion') == 'success' and
                job.get('name') == f'hosted-macos / Complete macOS bank {bank}', 'successful exact bank job')
        jobs.add(job['id'])
        for name in ['Verify macOS environment', 'Build all native tests', 'Execute complete native bank'] + (
                ['Run complete tooling tests', 'Build macOS Release app', 'Validate codebase map'] if bank == 0 else []):
            steps = [s for s in job.get('steps', []) if isinstance(s, dict) and s.get('name') == name]
            require(len(steps) == 1 and steps[0].get('status') == 'completed' and steps[0].get('conclusion') == 'success', 'required native step: ' + name)
        expected = plan(receipt['discovery'], bank, BANKS)
        require(receipt['plan'] == expected, 'recomputed complete native discovery plan')
        digests.add(expected['discoverySHA256'])
        completed = receipt['completedSlices']
        require(isinstance(completed, list) and len(completed) == len(expected['selected']), 'complete executed slices')
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
            for case in selection['identifiers']:
                key = selection['library'] + ':' + case
                require(key not in discovered, 'duplicate executed identity'); discovered.add(key)
    require(len(digests) == 1 and seen == set(range(BANKS)), 'common discovery and complete banks')
    require(sha('\n'.join(sorted(discovered)).encode()) == next(iter(digests)), 'exhaustive discovery union')
    return dict(schema=SCHEMA, source=source, environment='hosted-macos', discoveredTests=len(discovered),
                executedTests=executed, explicitlySkippedTests=skipped, completeNativeSuitesAndReleaseBuild=True,
                localExecution=False, automatedQualityQualification=False, runtimeQualification=False, item39Complete=False)


def validate_bound_receipt(root, record, execution):
    errors = execution_errors(execution, record.get('subject'), record.get('revision'), 'full-local-verification', 'passed')
    if errors: return errors
    root = Path(root).resolve(); path = root / execution['receipt']
    try:
        require(path.resolve().is_relative_to(root), 'receipt escapes repository')
        raw = path.read_bytes(); require(len(raw) <= 32 * 1024 * 1024, 'oversized hosted receipt')
        require(sha(raw) == execution['receiptSHA256'], 'hosted receipt digest mismatch')
        verify(strict_json(raw), record['revision'])
    except (OSError, ValueError, TypeError, KeyError) as exc:
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


def run_logged_native(command, root, log):
    """Keep exact receipt bytes and expose progress before the child completes."""
    decoder = codecs.getincrementaldecoder('utf-8')(errors='replace')
    with log.open('wb') as stream, subprocess.Popen(command, cwd=root,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT) as process:
        require(process.stdout is not None, 'native output pipe required')
        while chunk := process.stdout.read1(64 * 1024):
            stream.write(chunk)
            stream.flush()
            sys.stdout.write(decoder.decode(chunk))
            sys.stdout.flush()
        sys.stdout.write(decoder.decode(b'', final=True))
        sys.stdout.flush()
        return subprocess.CompletedProcess(command, process.wait())


def run_bank(bank, build_path, output):
    require(platform.system() == 'Darwin' and os.environ.get('GITHUB_ACTIONS') == 'true' and
            os.environ.get('RUNNER_OS') == 'macOS', 'hosted native macOS required')
    root = Path(__file__).resolve().parents[1]
    def git(*args): return subprocess.check_output(['git', *args], cwd=root, text=True).strip()
    source = git('rev-parse', 'HEAD'); require(source == os.environ.get('GITHUB_SHA'), 'checkout source binding')
    require(not git('status', '--porcelain', '--untracked-files=normal'), 'clean immutable source')
    output.mkdir(parents=True, exist_ok=False)
    libraries = {'xctest': ['--enable-xctest', '--disable-swift-testing'],
                 'swift-testing': ['--disable-xctest', '--enable-swift-testing']}
    discoveries = {}
    for library, flags in libraries.items():
        discoveries[library] = subprocess.check_output(['swift', 'test', '--build-path', str(build_path),
            'list', '--skip-build', *flags], cwd=root, text=True)
    selection = plan(discoveries, bank, BANKS); results = []
    for ordinal, selected in enumerate(selection['selected']):
        print(f'BEGIN native slice {bank}:{selected["library"]}:{selected["suite"]}', flush=True)
        log = output / f'{ordinal}.log'
        result = run_logged_native(['swift', 'test', '--build-path', str(build_path), '--skip-build',
            '--no-parallel', *libraries[selected['library']], '--filter', selected['selector']], root, log)
        raw = log.read_bytes()
        require_native_success(result, raw, selected['library'], build_path, selected['selector'])
        counts = summarize_log(raw.decode(), selected['library'], len(selected['identifiers']), selected['identifiers'])
        results.append(dict(selection=selected, **counts, exitCode=result.returncode, logSHA256=sha(raw)))
    require(git('rev-parse', 'HEAD') == source and not git('status', '--porcelain', '--untracked-files=normal'), 'source changed during tests')
    emit(dict(schema='autotechno-hosted-macos-bank.v1', source=source, environment='hosted-macos',
              bank=bank, banks=BANKS, discovery=discoveries, plan=selection, completedSlices=results))


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
        receipt = decode_chunks(raw.decode('utf-8'), source, bank)
        rows.append(dict(job=job, receipt=receipt)); logs[f'bank-{bank}.log.gz'] = gzip.compress(raw,mtime=0)
    bundle = dict(schema=SCHEMA,source=source,run=run,workflow=workflow,banks=rows)
    result = verify(bundle,source)
    refreshed = api(f'runs/{run_id}')
    require(all(refreshed.get(key) == run.get(key) for key in
                ['id','head_sha','status','conclusion','run_attempt','workflow_id']), 'run changed during collection')
    output.mkdir(parents=True,exist_ok=False)
    for name, raw in logs.items(): (output/name).write_bytes(raw)
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
    args = parser.parse_args()
    if args.diagnostic_filter is not None:
        require(args.build_path is not None and args.run is None and args.bank is None and
                args.source is None and args.output is None, 'diagnostic-only arguments')
        raise SystemExit(diagnose_crash(args.build_path, args.diagnostic_filter))
    require(args.output is not None, 'verification output required')
    if args.run is not None:
        require(args.source and args.bank is None and args.build_path is None, 'collection arguments')
        print(json.dumps(collect(args.run,args.source,args.output),sort_keys=True))
    else:
        require(args.bank is not None and args.build_path is not None and args.source is None, 'native bank arguments')
        run_bank(args.bank,args.build_path,args.output)
