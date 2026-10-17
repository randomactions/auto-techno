#!/usr/bin/env python3
"""Read-only AT-0039 primary native-product verification.

Consumes an independently pinned original cold proof and the complete original
native execution. JSON is inspected as recorded data; sealed Swift candidate
products are never decoded, reconstructed, rerendered, installed or promoted.
A successful result applies only to the frozen study source. The full item
completion guard remains separate and fail-closed.
"""
from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import dataclass
import gzip
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess

MAXIMUM_DOCUMENT_BYTES = 64 * 1024 * 1024
CHECKPOINTS = ["establishment", "chapter-change", "contrast", "major-break",
               "release", "identity-return", "long-continuation"]
HARD_GATES = {"allSamplesFinite", "audioSafetyValid", "blockChannelsAligned",
              "blocksPresent", "completeInputs", "fullMixFinite", "graphValid",
              "symbolicValid", "upperTimbreFinite"}


class VerificationError(ValueError):
    """Missing, changed, incomplete or inconsistent original evidence."""


def need(ok, label):
    if not ok:
        raise VerificationError(label)


def sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def strict(raw):
    need(isinstance(raw, (str, bytes)) and 0 < len(raw) <= MAXIMUM_DOCUMENT_BYTES,
         "bounded nonempty JSON required")
    def pairs(rows):
        result = {}
        for key, value in rows:
            need(key not in result, "duplicate JSON key")
            result[key] = value
        return result
    def number(value):
        result = float(value)
        need(math.isfinite(result), "finite JSON required")
        return result
    def bad(_):
        raise VerificationError("nonfinite JSON")
    try:
        return json.loads(raw, object_pairs_hook=pairs, parse_float=number,
                          parse_constant=bad)
    except (UnicodeError, RecursionError, json.JSONDecodeError) as exc:
        raise VerificationError("invalid bounded JSON") from exc


def raw_file(path):
    path = Path(path)
    need(path.is_file() and not path.is_symlink() and
         0 < path.stat().st_size <= MAXIMUM_DOCUMENT_BYTES, "bounded regular file required")
    with path.open("rb") as handle:
        raw = handle.read(MAXIMUM_DOCUMENT_BYTES + 1)
    need(0 < len(raw) <= MAXIMUM_DOCUMENT_BYTES, "file exceeds bound")
    return raw


def load(path):
    value = strict(raw_file(path))
    need(isinstance(value, dict), "JSON root must be an object")
    return value


def inside(root, relative):
    need(isinstance(relative, str) and relative and "\\" not in relative,
         "relative evidence path required")
    rel = Path(relative)
    need(not rel.is_absolute() and ".." not in rel.parts, "evidence path escapes root")
    path = root / rel
    need(path.resolve().is_relative_to(root.resolve()) and
         not any((root / parent).is_symlink() for parent in (rel, *rel.parents)),
         "evidence symlink or escaped path")
    return path


def archived_bytes(path):
    raw_file(path)  # Bound and reject a substituted archive before decompression.
    with gzip.open(path, "rb") as handle:
        raw = handle.read(MAXIMUM_DOCUMENT_BYTES + 1)
    need(0 < len(raw) <= MAXIMUM_DOCUMENT_BYTES, "bounded original archive required")
    return raw


def report_key(r):
    c = r['commitProvenance']
    return (r['sampleRate'], r['evidenceFingerprint'], r['routeFingerprint'], r['routeGeneration'], c['outgoingRenderDSPFingerprint'], c['outgoingQualityStateFingerprint'], r['selectedCandidateEvidence']['graphFingerprint'])

def receipt_key(s):
    return (s['sampleRate'], s['sourceReportFingerprint'], s['routeFingerprint'], s['routeGeneration'], s['sourceOutgoingRenderDSPFingerprint'], s['successorIncomingQualityFingerprint'], s['successorPreviousGraphFingerprint'])

