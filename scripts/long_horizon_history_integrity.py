#!/usr/bin/env python3
"""Audit completed shared-journey coverage, timeline and original input bindings.

This reads an existing producer's artifacts. It never starts a capture, imports
one into calibration, reconstructs PCM, or supplies quality/runtime authority.
"""
import argparse
import base64
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import struct
import subprocess
import sys

_IMPLEMENTATION_SHA_AT_IMPORT = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
MAX_JSON_BYTES = 64 * 1024 * 1024
MAX_NUMERIC_BYTES = 128 * 1024 * 1024
OPERATORS = ('maintain', 'rise', 'recover', 'reframe', 'payoff', 'recall')
METRICS = (
    'integrated-loudness-lufs', 'maximum-momentary-loudness-lufs',
    'true-peak-dbtp', 'mean-bar-crest-factor-db', 'spectral-centroid-hz',
    'spectral-centroid-spread-hz', 'transient-density-per-second',
    'positive-spectral-flux-mean', 'low-energy-ratio', 'mid-energy-ratio',
    'high-energy-ratio', 'maximum-masking-overlap', 'mean-wet-to-dry-db',
    'stereo-correlation', 'low-stereo-correlation', 'movement-score',
)
SOURCE_INPUTS = ('Package.swift', 'Sources', 'Tests', 'scripts',
                 'docs/BASELINE_CORPUS.json', 'docs/ROADMAP_EXECUTION_BASELINE.json')
FALSE_CLAIMS = ('archiveImport', 'runtimeActivation', 'fullRuntimeQualification',
                'longHorizonQualification', 'capacityOrOutputQualification')


class HistoryIntegrityError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise HistoryIntegrityError(message)


def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def load(path):
    require(path.is_file() and not path.is_symlink(), 'regular JSON file required')
    require(0 < path.stat().st_size <= MAX_JSON_BYTES, 'bounded JSON file required')
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, 'duplicate JSON key: ' + key)
            result[key] = value
        return result
    def invalid(value):
        raise HistoryIntegrityError('nonfinite JSON number: ' + value)
    def number(value):
        parsed = float(value)
        require(math.isfinite(parsed), 'nonfinite JSON number: ' + value)
        return parsed
    def integer(value):
        parsed = int(value)
        require(abs(parsed) <= sys.float_info.max, 'JSON integer exceeds finite Double domain')
        return parsed
    with path.open('rb') as handle:
        raw = handle.read(MAX_JSON_BYTES + 1)
    require(len(raw) <= MAX_JSON_BYTES, 'bounded JSON file required')
    result = json.loads(raw.decode('utf-8'), object_pairs_hook=pairs, parse_constant=invalid,
                        parse_float=number, parse_int=integer)
    require(isinstance(result, dict), 'JSON object required')
    return result


def uint(value, label, minimum=0):
    require(type(value) is int and minimum <= value <= 2**64 - 1,
            'invalid integer: ' + label)
    return value


def exact_rows(rows, key, expected, label):
    require(isinstance(rows, list) and len(rows) == len(expected), label + ' count')
    names = [row.get(key) if isinstance(row, dict) else None for row in rows]
    require(all(isinstance(name, str) for name in names) and
            len(set(names)) == len(names) and set(names) == set(expected),
            label + ' must contain each identity exactly once')
    return {row[key]: row for row in rows}


def metric_rows(rows, count):
    missing = {}
    for row in exact_rows(rows, 'metric', METRICS, 'metrics').values():
        support = uint(row.get('observationCount'), 'metric observations', 2)
        require(support <= count, 'metric support exceeds its observation count')
        if support < count:
            missing[row['metric']] = count - support
        values = [row.get(name) for name in ('minimum', 'mean', 'maximum')]
        require(all(type(v) in (int, float) and abs(v) <= sys.float_info.max and
                    math.isfinite(v) for v in values),
                'finite metric bounds required')
        low, mean, high = values
        # The native MetricState adds n values, then divides by Double(n).
        # gamma_(n+2) covers summation, count conversion and division roundoff;
        # one scale-relative ulp also covers gradual underflow. Exact zeros
        # need no allowance. A fixed absolute floor would hide tiny bad means.
        roundoff = (support + 2) * (math.ulp(1.0) / 2)
        require(roundoff < 1, 'finite metric roundoff bound unavailable')
        scale = max(abs(low), abs(high))
        epsilon = 0.0 if scale == 0 else scale * (roundoff / (1 - roundoff)) + math.ulp(scale)
        require(math.isfinite(epsilon), 'finite metric roundoff bound unavailable')
        require(low <= high and low - epsilon <= mean <= high + epsilon,
                'inconsistent metric bounds')
    return missing


