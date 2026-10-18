#!/usr/bin/env python3
"""Read AT-0039 claim reports without conflating parsing and qualification.

Pure report diagnosis requires no platform run and grants no execution authority.
The complete-bank mode retains all sixteen native banks and separately checks
the existing required claim products. Neither mode qualifies the complete item,
resources, runtime, preferred sound or perceptual harm, and neither runs a producer.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import zlib

import hosted_macos_verification as hosted
import at0039_claim_readers as claims

require = hosted.require
RATES = (44100, 48000)
FAMILIES = {'sine': 'development', 'triangle': 'held-out-family',
            'asymmetric-pulse': 'held-out-family'}
SCENARIOS = {
    'intentional-overlap': (1, 4, 16, False, False),
    'phase-cancellation': (1, 0, 16, True, False),
    'half-amplitude': (0.25, 2.25, 16, False, False),
    'double-amplitude': (0.25, 9, 16, False, False),
    'deleted-required-companion': (0, 1, 0, False, True),
    'intentional-absence': (0, 1, 0, False, False),
}
MASKING = 'autotechno-algorithmic-masking-component.v1'
FILTER = 'autotechno-masking-filter-response.v1'
TESTS = {
    MASKING: ('algorithmicFaultBenchmark()',
              'Algorithmic masking benchmark preserves independent fault evidence'),
    FILTER: ('algorithmicFilterResponse()',
             'Masking filters agree with independent closed-form causal responses'),
}
OWNER = 'AutoTechnoCoreTests.SpectrumMaskingAnalyzerTests/'
SCOPE = 'constructed-linear-relations-and-declared-causal-filter-errors-only'
LIMITATIONS = ['score-to-render-fidelity', 'shared-nonlinear-mix-damage',
               'perceptual-masking-harm', 'musical-preference', 'groove-quality',
               'general-frequency-response-calibration', 'complete-at0039-acceptance']


def keys(value, expected, label):
    require(type(value) is dict and set(value) == set(expected), label + ' fields')


def number(value, label, *, lower=None):
    require(type(value) in (int, float) and math.isfinite(value), label + ' finite number')
    require(lower is None or value >= lower, label + ' lower bound')
    return value


def integer(value, expected, label):
    require(type(value) is int and value == expected, label + ' exact integer')


def header(report, schema, scope, uncertainty, unavailable, extra=()):
    keys(report, {'schema', 'scope', 'uncertainty', 'unavailable', 'rows', 'failures'} | set(extra), schema)
    require(report['schema'] == schema and report['scope'] == scope and
            report['uncertainty'] == uncertainty, 'original benchmark claim boundary')
    require(report['unavailable'] == unavailable, 'unavailable dimensions must remain explicit')
    require(report['failures'] == [], 'native benchmark failures remain failures')
    require(type(report['rows']) is list, 'actual benchmark rows required')


def masking(report):
    header(report, MASKING, 'constructed-linear-signals-no-score-or-perceptual-qualification',
           'not-estimated-fixed-families-not-random-independent-listeners',
           ['score-to-render-fidelity', 'shared-nonlinear-mix-damage',
            'perceptual-masking-harm', 'musical-preference', 'groove-quality'], {'summaries'})
    expected = [(rate, family, scenario) for rate in RATES for family in FAMILIES
                for scenario in SCENARIOS]
    actual = []
    for row in report['rows']:
        keys(row, {'family', 'split', 'sampleRate', 'scenario', 'expectedOverlap',
                   'observedOverlap', 'activePairWindows', 'absoluteError',
                   'expectedLinearSumEnergyRatio', 'linearSumEnergyRatio',
                   'exactCancellation', 'missingRequiredCompanion', 'replayExact'}, 'linear row')
        rate, family, scenario = row['sampleRate'], row['family'], row['scenario']
        require(type(rate) is int and rate in RATES and type(family) is str and family in FAMILIES and
                type(scenario) is str and scenario in SCENARIOS, 'frozen source family/rate/scenario')
        require(row['split'] == FAMILIES[family], 'development/held-out family split')
        actual.append((rate, family, scenario))
        overlap, ratio, active, cancelled, missing = SCENARIOS[scenario]
        for field in ('expectedOverlap', 'observedOverlap', 'absoluteError',
                      'expectedLinearSumEnergyRatio', 'linearSumEnergyRatio'):
            number(row[field], field, lower=0)
        require(row['expectedOverlap'] == row['observedOverlap'] == overlap and
                row['absoluteError'] == 0, 'exact binary-gain overlap relation')
        integer(row['activePairWindows'], active, 'active pair windows')
        require(row['expectedLinearSumEnergyRatio'] == ratio, 'independent linear energy oracle')
        # The existing native oracle's gamma(8N) forward-error envelope; this is
        # a numerical bound, never a fitted or perceptual acceptance threshold.
        nu = 8 * (rate // 4) * sys.float_info.epsilon
        bound = nu / (1 - nu) * max(1, ratio)
        require(abs(row['linearSumEnergyRatio'] - ratio) <= bound, 'linear energy numerical bound')
        require(row['exactCancellation'] is cancelled and
                row['missingRequiredCompanion'] is missing and row['replayExact'] is True,
                'separate cancellation/required-role/replay witnesses')
    require(actual == expected, 'all 36 ordered paired rows without duplication or pooling')
    summaries = report['summaries']
    require(type(summaries) is list and len(summaries) == 6, 'all six family/rate summaries')
    for row, (rate, family) in zip(summaries, [(r, f) for r in RATES for f in FAMILIES]):
        keys(row, {'family', 'split', 'sampleRate', 'rowCount', 'meanAbsoluteError',
                   'rootMeanSquareError', 'meanSignedError'}, 'linear summary')
        require(row['family'] == family and row['split'] == FAMILIES[family], 'summary source family')
        integer(row['sampleRate'], rate, 'summary rate')
        integer(row['rowCount'], 6, 'summary paired row count')
        # Every underlying signed overlap error was independently checked as 0.
        for field in ('meanAbsoluteError', 'rootMeanSquareError', 'meanSignedError'):
            require(number(row[field], field) == 0, 'recomputed per-family continuous error')
    return {'rows': 36, 'sourceFamilies': 3, 'pairedRates': list(RATES),
            'summaries': 6, 'cancellationWitnesses': 6, 'missingCompanionWitnesses': 6}


def error_summary(row, count, bound):
    keys(row, {'count', 'meanAbsoluteError', 'rootMeanSquareError',
               'meanSignedError', 'maximumAbsoluteError'}, 'reported error summary')
    integer(row['count'], count, 'reported error observation count')
    mean = number(row['meanSignedError'], 'signed error')
    mae = number(row['meanAbsoluteError'], 'absolute error', lower=0)
    rms = number(row['rootMeanSquareError'], 'square error', lower=0)
    maximum = number(row['maximumAbsoluteError'], 'maximum error', lower=0)
    require(maximum <= bound, 'declared analytic forward-error bound')
    # Permit only arithmetic roundoff when checking inequalities between the
    # producer's aggregated statistics. The actual maximum bound above is exact.
    rounding = 16 * sys.float_info.epsilon * maximum
    require(abs(mean) <= mae + rounding and mae <= rms + rounding and
            rms <= maximum + rounding, 'inconsistent reported error statistics')


def filters(report):
    header(report, FILTER, 'declared-causal-filter-transfer-and-window-energy-only',
           'fixed-constructions-no-population-interval-or-fitted-classifier',
           ['perceptual-masking-harm', 'score-to-render-fidelity',
            'nonlinear-full-mix-quality', 'general-frequency-response-calibration'])
    families = {'step': 'development', 'impulse': 'held-out-construction',
                'alternating': 'held-out-construction'}
    expected = [(rate, family, band) for rate in RATES for family in families
                for band in ('sub', 'low-mid', 'mid', 'high')]
    actual = []
    bounds = []
    for operations in (32, 128):
        nu = operations * (4096 + 1) * sys.float_info.epsilon
        bounds.append(nu / (1 - nu))
    for row in report['rows']:
        keys(row, {'family', 'split', 'sampleRate', 'band', 'samples', 'windowEnergies',
                   'sampleAbsoluteErrorBound', 'energyAbsoluteErrorBound'}, 'causal filter row')
        rate, family = row['sampleRate'], row['family']
        require(type(rate) is int and rate in RATES and type(family) is str and family in families and
                row['split'] == families[family], 'independent causal construction split')
        actual.append((rate, family, row['band']))
        for field, bound in zip(('sampleAbsoluteErrorBound', 'energyAbsoluteErrorBound'), bounds):
            require(number(row[field], field, lower=0) == bound, 'unchanged derived numerical envelope')
        error_summary(row['samples'], 4096, bounds[0])
        error_summary(row['windowEnergies'], 16, bounds[1])
    require(actual == expected, 'all 24 ordered paired causal construction/band rows')
    return {'rows': 24, 'sourceFamilies': 3, 'pairedRates': list(RATES),
            'sampleErrorsPerRow': 4096, 'windowEnergyErrorsPerRow': 16,
            'reportedErrorStatisticsChecked': True,
            'rawPerSampleErrorsIndependentlyRecomputed': False}


def report_from_native(body, schema):
    return reports_from_native(body,schema,TESTS[schema][1],'Spectrum masking analyzer',1)[0]


def reports_from_native(body, schema, name, suite, count):
    """Reconstruct only a closed report from its original native slice text.

    CI line timestamps and exact declared test/suite lifecycle messages may
    interleave even inside a JSON key. A registered adjacent serial test start
    is also recognized only after this test passes and before its own pass.
    No unknown text is discarded. The whole
    original job remains the evidence; this is not the producer's raw-file hash.
    """
    require(type(body) is str and 0 < len(body) <= hosted.MAX_LOG_BYTES, 'bounded original native body')
    plain = re.sub(r'(?m)^\d{4}-\d\d-\d\dT\S+ ', '', body)
    boundaries = []
    for suffix in ('started\\.', 'passed after [0-9]+(?:\\.[0-9]+)? seconds\\.'):
        found = list(re.finditer(r'[◇✔] Test "' + re.escape(name) + '" ' + suffix, plain))
        require(len(found) == 1,
                'one actual named benchmark start and pass')
        boundaries.append(found[0])
    alternatives = [r'[◇✔] Test "' + re.escape(name) + '"', r'[◇✔] Suite "' + re.escape(suite) + '"']
    pattern = '(?:' + '|'.join(alternatives) + r') (?:started\.|passed after [0-9]+(?:\.[0-9]+)? seconds\.)(?:\r?\n)?'
    # Swift Testing may announce the next serial test before the previous
    # stdout write drains. Only its exact registered same-owner/suite start
    # may be removed, after this test's pass and with its own unique pass.
    # Unknown lifecycle text, concurrent starts, duplicates and failures stay.
    declared=[c for c in claim_cases() if c[2:5]==(name,suite,schema)]
    successors=[]
    if len(declared)==1:
        starts=list(re.finditer(r'◇ Test "([^"\r\n]+)" started\.',plain[boundaries[1].end():]))
        if starts:
            peer=starts[0].group(1)
            siblings=[c for c in claim_cases() if c[0]==declared[0][0] and c[3]==suite and c[2]==peer and c[4]!=schema]
            peer_starts=list(re.finditer(r'◇ Test "'+re.escape(peer)+r'" started\.',plain))
            peer_passes=list(re.finditer(r'✔ Test "'+re.escape(peer)+r'" passed after [0-9]+(?:\.[0-9]+)? seconds\.',plain))
            if (len(siblings)==len(peer_starts)==len(peer_passes)==1
                    and boundaries[1].end()<=peer_starts[0].start()<peer_passes[0].start()):
                successors.append(r'◇ Test "'+re.escape(peer)+r'" started\.(?:\r?\n)?')
    pattern = '(?:'+pattern+'|'+('|'.join(successors) if successors else r'(?!)')+')'
    # Keep a segment-level origin map, rather than normalizing arbitrary text or
    # storing an unbounded integer index for every character of a large log.
    pieces, origins, offset, length = [], [], 0, 0
    for annotation in re.finditer(pattern, plain):
        piece = plain[offset:annotation.start()]
        origins.append((length, length + len(piece), offset))
        pieces.append(piece); length += len(piece); offset = annotation.end()
    pieces.append(plain[offset:]); origins.append((length, length + len(pieces[-1]), offset))
    cleaned = ''.join(pieces)
    markers = list(re.finditer(r'"schema"\s*:\s*"' + re.escape(schema) + r'"', cleaned))
    decoder = json.JSONDecoder(object_pairs_hook=_unique, parse_constant=_invalid)
    require(0<len(markers)<=100, 'bounded original required reports')
    reports=[]
    for marker in markers:
        starts = [m.start() for m in re.finditer(r'\{', cleaned[:marker.start()])]
        require(0 < len(starts) <= 10000, 'bounded original report framing')
        found=False
        for start in reversed(starts):
            try: value,end=decoder.raw_decode(cleaned,start)
            except ValueError: continue
            if (type(value) is dict and value.get('schema')==schema and start<=marker.start()<end
                    and (start==0 or cleaned[start-1] in '\r\n') and (end==len(cleaned) or cleaned[end] in '\r\n')):
                original_start=next(origin+start-first for first,last,origin in origins if first<=start<last)
                if boundaries[0].end()<=original_start<boundaries[1].start():
                    require(end-start<=1024*1024,'bounded benchmark report'); reports.append(value)
                found=True; break
        require(found,'required original benchmark JSON is incomplete or contains foreign text')
    require(len(reports)==count, 'complete unique report count during actual named test')
    return reports


def _unique(items):
    result = {}
    for key, value in items:
        require(key not in result, 'duplicate benchmark JSON key')
        result[key] = value
    return result


def _invalid(value):
    raise ValueError('nonfinite benchmark JSON: ' + value)


def verify(bundle, source, logs):
    platform = hosted.verify(bundle, source, logs)
    result, bindings = {}, {}
    # Partitioning assigns individual identities, so the two tests may be in
    # different banks or share a slice. Do not impose cross-bank order/equality.
    for schema, (method, _) in TESTS.items():
        candidates = [(row['receipt']['bank'], selection) for row in bundle['banks']
                      for selection in row['receipt']['plan']['selected']
                      if selection['library'] == 'swift-testing' and
                      OWNER + method in selection['identifiers']]
        require(len(candidates) == 1, 'one executed occurrence of each required benchmark identity')
        bank, selection = candidates[0]
        text = logs[bank].decode('utf-8')
        markers = list(re.finditer(r'(?m)^(?:\d{4}-\d\d-\d\dT\S+ )?BEGIN native slice ([^\r\n]+)\r?\n', text))
        key = f"{bank}:swift-testing:{selection['suite']}"
        found = [(i, m) for i, m in enumerate(markers) if m.group(1) == key]
        require(len(found) == 1, 'one original benchmark suite boundary')
        index, marker = found[0]
        end = markers[index + 1].start() if index + 1 < len(markers) else text.find('"autotechno-hosted-receipt-chunk.v1"')
        require(end > marker.end(), 'original benchmark suite extent')
        body = text[marker.end():end]
        kind, validator = ('masking', masking) if schema == MASKING else ('causalFilter', filters)
        result[kind] = validator(report_from_native(body, schema))
        bindings[kind] = dict(bank=bank, originalJobLogSHA256=hosted.sha(logs[bank]))
    return dict(schema='autotechno-at0039-linear-benchmark-verification.v1', source=source,
                scope=SCOPE, originalLogBindings=bindings,
                nativeRun=platform['run'], reports=result,
                unavailable=LIMITATIONS, completeNativePlatformVerified=True,
                constructedLinearEvidenceVerified=True, fullAlgorithmicAcceptanceVerified=False,
                runtimeQualification=False, item39Complete=False)


def claim_cases():
    """Existing native identities, rather than a new benchmark producer."""
    rows=[
        ('PCMKickFoundationCollisionAnalyzerTests','algorithmicSourceEnergy()','Closed-form source energy survives gain, truncation and absence controls','PCM kick/foundation collision evidence',claims.ENERGY,1,None),
        ('KickSourceDynamicsTests','algorithmicScoreRenderFaults()','Native score-to-kick binding rejects rendered fault recipes','Source-local kick dynamics',claims.KICK,1,None),
        ('FoundationRhythmicRelationTests','algorithmicFoundationBassFaults()','Native foundation bass binding rejects score-to-PCM faults','Score-owned foundation rhythm',claims.BASS,1,None),
        ('FoundationRhythmicRelationTests','algorithmicFoundationCompanionFaults()','Native rumble and modal companions preserve original score binding','Score-owned foundation rhythm',claims.COMPANION,1,None),
        ('FoundationRhythmicRelationTests','algorithmicFoundationReleaseFaults()','Native source release distinguishes score authority from truncation','Score-owned foundation rhythm',claims.RELEASE,1,None),
        ('FoundationRhythmicRelationTests','algorithmicFullPhraseBassFaults()','Native full-phrase bass faults cannot bind to the original transaction','Score-owned foundation rhythm',claims.FULL_BASS,1,None),
        ('FoundationRhythmicRelationTests','algorithmicFullPhraseCompanionFaults()','Native full-phrase companion faults cannot bind to the original transaction','Score-owned foundation rhythm',claims.FULL_COMPANION,2,None),
        ('FoundationRhythmicRelationTests','algorithmicFullPhraseOutputFrameFaults()','Full-phrase output frame loss cannot bind to the original transaction','Score-owned foundation rhythm',claims.OUTPUT,1,None),
        ('ModalPercussionDSPTests','algorithmicModalContinuationFaults()','AT-0039 canonical modal continuation detects lost voices and lost records','Modal percussion DSP',claims.MODAL,1,None),
        ('SourceTerminalDeclickTests','algorithmicRumbleDurationFaults()','AT-0039 rumble support distinguishes bar clipping from unauthorized shortening','Source-terminal de-clicking',claims.RUMBLE,1,None),
        ('SourceTerminalDeclickTests','algorithmicKickFullPhraseSupport()','Canonical full-phrase kick support reaches candidate admission','Source-terminal de-clicking',claims.KICK_SUPPORT,1,None),
        ('SourceTerminalDeclickTests','algorithmicRumbleFullPhraseSupport()','Canonical full-phrase rumble support reaches candidate admission','Source-terminal de-clicking',claims.RUMBLE_SUPPORT,1,None),
        ('ModalSuccessorReportJoinTests','nativePreparedAdmissionFaultMatrix(rate:)','Prepared admission faults refuse at both native sample rates','Modal successor report join',claims.PREPARED,2,None),
        ('ModalSuccessorReportJoinTests','nativePreparedSuccessorBindingFaultMatrix(rate:)','Actual successor input mismatches refuse native prepared admission','Modal successor report join',claims.SUCCESSOR,2,None),
    ]
    for suffix,behavior in [('Absent','absent'),('Monotone','monotone'),('Point','point'),('Pump','pump'),('SubPulse','subPulse')]:
        rows.append(('FoundationRhythmicRelationTests',f'algorithmicFullPhrase{suffix}BassFaults()',
            f'Full-phrase faults bind {behavior} bass behavior','Score-owned foundation rhythm',claims.FULL_BEHAVIOR,1,behavior))
    return rows


def verify_claims(bundle,source,logs):
    """Join strict claim reads to complete original bank execution, never item completion."""
    result=verify(bundle,source,logs)  # Preserves every existing sixteen-bank gate.
    results={}
    for owner,method,name,suite,schema,count,behavior in claim_cases():
        identity=f'AutoTechnoCoreTests.{owner}/{method}'
        candidates=[(row['receipt']['bank'],selection) for row in bundle['banks']
                    for selection in row['receipt']['plan']['selected']
                    if selection['library']=='swift-testing' and identity in selection['identifiers']]
        require(len(candidates)==1,'one actual occurrence of required claim identity: '+identity)
        bank,selection=candidates[0]; text=logs[bank].decode('utf-8')
        markers=list(re.finditer(r'(?m)^(?:\d{4}-\d\d-\d\dT\S+ )?BEGIN native slice ([^\r\n]+)\r?\n',text))
        key=f"{bank}:swift-testing:{selection['suite']}"
        found=[(i,m) for i,m in enumerate(markers) if m.group(1)==key]
        require(len(found)==1,'one actual original claim slice')
        index,marker=found[0]
        end=markers[index+1].start() if index+1<len(markers) else text.find('"autotechno-hosted-receipt-chunk.v1"')
        require(end>marker.end(),'complete original claim slice')
        reports=reports_from_native(text[marker.end():end],schema,name,suite,count)
        checked=[claims.read(report) for report in reports]
        if schema in (claims.PREPARED,claims.SUCCESSOR):
            require(sorted(report['sampleRate'] for report in reports)==list(RATES),'both actual prepared native rates')
        if schema==claims.FULL_COMPANION:
            require(sorted(report['rows'][0]['companionVoice'] for report in reports)==['rumble','tunedTom'],'both canonical companion products')
        if behavior is not None:
            require(reports[0]['rows'][0]['selectedFoundationBehavior']==behavior,'exact declared behavior identity')
        results[identity]=dict(reportSchema=schema, reports=checked, bank=bank, originalJobLogSHA256=hosted.sha(logs[bank]))
    return dict(schema='autotechno-at0039-native-claim-reports.v1',source=source,
                linear=result, claimReports=results, originalNativeLogReportsVerified=True,
                compiledBuildClosureIndependentlyAuthenticated=False,currentSourceApplicability=False,
                fullAlgorithmicAcceptanceVerified=False,runtimeQualification=False,item39Complete=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--bundle', type=Path)
    mode.add_argument('--report', type=Path, help='Bounded report diagnosis only; authenticates no native execution or source applicability')
    parser.add_argument('--bundle-sha256')
    parser.add_argument('--report-sha256')
    parser.add_argument('--source')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    try:
        if args.report is not None:
            require(args.source is None and args.bundle_sha256 is None, 'report diagnosis cannot claim a qualified source or platform')
            require(type(args.report_sha256) is str and re.fullmatch('[0-9a-f]{64}', args.report_sha256), 'pinned report digest')
            raw = hosted.bounded_regular(args.report, 1024*1024)
            require(hosted.sha(raw)==args.report_sha256, 'input report digest')
            result = read_report(hosted.strict_json(raw))
            require(hosted.bounded_regular(args.report,1024*1024)==raw, 'input changed during report diagnosis')
            result['inputReportSHA256']=args.report_sha256
            print(json.dumps(result,sort_keys=True)); return 0
        require(args.report_sha256 is None and type(args.source) is str, 'exact source is required for platform mode')
        require(re.fullmatch('[0-9a-f]{64}', args.bundle_sha256), 'independently pinned original bundle')
        command = ['git', '-c', 'core.fsmonitor=false', '-C', str(root)]
        require(subprocess.check_output(command + ['rev-parse', 'HEAD'], text=True).strip() == args.source
                and not subprocess.check_output(command + ['status', '--porcelain', '--untracked-files=all']).strip(),
                'clean exact target source required')
        inputs = {}
        paths=['scripts/at0039_algorithmic_verification.py', 'scripts/at0039_claim_readers.py', 'scripts/hosted_macos_verification.py',
                         'scripts/tooling_verification.py', 'scripts/windows_test_plan.py',
                         'Tests/AutoTechnoCoreTests/SpectrumMaskingAnalyzerTests.swift',
                         'Sources/AutoTechnoDSP/SpectrumMaskingAnalyzer.swift']
        paths+=sorted({f'Tests/AutoTechnoCoreTests/{case[0]}.swift' for case in claim_cases()})
        for relative in paths:
            raw = hosted.bounded_regular(root / relative, 2 * 1024 * 1024)
            require(raw == subprocess.check_output(command + ['show', args.source + ':' + relative]),
                    'exact committed verifier/native owner bytes')
            inputs[root / relative] = hosted.sha(raw)
        raw = hosted.bounded_regular(args.bundle, 32 * 1024 * 1024)
        require(hosted.sha(raw) == args.bundle_sha256, 'original bundle digest')
        directory = args.bundle.parent / (args.bundle.stem + '-logs')
        logs, archives = hosted.original_logs(directory)
        result = verify_claims(hosted.strict_json(raw), args.source, logs)
        require(hosted.bounded_regular(args.bundle, 32 * 1024 * 1024) == raw and
                all(hosted.sha(hosted.bounded_regular(p, hosted.MAX_LOG_BYTES)) == d for p, d in archives.items()) and
                all(hosted.sha(hosted.bounded_regular(p, 2 * 1024 * 1024)) == d for p, d in inputs.items()),
                'original or implementation inputs changed during verification')
        require(subprocess.check_output(command + ['rev-parse', 'HEAD'], text=True).strip() == args.source
                and not subprocess.check_output(command + ['status', '--porcelain', '--untracked-files=all']).strip(),
                'target source changed during verification')
        print(json.dumps(result, sort_keys=True))
        return 0
    except (OSError, ValueError, KeyError, TypeError, IndexError, OverflowError, EOFError, zlib.error, subprocess.SubprocessError) as exc:
        print('AT-0039 benchmark verification refused: ' + str(exc), file=sys.stderr)
        return 1


def read_report(report):
    """Validate report semantics only. A passed JSON document is never execution."""
    require(type(report) is dict, 'claim report object')
    if report.get('schema') not in (MASKING,FILTER):
        return claims.read(report)
    result=(masking if report['schema']==MASKING else filters)(report)
    return dict(schema='autotechno-at0039-claim-read.v1', reportSchema=report['schema'], checks=result,
                originalUnavailable=report['unavailable'], nativeExecutionAuthenticated=False,
                currentSourceApplicability=False, fullAlgorithmicAcceptanceVerified=False,
                runtimeQualification=False, item39Complete=False)


if __name__ == '__main__':
    raise SystemExit(main())