def verify_trajectory(d, row, partition, entry, engine):
    need(row['partition'] == partition and row['ordinal'] == entry['ordinal'], 'exact cohort order')
    need(d['frozenPlanningEntry'] == entry, 'frozen original planning entry')
    b = d['actualReportBank']
    reports = b['reports']
    receipts = d['actualSuccessorReceipts']
    trajectory = d['continuousTrajectory']
    obs = trajectory['observations']
    need(b['engineVersion'] == engine and b['sampleRates'] == [44100, 48000], 'bank engine and both native rates')
    need(b['sourceReportCount'] == len(reports) == len(receipts) == row['originalReportCount'] == row['actualSuccessorCount'] == 14, 'complete actual report/successor counts')
    need(d['requiredUnavailableObservationCount'] == row['requiredUnavailableObservationCount'] == 0, 'required unavailable observations')
    need(trajectory['sourceBankFingerprint'] == row['originalBankFingerprint'] and len(obs) == 14, 'trajectory origin and count')
    for rate in [44100, 48000]:
        need([r['checkpoint'] for r in reports if r['sampleRate'] == rate] == CHECKPOINTS, 'all seven checkpoint identities independently at each native rate')
        need(sorted((o['checkpoint'] for o in obs if o['sampleRate'] == rate)) == sorted(CHECKPOINTS), 'all seven observation identities at each rate')
        need(type(d['renderedPhraseCounts'][str(rate)]) is int and max((c['phraseIndex'] for c in entry['checkpoints'])) < d['renderedPhraseCounts'][str(rate)] <= 128, 'actual rendering reaches last checkpoint and successor within bound')
    need(Counter(map(report_key, reports)) == Counter(map(receipt_key, receipts)), 'complete exact successor tuple Counter/multiplicity')
    for r in reports:
        candidate = r['selectedCandidateEvidence']
        ev = r['candidateEvaluation']
        commit = r['commitProvenance']
        need(r['engineVersion'] == ev['engineVersion'] == engine and ev['boundsValid'] is True, 'current engine and candidate bounds')
        need(set(candidate['hardGates']) == HARD_GATES and all((v is True for v in candidate['hardGates'].values())), 'all complete hard gates independently')
        need(type(r['correctionRenderCount']) is int and 0 <= r['correctionRenderCount'] <= 1, 'two-render bound')
        need(type(ev['sourceAttemptCount']) is int and ev['sourceAttemptCount'] == len(ev['attempts']) <= 2 and (ev['sourceAttemptCount'] > 0), 'complete attempts and two renders')
        need(type(ev['selectedAttemptIndex']) is int and 0 <= ev['selectedAttemptIndex'] < len(ev['attempts']), 'selected actual attempt')
        need(commit['selectedSampleHash'] == r['sampleHash'] and commit['candidateEvaluationFingerprint'] == r['evidenceFingerprint'], 'selected PCM/evaluation commit binding')
        successors = [s for s in receipts if receipt_key(s) == report_key(r)]
        need(successors, 'actual source successor')
        for s in successors:
            need(s['firstBar']['sampleRate'] == r['sampleRate'] and s['successorIncomingRenderDSPFingerprint'] == commit['outgoingRenderDSPFingerprint'], 'exact next native render continuation')
        observations = [o for o in obs if o['sampleRate'] == r['sampleRate'] and o['checkpoint'] == r['checkpoint']]
        need(len(observations) == 1, 'one projected observation per native checkpoint')
        o = observations[0]
        need(o['engineVersion'] == engine and o['hardGatesPassed'] is True, 'actual projected hard gates')
        need(o['sourceMetricCount'] == len(o['metrics']) and len({x['metric'] for x in o['metrics']}) == len(o['metrics']), 'all unique actual metrics')
        for metric in o['metrics']:
            need(type(metric['value']) in (int, float) and math.isfinite(metric['value']), 'finite measured observation')
        projection = o['continuousModalSource']['projection']
        need(projection['checkpoint'] == r['checkpoint'] and projection['sampleRate'] == r['sampleRate'] and (projection['sourceReportFingerprint'] == r['evidenceFingerprint']), 'projection native/checkpoint/source identity')
        need(any((s['sourceIdentityFingerprint'] == o['continuousModalSource']['sourceIdentityFingerprint'] for s in successors)), 'projection actual source identity')
    return dict(ordinal=entry['ordinal'], rootSeed=entry['rootSeed'], partition=partition, bankFingerprint=row['originalBankFingerprint'], originalReports=14, actualSuccessors=14, requiredUnavailableObservations=0)