def verify_history(document, binding, roots, primary_policy, engine, *, effect_schema_version=2):
    require(type(effect_schema_version) is int and effect_schema_version in (2, 3),
            'unsupported bound effect schema')
    require(document.get('schema') == 'autotechno-long-horizon-shared-journey.v2',
            'unsupported journey schema')
    require(all(document.get(key) is False for key in FALSE_CLAIMS),
            'history must retain its unavailable qualification claims')
    require(document.get('inputBindingFingerprint') == binding and
            document.get('primaryPolicyVersion') == primary_policy, 'history origin binding')
    require(document.get('sourceScope') == 'current-shared-preparation-primary-only-bootstrap-with-core-recovery'
            and document.get('memoryScope') == 'numeric-reservation-covers-preparation-chain-not-combined-held-playback'
            and document.get('presentationScope') == 'offline-selected-retained-pcm-no-device-scheduling-proof',
            'original observation and unavailable capacity/output scopes required')
    j = document.get('journey')
    require(isinstance(j, dict), 'journey object required')
    seed = uint(j.get('rootSeed'), 'root seed')
    rate = uint(j.get('sampleRate'), 'sample rate')
    require(seed in roots and rate in (44100, 48000), 'declared native cohort required')
    require(j.get('completedRequestedScope') is True and j.get('endsAtClosedLeaf') is True,
            'completed closed-leaf scope required')
    require(j.get('requestedMinimumBars') == 7800 and
            j.get('requestedPrefixPhraseCount') is None and j.get('failureCode') is None and
            j.get('failureDetails') == [], 'full four-hour scope without failure required')
    phrases = uint(j.get('consumedPhraseCount'), 'consumed phrases', 1)
    s, a, e = (j.get(key) for key in ('signal', 'semantic', 'effects'))
    require(all(isinstance(x, dict) for x in (s, a, e)), 'three evidence families required')
    for x in (s, a, e):
        uint(x.get('schemaVersion'), 'evidence schema version', 1)
        uint(x.get('rootSeed'), 'evidence root seed')
        require(x.get('rootSeed') == seed and x.get('availability') == 'available' and
                x.get('qualificationStatus') == 'unavailable' and
                x.get('qualificationReason') == 'no-calibrated-long-horizon-policy',
                'evidence family identity/availability/qualification')
    require(s.get('schemaVersion') == 3 and s.get('schemaIdentifier') ==
            'autotechno-long-horizon-signal-trajectory-report.v3' and
            s.get('sampleRate') == rate, 'signal schema/route')
    require(a.get('schemaVersion') == 1 and a.get('schemaIdentifier') ==
            'autotechno-long-horizon-semantic.v1' and e.get('schemaVersion') == effect_schema_version and
            e.get('schemaIdentifier') == f'autotechno-long-horizon-effect-dose.v{effect_schema_version}',
            'semantic/effect schemas')
    require(a.get('engineVersion') == engine, 'semantic engine differs from original source')
    bars = uint(s.get('renderedBarCount'), 'rendered bars', 7800)
    require(phrases <= bars <= phrases * 16, 'bounded phrase/bar geometry')
    require(bars == a.get('observedBarCount') == e.get('barCount') == a.get('nextExpectedBar')
            and phrases == s.get('observationCount') == a.get('observedPhraseCount') ==
            e.get('phraseCount') == a.get('nextExpectedPhraseIndex'), 'evidence counters')
    require(all(uint(value, 'origin/omission counter') == 0 for value in
                (a.get('startingBar'), a.get('startingPhraseIndex'),
                 s.get('omittedBarCount'), s.get('omittedPhraseCount'))), 'complete origin/no omissions')
    counts = exact_rows(s.get('operatorCounts'), 'operatorKind', OPERATORS, 'operators')
    transitions = exact_rows(s.get('operatorTransitions'), 'operatorKind', OPERATORS, 'operator transitions')
    operator_total = transition_total = 0
    conditional_transitions = {}
    for name in OPERATORS:
        observed = uint(counts[name].get('observationCount'), 'operator observations', 1)
        count = uint(transitions[name].get('transitionCount'), 'operator transitions', 2)
        require(count <= observed, 'operator transition support exceeds observations')
        missing = metric_rows(transitions[name].get('metricDeltas'), count)
        if missing:
            conditional_transitions[name] = missing
        operator_total += observed
        transition_total += count
    # Canonical neutral fallback has no episode/operator identity. It still
    # contributes ordinary signal observations; never manufacture an operator.
    require(operator_total <= phrases and transition_total <= phrases - 1,
            'operator support exceeds the complete history')
    conditional_signal = metric_rows(s.get('metrics'), phrases)
    recent = s.get('recentPhrases')
    require(isinstance(recent, list) and len(recent) == min(phrases, 32), 'bounded recent phrase coverage')
    end_bar = None
    for ordinal, row in enumerate(recent, phrases - len(recent)):
        require(isinstance(row, dict) and row.get('schemaVersion') == 2 and
                row.get('schemaIdentifier') == 'autotechno-long-horizon-signal-trajectory.v2' and
                row.get('hardGatesPassed') is True and row.get('rootSeed') == seed and
                row.get('sampleRate') == rate and row.get('phraseIndex') == ordinal,
                'recent phrase identity/hard gates')
        uint(row.get('rootSeed'), 'recent root seed')
        start = uint(row.get('startBar'), 'recent start bar')
        count = uint(row.get('barCount'), 'recent bar count', 1)
        require(count <= 16 and (end_bar is None or start == end_bar), 'recent phrase adjacency')
        end_bar = start + count
    require(end_bar == bars, 'recent phrases must end at the completed boundary')
    for key, maximum in (('recentTransitions', 32), ('recentEpisodes', 16)):
        require(isinstance(s.get(key), list) and len(s[key]) <= maximum, 'bounded ' + key)
    accepted = uint(j.get('acceptedFrameCount'), 'accepted frames', 1)
    frames_per_bar = round(240 / 130 * rate)
    require(accepted == bars * frames_per_bar, 'native accepted frame/bar geometry')
    repeats = j.get('accountedRepeats')
    require(isinstance(repeats, list), 'repeat records required')
    previous_end = total = 0
    for row in repeats:
        require(isinstance(row, dict), 'repeat record object')
        start = uint(row.get('startSample'), 'repeat start')
        end = uint(row.get('endSample'), 'repeat end', 1)
        frames = uint(row.get('frameCount'), 'repeat frames', 1)
        repeat_bars = uint(row.get('barCount'), 'repeat bars', 1)
        # The producer repeats a complete accepted phrase, including when
        # selecting one of its same-length prepared evolution variants.
        require(repeat_bars <= 16 and frames == repeat_bars * frames_per_bar and
                start % frames_per_bar == 0, 'repeat native bar geometry')
        require(previous_end <= start and end - start == frames, 'repeat sample accounting/order')
        previous_end = end
        total += frames
    end = uint(j.get('endSample'), 'history end', 1)
    require(end == accepted + total and previous_end <= end, 'accepted/repeat/end sample accounting')
    rejected = j.get('rejectedPreparations')
    require(isinstance(rejected, list), 'rejected preparations required')
    attempts = uint(j.get('newPreparationAttemptCount'), 'preparation attempts')
    children = uint(j.get('ownedChildConsumptionCount'), 'owned children')
    require(attempts + children == phrases + len(rejected), 'attempt/child/refusal accounting')
    require(uint(j.get('reservedNumericPeakBytes'), 'numeric reservation', 1) <= MAX_NUMERIC_BYTES,
            'numeric reservation exceeds existing ceiling')
    return dict(rootSeed=seed, sampleRate=rate, acceptedPhrases=phrases, acceptedBars=bars,
                preparationAttempts=attempts, ownedChildren=children, rejectedPreparations=len(rejected),
                accountedRepeats=len(repeats), neutralOperatorObservationCount=phrases - operator_total,
                conditionallyUnavailableSignalObservations=conditional_signal,
                conditionallyUnavailableTransitionObservations=conditional_transitions)


