#!/usr/bin/env python3
"""Verify complete native Windows banks and Release build, never runtime quality."""
import argparse
import gzip
import json
from pathlib import Path
import re
import subprocess

from hosted_macos_verification import require, sha, strict_json, summarize_log
from windows_test_plan import plan

SCHEMA = 'autotechno-hosted-windows-verification.v1'
BANKS = 8
WORKFLOW = '.github/workflows/windows-distribution.yml'
MAX_LOG_BYTES = 64 * 1024 * 1024
JOB_NAME = re.compile(r'Windows x64 source validation \(bank-([0-7])\)')


def records(log, schema):
    values = []
    for line in log.splitlines():
        start = line.find('{')
        if start < 0:
            continue
        try:
            value = strict_json(line[start:])
        except ValueError:
            continue
        if isinstance(value, dict) and value.get('schema') == schema:
            values.append(value)
    require(len(values) == 1, 'exactly one native ' + schema)
    return values[0]


def parse_bank(raw, source, bank):
    """Derive counts from original job output, including every named skip."""
    require(isinstance(raw, bytes) and 0 < len(raw) <= MAX_LOG_BYTES, 'bounded original log')
    # PowerShell can emit a BOM before a later native process's first line.
    # Normalize only line-leading encoding markers; retain original bytes/hash.
    log = re.sub(r'(?m)^\ufeff', '', raw.decode('utf-8-sig'))
    selection = records(log, 'autotechno-windows-test-bank-plan.v2')
    result = records(log, 'autotechno-windows-test-bank-result.v2')
    require(type(bank) is int and 0 <= bank < BANKS and
            type(selection.get('bank')) is int and selection['bank'] == bank and
            type(selection.get('banks')) is int and selection['banks'] == BANKS and
            selection.get('nativeExecutionProven') is False and
            selection.get('partitionUnit') == 'discovered-test-identity', 'native plan scope')
    require(result.get('source') == source and type(result.get('bank')) is int and
            result['bank'] == bank and type(result.get('banks')) is int and result['banks'] == BANKS and
            result.get('partitionUnit') == selection['partitionUnit'] and
            result.get('fullWindowsQualification') is False and
            result.get('discoverySHA256') == selection.get('discoverySHA256') and
            result.get('discoveredIdentifiers') == selection.get('discoveredIdentifiers'), 'native result binding')
    selected, completed = selection.get('selected'), result.get('completedSlices')
    require(isinstance(selected, list) and isinstance(completed, list) and
            len(selected) == len(completed), 'complete selected slices')
    # The workflow emits these literal boundaries only around actual execution.
    boundaries = re.findall(r'(?:^|\n)(?:\d{4}-\d\d-\d\dT\S+ )?'
                            r'(BEGIN|END) native suite slice ([^\r\n]+)', log)
    require(len(boundaries) == 2 * len(selected), 'complete unique native boundaries')
    slices = re.findall(r'(?:^|\n)(?:\d{4}-\d\d-\d\dT\S+ )?'
                        r'BEGIN native suite slice ([^\r\n]+)\r?\n(.*?)'
                        r'(?:\d{4}-\d\d-\d\dT\S+ )?END native suite slice ([^\r\n]+)',
                        log, re.DOTALL)
    require(len(slices) == len(selected), 'closed native slices')
    counts = dict(executedTests=0, explicitlySkippedTests=0)
    for selected, receipt, (begin, body, end) in zip(selected, completed, slices):
        require(isinstance(selected, dict) and isinstance(receipt, dict), 'slice objects')
        library, suite = selected.get('library'), selected.get('suite')
        key = f'{library}:{suite}'
        require(library in ('xctest', 'swift-testing') and
                begin == f'{key}, bank {bank}/{BANKS}' and end == key, 'ordered native execution')
        identifiers = selected.get('identifiers')
        require(isinstance(identifiers, list) and identifiers and
                receipt.get('identifiers') == identifiers and
                receipt.get('selector') == selected.get('selector') and
                receipt.get('library') == library and receipt.get('suite') == suite and
                type(receipt.get('discovered')) is int and receipt['discovered'] == len(identifiers) and
                type(receipt.get('exitCode')) is int and receipt['exitCode'] == 0, 'exact executed selection')
        measured = summarize_log(body, library, len(identifiers), identifiers)
        for name in ('reportedTests', 'explicitlySkippedTests', 'executedTests'):
            require(type(receipt.get(name)) is int and receipt[name] == measured[name], 'measured native count: ' + name)
        require(re.fullmatch('[0-9a-f]{64}', str(receipt.get('logSHA256'))), 'native slice digest')
        # Actions timestamps/line endings transform stdout. Do not claim to have
        # recomputed Tee-Object file hashes from the transformed job log.
        for name in counts:
            counts[name] += measured[name]
    return selection, counts


def required_steps(bank):
    return ['Check out source', 'Install Swift 6.3.3', 'Show toolchain',
            'Set up Python for complete Windows banks', 'Verify bank planner before compiling tests',
            'Verify sealed JSON checkout bytes', 'Build diagnostic test executable',
            'Execute every discovered test slice in assigned Windows bank'] + (
                ['Build release app in full Windows validation'] if bank == 0 else [])


