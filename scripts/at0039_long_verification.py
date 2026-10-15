"""Read-only original Long-study verification; no capture or completion authority.

Authenticates independently pinned original cold and terminal byte records.
It never decodes sealed candidate products, constructs state, rerenders histories
or supplies current-source applicability or full item-completion authority.
"""
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
import base64
import gzip
import hashlib
import re
import struct
import subprocess

from at0039_primary_verification import (VerificationError, need, canonical,
    inside, load, raw_file, sha, strict, MAXIMUM_DOCUMENT_BYTES)
from long_horizon_history_integrity import verify_history, SOURCE_INPUTS

RATES = (44100, 48000)
OBSERVATION = 'autotechno-long-horizon-policy-observation.v7'
CORPUS = 'autotechno-long-horizon-policy-corpus.v7'
PROFILE = 'autotechno-long-horizon-professional-profile.v21'
ADVERSARIAL = 'autotechno-long-horizon-adversarial.v21'
HOLDOUT = 'autotechno-long-horizon-holdout.v21'
IMPLEMENTATION_SHA256 = {str(Path(name).resolve()): sha(Path(name)) for name in
    [__file__, canonical.__code__.co_filename, verify_history.__code__.co_filename]}


def stable_implementation():
    need(all(sha(Path(path)) == digest for path,digest in IMPLEMENTATION_SHA256.items()),
         'verifier or a verification dependency changed during audit')