def verify_products(cohort, protocol, manifest, documents, artifacts, status, log,
                    source, engine):
    """Inspect recorded native products; caller must authenticate their cold origin."""
    need(cohort['gitHead'] == protocol['acceptedExecutionHead'] ==
         manifest['acceptedExecutionHead'] == source, 'original frozen source')
    need(cohort['historicalCohortsRetagged'] is False and
         manifest['historicalContextRetagged'] is False and
         protocol['archiveImport'] is False, 'no archive import or historical retag')
    need(protocol['sampleRates'] == [44100, 48000] and
         protocol['maximumPeakWorkingBytes'] == 128 * 1024 * 1024 and
         protocol['maximumRenderPasses'] == 2 and protocol['maximumPhrases'] == 128,
         'unchanged native rates and numeric/render/presentation bounds')
    need(manifest['acceptedExecutionInputObjects'] == protocol['acceptedExecutionInputObjects'] ==
         cohort['acceptedInputObjects'], 'frozen exact input objects')
    expected = [(part, entry) for part in ['development', 'holdout'] for entry in cohort[part]]
    need(len(cohort['development']) == 40 and len(cohort['holdout']) == 6 and
         len({entry['rootSeed'] for _, entry in expected}) == 46 and
         len({entry['ordinal'] for _, entry in expected}) == 46,
         '40 development and six disjoint holdout trajectories')
    rows = manifest['completedTrajectories']
    need(len(rows) == 46 and set(documents) == {entry['ordinal'] for _, entry in expected},
         'all 46 actual complete native trajectory products required')
    for row, (partition, entry) in zip(rows, expected):
        need(row['artifact'] == f'{partition}-ordinal-{entry["ordinal"]}.json',
             'exact original trajectory path')
        verify_trajectory(documents[entry['ordinal']], row, partition, entry, engine)
    need(type(status['exitCode']) is int and status['exitCode'] == 0 and
         status['actualInputsUnchanged'] is True and status['oneNativeTestPassed'] is True,
         'successful original terminal native receipt')
    need(hashlib.sha256(log).hexdigest() == status['originalLogSHA256'], 'original native log bytes')
    text = log.decode('utf-8')
    need(len(re.findall(r'✔ Test run with 1 test passed', text)) == 1 and
         'skipped' not in text.lower() and 'failed' not in text.lower(),
         'one actual native test without skip/failure')
    need(manifest['status'] == 'captured-not-activated' and
         manifest['freshCohortRendered'] is True and
         manifest['fitStatus'] == 'complete-offline-unqualified' and
         manifest['originalNativeReportCount'] == manifest['actualSuccessorReceiptCount'] == 644,
         'complete typed native producer result')
    q = artifacts['qualification']
    need(q == manifest['offlineContinuousQualification'] and
         q['status'] == 'offline-adversarial-and-holdout-passed-not-activated' and
         q['runtimeActivation'] is False and q['archiveImport'] is False,
         'original native qualification result')
    for partition, count in [('development', 40), ('holdout', 6)]:
        corpus = artifacts[partition]
        need(corpus['engineVersion'] == engine and
             corpus['sourceTrajectoryCount'] == len(corpus['trajectories']) == count and
             corpus['sourceObservationCount'] == count * 14, 'exact native corpus size and engine')
        actual = Counter(canonical(documents[entry['ordinal']]['continuousTrajectory'])
                         for entry in cohort[partition])
        need(Counter(canonical(t) for t in corpus['trajectories']) == actual,
             'complete corpus equals original actual native trajectory products')
    profile, suite, held = (artifacts[name] for name in ['profile', 'adversarial', 'holdoutVerdicts'])
    need(suite['schemaVersion'] == protocol['adversarialSchema'] and
         suite['suiteVersion'] == protocol['adversarialVersion'] and
         held['schemaVersion'] == protocol['holdoutSchema'] and
         held['qualificationVersion'] == protocol['holdoutVersion'],
         'current native adversarial and holdout schemas')
    need(profile['engineVersion'] == held['engineVersion'] == engine and
         profile['schemaVersion'] == protocol['profileSchema'] and
         profile['profileVersion'] == protocol['profileVersion'], 'current primary profile identity')
    need(len(suite['cases']) == 34 and len({c['scenario'] for c in suite['cases']}) == 34 and
         all(c['rejected'] is True and set(c['expectedReasons']).issubset(c['actualReasons'])
             for c in suite['cases']), 'all 34 original adversarial reason checks')
    need(suite['baselineAcceptanceCount'] == suite['sourceObservationCount'] == 560 and
         suite['liveBaselineAcceptanceCount'] == len(set(suite['liveBaselineObservationFingerprints'])) == 2,
         'all ordinary and two live baseline acceptance')
    need(held['acceptedObservationCount'] == held['sourceObservationCount'] == 84 and
         held['overlappingSourceBankCount'] == 0 and held['calibrationTrajectoryCount'] == 40 and
         held['holdoutTrajectoryCount'] == len(held['trajectories']) == 6,
         'complete independent holdout')
    need(all(t['acceptedObservationCount'] == t['sourceObservationCount'] == 14 and
             len(t['verdicts']) == 14 and not t['relationshipFailures'] and
             all(v['accepted'] is True and not v['failedMetrics'] and not v['reasons']
                 for v in t['verdicts']) for t in held['trajectories']),
         'every holdout verdict independently accepted')
    need({t['sourceBankFingerprint'] for t in held['trajectories']} ==
         {t['sourceBankFingerprint'] for t in artifacts['holdout']['trajectories']} and
         all(Counter((v['sampleRate'], v['checkpoint']) for v in t['verdicts']) ==
             Counter((rate, cp) for rate in [44100, 48000] for cp in CHECKPOINTS)
             for t in held['trajectories']), 'exact holdout source and native checkpoint coverage')
    need(q['profileFingerprint'] == suite['profileFingerprint'] == held['profileFingerprint'] and
         q['adversarialFingerprint'] == held['adversarialSuiteFingerprint'],
         'exact native qualification resource joins')
    # A narrow origin check never supplies later-source applicability, Long,
    # installed-resource, complete memory/deadline, platform, app or full-item authority.
    return dict(schema='autotechno-at0039-primary-original-product-verification.v1',
                source=source, engine=engine, trajectories=46, originalReports=644,
                actualSuccessors=644, adversarialCases=34, holdoutObservations=84,
                allSevenCheckpointsBothNativeRates=True, exactSuccessorTupleMultiplicity=True,
                originalNativeProductsConsistent=True, freshCaptureConstructed=False,
                sealedCandidateProductsDecoded=False, nativePredicatesReexecuted=False,
                currentSourceApplicabilityVerified=False, installedArtifactsVerified=False,
                longHorizonQualified=False, completeResourceQualification=False,
                fullPlatformQualified=False, runtimeQualification=False, item39Complete=False,
                profileFingerprint=q['profileFingerprint'],
                adversarialFingerprint=q['adversarialFingerprint'],
                holdoutFingerprint=q['holdoutFingerprint'])


