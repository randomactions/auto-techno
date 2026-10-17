#!/usr/bin/env python3
"""Authenticate current quality-source applicability and committed derived bytes.

This read-only component invokes both complete original native-study verifiers.
Its request selects original evidence; it cannot supply a passed result. Only
the six literal artifact bindings in each existing loader and closed forward transitions in three existing
non-capture check owners may differ from the compiled studies.
No capture, installation, runtime or item completion occurs.
"""
from __future__ import annotations

import argparse
from dataclasses import fields
import hashlib
from pathlib import Path
import re
import subprocess
import sys

import at0039_primary_verification as primary
import at0039_long_verification as long

need = primary.need
SCHEMA = 'autotechno-at0039-quality-applicability-request.v1'
OWNERS = ('AutoTechnoCore', 'AutoTechnoDSP', 'AutoTechnoTransport')
RESOURCES = 'Sources/AutoTechnoDSP/Resources/'
LOADERS = {
    'primary': 'Sources/AutoTechnoDSP/ProfessionalQualityPrimaryArtifacts.swift',
    'long': 'Sources/AutoTechnoDSP/LongHorizonProfessionalPolicyArtifacts.swift',
}
BINDINGS = {
    'primary': ('expectedProfileFingerprint', 'expectedAdversarialSuiteFingerprint',
                'expectedHoldoutQualificationFingerprint'),
    'long': ('expectedProfileFingerprint', 'expectedAdversarialFingerprint',
             'expectedHoldoutFingerprint'),
}
KINDS = ('profile', 'adversarial', 'holdout')
RESOURCE_PREFIXES = {
    'primary': ('professional-quality-primary-profile',
                'professional-quality-primary-adversarial-suite',
                'professional-quality-primary-holdout'),
    'long': ('long-horizon-professional-profile', 'long-horizon-adversarial-suite',
             'long-horizon-holdout'),
}
READINESS_OWNERS = {
    'Tests/AutoTechnoCoreTests/PrimaryEvaluatorReadinessTests.swift':
        'installedPrimaryRetainsUnavailableLongHorizonHost',
    'Tests/AutoTechnoCoreTests/LongHorizonProfessionalPolicyTests.swift': 'bundledArtifacts',
    'Tests/AutoTechnoCoreTests/LongHorizonSignalTrajectoryTests.swift': 'eightHourTrajectoryIsBounded',
}
ENGINE52_REHEARSAL_OWNER = 'Tests/AutoTechnoCoreTests/LongHorizonSignalTrajectoryTests.swift'
def validate_rehearsal_identity_template(row):
    """No rehearsal generation or evidence predicate may change with its pins."""
    need(row['path'] == ENGINE52_REHEARSAL_OWNER and
         row['symbol'] == 'eightHourTrajectoryIsBounded', 'one synthetic rehearsal owner')
    code = lambda text: ''.join(line for line in text.splitlines(keepends=True)
                               if not line.lstrip().startswith('//'))
    expected = code(row['original'])
    for old, new in [('"autotechno-canonical-engine.v51"', '"autotechno-canonical-engine.v52"'),
                     ('"1e90955e389c8215"', '"9cb5deaba047abf2"')]:
        need(expected.count(old) == 1 and new not in expected,
             'one original versioned rehearsal identity pin')
        expected = expected.replace(old, new)
    need(code(row['current']) == expected,
         'rehearsal transition may change only its two versioned identity pins and comments')


READINESS_PATH = Path(__file__).with_name('at0039_readiness_transitions.json')
READINESS = primary.load(READINESS_PATH)
need(set(READINESS) == {'schema', 'transitions'} and
     READINESS['schema'] == 'autotechno-at0039-noncapture-readiness-transitions.v3' and
     type(READINESS['transitions']) is list and len(READINESS['transitions']) == 4,
     'closed built-in readiness transition catalogue')
need({row['path'] for row in READINESS['transitions']} == set(READINESS_OWNERS),
     'only the three declared non-capture check owners')