@dataclass(frozen=True)
class Context:
    source_root: Path
    study: Path
    runner: Path
    evidence_root: Path
    cold_proof: str
    cold_sha256: str
    source: str
    terminal_proof: str
    terminal_sha256: str

    def git(self, *args):
        return subprocess.check_output(['git', '-c', 'core.fsmonitor=false', '-C',
            str(self.source_root), *args], text=True, stderr=subprocess.DEVNULL,
            timeout=30).strip()

    def original(self, record, live):
        archive = inside(self.evidence_root, record['archive'])
        need(archive.stat().st_size <= MAXIMUM_DOCUMENT_BYTES, 'bounded original archive')
        with gzip.open(archive, 'rb') as handle:
            raw = handle.read(MAXIMUM_DOCUMENT_BYTES + 1)
        need(type(record['bytes']) is int and 0 <= record['bytes'] <= MAXIMUM_DOCUMENT_BYTES and
             len(raw) == record['bytes'] and hashlib.sha256(raw).hexdigest() == record['sha256'],
             'original archive digest and size')
        need(live.is_file() and not live.is_symlink() and live.stat().st_size == len(raw),
             'live original size differs from preserved byte archive')
        with live.open('rb') as handle:
            current = handle.read(MAXIMUM_DOCUMENT_BYTES + 1)
        need(current == raw, 'live original differs from preserved byte archive')
        return raw

    def inputs(self):
        stable_implementation()
        need(re.fullmatch('[0-9a-f]{40}', self.source) is not None and
             re.fullmatch('[0-9a-f]{64}', self.cold_sha256) is not None,
             'exact frozen source and independently pinned cold proof required')
        proof = load(inside(self.evidence_root, self.cold_proof))
        need(sha(inside(self.evidence_root, self.cold_proof)) == self.cold_sha256,
             'independently pinned original cold proof SHA256')
        need(proof['schema'] == 'autotechno-engine51-long-cold-launch-audit.v1' and
             proof['source'] == self.source and proof['coldNativeControls'] == 26 and
             all(proof[key] is True for key in ['zeroSkips', 'freshInitialState',
                 'explicitImmutableRefBoundBeforePCM']) and
             all(proof[key] is False for key in ['archiveImport', 'partialStateImport',
                 'historicalRetag', 'longHorizonQualified', 'fullPlatformQualified',
                 'runtimeQualified', 'item39Complete']), 'original cold scope and controls')
        cold = proof['cold']
        need(cold['source'] == self.source and self.git('rev-parse', 'HEAD') == self.source and
             not self.git('status', '--porcelain', '--untracked-files=all'), 'clean exact original source')
        records = proof['files']
        need(records and len({x['archive'] for x in records}) == len(records) and
             len({x['source'] for x in records}) == len(records), 'unique original cold file inventory')
        for record in records:
            live = Path(record['source'])
            need(live.is_absolute(), 'absolute original cold input path')
            self.original(record, live)
        inventory = {Path(x['source']).resolve(): x for x in records}
        for name in ['build-metadata.json', 'tracked-inputs.json', 'execution-protocol.json',
                     'pre-PCM-audit.json', 'build-status.json', 'cold-controls.log']:
            need((self.runner/name).resolve() in inventory, 'required original cold file: ' + name)
        metadata = load(self.runner/'build-metadata.json')
        tracked = load(self.runner/'tracked-inputs.json')
        protocol = load(self.runner/'execution-protocol.json')
        pre = load(self.runner/'pre-PCM-audit.json')
        need(metadata['source'] == self.source and pre['cold'] == cold and
             pre['captureStarted'] is False and pre['archiveImport'] is False and
             pre['inputBindingFingerprint'] == proof['inputBindingFingerprint'],
             'pre-PCM original source and binding')
        need(Path(metadata['frozenCheckout']).resolve() == self.source_root.resolve() and
             Path(protocol['output']).resolve() == self.study.resolve() and
             self.study.resolve().is_relative_to((self.source_root/'docs/local/reports').resolve()),
             'original checkout and confined study namespace')
        need(protocol['source'] == self.source and isinstance(protocol['immutableOriginRef'], str) and
             protocol['immutableOriginRef'].startswith('refs/remotes/origin/') and
             self.git('rev-parse', protocol['immutableOriginRef']) == self.source,
             'explicit immutable published origin ref')
        for key, name in [('buildMetadataSHA256', 'build-metadata.json'),
                          ('trackedInputsSHA256', 'tracked-inputs.json'),
                          ('protocolSHA256', 'execution-protocol.json'),
                          ('coldLogSHA256', 'cold-controls.log')]:
            need(sha(self.runner/name) == cold[key], 'cold exact bytes: ' + name)
        need(sha(self.runner/'runner') == metadata['executableSHA256'] == cold['runnerSHA256'],
             'original native executable bytes')
        need(set(tracked) == set(self.git('ls-files').splitlines()) and
             len(tracked) == cold['trackedInputs'], 'complete original tracked inventory')
        for relative, digest in tracked.items():
            need(sha(inside(self.source_root, relative)) == digest and
                 hashlib.sha256(subprocess.check_output(['git', '-C', str(self.source_root),
                    'show', self.source + ':' + relative], timeout=30)).hexdigest() == digest,
                 'original tracked bytes match frozen Git: ' + relative)
        groups = ['sources', 'resources', 'objects', 'compilerSupport', 'modules', 'actualRuntimeResources']
        counts = dict(sources=cold['sourceFiles'], resources=cold['actualRuntimeResources'],
                      objects=cold['objects'], compilerSupport=cold['compilerSupport'],
                      modules=cold['modules'], actualRuntimeResources=cold['actualRuntimeResources'])
        for group in groups:
            need(isinstance(metadata[group], dict) and len(metadata[group]) == counts[group],
                 'complete original build group: ' + group)
            for name, digest in metadata[group].items():
                path = Path(name)
                need(path.is_file() and not path.is_symlink() and sha(path) == digest,
                     'actual compiled/runtime input changed: ' + group)
                if group in ['sources', 'resources']:
                    relative = path.resolve().relative_to(self.source_root.resolve()).as_posix()
                    need(tracked.get(relative) == digest, 'compiled bytes are original tracked Git inputs')
        production = {p for p in metadata['sources'] if '/Sources/' in p}
        tests = {p for p in metadata['sources'] if '/Tests/' in p}
        need(len(production) == 95 and len(tests) == 13 and
             production == {p for key in ['core', 'dsp', 'transport'] for p in
                metadata['commands'][key] if p.endswith('.swift') and '/Sources/' in p} and
             tests == {p for p in metadata['commands']['tests'] if p.endswith('.swift') and '/Tests/' in p},
             'actual compiler commands include every original production and test input')
        for key in ['core', 'dsp', 'transport', 'tests']:
            worker = load(self.runner/(key+'-compile-worker.json'))
            state = load(self.runner/(key+'-compile-status.json'))
            need(worker['command'] == metadata['commands'][key] and
                 type(state['exitCode']) is int and state['exitCode'] == 0,
                 'successful original compiler invocation: ' + key)
        searches, i = [], 0
        command = metadata['commands']['tests']
        while i < len(command):
            if command[i] == '-Xcc': i += 2; continue
            if command[i] == '-I': searches.append(command[i+1]); i += 2; continue
            i += 1
        need(searches == [str(self.runner/'Modules'), str(self.runner/'support/Modules')],
             'original isolated production module search, excluding Clang flags')
        need({Path(p).name: h for p,h in metadata['resources'].items()} ==
             {Path(p).name: h for p,h in metadata['actualRuntimeResources'].items()},
             'actual runtime bundle bytes equal original source resources')
        build_status = load(self.runner/'build-status.json')
        need(type(build_status['exitCode']) is int and build_status['exitCode'] == 0 and
             build_status['source'] == self.source and build_status['actualNativeTests'] == 26 and
             build_status['zeroSkips'] is True and build_status['allActualInputsUnchanged'] is True,
             'original successful compiled and cold native controls')
        cold_text = raw_file(self.runner/'cold-controls.log').decode('utf-8')
        need(len(re.findall(r'Test run with 26 tests passed after [0-9.]+ seconds\.', cold_text)) == 1 and
             'skipped' not in cold_text.lower() and 'recorded an issue' not in cold_text,
             'original complete cold control stdout')
        source_text = (self.source_root/'Sources/AutoTechnoCore/QualityQualification.swift').read_text()
        need(set(re.findall(r'"(autotechno-canonical-engine\.v\d+)"', source_text)) == {cold['engineVersion']},
             'engine identity comes from compiled original source')
        registry = (self.source_root/'Sources/AutoTechnoDSP/ProfessionalQualityPrimaryArtifacts.swift').read_text()
        seals = []
        for name in ['Profile', 'AdversarialSuite', 'HoldoutQualification']:
            found = re.findall('expected' + name + r'Fingerprint\s*:\s*String\?\s*=\s*"([0-9a-f]{16})"', registry)
            need(len(found) == 1, 'one installed original primary seal'); seals += found
        need(protocol['primarySeals'] == seals, 'exact original installed primary seals')
        evaluator = (self.source_root/'Sources/AutoTechnoDSP/ProfessionalQualityPrimaryEvaluator.swift').read_text()
        families = re.findall(r'policyFamilyVersion\s*=\s*"([^"]+)"', evaluator)
        need(len(families) == 1 and cold['primaryPolicyVersion'] == families[0] +
             '.profile-' + seals[0] + '.adversarial-' + seals[1] + '.holdout-' + seals[2],
             'original route-local primary policy identity')
        value = 0xcbf29ce484222325
        def feed(raw):
            nonlocal value
            for byte in raw: value = ((value ^ byte) * 0x100000001b3) & ((1 << 64) - 1)
        def string(text):
            raw = text.encode(); feed(b'\x73' + struct.pack('<Q', len(raw)) + raw)
        feed(b'\xd0'); string('long-horizon-shared-preparation-inputs.v1'); string(self.source)
        for name in sorted(self.git('ls-files', '--cached', '--others', '--exclude-standard', '--', *SOURCE_INPUTS).splitlines()):
            string(name); string(base64.b64encode(raw_file(inside(self.source_root, name))).decode())
        for seal in seals: string(seal)
        need(f'{value:016x}' == proof['inputBindingFingerprint'], 'recomputed canonical original input binding')
        producer = (self.source_root/'Tests/AutoTechnoCoreTests/LongHorizonPolicyCalibrationIntegrationTests.swift').read_text()
        for key, count in [('developmentRoots', 7), ('holdoutRoots', 2)]:
            found = re.findall(key + r'\s*:\s*\[UInt64\]\s*=\s*\[([0-9_,\s]+)\]', producer)
            need(len(found) == 1, 'one compiled canonical native cohort declaration')
            seeds = [int(x.strip().replace('_', '')) for x in found[0].split(',') if x.strip()]
            need(seed_list(seeds, count) == cold[key] == protocol[key], 'compiled canonical cohort identity')
        policy_source = (self.source_root/'Sources/AutoTechnoDSP/LongHorizonProfessionalPolicy.swift').read_text()
        for name, expected in [('observationVersion', OBSERVATION), ('corpusVersion', CORPUS),
                               ('profileVersion', PROFILE), ('adversarialVersion', ADVERSARIAL),
                               ('holdoutVersion', HOLDOUT)]:
            need(re.findall(r'static let '+name+r'\s*=\s*"([^"]+)"', policy_source) == [expected],
                 'schema comes from the original compiled policy: ' + name)
        attack_enum = policy_source.split('package enum LongHorizonAdversarialAttack:', 1)[1].split('\n}',1)[0]
        attacks = re.findall(r'case \w+ = "([^"]+)"', attack_enum)
        need(len(attacks) == 10 and len(set(attacks)) == 10, 'original canonical adversarial attack inventory')
        drivers = [r for r in records if Path(r['source']).name == 'run_at0039_engine51_long_study_v1.py']
        need(len(drivers) == 1, 'one preserved original launch and observer driver')
        stable_implementation()
        return dict(source=self.source, cold=cold, protocol=protocol,
                    inputBindingFingerprint=proof['inputBindingFingerprint'], attacks=attacks,
                    coldProofSHA256=self.cold_sha256,
                    driverSHA256=drivers[0]['sha256'],
                    prePCMAuditSHA256=sha(self.runner/'pre-PCM-audit.json'))


