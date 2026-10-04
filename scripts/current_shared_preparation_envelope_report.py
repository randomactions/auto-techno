#!/usr/bin/env python3
"""Strict descriptive verifier for complete current shared-owner observations.

This report never supplies typed calibration, activation, capacity or output
qualification. PCM identity is checked by the frozen Swift producer; this tool
checks its independently bound metadata, matrix and state-link claims.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re
import sys
from typing import Any
import performance_envelope_report as common

SCHEMA = 'autotechno-current-shared-preparation-envelope-observations.v1'
REPORT_SCHEMA = 'autotechno-current-shared-preparation-envelope-report.v1'
MAX_BYTES = 128 * 1024 * 1024
FLAGS = {'capacityQualification', 'runtimeActivation', 'minMaxTwoPassRebuildQualification',
         'lifecycleQualification', 'callbackOrPhysicalOutputQualification'}
IDENTITY = {'gitHead', 'sourceFingerprint', 'contractBaselineFingerprint', 'corpusSha256',
            'engineVersion', 'primaryPolicyVersion', 'longHorizonPolicyVersion'}
TOP = IDENTITY | FLAGS | {'schema', 'buildConfiguration', 'clock', 'memory', 'machine',
    'trialPolicy', 'measurementScope', 'phaseTimingAvailability', 'referenceStorageScope',
    'maximumReservedNumericBytes', 'executionComplete', 'observations', 'producerObservations'}
BASE = {'caseId', 'routeId', 'sampleRate', 'channelCount', 'trialIndex', 'isWarmup', 'outcome'}
TIMED = {'rootSeed', 'checkpoint', 'sourcePhraseIndex', 'replayFingerprint',
         'completePreparationNanoseconds', 'processHighWaterBytesBefore',
         'processHighWaterBytesAfter', 'referenceNodes'}
PRODUCT = {'exactJourneyIdentityMatch', 'ownershipValid', 'audioDurationNanoseconds',
           'nodes', 'qualityOutcome', 'qualityReasonCodes'}
BUDGET = {'reservedPeakWorkingBytes', 'retainedNumericBytes', 'reservedSourceCount',
          'reservedMaximumRenderPassCount'}
FAILURE = {'failureStage', 'failureCode', 'failureDetails'}
NODE_TEXT = {'sampleHash', 'planFingerprint', 'candidateEvaluationFingerprint', 'replayFingerprint',
    'incomingCoreFingerprint', 'incomingRenderFingerprint', 'incomingGraphFingerprint',
    'incomingLongHorizonFingerprint', 'outgoingCoreFingerprint', 'outgoingRenderFingerprint',
    'outgoingGraphFingerprint', 'outgoingLongHorizonFingerprint'}
NODE = NODE_TEXT | {'phraseIndex', 'barCount', 'frameCount', 'renderPassCount',
                   'preparedOriginMatches', 'commitEligible', 'requiresQualifiedSuccessor'}
Error = common.PerformanceEnvelopeError

def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)

def swift_string(root: Path, relative: str, name: str) -> str:
    matches = re.findall(r'package\s+static\s+let\s+' + re.escape(name) + r'(?:\s*:\s*String\?)?\s*=\s*"([^"]+)"',
                         (root / relative).read_text())
    require(len(matches) == 1, f'ambiguous/missing or unqualified Swift identity {relative}:{name}')
    return matches[0]

def expected_identity(root: Path) -> dict[str, str]:
    baseline = common.load_json(root / 'docs/ROADMAP_EXECUTION_BASELINE.json', 'contract')
    primary_file = 'Sources/AutoTechnoDSP/ProfessionalQualityPrimaryArtifacts.swift'
    long_file = 'Sources/AutoTechnoDSP/LongHorizonProfessionalPolicyArtifacts.swift'
    primary_family = swift_string(root, 'Sources/AutoTechnoDSP/ProfessionalQualityPrimaryEvaluator.swift', 'policyFamilyVersion')
    long_family = swift_string(root, 'Sources/AutoTechnoDSP/LongHorizonProfessionalPolicy.swift', 'policyFamilyVersion')
    def policy(family: str, file: str, names: list[str]) -> str:
        fps = [swift_string(root, file, name) for name in names]
        return '.'.join([family, 'profile-' + fps[0], 'adversarial-' + fps[1], 'holdout-' + fps[2]])
    require(not common.git_output(root, ['status', '--porcelain', '--untracked-files=all']).strip(),
            'current envelope verification requires clean frozen source')
    return {
        'gitHead': common.git_output(root, ['rev-parse', 'HEAD']).strip(),
        'sourceFingerprint': common.source_fingerprint(root),
        'contractBaselineFingerprint': common.text(baseline.get('snapshotFingerprint'), 'contract fingerprint'),
        'corpusSha256': common.sha256_path(root / 'docs/BASELINE_CORPUS.json'),
        'engineVersion': swift_string(root, 'Sources/AutoTechnoCore/QualityQualification.swift', 'engineVersion'),
        'primaryPolicyVersion': policy(primary_family, primary_file, ['expectedProfileFingerprint',
            'expectedAdversarialSuiteFingerprint', 'expectedHoldoutQualificationFingerprint']),
        'longHorizonPolicyVersion': policy(long_family, long_file, ['expectedProfileFingerprint',
            'expectedAdversarialFingerprint', 'expectedHoldoutFingerprint']),
    }

def validate_nodes(value: Any, rate: int, location: str, admitted: bool) -> list[dict]:
    nodes = common.sequence(value, location)
    require(bool(nodes), location + ' is empty')
    for index, raw in enumerate(nodes):
        node = common.mapping(raw, f'{location}[{index}]')
        common.exact_keys(node, NODE, location)
        for field in NODE_TEXT:
            common.text(node[field], location + '.' + field)
        phrase = common.integer(node['phraseIndex'], location + '.phraseIndex')
        bars = common.integer(node['barCount'], location + '.barCount', 1)
        require(bars <= 16, location + ' exceeds phrase-bar bound')
        frames = common.integer(node['frameCount'], location + '.frameCount', 1)
        require(frames == bars * round(240 / 130 * rate), location + ' has false native frame geometry')
        passes = common.integer(node['renderPassCount'], location + '.renderPassCount', 1)
        require(passes <= 2, location + ' exceeds render-pass bound')
        for field in ['preparedOriginMatches', 'commitEligible', 'requiresQualifiedSuccessor']:
            common.boolean(node[field], location + '.' + field)
        if admitted:
            require(node['preparedOriginMatches'] and node['commitEligible'], location + ' has ineligible origin/product')
            require(node['requiresQualifiedSuccessor'] == (index < len(nodes) - 1), location + ' has incomplete child ownership')
        if index:
            previous = nodes[index - 1]
            require(phrase == previous['phraseIndex'] + 1, location + ' skips a child phrase')
            for kind in ['Core', 'Render', 'Graph', 'LongHorizon']:
                require(previous['outgoing' + kind + 'Fingerprint'] == node['incoming' + kind + 'Fingerprint'],
                        location + ' has foreign ' + kind + ' continuation')
    return nodes

def validate_details(value: Any) -> None:
    details = common.sequence(value, 'failureDetails')
    require(len(details) <= 24 and all(isinstance(item, str) for item in details), 'unbounded/non-string failure details')
    require(len(set(details)) == len(details), 'duplicate failure details')

def validate(raw: dict, corpus: dict, expected: dict) -> dict:
    common.exact_keys(raw, TOP, 'raw')
    require(raw['schema'] == SCHEMA, 'unsupported current shared-envelope schema')
    require(raw['executionComplete'] is True, 'current capture is incomplete')
    require(raw['buildConfiguration'] == 'release', 'current capture is not Release')
    common.integer(raw['maximumReservedNumericBytes'], 'maximum numeric bytes', 1)
    require(raw['maximumReservedNumericBytes'] == MAX_BYTES and not isinstance(raw['maximumReservedNumericBytes'], bool), 'numeric reservation bound changed')
    for flag in FLAGS:
        require(raw[flag] is False, 'descriptive envelope cannot claim ' + flag)
    for field in IDENTITY:
        require(common.text(raw[field], field) == expected[field], 'stale/foreign ' + field)
    require(raw['clock'] == {'kind': 'dispatch-uptime-monotonic', 'unit': 'nanoseconds', 'samplingLocation': 'detached-test-process'}, 'foreign clock')
    require(raw['memory'] == {'kind': 'getrusage-ru_maxrss', 'unit': 'bytes', 'scope': 'whole-test-process-high-water', 'attribution': 'monotonic-process-bound-not-phase-exclusive'}, 'foreign memory attribution')
    common.validate_machine(raw['machine'])
    require(raw['measurementScope'] == 'all-baseline-checkpoints-through-current-shared-owner', 'foreign measurement scope')
    require(raw['phaseTimingAvailability'] == 'not-instrumented-shared-owner', 'invented phase timings')
    require(raw['referenceStorageScope'] == 'exact-journey-product-held-outside-timed-preparation', 'false reference-storage attribution')
    require(corpus.get('schema') == 'autotechno-baseline-corpus.v1' and corpus.get('corpusVersion') == 1, 'unsupported corpus')
    cases = {item['id']: item for item in corpus['cases']}
    routes = {item['id']: item for item in corpus['routes']}
    require(len(cases) == len(corpus['cases']) == 7 and len(routes) == len(corpus['routes']) == 2, 'corpus membership changed')
    require(sorted(item['sampleRate'] for item in routes.values()) == [44100, 48000] and all(item['channelCount'] == 2 for item in routes.values()), 'native route matrix changed')
    require(raw['trialPolicy'] == {'warmupCount': 1, 'timedTrialCount': 3, 'caseIds': [item['id'] for item in corpus['cases']], 'sampleRates': [44100, 48000], 'ordering': 'frozen-corpus-case-route-trial', 'warmupObservationsRetained': True}, 'trial policy changed')
    for field in ['warmupCount', 'timedTrialCount']:
        common.integer(raw['trialPolicy'][field], 'trialPolicy.' + field, 1)
    for rate in raw['trialPolicy']['sampleRates']: common.integer(rate, 'trialPolicy sample rate', 1)
    expected_slots = [(case['id'], route['id'], trial) for case in corpus['cases'] for route in corpus['routes'] for trial in [-1, 0, 1, 2]]
    rows = common.sequence(raw['observations'], 'observations')
    require([(row.get('caseId'), row.get('routeId'), row.get('trialIndex')) for row in rows] == expected_slots, 'missing/duplicate/reordered matrix slots')
    prior_high_water = 0
    contexts: dict[tuple[str, str], Any] = {}
    accepted = []
    refusals = []
    for row in rows:
        outcome = common.text(row.get('outcome'), 'outcome')
        require(outcome in {'target-journey-unavailable', 'preparation-refused', 'calibrated-rejection', 'commit-eligible'}, 'invalid/stopped capture outcome')
        slot = (row['caseId'], row['routeId'], row['trialIndex'])
        route = routes[row['routeId']]; case = cases[row['caseId']]
        context_key = (row['caseId'], row['routeId'])
        context_value = 'target-unavailable' if outcome == 'target-journey-unavailable' else [row.get('sourcePhraseIndex'), row.get('replayFingerprint'), row.get('referenceNodes')]
        if context_key in contexts:
            require(contexts[context_key] == context_value, 'journey reference changed across trials')
        else: contexts[context_key] = context_value
        trial = common.integer(row['trialIndex'] + 1, 'trialIndex shifted') - 1
        require(not isinstance(row['trialIndex'], bool) and row['isWarmup'] is (trial < 0), 'warmup/trial identity changed')
        common.integer(row['sampleRate'], 'row sample rate', 1)
        common.integer(row['channelCount'], 'row channels', 1)
        require(row['sampleRate'] == route['sampleRate'] and row['channelCount'] == 2, 'row route changed')
        if outcome == 'target-journey-unavailable':
            require(set(row) in [BASE | {'failureCode'}, BASE | FAILURE], 'unknown target-refusal fields')
            common.text(row.get('failureCode'), 'failureCode')
            if 'failureStage' in row:
                common.text(row['failureStage'], 'failureStage'); validate_details(row['failureDetails'])
            refusals.append({'slot': list(slot), 'outcome': outcome, 'code': row['failureCode']})
            continue
        common.integer(row['rootSeed'], 'root seed')
        require(row['rootSeed'] <= 2**64 - 1, 'root seed exceeds UInt64')
        require(row['rootSeed'] == case['rootSeed'] and not isinstance(row['rootSeed'], bool) and row['checkpoint'] == case['checkpoint'], 'row corpus identity changed')
        common.integer(row['sourcePhraseIndex'], 'sourcePhraseIndex')
        common.text(row['replayFingerprint'], 'replayFingerprint')
        common.integer(row['completePreparationNanoseconds'], 'completePreparationNanoseconds', 1)
        before = common.integer(row['processHighWaterBytesBefore'], 'high-water before', 1)
        after = common.integer(row['processHighWaterBytesAfter'], 'high-water after', 1)
        require(after >= before >= prior_high_water, 'whole-process high-water decreased')
        prior_high_water = after
        reference = validate_nodes(row['referenceNodes'], route['sampleRate'], 'referenceNodes', True)
        require(reference[0]['phraseIndex'] == row['sourcePhraseIndex'] and reference[0]['replayFingerprint'] == row['replayFingerprint'], 'reference origin changed')
        if outcome == 'preparation-refused':
            common.exact_keys(row, BASE | TIMED | FAILURE, 'preparation refusal')
            common.text(row['failureStage'], 'failureStage'); common.text(row['failureCode'], 'failureCode')
            validate_details(row['failureDetails'])
            refusals.append({'slot': list(slot), 'outcome': outcome, 'code': row['failureCode']})
            continue
        present_budget = set(row) & BUDGET
        require(present_budget in [set(), BUDGET], 'partial reservation metadata')
        common.exact_keys(row, BASE | TIMED | PRODUCT | present_budget, 'product row')
        common.text(row['qualityOutcome'], 'qualityOutcome')
        reasons = common.sequence(row['qualityReasonCodes'], 'qualityReasonCodes')
        for reason in reasons: common.text(reason, 'quality reason')
        common.boolean(row['exactJourneyIdentityMatch'], 'exact identity')
        common.boolean(row['ownershipValid'], 'ownershipValid')
        nodes = validate_nodes(row['nodes'], route['sampleRate'], 'nodes', outcome == 'commit-eligible')
        duration = common.integer(row['audioDurationNanoseconds'], 'audio duration', 1)
        require(abs(duration - int(nodes[0]['frameCount'] / route['sampleRate'] * 1e9)) <= 1, 'audio duration changed')
        if present_budget:
            peak = common.integer(row['reservedPeakWorkingBytes'], 'reserved peak', 1)
            retained = common.integer(row['retainedNumericBytes'], 'retained numeric bytes')
            count = common.integer(row['reservedSourceCount'], 'reserved source count', 1)
            passes = common.integer(row['reservedMaximumRenderPassCount'], 'reserved maximum passes', 1)
            require(retained <= peak <= MAX_BYTES and count == len(nodes) and max(node['renderPassCount'] for node in nodes) <= passes <= 2, 'invalid aggregate reservation')
        if outcome == 'commit-eligible':
            require(present_budget == BUDGET and row['exactJourneyIdentityMatch'] is True and row['ownershipValid'] is True and nodes == reference, 'admitted shared product differs from exact journey')
            accepted.append(row)
        else:
            refusals.append({'slot': list(slot), 'outcome': outcome, 'codes': reasons})
    producers = common.sequence(raw['producerObservations'], 'producerObservations')
    expected_producer = [(frames, trial) for frames in [128, 256, 512, 1024] for trial in range(9)]
    require([(row.get('frameCount'), row.get('trialIndex')) for row in producers] == expected_producer, 'producer matrix changed')
    for row in producers:
        common.exact_keys(row, common.PRODUCER_KEYS, 'producer')
        for field in ['frameCount', 'operationCount']: common.integer(row[field], 'producer.' + field, 1)
        for field in ['trialIndex', 'droppedPacketDelta', 'rejectedPacketDelta']: common.integer(row[field], 'producer.' + field)
        require(row['id'] == f"native-stereo-{row['frameCount']}--trial-{row['trialIndex']}", 'producer identity changed')
        require(row['operationCount'] == 128 and row['exactRoundTrip'] is True and row['droppedPacketDelta'] == 0 and row['rejectedPacketDelta'] == 0, 'producer round trip failed')
        common.integer(row['batchNanoseconds'], 'producer duration', 1)
    timed = [row for row in accepted if row['trialIndex'] >= 0]
    body = {'schema': REPORT_SCHEMA, **expected, **{flag: False for flag in FLAGS},
            'scope': raw['measurementScope'], 'requiredMatrixPassed': not refusals,
            'observationCount': len(rows), 'timedAcceptedCount': len(timed), 'refusals': refusals,
            'status': 'descriptive-shared-envelope-observed' if not refusals else 'descriptive-shared-envelope-with-refusals',
            'phaseTimingAvailability': raw['phaseTimingAvailability'],
            'memoryAttribution': raw['memory'], 'referenceStorageScope': raw['referenceStorageScope'],
            'routes': []}
    for route in routes.values():
        selected = [row for row in timed if row['routeId'] == route['id']]
        body['routes'].append({'routeId': route['id'], 'acceptedTimedCount': len(selected),
            'completePreparationNanoseconds': common.timing_summary(row['completePreparationNanoseconds'] for row in selected) if selected else None,
            'reservedPeakWorkingBytesMaximum': max((row['reservedPeakWorkingBytes'] for row in selected), default=None),
            'wholeProcessHighWaterBytesMaximum': max((row['processHighWaterBytesAfter'] for row in selected), default=None)})
    body['reportFingerprint'] = common.sha256_bytes(common.canonical_bytes(body))
    return body

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--raw', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    try:
        raw = common.load_json(args.raw, 'current shared observations')
        corpus = common.load_json(root / 'docs/BASELINE_CORPUS.json', 'corpus')
        report = validate(raw, corpus, expected_identity(root))
        report['rawSha256'] = common.sha256_path(args.raw)
        # Include the exact input hash in the deterministic report seal.
        report.pop('reportFingerprint')
        report['reportFingerprint'] = common.sha256_bytes(common.canonical_bytes(report))
        if args.output:
            args.output.write_bytes(common.canonical_bytes(report) + b'\n')
        print(json.dumps({'status': report['status'], 'requiredMatrixPassed': report['requiredMatrixPassed'],
                          'reportFingerprint': report['reportFingerprint'], 'capacityQualification': False}))
        return 0 if report['requiredMatrixPassed'] else 1
    except (Error, OSError, KeyError, TypeError, ValueError) as exc:
        print(f'current shared envelope: {exc}', file=sys.stderr)
        return 2

if __name__ == '__main__':
    raise SystemExit(main())