for row in READINESS['transitions']:
    need(set(row) == {'path', 'symbol', 'original', 'current'} and
         row['symbol'] == READINESS_OWNERS[row['path']] and
         all(type(row[k]) is str and 0 < len(row[k]) < 32768 for k in ('original', 'current')) and
         row['original'] != row['current'] and
         all(len(re.findall(r'\bfunc ' + re.escape(row['symbol']) + r'\(', row[k])) == 1
             for k in ('original', 'current')), 'exact bounded admission-test templates')
    if row['path'] == ENGINE52_REHEARSAL_OWNER:
        validate_rehearsal_identity_template(row)
IMPLEMENTATION = {str(Path(p).resolve()): primary.sha(p) for p in
                  (__file__, primary.__file__, long.__file__,
                   long.verify_history.__code__.co_filename, READINESS_PATH)}


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def git(root, *args):
    return subprocess.check_output(
        ['git', '-c', 'core.fsmonitor=false', '-C', str(root), *args],
        stderr=subprocess.DEVNULL, timeout=30)


def clean_head(root, source):
    need(re.fullmatch('[0-9a-f]{40}', source) is not None, 'exact target commit required')
    need(git(root, 'rev-parse', 'HEAD').decode().strip() == source and
         not git(root, 'status', '--porcelain', '--untracked-files=all').strip(),
         'clean exact target source required')


def tracked_bytes(root, source, relative):
    raw = primary.raw_file(primary.inside(root, relative))
    need(git(root, 'show', source + ':' + relative) == raw,
         'target bytes differ from committed Git: ' + relative)
    return raw


def verify_implementation(root, source):
    for path, checksum in IMPLEMENTATION.items():
        need(digest(tracked_bytes(root, source, 'scripts/' + Path(path).name)) == checksum,
             'verifier implementation differs from exact target Git')


def loader(raw, family):
    """Allow literal bindings, not edited decoder/control-flow expressions."""
    need(raw.isascii(), 'ASCII loader syntax required')
    text = raw.decode('ascii')
    # Full-line comments have no Swift effect. Inline code/comments remain exact.
    text = '\n'.join(line for line in text.split('\n')
                     if line.strip() and not line.lstrip().startswith('//'))
    names, seals = {}, {}
    for kind, prefix in zip(KINDS, RESOURCE_PREFIXES[family]):
        field = kind + 'Resource'
        pattern = (r'^[ \t]*package static let ' + field +
                   r'[ \t]*=[ \t]*\n?[ \t]*"(' + prefix + r'-v[1-9][0-9]*)"[ \t]*$')
        matches = list(re.finditer(pattern, text, re.MULTILINE))
        need(len(matches) == 1, 'one literal resource binding required: ' + field)
        names[kind] = matches[0].group(1)
        text = re.sub(pattern, 'package static let ' + field + ' = <resource>',
                      text, flags=re.MULTILINE)
    for kind, field in zip(KINDS, BINDINGS[family]):
        pattern = (r'^[ \t]*package static let ' + field +
                   r':[ \t]*String\?[ \t]*=[ \t]*(nil|"[0-9a-f]{16}")[ \t]*$')
        matches = list(re.finditer(pattern, text, re.MULTILINE))
        need(len(matches) == 1, 'one literal seal binding required: ' + field)
        value = matches[0].group(1)
        seals[kind] = None if value == 'nil' else value[1:-1]
        text = re.sub(pattern, 'package static let ' + field + ': String? = <seal>',
                      text, flags=re.MULTILINE)
    return text, names, seals


def relative_inputs(context, mapping):
    need(isinstance(mapping, dict) and mapping, 'nonempty authenticated input inventory')
    result = {}
    for name, checksum in mapping.items():
        need(type(name) is str and Path(name).is_absolute() and
             re.fullmatch('[0-9a-f]{64}', checksum) is not None,
             'absolute input path and SHA256 required')
        try:
            relative = Path(name).resolve().relative_to(context.source_root.resolve()).as_posix()
        except ValueError as exc:
            raise primary.VerificationError('compiled input outside original source') from exc
        need(relative not in result, 'duplicate normalized compiled input')
        need(primary.sha(primary.inside(context.source_root, relative)) == checksum,
             'original input changed during applicability check')
        result[relative] = checksum
    return result