def seed_list(values, count):
    need(isinstance(values, list) and len(values) == count and
         all(type(x) is int and 0 <= x < 2**64 for x in values) and
         len(set(values)) == count, 'exact distinct unsigned root cohort')
    return values


def accepted(verdict):
    need(verdict['accepted'] is True and all(verdict[key] == [] for key in
         ['failedDimensions', 'failedSemanticMetrics', 'failedOperatorDeltas',
          'failedEffectFamilies']), 'every native verdict independently accepts every dimension')


def projected_semantics(report):
    periodicity = report.get('dominantSemanticPeriodicity')
    signatures, recall, debt = [report[k] for k in
        ['eventSignatureRecurrence', 'identityRecall', 'dramaticDebt']]
    values = [
        ('high-tension-dwell-bars', report['tensionDwell']['maximumHighDwellBars']),
        ('recovery-bar-ratio', report['tensionDwell']['recoveryBarCount'] / report['observedBarCount']),
        ('dominant-semantic-periodicity', periodicity['semanticMatchRate'] if periodicity else 0),
        ('event-signature-repeat-ratio', signatures['repeatObservationCount'] / signatures['observationCount']
            if signatures['observationCount'] else 0),
        ('matched-identity-recall-ratio', recall['matchedHomeSignatureBarCount'] / recall['identityReturnBarCount']
            if recall['identityReturnBarCount'] else 1),
        ('zero-age-debt-ratio', debt['zeroAgePaidCount'] / debt['paidCount'] if debt['paidCount'] else 0),
        ('overdue-debt-count', debt['overduePaidCount'] + debt['overdueOutstandingCount']),
        ('oldest-debt-age-bars', debt['oldestOutstandingAgeBars']),
        ('maximum-capability-run-bars', max((x['maximumRunBars'] for x in report['capabilityRecurrence']), default=0)),
    ]
    return [dict(metric=name, value=float(value)) for name, value in values]