def artifact_fingerprint(domain, raw):
    """Existing Swift StreamingFNV1a domain/string encoding over original JSON bytes."""
    name = domain.encode('utf-8')
    encoded = b'\xd0\x73' + len(name).to_bytes(8, 'little') + name
    encoded += b'\x73' + len(raw).to_bytes(8, 'little') + raw
    value = 0xcbf29ce484222325
    for byte in encoded:
        value = ((value ^ byte) * 0x100000001b3) & ((1 << 64) - 1)
    return f'{value:016x}'


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False)


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
                                        str(self.source_root), *args], text=True,
                                       stderr=subprocess.DEVNULL, timeout=30).strip()

    def inputs(self):
        """Authenticate the pinned pre-capture proof, not its reporting booleans."""
        need(re.fullmatch('[0-9a-f]{40}', self.source) is not None and
             re.fullmatch('[0-9a-f]{64}', self.cold_sha256) is not None,
             'exact frozen source and independently pinned cold proof required')
        proof_path = inside(self.evidence_root, self.cold_proof)
        raw = raw_file(proof_path)
        need(hashlib.sha256(raw).hexdigest() == self.cold_sha256, 'original cold proof SHA256')
        cold = strict(raw)
        need(cold['source'] == self.source and cold['captureStarted'] is False and
             cold['archiveImport'] is False and cold['historicalCohortsRetagged'] is False,
             'original pre-capture proof source and intent')
        need(Path(cold['frozenCheckout']).resolve() == self.source_root.resolve() and
             Path(cold['runner']).resolve() == (self.runner / 'runner').resolve(),
             'original checkout and executable paths')
        records = cold['files']
        need(isinstance(records, list) and len({r['archive'] for r in records}) == len(records),
             'unique original cold archives')
        lookup = {record['archive']: record for record in records}
        checked = {}
        def original(live, relative):
            archive = proof_path.parent / relative
            archive_relative = archive.relative_to(self.evidence_root).as_posix()
            record = lookup[archive_relative]
            data = archived_bytes(inside(self.evidence_root, archive_relative))
            current = raw_file(live)
            need(type(record['bytes']) is int and len(data) == record['bytes'] and
                 hashlib.sha256(data).hexdigest() == record['sha256'] and data == current,
                 'original cold archive byte/size/digest binding: ' + relative)
            checked[str(live)] = record['sha256']
        original(self.runner / 'build-metadata.json', 'runner/build-metadata.json.gz')
        original(self.runner / 'tracked-inputs.json', 'runner/tracked-inputs.json.gz')
        metadata = load(self.runner / 'build-metadata.json')
        need(sha(self.runner / 'build-metadata.json') == cold['buildMetadataSHA256'] and
             metadata['source'] == self.source and metadata['engine'] == cold_engine(cold),
             'original compiled source/build/engine')
        for name in ['selection-protocol.json', 'cohort.json', 'execution-protocol.json', 'preparation.json']:
            original(self.study / name, 'protocols/' + name + '.gz')
        for stage in ['freeze', 'replay', 'validate']:
            for suffix in ['-status.json', '-launch.json', '.log']:
                name = stage + suffix
                original(self.study / name, 'protocols/' + name + '.gz')
            receipt = load(self.study / (stage + '-status.json'))
            need(type(receipt['exitCode']) is int and receipt['exitCode'] == 0 and
                 receipt['actualInputsUnchanged'] is True and receipt['oneNativeTestPassed'] is True and
                 receipt['originalLogSHA256'] == sha(self.study / (stage + '.log')),
                 'original successful cold native stage')
        old_launch = archived_bytes(inside(self.evidence_root,
            (proof_path.parent / 'execution-start/execute-launch.json.gz').relative_to(self.evidence_root).as_posix()))
        need(raw_file(self.study / 'execute-launch.json') == old_launch,
             'original execution-start archive')
        launch = strict(old_launch)
        need(launch['source'] == self.source and launch['buildMetadataSHA256'] == cold['buildMetadataSHA256'] and
             launch['runnerSHA256'] == cold['runnerSHA256'], 'original execution source/build binding')
        need(self.git('rev-parse', 'HEAD') == self.source and
             not self.git('status', '--porcelain', '--untracked-files=all'), 'clean exact frozen source')
        tracked = load(self.runner / 'tracked-inputs.json')
        need(set(tracked) == set(self.git('ls-files').splitlines()), 'complete original tracked inventory')
        for relative, digest in tracked.items():
            path = inside(self.source_root, relative)
            need(sha(path) == digest and
                 hashlib.sha256(subprocess.check_output(['git', '-C', str(self.source_root),
                    'show', self.source + ':' + relative], timeout=30)).hexdigest() == digest,
                 'tracked bytes match published frozen Git: ' + relative)
        for group in ['sources', 'resources', 'objects', 'compilerSupport', 'modules', 'actualRuntimeResources']:
            need(isinstance(metadata[group], dict) and metadata[group], 'complete nonempty build input group')
            for name, digest in metadata[group].items():
                need(sha(name) == digest, 'actual compiled/runtime input drift: ' + group)
        for relative, digest in cold['actualGitBoundInputs'].items():
            need(sha(inside(self.source_root, relative)) == digest,
                 'original compiled source/test/resource Git bytes')
        need(sha(self.runner / 'runner') == cold['runnerSHA256'] == metadata['executableSHA256'],
             'original executable bytes')
        return dict(source=self.source, coldProofSHA256=self.cold_sha256,
                    buildMetadataSHA256=cold['buildMetadataSHA256'], runnerSHA256=cold['runnerSHA256'],
                    trackedInputs=len(tracked), inputCounts={k: len(metadata[k]) for k in
                        ['sources', 'resources', 'objects', 'compilerSupport', 'modules', 'actualRuntimeResources']},
                    originalColdOriginBound=True)