def readiness_transition(original, current, relative, *, compiled_engine=None):
    """One forward transition; every byte outside the known method stays exact.

    These Testing checks are not called by the canonical capture entrypoints.
    The synthetic rehearsal transition additionally requires the exact compiled
    engine52 source; an engine51 study cannot receive its identity pins. No
    client-provided mapping, arbitrary test edit or rollback is accepted. Actual installed-positive native execution remains a separate gate.
    """
    if relative == ENGINE52_REHEARSAL_OWNER:
        need(compiled_engine == 'autotechno-canonical-engine.v52',
             'synthetic rehearsal identity transition requires compiled engine52')
    rows = [row for row in READINESS['transitions'] if row['path'] == relative and
            original.count(row['original'].encode()) == 1 and
            current.count(row['current'].encode()) == 1]
    need(len(rows) == 1, 'compiled source/test changed: ' + relative)
    row = rows[0]
    old, new = row['original'].encode(), row['current'].encode()
    need(original.count(old) == current.count(new) == 1 and
         new not in original and old not in current and
         original.replace(old, b'<declared-readiness-method>') ==
         current.replace(new, b'<declared-readiness-method>'),
         'change exceeds the exact non-capture readiness transition: ' + relative)
    return dict(path=relative, symbol=row['symbol'], originalSHA256=digest(original),
                currentSHA256=digest(current), actualInstalledPositiveNativeVerified=False)


def inventory(root, relative, *, swift_only=False):
    base = primary.inside(root, relative)
    need(base.is_dir(), 'required source directory missing')
    paths = set()
    for path in base.rglob('*'):
        need(not path.is_symlink(), 'symlink in source/resource inventory')
        if path.is_file() and (not swift_only or path.suffix == '.swift'):
            paths.add(path.relative_to(root).as_posix())
    return paths


def source_installation(root, source, contexts, artifacts):
    """Source/resource closure only; callers must first verify native originals."""
    clean_head(root, source)
    target = {}
    read = lambda rel: target.setdefault(rel, tracked_bytes(root, source, rel))
    target_sources = set().union(*(inventory(root, 'Sources/' + owner, swift_only=True)
                                   for owner in OWNERS))
    target_resources = inventory(root, RESOURCES)
    all_owned_files = set().union(*(inventory(root, 'Sources/' + owner) for owner in OWNERS))
    need(all_owned_files == target_sources | target_resources,
         'unbound non-Swift production input')
    installed = {}
    selected = set()
    readiness = []
    for family in LOADERS:
        body, names, seals = loader(read(LOADERS[family]), family)
        need(seals == artifacts[family]['seals'] and all(seals.values()),
             'installed seals must match complete native qualification: ' + family)
        installed[family] = dict(body=body, names=names, seals=seals)
        for kind in KINDS:
            relative = RESOURCES + names[kind] + '.json'
            selected.add(relative)
            raw = read(relative)
            original = artifacts[family]['bytes'][kind]
            canonical = raw[:-1] if raw.endswith(b'\n') else raw
            need(raw in (original, original + b'\n') and canonical == original,
                 'installed bytes differ from native artifact beyond one packaging LF: ' + relative)
    for context in contexts:
        metadata = primary.load(context.runner / 'build-metadata.json')
        sources = relative_inputs(context, metadata['sources'])
        production = {p for p in sources if any(p.startswith('Sources/' + o + '/') for o in OWNERS)}
        need(production == target_sources and all(any(p.startswith('Sources/' + o + '/')
             for p in production) for o in OWNERS), 'complete compiled production source inventory')
        need(all(p in production or p.startswith('Tests/') for p in sources),
             'unrecognized compiled source owner')
        package = primary.raw_file(primary.inside(context.source_root, 'Package.swift'))
        need(read('Package.swift') == package, 'package/compiler/dependency contract changed')
        for relative, checksum in sources.items():
            current = read(relative)
            if relative in LOADERS.values():
                family = next(k for k, value in LOADERS.items() if value == relative)
                original = primary.raw_file(primary.inside(context.source_root, relative))
                need(loader(original, family)[0] == installed[family]['body'],
                     'loader changed beyond literal installation bindings: ' + relative)
            else:
                if digest(current) != checksum:
                    original = primary.raw_file(primary.inside(context.source_root, relative))
                    compiled_engine = None
                    if relative == ENGINE52_REHEARSAL_OWNER:
                        engine_path = 'Sources/AutoTechnoCore/QualityQualification.swift'
                        engine_raw = primary.raw_file(primary.inside(context.source_root, engine_path))
                        need(sources.get(engine_path) == digest(engine_raw),
                             'rehearsal transition must bind the actual compiled engine owner')
                        versions = set(re.findall(rb'"(autotechno-canonical-engine\.v[0-9]+)"', engine_raw))
                        need(len(versions) == 1, 'one actual compiled canonical engine required')
                        compiled_engine = next(iter(versions)).decode('ascii')
                    transition = readiness_transition(original, current, relative,
                                                      compiled_engine=compiled_engine)
                    readiness.append(dict(studySource=context.source, **transition))
        resources = relative_inputs(context, metadata['resources'])
        need(all(p.startswith(RESOURCES) for p in resources), 'one original resource owner')
        need(set(resources) <= target_resources and target_resources - set(resources) <= selected,
             'removed historical or unqualified added resource')
        for relative, checksum in resources.items():
            need(digest(read(relative)) == checksum,
                 'historical resource bytes must remain unchanged: ' + relative)
    clean_head(root, source)
    need(all(tracked_bytes(root, source, name) == raw for name, raw in target.items()),
         'target source/resource bytes changed during applicability audit')
    return dict(targetSource=source, compiledProductionSources=len(target_sources),
                checkedSourceAndResourceSHA256={p: digest(raw) for p, raw in sorted(target.items())},
                installedResources={k: v['names'] for k, v in installed.items()},
                nonCaptureReadinessTransitions=readiness)