def projected_effects(report):
    result = []
    need([f['family'] for f in report['families']] ==
         ['generated-graph', 'pulse-echo', 'percussion-echo-texture', 'spatial-fdn'],
         'complete original effect-family reduction')
    for family in report['families']:
        row = {k: family[k] for k in ['family', 'eligibleBarCount', 'activeBarCount',
            'tailOnlyBarCount', 'recoveryCount', 'maximumActiveRunBars', 'wetBarOccupancy']}
        row['observedBarCount'] = report['barCount']
        if family.get('maximumReturnToSourceDB') is not None:
            row['maximumReturnToSourceDB'] = family['maximumReturnToSourceDB']
        if family['family'] == 'generated-graph':
            for k in ['materialWorldCount', 'meanEffectWorldDistance', 'maximumEffectWorldDistance']:
                row[k] = report[k]
        result.append(row)
    return result


def verify_products(protocol, cold, documents, artifacts, status, log, source,
                    binding, attacks):
    """Join all original native products; a caller must authenticate their bytes.

    A successful structural join is not independent native execution attestation.
    No generic result record can supply the separate original-byte context.
    """
    development = seed_list(protocol['developmentRoots'], 7)
    holdout = seed_list(protocol['holdoutRoots'], 2)
    need(len(set(development + holdout)) == 9, 'development and holdout roots must be disjoint')
    need(protocol['source'] == cold['source'] == source and
         protocol['developmentRoots'] == cold['developmentRoots'] and
         protocol['holdoutRoots'] == cold['holdoutRoots'] and
         protocol['nativeRates'] == cold['sampleRates'] == list(RATES), 'exact frozen native cohort and source')
    need(protocol['allHistoriesFromInitialState'] is True and
         protocol['eachNativeHistoryMustIndependentlyPassEveryGate'] is True and
         protocol['noCrossRateHistoryEqualityRequired'] is True and
         all(protocol[key] is False for key in ['archiveImport', 'partialStateImport',
             'historicalHistoriesRetagged', 'runtimeActivation', 'item39Complete']),
         'fresh independent native histories without import or retagging')
    need(type(protocol['numericCeilingBytes']) is int and
         protocol['numericCeilingBytes'] == 128 * 1024 * 1024 and
         type(protocol['maximumRenderPasses']) is int and protocol['maximumRenderPasses'] == 2 and
         type(protocol['minimumActualAcceptedBarsPerHistory']) is int and
         protocol['minimumActualAcceptedBarsPerHistory'] == 7800 and
         type(protocol['requiredCompleteHistories']) is int and protocol['requiredCompleteHistories'] == 18,
         'unchanged numeric/render/history bounds')
    expected = {(seed, rate) for seed in development + holdout for rate in RATES}
    need(isinstance(documents, dict) and set(documents) == expected,
         'all eighteen complete original native histories required')
    histories = {}
    for key in sorted(expected):
        document = documents[key]
        row = verify_history(document, binding,
            development + holdout, cold['primaryPolicyVersion'], cold['engineVersion'])
        need((row['rootSeed'], row['sampleRate']) == key, 'history identity matches its original file')
        histories[key] = row

    engine, policy = cold['engineVersion'], cold['primaryPolicyVersion']
    observations = {}
    for partition, seeds in [('development', development), ('holdout', holdout)]:
        corpus = artifacts[partition]
        need(corpus['schemaVersion'] == CORPUS and corpus['engineVersion'] == engine and
             corpus['primaryPolicyVersion'] == policy, 'exact original corpus identity')
        rows = corpus['observations']
        need(len(rows) == len(seeds) and Counter(x['rootSeed'] for x in rows) == Counter(seeds),
             'complete exact corpus roots with multiplicity')
        for observation in rows:
            seed = observation['rootSeed']
            need(observation['schemaVersion'] == OBSERVATION and
                 observation['engineVersion'] == engine and observation['primaryPolicyVersion'] == policy,
                 'original policy observation identity')
            routes = observation['routes']
            need(len(routes) == 2 and [r['sampleRate'] for r in routes] == list(RATES),
                 'both native routes are present independently')
            observations[seed] = observation
            for route in routes:
                rate = route['sampleRate']; key = seed, rate
                journey = documents[key]['journey']
                signal, semantic = journey['signal'], journey['semantic']
                need(route['schemaVersion'] == 'autotechno-long-horizon-runtime-observation.v5' and
                     route['rootSeed'] == seed and route['engineVersion'] == engine and
                     route['primaryPolicyVersion'] == policy and
                     route['semanticFingerprint'] == semantic['trajectoryFingerprint'] and
                     route['signalFingerprint'] == signal['trajectoryFingerprint'] and
                     route['observedPhraseCount'] == semantic['observedPhraseCount'] and
                     route['observedBarCount'] == semantic['observedBarCount'] and
                     route['signalObservationCount'] == signal['observationCount'] and
                     route['signalOmittedPhraseCount'] == signal['omittedPhraseCount'] == 0,
                     'each corpus route binds its own complete native history')
                expected_deltas = [dict(sampleRate=rate, operatorKind=t['operatorKind'],
                    metric=m['metric'], transitionCount=m['observationCount'], meanDelta=m['mean'])
                    for t in signal['operatorTransitions'] for m in t['metricDeltas']]
                need(route['operatorDeltas'] == expected_deltas,
                     'route deltas are exact native per-rate reductions, without averaging')
                need(route['semanticValues'] == projected_semantics(semantic) and
                     route['effects'] == projected_effects(journey['effects']),
                     'semantic and effect values are exact original native reductions')

    profile, suite, held = [artifacts[k] for k in ['profile', 'adversarial', 'holdoutVerdicts']]
    need(profile['profileVersion'] == PROFILE and profile['engineVersion'] == engine and
         profile['primaryPolicyVersion'] == policy and profile['sampleRates'] == list(RATES) and
         type(profile['developmentJourneyCount']) is int and profile['developmentJourneyCount'] == 7 and
         Counter(profile['developmentRootSeeds']) == Counter(development) and
         profile['developmentCorpusFingerprint'] == artifacts['development']['fingerprint'],
         'profile binds the original development corpus and native rates')
    need(suite['schemaVersion'] == ADVERSARIAL and suite['engineVersion'] == engine and
         suite['profileFingerprint'] == profile['fingerprint'] and suite['passed'] is True,
         'original native adversarial identity')
    need(isinstance(attacks, list) and attacks and len(set(attacks)) == len(attacks),
         'frozen canonical attack identities required')
    cases = suite['cases']
    need(Counter((c['sampleRate'], c['attack']) for c in cases) ==
         Counter((rate, attack) for rate in RATES for attack in attacks) and
         all(c['rejected'] is True and c['failedDimensions'] for c in cases),
         'every original adversarial attack rejected at each rate')
    need(suite['sourceObservationFingerprint'] == observations[development[0]]['sourceFingerprint'],
         'adversarial baseline is the original first development observation')
    need(held['schemaVersion'] == HOLDOUT and held['engineVersion'] == engine and
         held['profileFingerprint'] == profile['fingerprint'] and
         held['adversarialFingerprint'] == suite['fingerprint'] and
         held['developmentCorpusFingerprint'] == artifacts['development']['fingerprint'] and
         held['holdoutCorpusFingerprint'] == artifacts['holdout']['fingerprint'] and held['qualified'] is True,
         'exact original independent holdout joins')
    need(len(held['journeys']) == 2 and Counter(j['rootSeed'] for j in held['journeys']) == Counter(holdout),
         'both distinct holdout journeys required')
    for journey in held['journeys']:
        observation = observations[journey['rootSeed']]
        need(journey['sourceFingerprint'] == observation['sourceFingerprint'], 'holdout source identity')
        verdict = journey['verdict']; accepted(verdict)
        routes = verdict['routeVerdicts']
        need(len(routes) == 2 and [r['sampleRate'] for r in routes] == list(RATES),
             'each holdout has both independent native verdicts')
        for verdict_route, actual_route in zip(routes, observation['routes']):
            need(verdict_route['sourceFingerprint'] == actual_route['sourceFingerprint'],
                 'holdout native verdict is bound to its actual route')
            accepted(verdict_route['verdict'])

    need(type(status['exitCode']) is int and status['exitCode'] == 0 and
         status['source'] == source and status['actualOneNativeTestZeroSkipsPassed'] is True and
         status['independentlyAuditedCompleteHistories'] == status['requiredHistories'] == 18 and
         status['observerErrors'] == [] and status['all18CompleteHistoryAuditsPassed'] is True and
         status['originalLogSHA256'] == hashlib.sha256(log).hexdigest(),
         'original complete terminal native execution and observer receipt')
    text = log.decode('utf-8')
    need(len(re.findall(r'Test run with 1 test passed after [0-9.]+ seconds\.', text)) == 1 and
         'skipped' not in text.lower() and 'recorded an issue' not in text,
         'one complete original native test, zero skips or issues')
    for partition, seeds in [('development', development), ('holdout', holdout)]:
        recorded = re.findall(partition + r'-native root=(\d+) rate=(\d+) accepted=(true|false) source=([0-9a-f]{16})', text)
        required = [(str(seed), str(rate), 'true', next(r['sourceFingerprint'] for r in
                     observations[seed]['routes'] if r['sampleRate'] == rate)) for seed in seeds for rate in RATES]
        need(Counter(recorded) == Counter(required), 'original native per-route development/holdout verdicts')
    for label, artifact in [('profile', profile), ('adversarial', suite), ('holdout', held)]:
        need(re.findall(r'\b' + label + r'=([0-9a-f]{16})\b', text) == [artifact['fingerprint']],
             'original native derived artifact fingerprint: ' + label)
    return dict(schema='autotechno-at0039-long-original-product-verification.v1',
        source=source, engine=engine, originalNativeProductsConsistent=True,
        completeHistories=18, developmentRoots=7, holdoutRoots=2,
        independentNativeRateGates=True, crossRateHistoryEqualityRequired=False,
        freshCaptureConstructed=False, nativeExecutionProven=False,
        originalByteContextAuthenticated=False, sealedCandidateProductsDecoded=False,
        currentSourceApplicabilityVerified=False, installedArtifactsVerified=False,
        completeResourceQualification=False, fullPlatformQualified=False,
        runtimeQualification=False, item39Complete=False)