def verify(bundle, source, logs):
    require(isinstance(source, str) and re.fullmatch('[0-9a-f]{40}', source), 'exact source required')
    require(isinstance(bundle, dict) and set(bundle) == {'schema', 'source', 'run', 'workflow', 'banks'} and
            bundle['schema'] == SCHEMA and bundle['source'] == source, 'bundle source/scope')
    run, workflow = bundle['run'], bundle['workflow']
    require(type(run.get('id')) is int and run['id'] > 0 and
            type(run.get('run_attempt')) is int and run['run_attempt'] > 0 and
            run.get('head_sha') == source and run.get('status') == 'completed' and
            run.get('conclusion') == 'success' and run.get('event') == 'workflow_dispatch' and
            run.get('repository', {}).get('full_name') == 'randomactions/auto-techno', 'terminal exact-source run')
    require(type(workflow.get('id')) is int and workflow['id'] == run.get('workflow_id') and
            workflow.get('path') == WORKFLOW and workflow.get('state') == 'active', 'native workflow')
    require(isinstance(bundle['banks'], list) and len(bundle['banks']) == BANKS and
            set(logs) == set(range(BANKS)), 'all eight banks and original logs required')
    seen, jobs, plans, discovery = set(), set(), {}, {'xctest': [], 'swift-testing': []}
    counts = dict(executedTests=0, explicitlySkippedTests=0)
    for row in bundle['banks']:
        require(isinstance(row, dict) and set(row) == {'bank', 'job', 'logSHA256'}, 'bank fields')
        bank, job = row['bank'], row['job']
        require(type(bank) is int and 0 <= bank < BANKS and bank not in seen, 'unique bank')
        seen.add(bank)
        require(type(job.get('id')) is int and job['id'] > 0 and job['id'] not in jobs and
                job.get('run_id') == run['id'] and job.get('run_attempt') == run['run_attempt'] and
                job.get('head_sha') == source and job.get('status') == 'completed' and
                job.get('conclusion') == 'success' and
                job.get('name') == f'Windows x64 source validation (bank-{bank})', 'successful exact bank job')
        jobs.add(job['id'])
        require(isinstance(job.get('steps'), list), 'native steps')
        for name in required_steps(bank):
            matches = [s for s in job['steps'] if isinstance(s, dict) and s.get('name') == name]
            require(len(matches) == 1 and matches[0].get('status') == 'completed' and
                    matches[0].get('conclusion') == 'success', 'successful native step: ' + name)
        raw = logs[bank]
        require(sha(raw) == row['logSHA256'], 'original job log digest')
        selection, measured = parse_bank(raw, source, bank)
        plans[bank] = selection
        for selected in selection['selected']:
            discovery[selected['library']].extend(selected['identifiers'])
        for name in counts:
            counts[name] += measured[name]
    # Rebuild the complete partition from the union, checking duplicate IDs,
    # omitted slices, selectors, shared discovery digest and every assignment.
    discovery = {key: '\n'.join(sorted(values)) for key, values in discovery.items()}
    for bank in range(BANKS):
        require(plans[bank] == plan(discovery, bank, BANKS), 'recomputed exhaustive discovery partition')
    return dict(schema=SCHEMA, source=source, run=run['id'], banks=BANKS,
                discoveredTests=sum(counts.values()), **counts,
                completeNativeSuitesAndReleaseBuild=True, originalJobLogsVerified=True,
                suiteFileHashesIndependentlyVerified=False, runtimeQualification=False,
                automatedQualityQualification=False, item39Complete=False)


def collect(run_id, source, output):
    require(type(run_id) is int and run_id > 0 and re.fullmatch('[0-9a-f]{40}', source), 'run and source')
    require(not output.exists(), 'fresh output directory required')
    def api(suffix, raw=False):
        value = subprocess.check_output(['gh', 'api', 'repos/randomactions/auto-techno/actions/' + suffix], timeout=120)
        require(len(value) <= MAX_LOG_BYTES, 'bounded response')
        return value if raw else strict_json(value)
    run = api(f'runs/{run_id}')
    require(run.get('head_sha') == source and run.get('status') == 'completed' and
            run.get('conclusion') == 'success', 'terminal exact-source success required')
    workflow = api(f'workflows/{run["workflow_id"]}')
    listing = api(f'runs/{run_id}/jobs?per_page=100&filter=latest')
    require(type(listing.get('total_count')) is int and 0 < listing['total_count'] <= 100 and
            len(listing.get('jobs', [])) == listing['total_count'], 'complete job listing')
    jobs = [j for j in listing['jobs'] if JOB_NAME.fullmatch(j.get('name', ''))]
    require(len(jobs) == BANKS, 'all eight native jobs required')
    rows, logs = [], {}
    for job in jobs:
        bank = int(JOB_NAME.fullmatch(job['name'])[1])
        require(bank not in logs, 'unique collected bank')
        logs[bank] = api(f'jobs/{job["id"]}/logs', raw=True)
        rows.append(dict(bank=bank, job=job, logSHA256=sha(logs[bank])))
    bundle = dict(schema=SCHEMA, source=source, run=run, workflow=workflow, banks=rows)
    result = verify(bundle, source, logs)
    refreshed = api(f'runs/{run_id}')
    require(all(refreshed.get(k) == run.get(k) for k in
                ('id', 'head_sha', 'status', 'conclusion', 'run_attempt', 'workflow_id')), 'run changed during collection')
    output.mkdir(parents=True, exist_ok=False)
    for bank, raw in logs.items():
        (output / f'bank-{bank}.log.gz').write_bytes(gzip.compress(raw, mtime=0))
    for name, value in [('receipt', bundle), ('verification', result)]:
        (output / f'{name}.json').write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', type=int, required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(collect(args.run, args.source, args.output), sort_keys=True))