def git(root, *args):
    return subprocess.check_output(['git', '-c', 'core.fsmonitor=false', *args],
                                   cwd=root, text=True, timeout=30).strip()


def relative_file(root, name):
    require(isinstance(name, str) and name and '\\' not in name, 'relative input path required')
    path = PurePosixPath(name)
    require(not path.is_absolute() and '..' not in path.parts and path.as_posix() == name,
            'input path escapes origin or is not canonical')
    result = root / name
    require(result.resolve().is_relative_to(root.resolve()) and result.is_file() and
            not any((root / part).is_symlink() for part in (Path(name), *Path(name).parents)),
            'regular origin input required')
    return result


def verify_origin(root, runner, resources, source):
    require(re.fullmatch('[0-9a-f]{40}', source) is not None and
            git(root, 'rev-parse', 'HEAD') == source and
            not git(root, 'status', '--porcelain', '--untracked-files=all'), 'clean exact origin source required')
    before_build, before_launch = sha(runner / 'build-metadata.json'), sha(runner / 'launch.json')
    build, launch = load(runner / 'build-metadata.json'), load(runner / 'launch.json')
    require(build.get('source') == launch.get('source') == source and
            launch.get('archiveImport') is False and launch.get('runtimeActivation') is False,
            'original producer source/scope')
    require((runner / 'runner').is_file() and not (runner / 'runner').is_symlink() and
            sha(runner / 'runner') == build.get('executableSHA256') == launch.get('runnerSHA256'),
            'original executable bytes changed')
    groups = build.get('inputs')
    require(isinstance(groups, dict) and set(groups) == {'sources', 'testFiles', 'objects', 'resources'},
            'complete producer input groups required')
    require(isinstance(groups['sources'], dict) and {
        'Sources/AutoTechnoCore/QualityQualification.swift',
        'Sources/AutoTechnoDSP/ProfessionalQualityPrimaryArtifacts.swift',
        'Sources/AutoTechnoDSP/ProfessionalQualityPrimaryEvaluator.swift',
    } <= set(groups['sources']), 'engine and primary owners must be bound compiled inputs')
    checked = 0
    for kind, entries in groups.items():
        require(isinstance(entries, dict) and entries, 'nonempty producer input group')
        for name, digest in entries.items():
            require(isinstance(digest, str) and re.fullmatch('[0-9a-f]{64}', digest), 'input SHA256 required')
            if kind in ('sources', 'testFiles'):
                path = relative_file(root, name)
                require(name.startswith('Sources/' if kind == 'sources' else 'Tests/'), 'input ownership')
            elif kind == 'objects':
                path = Path(name)
                require(path.is_absolute() and path.is_file() and not path.is_symlink(), 'original object path')
            else:
                path = relative_file(root / 'Sources/AutoTechnoDSP/Resources', name)
                require(sha(relative_file(resources, name)) == digest, 'runtime resource bytes changed')
            require(sha(path) == digest, 'original compiled input bytes changed: ' + kind)
            checked += 1
    registry = relative_file(root, 'Sources/AutoTechnoDSP/ProfessionalQualityPrimaryArtifacts.swift').read_text()
    seals = []
    for name in ('Profile', 'AdversarialSuite', 'HoldoutQualification'):
        values = re.findall(r'expected' + name + r'Fingerprint\s*:\s*String\?\s*=\s*"([0-9a-f]{16})"', registry)
        require(len(values) == 1, 'registered primary seal required')
        seals.append(values[0])
    evaluator = relative_file(root, 'Sources/AutoTechnoDSP/ProfessionalQualityPrimaryEvaluator.swift').read_text()
    family = re.findall(r'policyFamilyVersion\s*=\s*"([^"]+)"', evaluator)
    require(len(family) == 1, 'one original primary family required')
    policy = family[0] + '.profile-' + seals[0] + '.adversarial-' + seals[1] + '.holdout-' + seals[2]
    qualification = relative_file(root, 'Sources/AutoTechnoCore/QualityQualification.swift').read_text()
    engines = re.findall(r'engineVersion\s*=\s*"([^"]+)"', qualification)
    require(len(engines) == 1, 'one original engine version required')
    h = 0xcbf29ce484222325
    def feed(raw):
        nonlocal h
        for byte in raw:
            h = ((h ^ byte) * 0x100000001b3) & 0xffffffffffffffff
    def string(value):
        raw = value.encode()
        feed(b'\x73' + struct.pack('<Q', len(raw)) + raw)
    feed(b'\xd0')
    string('long-horizon-shared-preparation-inputs.v1')
    string(source)
    names = sorted(git(root, 'ls-files', '--cached', '--others', '--exclude-standard', '--', *SOURCE_INPUTS).splitlines())
    require(names, 'original source inputs required')
    for name in names:
        string(name)
        string(base64.b64encode(relative_file(root, name).read_bytes()).decode())
    for seal in seals:
        string(seal)
    development, holdout = launch.get('developmentRoots'), launch.get('holdoutRoots')
    require(isinstance(development, list) and isinstance(holdout, list) and
            len(development) == 7 and len(holdout) == 2 and
            all(type(x) is int and 0 <= x < 2**64 for x in development + holdout) and
            len(set(development + holdout)) == 9 and launch.get('sampleRates') == [44100, 48000],
            'seven development/two disjoint holdout roots and both native rates required')
    producer_path = 'Tests/AutoTechnoCoreTests/LongHorizonPolicyCalibrationIntegrationTests.swift'
    require(producer_path in groups['testFiles'], 'canonical native producer must be a bound compiled input')
    producer = relative_file(root, producer_path).read_text()
    for name, expected in (('developmentRoots', development), ('holdoutRoots', holdout)):
        matches = re.findall(name + r'\s*:\s*\[UInt64\]\s*=\s*\[([0-9_,\s]+)\]', producer)
        require(len(matches) == 1, 'one original producer cohort declaration required')
        parsed = [int(x.strip().replace('_', '')) for x in matches[0].split(',') if x.strip()]
        require(parsed == expected, 'launch cohort differs from bound canonical producer')
    require(sha(runner / 'build-metadata.json') == before_build and
            sha(runner / 'launch.json') == before_launch, 'producer metadata changed during verification')
    return dict(source=source, inputBindingFingerprint=f'{h:016x}', roots=development + holdout,
                primaryPolicyVersion=policy, engineVersion=engines[0], sourceInputsBound=len(names),
                compiledInputsChecked=checked, buildMetadataSHA256=before_build, launchSHA256=before_launch)