ARTIFACTS = dict(development='long-horizon-development-corpus-local-v7.json',
    holdout='long-horizon-holdout-corpus-local-v7.json',
    profile='long-horizon-professional-profile-v21.json',
    adversarial='long-horizon-adversarial-suite-v21.json',
    holdoutVerdicts='long-horizon-holdout-v21.json')


def original_paths(context, inputs):
    result = {'study/'+name: inside(context.study, name) for name in ARTIFACTS.values()}
    for seed in inputs['protocol']['developmentRoots'] + inputs['protocol']['holdoutRoots']:
        for rate in RATES:
            name = f'actual-journey-{seed}-{rate}.json'
            result['study/'+name] = inside(context.study, name)
            name = f'actual-journey-{seed}-{rate}-audit.json'
            result['observer/'+name] = inside(context.evidence_root,
                str(Path(context.cold_proof).parent/name))
    for name in ['execution-launch.json', 'execution-status.json', 'execution.log']:
        result['runner/'+name] = inside(context.runner, name)
    need(all(path.is_file() and not path.is_symlink() for path in result.values()),
         'every original study, observer and terminal file is required')
    return result


def inspect(context, inputs, paths):
    """Read originals only; independent archive authentication is done by caller."""
    documents = {}
    for seed in inputs['protocol']['developmentRoots'] + inputs['protocol']['holdoutRoots']:
        for rate in RATES:
            name = f'actual-journey-{seed}-{rate}'
            path = paths['study/'+name+'.json']
            documents[seed, rate] = load(path)
            row = verify_history(documents[seed, rate], inputs['inputBindingFingerprint'],
                inputs['protocol']['developmentRoots'] + inputs['protocol']['holdoutRoots'],
                inputs['cold']['primaryPolicyVersion'], inputs['cold']['engineVersion'])
            observer = load(paths['observer/'+name+'-audit.json'])
            need(all(observer[k] == value for k,value in row.items()) and
                 observer['source'] == context.source and observer['originalRouteSHA256'] == sha(path) and
                 observer['coldByteBindingsRechecked'] is True and
                 observer['historyIndependentlyAudited'] is True,
                 'each original read-only observer receipt binds its complete native history')
    artifacts = {key: load(paths['study/'+name]) for key,name in ARTIFACTS.items()}
    launch = load(paths['runner/execution-launch.json'])
    need(launch['source'] == context.source and
         launch['coldPrivateAuditSHA256'] == context.cold_sha256 and
         launch['buildMetadataSHA256'] == inputs['cold']['buildMetadataSHA256'] and
         launch['runnerSHA256'] == inputs['cold']['runnerSHA256'] and
         launch['protocolSHA256'] == inputs['cold']['protocolSHA256'] and
         launch['prePCMAuditSHA256'] == inputs['prePCMAuditSHA256'] and
         launch['driverSHA256'] == inputs['driverSHA256'] and
         launch['inputAuditorSHA256'] == inputs['cold']['auditorSHA256'] and
         launch['inputBindingFingerprint'] == inputs['inputBindingFingerprint'] and
         launch['command'] == [str(context.runner/'runner'), '--no-parallel', '--filter',
            'LongHorizonPolicyCalibrationIntegrationTests[/.]generateArtifacts'] and
         type(launch['pid']) is int and launch['pid'] > 0 and
         all(launch[k] is False for k in ['archiveImport', 'partialStateImport', 'runtimeActivation']),
         'exact original producer launch and cold proof binding')
    return verify_products(inputs['protocol'], inputs['cold'], documents, artifacts,
        load(paths['runner/execution-status.json']), raw_file(paths['runner/execution.log']),
        context.source, inputs['inputBindingFingerprint'], inputs['attacks'])