def cold_engine(cold):
    # The exact source and cold execution protocol, rather than a caller's engine label,
    # supply the version. This helper handles the original proof's schema without
    # adding a trusted current-engine field to that immutable historical document.
    source = Path(cold['frozenCheckout']) / 'Sources/AutoTechnoCore/QualityQualification.swift'
    matches = re.findall(r'"(autotechno-canonical-engine\.v\d+)"', source.read_text())
    need(len(set(matches)) == 1, 'one canonical frozen engine version')
    return matches[0]


def verify(context):
    before = context.inputs()
    terminal_path = inside(context.evidence_root, context.terminal_proof)
    terminal_raw = raw_file(terminal_path)
    need(re.fullmatch('[0-9a-f]{64}', context.terminal_sha256) is not None and
         hashlib.sha256(terminal_raw).hexdigest() == context.terminal_sha256,
         'independently pinned original terminal proof SHA256')
    original_terminal = strict(terminal_raw)
    need(original_terminal['source'] == context.source and
         original_terminal['buildMetadataSHA256'] == before['buildMetadataSHA256'] and
         original_terminal['runnerSHA256'] == before['runnerSHA256'],
         'original terminal source/build/runner binding')
    cohort = load(context.study / 'cohort.json')
    protocol = load(context.study / 'execution-protocol.json')
    manifest = load(context.study / 'capture/execution.json')
    for key, filename in [('frozenCohortBlob', 'cohort.json'), ('protocolBlob', 'execution-protocol.json'),
                          ('selectionProtocolBlob', 'selection-protocol.json')]:
        need(manifest[key] == context.git('hash-object', str(context.study / filename)),
             'exact frozen input blob: ' + key)
    documents = {}
    file_hashes = {}
    product_hashes = {str(terminal_path): context.terminal_sha256}
    product_hashes.update({str(context.study / name): sha(context.study / name)
                      for name in ['cohort.json', 'execution-protocol.json',
                                   'capture/execution.json', 'execute-status.json', 'execute.log']})
    for partition in ['development', 'holdout']:
        for entry in cohort[partition]:
            filename = f'{partition}-ordinal-{entry["ordinal"]}.json'
            path = inside(context.study / 'capture', filename)
            raw = raw_file(path)
            documents[entry['ordinal']] = strict(raw)
            file_hashes[filename] = hashlib.sha256(raw).hexdigest()
    original_rows = original_terminal['files']
    need(len(original_rows) == 46 and len({r['ordinal'] for r in original_rows}) == 46,
         'full independently preserved original terminal inventory')
    for row in original_rows:
        name = f'{row["partition"]}-ordinal-{row["ordinal"]}.json'
        need(name in file_hashes and file_hashes[name] == row['sha256'],
             'original preserved native trajectory SHA256')
        archive = inside(context.evidence_root, row['archive'])
        data = archived_bytes(archive)
        need(len(data) == row['bytes'] and hashlib.sha256(data).hexdigest() == row['sha256'],
             'original preserved native trajectory archive')
    filenames = dict(development='development-corpus.json', holdout='holdout-corpus.json',
                     profile='offline-profile.json', adversarial='continuous-adversarial-suite.json',
                     qualification='offline-continuous-qualification.json',
                     holdoutVerdicts='continuous-holdout-qualification.json')
    artifacts = {}
    raw_artifacts = {}
    for key, name in filenames.items():
        path = inside(context.study / 'capture', name)
        raw_artifacts[key] = raw_file(path)
        artifacts[key] = strict(raw_artifacts[key])
        product_hashes[str(path)] = hashlib.sha256(raw_artifacts[key]).hexdigest()
    q = artifacts['qualification']
    for key, field, domain in [
        ('profile', 'profileFingerprint', 'professional-quality-calibration-json.v3'),
        ('adversarial', 'adversarialFingerprint', 'professional-quality-adversarial-suite-json.v4'),
        ('holdoutVerdicts', 'holdoutFingerprint', 'professional-quality-holdout-qualification-json.v2')]:
        need(artifact_fingerprint(domain, raw_artifacts[key]) == q[field],
             'original native derived artifact byte fingerprint: ' + key)
    status = load(context.study / 'execute-status.json')
    log = raw_file(context.study / 'execute.log')
    need(status == original_terminal['nativeStatus'] and
         artifacts['qualification'] == original_terminal['offlineQualification'],
         'original preserved native terminal and derived qualification result')
    result = verify_products(cohort, protocol, manifest, documents, artifacts,
                             status, log, context.source, protocol['engineVersion'])
    need(context.inputs() == before, 'all cold/source/build/runtime inputs stable through audit')
    for name, digest in file_hashes.items():
        need(sha(context.study / 'capture' / name) == digest, 'native trajectory changed during audit')
    for name, digest in product_hashes.items():
        need(sha(name) == digest, 'native terminal product changed during verification')
    result.update(before, originalTerminalProofSHA256=context.terminal_sha256,
                  originalNativeLogSHA256=hashlib.sha256(log).hexdigest(),
                  productSHA256=product_hashes)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['source-root', 'study', 'runner', 'evidence-root']:
        parser.add_argument('--' + name, type=Path, required=True)
    for name in ['cold-proof', 'cold-sha256', 'source', 'terminal-proof', 'terminal-sha256']:
        parser.add_argument('--' + name, required=True)
    args = parser.parse_args()
    try:
        result = verify(Context(**vars(args)))
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as exc:
        print('AT-0039 primary verification refused: ' + str(exc))
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