def audit(root, runner, resources, source, reports):
    require(sha(Path(__file__)) == _IMPLEMENTATION_SHA_AT_IMPORT,
            'verifier implementation changed since import')
    context = verify_origin(root, runner, resources, source)
    rows, seen = [], set()
    for report in reports:
        require(report.resolve().is_relative_to(root.resolve()), 'report must remain inside origin')
        before = sha(report)
        row = verify_history(load(report), context['inputBindingFingerprint'],
                             context['roots'], context['primaryPolicyVersion'], context['engineVersion'])
        key = row['rootSeed'], row['sampleRate']
        require(key not in seen, 'duplicate completed route')
        seen.add(key)
        require(sha(report) == before, 'report changed during verification')
        rows.append(dict(**row, artifactSHA256=before))
    require(rows and verify_origin(root, runner, resources, source) == context,
            'origin inputs changed during verification')
    for report, row in zip(reports, rows):
        require(sha(report) == row['artifactSHA256'], 'report changed before batch completion')
    require(sha(Path(__file__)) == _IMPLEMENTATION_SHA_AT_IMPORT,
            'verifier implementation changed during verification')
    return dict(schema='autotechno-long-history-integrity.v1', **context, histories=rows,
                verifierSHA256=_IMPLEMENTATION_SHA_AT_IMPORT,
                verifiedHistories=len(rows), requiredHistories=18,
                scope='original-input-binding-completed-coverage-and-timeline',
                nativeExecutionProven=False, longHorizonQualification=False,
                completeAllocatorRSSDeadlineQualification=False, runtimeQualification=False,
                item39Complete=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--origin-root', type=Path, required=True)
    parser.add_argument('--runner-directory', type=Path, required=True)
    parser.add_argument('--runtime-resources', type=Path, required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--report', type=Path, action='append', required=True)
    args = parser.parse_args()
    try:
        result = audit(args.origin_root.resolve(), args.runner_directory.resolve(),
                       args.runtime_resources.resolve(), args.source, args.report)
        print(json.dumps(result, sort_keys=True, allow_nan=False))
    except (HistoryIntegrityError, OSError, ValueError, subprocess.SubprocessError) as exc:
        parser.exit(1, 'Long history integrity failed: ' + str(exc) + '\n')


if __name__ == '__main__':
    main()