def collect_terminal(context):
    """Describe already-preserved originals; no capture, import or archive writes.

    The caller preserves and pins this manifest independently before verify().
    A live/prefix/failed study cannot produce this terminal preservation manifest.
    """
    before = context.inputs()
    paths = original_paths(context, before)
    digests = {name: sha(path) for name,path in paths.items()}
    result = inspect(context, before, paths)
    parent = Path(context.cold_proof).parent
    records = []
    for name, path in paths.items():
        if name.startswith('observer/') or name in ['runner/execution-status.json', 'runner/execution-launch.json']:
            archive, encoding = str(parent/path.name), 'raw'
        else:
            archive = str(parent/('original-execution.log.gz' if name == 'runner/execution.log' else path.name+'.gz'))
            encoding = 'gzip'
        record = dict(path=name, archive=archive, encoding=encoding,
                      sha256=digests[name], bytes=path.stat().st_size)
        authenticate_original(context, record, path)
        records.append(record)
    need(context.inputs() == before and all(sha(p) == digests[n] for n,p in paths.items()),
         'original source/build/runtime and products stable through terminal preservation')
    return dict(schema='autotechno-at0039-long-terminal-preservation.v1', source=context.source,
        coldProofSHA256=context.cold_sha256, files=records, result=result,
        freshCaptureConstructed=False, item39Complete=False)