def context_from_request(value, cls):
    names = {field.name for field in fields(cls)}
    need(isinstance(value, dict) and set(value) == names and
         all(type(v) is str and v for v in value.values()), 'closed original-context selector required')
    value = dict(value)
    for name in ('source_root', 'study', 'runner', 'evidence_root'):
        need(Path(value[name]).is_absolute(), 'absolute owned context path required')
        value[name] = Path(value[name])
    need(re.fullmatch('[0-9a-f]{40}', value['source']) is not None and
         all(re.fullmatch('[0-9a-f]{64}', value[k]) is not None
             for k in ('cold_sha256', 'terminal_sha256')), 'original source and proof pins required')
    return cls(**value)


def native_artifacts(pcontext, lcontext, presult, lresult):
    need(presult['originalNativeProductsConsistent'] is True and
         presult['originalColdOriginBound'] is True and
         lresult['originalNativeProductsConsistent'] is True and
         lresult['originalByteContextAuthenticated'] is True and
         lresult['originalNativeExecutionBound'] is True,
         'both complete original native verifications required')
    fmt = long.bound_format(lresult['originalFormat'])
    need(fmt in (long.RECOVERY, long.UPPER_COLOR) and
         presult['engine'] == lresult['engine'] == fmt.engine_version,
         'same engine and exact recovery-study format required')
    inputs = lcontext.inputs()
    need(inputs.get('formatKey') == fmt.key, 'original cold format matches verified native result')
    seals = dict(zip(KINDS, (presult['profileFingerprint'], presult['adversarialFingerprint'],
                             presult['holdoutFingerprint'])))
    need(inputs['protocol']['primarySeals'] == list(seals.values()),
         'Long study must use the independently qualified installed primary seals')
    data = {'primary': dict(seals=seals, bytes={}), 'long': dict(seals={}, bytes={})}
    stable = dict(presult['productSHA256'])
    terminal = primary.load(primary.inside(lcontext.evidence_root, lcontext.terminal_proof))
    records = {r['path']: r for r in terminal['files']}
    long_paths = long.original_paths(lcontext, inputs)
    for kind, pfile, lkey in zip(KINDS,
            ('offline-profile.json', 'continuous-adversarial-suite.json',
             'continuous-holdout-qualification.json'), ('profile', 'adversarial', 'holdoutVerdicts')):
        path = pcontext.study / 'capture' / pfile
        raw = primary.raw_file(path)
        need(digest(raw) == presult['productSHA256'][str(path)], 'primary native product changed')
        data['primary']['bytes'][kind] = raw
        filename = fmt.artifacts[lkey]
        path = lcontext.study / filename
        long.authenticate_original(lcontext, records['study/' + filename], path)
        raw = primary.raw_file(path)
        data['long']['bytes'][kind] = raw
        data['long']['seals'][kind] = primary.strict(raw)['fingerprint']
    # Keep the complete native terminal inventory stable across source comparison.
    for context, rows, prefix in ((pcontext,
            primary.load(primary.inside(pcontext.evidence_root, pcontext.terminal_proof))['files'],
            'capture/'), (lcontext, terminal['files'], None)):
        for row in rows:
            if prefix is not None:
                name = f"{row['partition']}-ordinal-{row['ordinal']}.json"
                path = context.study / prefix / name
            else:
                path = long_paths[row['path']]
            need(primary.sha(path) == row['sha256'], 'original native product changed after verification')
            stable[str(path)] = row['sha256']
            archive = primary.inside(context.evidence_root, row['archive'])
            stable[str(archive)] = primary.sha(archive)
    for family in data.values():
        need(all(type(v) is str and re.fullmatch('[0-9a-f]{16}', v) is not None
                 for v in family['seals'].values()), 'native artifact seals required')
    return data, stable


def verify(root, request_path, request_sha256):
    need(re.fullmatch('[0-9a-f]{64}', request_sha256) is not None, 'independently pinned request required')
    raw = primary.raw_file(request_path)
    need(digest(raw) == request_sha256, 'request SHA256 mismatch')
    request = primary.strict(raw)
    need(isinstance(request, dict) and set(request) == {'schema', 'targetSource', 'primary', 'long'}
         and request['schema'] == SCHEMA, 'closed applicability request required; result JSON is not evidence')
    source = request['targetSource']
    clean_head(root, source)
    verify_implementation(root, source)
    pcontext = context_from_request(request['primary'], primary.Context)
    lcontext = context_from_request(request['long'], long.Context)
    pbefore, lbefore = pcontext.inputs(), lcontext.inputs()
    presult = primary.verify(pcontext)
    lresult = long.verify(lcontext)
    artifacts, products = native_artifacts(pcontext, lcontext, presult, lresult)
    closure = source_installation(root, source, (pcontext, lcontext), artifacts)
    need(pcontext.inputs() == pbefore and lcontext.inputs() == lbefore and
         all(primary.sha(path) == checksum for path, checksum in products.items()) and
         primary.raw_file(request_path) == raw and
         all(primary.sha(path) == checksum for path, checksum in IMPLEMENTATION.items()),
         'original/target/implementation/request context changed during audit')
    need(source_installation(root, source, (pcontext, lcontext), artifacts) == closure,
         'target source/resource inventory changed during final original-context checks')
    return dict(schema='autotechno-at0039-quality-applicability-verification.v2', **closure,
                requestSHA256=request_sha256, engine=presult['engine'],
                primaryOriginalSource=pcontext.source, longOriginalSource=lcontext.source,
                primaryTerminalProofSHA256=pcontext.terminal_sha256,
                longTerminalProofSHA256=lcontext.terminal_sha256,
                verificationImplementationSHA256=IMPLEMENTATION,
                currentQualitySourceApplicabilityVerified=True, sourceResourceInstallationVerified=True,
                installedArtifactsVerified=False,
                freshCaptureConstructed=False, sealedCandidateProductsDecoded=False,
                completeResourceQualification=False, fullPlatformQualified=False,
                runtimeQualification=False, item39Complete=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target-root', type=Path, required=True)
    parser.add_argument('--request', type=Path, required=True)
    parser.add_argument('--request-sha256', required=True)
    args = parser.parse_args()
    try:
        result = verify(args.target_root.resolve(), args.request, args.request_sha256)
    except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError) as exc:
        print('quality applicability unavailable: ' + str(exc), file=sys.stderr)
        return 1
    print(primary.canonical(result))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