def authenticate_original(context, record, path):
    need(record['encoding'] in ['raw', 'gzip'], 'declared original archive encoding')
    if record['encoding'] == 'gzip':
        context.original(record, path)
    else:
        raw = raw_file(inside(context.evidence_root, record['archive']))
        need(type(record['bytes']) is int and len(raw) == record['bytes'] and
             hashlib.sha256(raw).hexdigest() == record['sha256'] and raw_file(path) == raw,
             'original raw preservation record')


def verify(context):
    before = context.inputs()
    proof_path = inside(context.evidence_root, context.terminal_proof)
    need(re.fullmatch('[0-9a-f]{64}', context.terminal_sha256) is not None and
         sha(proof_path) == context.terminal_sha256, 'independently pinned original terminal proof SHA256')
    proof = load(proof_path)
    need(proof['schema'] == 'autotechno-at0039-long-terminal-preservation.v1' and
         proof['source'] == context.source and proof['coldProofSHA256'] == context.cold_sha256,
         'original terminal preservation identity')
    paths = original_paths(context, before)
    rows = proof['files']
    need(len(rows) == len(paths) and len({r['path'] for r in rows}) == len(rows) and
         {r['path'] for r in rows} == set(paths) and
         len({r['archive'] for r in rows}) == len(rows), 'complete unique original terminal inventory')
    for row in rows: authenticate_original(context, row, paths[row['path']])
    result = inspect(context, before, paths)
    need(result == proof['result'] and context.inputs() == before and
         sha(proof_path) == context.terminal_sha256 and
         all(sha(paths[row['path']]) == row['sha256'] for row in rows),
         'original result and complete byte context stable through verification')
    result.update(originalByteContextAuthenticated=True,
        originalNativeExecutionBound=True, originalColdProofSHA256=context.cold_sha256,
        originalTerminalProofSHA256=context.terminal_sha256,
        verificationImplementationSHA256=IMPLEMENTATION_SHA256)
    return result


def main():
    import argparse, json
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['source-root', 'study', 'runner', 'evidence-root']:
        parser.add_argument('--'+name, type=Path, required=True)
    for name in ['cold-proof', 'cold-sha256', 'source']:
        parser.add_argument('--'+name, required=True)
    parser.add_argument('--terminal-proof', default='')
    parser.add_argument('--terminal-sha256', default='')
    parser.add_argument('--collect-terminal', action='store_true')
    args = parser.parse_args(); collect = args.collect_terminal; del args.collect_terminal
    try:
        context = Context(**vars(args))
        result = collect_terminal(context) if collect else verify(context)
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as exc:
        print('AT-0039 Long verification refused: '+str(exc))
        return 1
    print(json.dumps(result, sort_keys=True, allow_nan=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
