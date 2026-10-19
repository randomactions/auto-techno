"""Adversarial source/installation controls; synthetic data is never qualification."""
from dataclasses import asdict, replace
import json
import re
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import at0039_quality_applicability as q

ROOT = Path(__file__).resolve().parents[1]


def rehearsal_row(version=52):
    rows = [row for row in q.READINESS['transitions']
            if row['path'] == q.ENGINE52_REHEARSAL_OWNER and
            ('"autotechno-canonical-engine.v%d"' % version) in row['current']]
    assert len(rows) == 1
    return rows[0]


def fixture_compiled_engine(row):
    if row['path'] != q.ENGINE52_REHEARSAL_OWNER:
        return None
    return ('autotechno-canonical-engine.v57' if
            '"autotechno-canonical-engine.v57"' in row['current'] else
            'autotechno-canonical-engine.v56' if
            '"autotechno-canonical-engine.v56"' in row['current'] else
            'autotechno-canonical-engine.v55' if
            '\"autotechno-canonical-engine.v55\"' in row['current'] else
            'autotechno-canonical-engine.v54' if
            '"autotechno-canonical-engine.v54"' in row['current'] else
            'autotechno-canonical-engine.v52')


class LoaderTests(unittest.TestCase):
    def test_real_loaders_parse_with_three_resource_and_seal_bindings(self):
        for family, relative in q.LOADERS.items():
            body, names, seals = q.loader((ROOT / relative).read_bytes(), family)
            self.assertEqual(set(names), set(q.KINDS))
            self.assertEqual(set(seals), set(q.KINDS))
            self.assertIn('canonicalResourceData', body)

    def test_only_literals_and_full_line_comments_are_normalized(self):
        for family, relative in q.LOADERS.items():
            original = (ROOT / relative).read_bytes()
            changed = original + b'\n// New qualification provenance.\n'
            old_body, names, seals = q.loader(original, family)
            for name in names.values():
                changed = changed.replace(name.encode(), (name.rsplit('-v', 1)[0] + '-v90').encode())
            for field in q.BINDINGS[family]:
                import re
                changed = re.sub((field + r': String\? = (nil|"[0-9a-f]{16}")').encode(),
                                 (field + ': String? = "abcdef0123456789"').encode(), changed)
            self.assertEqual(q.loader(changed, family)[0], old_body)

    def test_expression_nil_duplicate_unsafe_or_nonliteral_resource_refused(self):
        current = (ROOT / q.LOADERS['primary']).read_bytes()
        # A qualified literal is an explicit parser fixture, independent of
        # whether the current engine's installed seals are present or nil.
        raw, count = re.subn(
            rb'(package static let expectedProfileFingerprint: String\? = )(nil|"[0-9a-f]{16}")',
            rb'\g<1>"abcdef0123456789"', current)
        self.assertEqual(count, 1)
        _, names, _ = q.loader(raw, 'primary')
        profile_name = names['profile'].encode()
        for changed in [
            raw.replace(b'"abcdef0123456789"', b'"abcdef0123456789" + ""'),
            raw.replace(b'"abcdef0123456789"', b'computeSeal()'),
            raw.replace(b'"abcdef0123456789"', b'nil /* unqualified */'),
            raw + b'\npackage static let expectedProfileFingerprint: String? = nil\n',
            raw.replace(profile_name, b'../foreign'),
            raw.replace(profile_name, b'professional-quality-primary-profile-v035'),
            raw + '\n// non-ASCII syntax \u2028\n'.encode(),
        ]:
            self.assertNotEqual(changed, raw, 'the adversarial fixture must actually mutate the binding')
            with self.subTest(changed=changed[-80:]), self.assertRaises(ValueError):
                q.loader(changed, 'primary')


class PrimaryRouteStrengtheningTests(unittest.TestCase):
    def test_only_the_exact_two_rate_assertions_can_strengthen_this_method(self):
        row = q.route_rows[0]
        q.validate_primary_route_template(row)
        for before, after in [("[8_000.0, 12_000.0]", "[44_100.0, 48_000.0]"),
                              ("== .unsupportedSampleRate", "== .available"),
                              ("#expect(!unsupported.requiresPreparedValidation)", "// assertion removed")]:
            changed = dict(row, current=row['current'].replace(before, after))
            self.assertNotEqual(changed['current'], row['current'])
            with self.assertRaises(ValueError): q.validate_primary_route_template(changed)
        for field, value in [('path', 'Tests/AutoTechnoCoreTests/Producer.swift'),
                             ('symbol', 'renderPreparedRoute'), ('original', row['original']+'// edited')]:
            with self.assertRaises(ValueError): q.validate_primary_route_template(dict(row, **{field: value}))

    def test_both_recorded_readiness_cuts_keep_other_owner_bytes_exact(self):
        current = (ROOT / q.PRIMARY_ROUTE_OWNER).read_bytes()
        rows = [row for row in q.READINESS['transitions'] if row['path'] == q.PRIMARY_ROUTE_OWNER
                and q.digest(row['original'].encode()) in
                (q.PRIMARY_ROUTE_ORIGINAL_SHA256, q.PRIMARY_ROUTE_BRIDGE_SHA256)]
        self.assertEqual(len(rows), 2)
        for row in rows:
            # Parser fixture only: actual historical Git/build binding is a
            # separate original-evidence audit, not a shallow-CI prerequisite.
            self.assertEqual(current.count(row['current'].encode()), 1)
            original = current.replace(row['current'].encode(), row['original'].encode())
            result = q.readiness_transition(original, current, q.PRIMARY_ROUTE_OWNER)
            self.assertFalse(result['actualInstalledPositiveNativeVerified'])
            with self.assertRaises(ValueError):
                q.readiness_transition(original, current+b'// unrelated producer change', q.PRIMARY_ROUTE_OWNER)

    def test_workflow_rate_matrix_requires_one_named_unskipped_native_execution(self):
        workflow = (ROOT / '.github/workflows/swift.yml').read_text()
        block = workflow.split('      - name: Verify current primary native and unsupported-rate readiness\n')[1].split('\n      - name: ')[0]
        self.assertIn('set -euo pipefail', block)
        self.assertIn("--filter 'PrimaryEvaluatorReadinessTests/installedPrimaryRetainsUnavailableLongHorizonHost'", block)
        self.assertNotIn('unsupported8KRouteStaysUnavailable', workflow)
        self.assertNotIn('unsupported12KRouteStaysUnavailable', workflow)
        code = block.split("<<'PYTHON'\n")[1].split('          PYTHON')[0]
        code = '\n'.join(line[10:] for line in code.splitlines())+'\n'
        name = 'Current qualified artifact seals determine host readiness'
        positive = f'◇ Test "{name}" started.\n✔ Test "{name}" passed after 0.1 seconds.\n✔ Test run with 1 test passed after 0.1 seconds.\n'
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'native.log'
            for text, accepted in [(positive, True),
                ('✔ Test run with 0 tests passed after 0.1 seconds.\n', False),
                (positive.replace(name, 'Foreign control'), False),
                (positive.replace('passed after 0.1', 'failed after 0.1', 1), False),
                (positive+'✘ Test had an issue\n', False),
                ('✔ Test run with 0 tests passed after 0.1 seconds.\n'+positive, False)]:
                path.write_text(text)
                child = subprocess.run([__import__('sys').executable, '-', str(path)], input=code,
                    text=True, capture_output=True, cwd=ROOT)
                self.assertEqual(child.returncode == 0, accepted, child.stderr)


class SourceClosureTests(unittest.TestCase):
    """Real Git/filesystem controls around explicitly synthetic native artifacts."""
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.old = self.base / 'old'
        self.target = self.base / 'target'
        self.runner = self.base / 'runner'
        self.runner.mkdir()
        self.old.mkdir()
        for relative, raw in {
            'Package.swift': b'// Synthetic package fixture\n',
            'Sources/AutoTechnoCore/Example.swift': b'struct Example {}\n',
            'Sources/AutoTechnoTransport/Example.swift': b'struct Transport {}\n',
            'Tests/AutoTechnoCoreTests/Producer.swift': b'// original producer\n',
            q.RESOURCES + 'historical.json': b'{"historical":true}\n',
            **{relative: (ROOT / relative).read_bytes() for relative in q.LOADERS.values()},
        }.items():
            p = self.old / relative
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(raw)
        sources = {str(p): q.primary.sha(p) for p in self.old.rglob('*.swift')
                   if p.name != 'Package.swift'}
        resources = {str(p): q.primary.sha(p) for p in (self.old / q.RESOURCES).iterdir()}
        (self.runner / 'build-metadata.json').write_text(json.dumps(dict(sources=sources, resources=resources)))
        import shutil
        shutil.copytree(self.old, self.target)
        self.artifacts = {}
        self.names = {}
        for family, relative in q.LOADERS.items():
            original = (self.target / relative).read_bytes()
            _, names, old_seals = q.loader(original, family)
            seals, products = {}, {}
            import re
            for i, (kind, name) in enumerate(names.items()):
                new_name = name.rsplit('-v', 1)[0] + '-v90'
                self.names[family, kind] = q.RESOURCES + new_name + '.json'
                original = original.replace(name.encode(), new_name.encode())
                products[kind] = json.dumps({'synthetic': family, 'kind': kind}).encode()
                seals[kind] = str(i + (1 if family == 'primary' else 4)) * 16
                (self.target / self.names[family, kind]).write_bytes(products[kind] + b'\n')
                field = q.BINDINGS[family][i]
                original = re.sub((field + r': String\? = (nil|"[0-9a-f]{16}")').encode(),
                    (field + ': String? = "' + seals[kind] + '"').encode(), original)
            (self.target / relative).write_bytes(original)
            self.artifacts[family] = dict(seals=seals, bytes=products)
        self.git('init', '-q')
        self.git('add', '.')
        self.commit()
        self.context = q.primary.Context(self.old, self.base / 'study', self.runner,
            self.base, 'cold.json', 'a'*64, 'b'*40, 'terminal.json', 'c'*64)

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.target), *args], stderr=subprocess.DEVNULL)

    def commit(self):
        self.git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                 'commit', '-qm', 'Synthetic contract fixture')
        self.source = self.git('rev-parse', 'HEAD').decode().strip()

    def check(self):
        return q.source_installation(self.target, self.source, (self.context, self.context), self.artifacts)

    def change(self, relative, data):
        (self.target / relative).write_bytes(data)
        self.git('add', '.')
        self.commit()

    def test_synthetic_literal_installation_source_closure(self):
        result = self.check()
        self.assertEqual(result['compiledProductionSources'], 4)
        self.assertEqual(len(result['installedResources']['primary']), 3)
        self.assertNotIn('item39Complete', result)

    def test_compiled_musical_source_change_refused(self):
        self.change('Sources/AutoTechnoCore/Example.swift', b'struct Changed {}\n')
        with self.assertRaisesRegex(ValueError, 'compiled source/test changed'):
            self.check()

    def test_compiled_producer_change_refused(self):
        self.change('Tests/AutoTechnoCoreTests/Producer.swift', b'// relaxed assertions\n')
        with self.assertRaisesRegex(ValueError, 'compiled source/test changed'):
            self.check()

    def test_package_change_refused(self):
        self.change('Package.swift', b'// altered dependency/settings\n')
        with self.assertRaisesRegex(ValueError, 'package/compiler/dependency'):
            self.check()

    def test_added_production_source_refused(self):
        self.change('Sources/AutoTechnoCore/Extra.swift', b'struct Extra {}\n')
        with self.assertRaisesRegex(ValueError, 'complete compiled production'):
            self.check()

    def test_unbound_c_source_refused(self):
        self.change('Sources/AutoTechnoCore/Extra.c', b'int extra;\n')
        with self.assertRaisesRegex(ValueError, 'unbound non-Swift'):
            self.check()

    def test_untracked_and_ignored_extra_swift_refused(self):
        self.change('.gitignore', b'Extra.swift\n')
        (self.target / 'Sources/AutoTechnoCore/Extra.swift').write_text('struct Extra {}\n')
        with self.assertRaisesRegex(ValueError, 'complete compiled production'):
            self.check()

    def test_dirty_and_wrong_head_refused(self):
        (self.target / 'Package.swift').write_text('dirty')
        with self.assertRaisesRegex(ValueError, 'clean exact target'):
            self.check()
        with self.assertRaisesRegex(ValueError, 'clean exact target'):
            q.clean_head(self.target, '0'*40)

    def test_loader_guard_change_refused(self):
        p = self.target / q.LOADERS['long']
        self.change(q.LOADERS['long'], p.read_bytes().replace(b'guard let', b'if let', 1))
        with self.assertRaisesRegex(ValueError, 'loader changed beyond'):
            self.check()

    def test_unsealed_installation_refused(self):
        p = self.target / q.LOADERS['long']
        self.change(q.LOADERS['long'], p.read_bytes().replace(b'"4444444444444444"', b'nil'))
        with self.assertRaisesRegex(ValueError, 'installed seals'):
            self.check()

    def test_foreign_seals_refused(self):
        p = self.target / q.LOADERS['primary']
        self.change(q.LOADERS['primary'], p.read_bytes().replace(b'"1111111111111111"', b'"aaaaaaaaaaaaaaaa"'))
        with self.assertRaisesRegex(ValueError, 'installed seals'):
            self.check()

    def test_native_bytes_mismatch_and_extra_lf_refused(self):
        rel = self.names['primary', 'profile']
        for raw in (b'{"passed":true}', self.artifacts['primary']['bytes']['profile'] + b'\n\n'):
            self.change(rel, raw)
            with self.assertRaisesRegex(ValueError, 'installed bytes differ'):
                self.check()

    def test_exact_native_bytes_without_packaging_lf_accepted(self):
        self.change(self.names['primary', 'profile'], self.artifacts['primary']['bytes']['profile'])
        self.check()

    def test_historical_resource_overwrite_refused(self):
        self.change(q.RESOURCES + 'historical.json', b'{"changed":true}\n')
        with self.assertRaisesRegex(ValueError, 'historical resource bytes'):
            self.check()

    def test_added_foreign_resource_refused(self):
        self.change(q.RESOURCES + 'foreign.json', b'{}')
        with self.assertRaisesRegex(ValueError, 'unqualified added resource'):
            self.check()

    def test_removed_historical_resource_refused(self):
        self.git('rm', q.RESOURCES + 'historical.json')
        self.commit()
        with self.assertRaisesRegex(ValueError, 'removed historical'):
            self.check()

    def test_symlink_resource_refused(self):
        p = self.target / self.names['long', 'profile']
        p.unlink()
        p.symlink_to(self.target / self.names['primary', 'profile'])
        self.git('add', '.')
        self.commit()
        with self.assertRaisesRegex(ValueError, 'symlink'):
            self.check()

    def test_duplicate_physical_compiler_input_alias_refused(self):
        p = self.old / 'Sources/AutoTechnoCore/Example.swift'
        with self.assertRaisesRegex(ValueError, 'duplicate normalized'):
            q.relative_inputs(self.context, {str(p): q.primary.sha(p), str(p.parent / '.' / p.name) + '/../Example.swift': q.primary.sha(p)})

    def test_complete_source_closure_admits_only_declared_readiness_transition(self):
        metadata = json.loads((self.runner / 'build-metadata.json').read_text())
        for row in q.READINESS['transitions'][:5]:
            old, current = self.old / row['path'], self.target / row['path']
            old.parent.mkdir(parents=True, exist_ok=True)
            current.parent.mkdir(parents=True, exist_ok=True)
            old.write_text('unchanged capture predicates\n' + row['original'])
            current.write_text('unchanged capture predicates\n' + row['current'])
            metadata['sources'][str(old)] = q.primary.sha(old)
        engine_path = 'Sources/AutoTechnoCore/QualityQualification.swift'
        for base in (self.old, self.target):
            (base / engine_path).write_text('let engine = "autotechno-canonical-engine.v52"\n')
        metadata['sources'][str(self.old / engine_path)] = q.primary.sha(self.old / engine_path)
        (self.runner / 'build-metadata.json').write_text(json.dumps(metadata))
        self.git('add', '.')
        self.commit()
        result = self.check()
        self.assertEqual(len(result['nonCaptureReadinessTransitions']), 6)
        self.assertTrue(all(not row['actualInstalledPositiveNativeVerified']
                            for row in result['nonCaptureReadinessTransitions']))
        relative = q.READINESS['transitions'][0]['path']
        self.change(relative, (self.target / relative).read_bytes().replace(
            b'unchanged capture predicates', b'relaxed capture predicates'))
        with self.assertRaisesRegex(ValueError, 'exceeds the exact'):
            self.check()


    def test_rehearsal_source_closure_reads_the_bound_engine_owner(self):
        row = rehearsal_row(52)
        metadata = json.loads((self.runner / 'build-metadata.json').read_text())
        for base, field in ((self.old, 'original'), (self.target, 'current')):
            path = base / row['path']
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(row[field])
            engine = base / 'Sources/AutoTechnoCore/QualityQualification.swift'
            engine.write_text('let engine = "autotechno-canonical-engine.v51"\n')
        for relative in (row['path'], 'Sources/AutoTechnoCore/QualityQualification.swift'):
            metadata['sources'][str(self.old / relative)] = q.primary.sha(self.old / relative)
        (self.runner / 'build-metadata.json').write_text(json.dumps(metadata))
        self.git('add', '.')
        self.commit()
        with self.assertRaisesRegex(ValueError, 'compiled engine52'):
            self.check()

    def test_engine54_transition_reads_actual_compiled_engine_and_digest(self):
        row = rehearsal_row(54)
        metadata = json.loads((self.runner / 'build-metadata.json').read_text())
        for base, field in ((self.old, 'original'), (self.target, 'current')):
            path = base / row['path']
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('unchanged capture owner\n' + row[field])
        metadata['sources'][str(self.old / row['path'])] = q.primary.sha(self.old / row['path'])
        relative = 'Sources/AutoTechnoCore/QualityQualification.swift'
        for engine in ('52', '54'):
            for base in (self.old, self.target):
                (base / relative).write_text('let engine = "autotechno-canonical-engine.v' + engine + '"\n')
            metadata['sources'][str(self.old / relative)] = q.primary.sha(self.old / relative)
            (self.runner / 'build-metadata.json').write_text(json.dumps(metadata))
            self.git('add', '.')
            self.commit()
            if engine == '52':
                with self.assertRaisesRegex(ValueError, 'compiled engine54'):
                    self.check()
            else:
                result = self.check()
                self.assertEqual(len(result['nonCaptureReadinessTransitions']), 2)
                self.assertTrue(all(not r['actualInstalledPositiveNativeVerified']
                                    for r in result['nonCaptureReadinessTransitions']))
        metadata['sources'][str(self.old / relative)] = '0' * 64
        (self.runner / 'build-metadata.json').write_text(json.dumps(metadata))
        with self.assertRaisesRegex(ValueError, 'original input changed'):
            self.check()


class AuthorityTests(unittest.TestCase):
    def test_generic_passed_json_cannot_select_or_bypass_native_readers(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'request.json'
            path.write_text('{"passed":true,"item39Complete":true}')
            with patch.object(q.primary, 'verify') as native, self.assertRaisesRegex(ValueError, 'closed applicability'):
                q.verify(Path(directory), path, q.primary.sha(path))
            native.assert_not_called()

    def test_context_selector_rejects_injected_passed_result_and_relative_root(self):
        ctx = q.primary.Context(Path('/original'), Path('/study'), Path('/runner'), Path('/private'),
            'cold.json', 'a'*64, 'b'*40, 'terminal.json', 'c'*64)
        value = {k: str(v) for k, v in asdict(ctx).items()}
        self.assertEqual(q.context_from_request(value, q.primary.Context), ctx)
        with self.assertRaises(ValueError):
            q.context_from_request(dict(value, passed=True), q.primary.Context)
        with self.assertRaises(ValueError):
            q.context_from_request(dict(value, source_root='relative'), q.primary.Context)

    def test_missing_complete_originals_propagate_before_source_applicability(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            ctx = q.primary.Context(root, root, root, root, 'cold.json', 'a'*64, 'b'*40, 'terminal.json', 'c'*64)
            value = {k: str(v) for k, v in asdict(ctx).items()}
            path = root / 'request.json'
            path.write_text(json.dumps(dict(schema=q.SCHEMA, targetSource='b'*40, primary=value, long=value)))
            with patch.object(q, 'clean_head'), patch.object(q, 'verify_implementation'), \
                 patch.object(q.primary.Context, 'inputs', return_value={}), \
                 patch.object(q.long.Context, 'inputs', return_value={}), \
                 patch.object(q.primary, 'verify', side_effect=ValueError('missing complete native terminal')), \
                 patch.object(q.long, 'verify') as lverify, patch.object(q, 'source_installation') as closure:
                with self.assertRaisesRegex(ValueError, 'missing complete native terminal'):
                    q.verify(root, path, q.primary.sha(path))
                lverify.assert_not_called()
                closure.assert_not_called()

    def test_synthetic_orchestration_calls_both_original_readers_and_never_completes_item(self):
        # Only call-order/result-scope control; mocked native verification is not evidence.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            ctx = q.primary.Context(root, root, root, root, 'cold.json', 'a'*64, 'b'*40, 'terminal.json', 'c'*64)
            value = {k: str(v) for k, v in asdict(ctx).items()}
            path = root / 'request.json'
            path.write_text(json.dumps(dict(schema=q.SCHEMA, targetSource='b'*40, primary=value, long=value)))
            for fail_long, change_target in ((False, False), (True, False), (False, True)):
                with self.subTest(fail_long=fail_long, change_target=change_target), \
                     patch.object(q, 'clean_head'), patch.object(q, 'verify_implementation'), \
                     patch.object(q.primary.Context, 'inputs', return_value={}), \
                     patch.object(q.long.Context, 'inputs', return_value={}), \
                     patch.object(q.primary, 'verify', return_value={'engine': 'synthetic'}) as pv, \
                     patch.object(q.long, 'verify', side_effect=ValueError('incomplete Long') if fail_long else None) as lv, \
                     patch.object(q, 'native_artifacts', return_value=({}, {})), \
                     patch.object(q, 'source_installation', side_effect=[{'targetSource': 'b'*40},
                         {'targetSource': 'c'*40 if change_target else 'b'*40}]) as closure:
                    if fail_long or change_target:
                        with self.assertRaisesRegex(ValueError, 'incomplete Long|target source/resource inventory changed'):
                            q.verify(root, path, q.primary.sha(path))
                    else:
                        result = q.verify(root, path, q.primary.sha(path))
                        self.assertTrue(result['currentQualitySourceApplicabilityVerified'])
                        self.assertTrue(result['sourceResourceInstallationVerified'])
                        for key in ('completeResourceQualification', 'fullPlatformQualified',
                                    'installedArtifactsVerified', 'runtimeQualification', 'item39Complete'):
                            self.assertIs(result[key], False)
                    pv.assert_called_once()
                    lv.assert_called_once()
                    self.assertEqual(closure.call_count, 0 if fail_long else 2)

    def test_long_primary_seals_cannot_inherit_foreign_primary_qualification(self):
        p = dict(originalNativeProductsConsistent=True, originalColdOriginBound=True,
                 engine=q.long.RECOVERY.engine_version, profileFingerprint='1'*16, adversarialFingerprint='2'*16,
                 holdoutFingerprint='3'*16)
        l = dict(originalNativeProductsConsistent=True, originalByteContextAuthenticated=True,
                 originalNativeExecutionBound=True, engine=q.long.RECOVERY.engine_version, originalFormat='v22-recovery')
        with patch.object(q.long.Context, 'inputs', return_value={'formatKey': q.long.RECOVERY.key, 'protocol': {'primarySeals': ['0'*16]*3}}):
            ctx = q.long.Context(Path('/a'), Path('/b'), Path('/c'), Path('/d'), '', '', '', '', '')
            with self.assertRaisesRegex(ValueError, 'Long study must use'):
                q.native_artifacts(None, ctx, p, l)

    def test_legacy_long_format_cannot_supply_current_applicability(self):
        p = dict(originalNativeProductsConsistent=True, originalColdOriginBound=True, engine=q.long.RECOVERY.engine_version)
        l = dict(originalNativeProductsConsistent=True, originalByteContextAuthenticated=True,
                 originalNativeExecutionBound=True, engine=q.long.RECOVERY.engine_version, originalFormat='v21')
        with self.assertRaisesRegex(ValueError, 'exact recovery-study format'):
            q.native_artifacts(None, None, p, l)


class NativeArtifactByteTests(unittest.TestCase):
    """Synthetic extraction controls after (not replacing) native verification."""
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.pstudy = self.root / 'primary'
        self.lstudy = self.root / 'long'
        self.lrunner = self.root / 'runner'
        for p in (self.pstudy / 'capture', self.lstudy, self.lrunner):
            p.mkdir(parents=True)
        self.pcontext = q.primary.Context(self.root, self.pstudy, self.root, self.root,
            'cold.json', 'a'*64, 'b'*40, 'pterminal.json', 'c'*64)
        self.lcontext = q.long.Context(self.root, self.lstudy, self.lrunner, self.root,
            'cold.json', 'a'*64, 'b'*40, 'lterminal.json', 'c'*64)
        self.presult = dict(originalNativeProductsConsistent=True, originalColdOriginBound=True,
            engine=q.long.RECOVERY.engine_version, profileFingerprint='1'*16, adversarialFingerprint='2'*16,
            holdoutFingerprint='3'*16, productSHA256={})
        for name in ('offline-profile.json', 'continuous-adversarial-suite.json',
                     'continuous-holdout-qualification.json'):
            p = self.pstudy / 'capture' / name
            p.write_bytes(b'{"synthetic":true}')
            self.presult['productSHA256'][str(p)] = q.primary.sha(p)
        primary_rows = []
        for ordinal in range(46):
            partition = 'development' if ordinal < 40 else 'holdout'
            filename = f'{partition}-ordinal-{ordinal}.json'
            path = self.pstudy / 'capture' / filename
            path.write_bytes(b'{"synthetic":true}')
            primary_rows.append(dict(partition=partition, ordinal=ordinal,
                                     **self.archive('capture/' + filename, path)))
        primary_terminal = self.root / 'pterminal.json'
        primary_terminal.write_text(json.dumps({'files': primary_rows}))
        primary_digest = q.primary.sha(primary_terminal)
        self.pcontext = replace(self.pcontext, terminal_sha256=primary_digest)
        self.presult['productSHA256'][str(primary_terminal)] = primary_digest
        self.lresult = dict(originalNativeProductsConsistent=True, originalByteContextAuthenticated=True,
            originalNativeExecutionBound=True, engine=q.long.RECOVERY.engine_version, originalFormat='v22-recovery')
        rows = []
        for key, filename in q.long.RECOVERY.artifacts.items():
            p = self.lstudy / filename
            p.write_text(json.dumps({'fingerprint': '4'*16, 'synthetic': key}))
            rows.append(self.archive('study/' + filename, p))
        for name in ('execution-launch.json', 'execution-status.json', 'execution.log'):
            p = self.lrunner / name
            p.write_bytes(b'synthetic original')
            rows.append(self.archive('runner/' + name, p))
        (self.root / 'lterminal.json').write_text(json.dumps({'files': rows}))
        self.inputs = dict(formatKey='v22-recovery', protocol=dict(developmentRoots=[], holdoutRoots=[],
                            primarySeals=['1'*16, '2'*16, '3'*16]))

    def archive(self, relative, p):
        import gzip
        name = p.name + '.gz'
        (self.root / name).write_bytes(gzip.compress(p.read_bytes(), mtime=0))
        return dict(path=relative, archive=name, encoding='gzip', bytes=p.stat().st_size,
                    sha256=q.primary.sha(p))

    def extract(self):
        with patch.object(q.long.Context, 'inputs', return_value=self.inputs):
            return q.native_artifacts(self.pcontext, self.lcontext, self.presult, self.lresult)

    def test_exact_native_products_and_full_stability_inventory(self):
        products, stable = self.extract()
        self.assertEqual(products['primary']['seals']['profile'], '1'*16)
        self.assertEqual(products['long']['seals']['profile'], '4'*16)
        self.assertTrue(all(q.primary.sha(p) == digest for p, digest in stable.items()))
        self.assertIn(str(self.lrunner / 'execution.log'), stable)
        self.assertIn(str(self.root / 'execution.log.gz'), stable)

    def test_engine52_extraction_requires_the_distinct_matching_cold_format(self):
        self.presult['engine']=self.lresult['engine']=q.long.UPPER_COLOR.engine_version
        self.lresult['originalFormat']=self.inputs['formatKey']=q.long.UPPER_COLOR.key
        products,stable=self.extract()
        self.assertEqual(products['long']['seals']['profile'],'4'*16)
        self.assertIn(str(self.lrunner/'execution.log'),stable)
        self.inputs['formatKey']=q.long.RECOVERY.key
        with self.assertRaisesRegex(ValueError,'cold format'):
            self.extract()
        self.inputs['formatKey']=q.long.UPPER_COLOR.key
        self.lresult['originalFormat']=q.long.RECOVERY.key
        with self.assertRaisesRegex(ValueError,'same engine'):
            self.extract()

    def test_primary_product_changed_after_original_verification_refused(self):
        (self.pstudy / 'capture/offline-profile.json').write_bytes(b'{"changed":true}')
        with self.assertRaisesRegex(ValueError, 'primary native product changed'):
            self.extract()

    def test_long_product_changed_after_original_verification_refused(self):
        (self.lstudy / q.long.RECOVERY.artifacts['profile']).write_bytes(b'{"changed":true}')
        with self.assertRaises(ValueError):
            self.extract()

    def test_long_preservation_archive_changed_refused(self):
        import gzip
        (self.root / (q.long.RECOVERY.artifacts['profile'] + '.gz')).write_bytes(
            gzip.compress(b'{"changed":true}', mtime=0))
        with self.assertRaisesRegex(ValueError, 'original archive digest'):
            self.extract()


class ReadinessTransitionTests(unittest.TestCase):
    def test_engine57_transition_retains_native_identity_and_all_exact_predicates(self):
        row = rehearsal_row(57)
        self.assertEqual(q.digest(row['original'].encode()), q.ENGINE57_REHEARSAL_ORIGINAL_SHA256)
        self.assertEqual(row['original'], rehearsal_row(56)['current'])
        self.assertEqual(row['current'], row['original'].replace(
            '"autotechno-canonical-engine.v56"', '"autotechno-canonical-engine.v57"'))
        self.assertIn('"6697de8de20cbdf6"', row['current'])
        q.validate_rehearsal_identity_template(row)
        result = q.readiness_transition(row['original'].encode(), row['current'].encode(),
            row['path'], compiled_engine='autotechno-canonical-engine.v57')
        self.assertFalse(result['actualInstalledPositiveNativeVerified'])
        for old, new in [('15_600', '0'), ('500_000', '500_001'),
                         ('"unavailable"', '"available"'),
                         ('6697de8de20cbdf6', '0000000000000000'),
                         ('report.omittedBarCount == 0', 'report.omittedBarCount >= 0')]:
            changed = dict(row, current=row['current'].replace(old, new))
            with self.subTest(old=old), self.assertRaises(ValueError):
                q.validate_rehearsal_identity_template(changed)
        for version in [None, 51, 52, 54, 55, 56, 58]:
            engine = None if version is None else 'autotechno-canonical-engine.v' + str(version)
            with self.subTest(engine=engine), self.assertRaisesRegex(ValueError, 'compiled engine57'):
                q.readiness_transition(row['original'].encode(), row['current'].encode(),
                    row['path'], compiled_engine=engine)
        for version in [52, 54, 55, 56]:
            older = rehearsal_row(version)
            with self.subTest(version=version), self.assertRaises(ValueError):
                q.readiness_transition(older['original'].encode(), row['current'].encode(),
                    row['path'], compiled_engine='autotechno-canonical-engine.v57')

    def test_engine57_preserves_all_eight_historical_templates_exactly(self):
        import hashlib
        packed = json.dumps(q.READINESS['transitions'][:8], sort_keys=True, separators=(',', ':')).encode()
        self.assertEqual(hashlib.sha256(packed).hexdigest(), 'abc6fdb2fcf76c7bfddd0ee978a2b3c746cd36621bb2cba48a964544b001cc18')
        self.assertEqual(q.READINESS['schema'], 'autotechno-at0039-noncapture-readiness-transitions.v8')

    def test_engine56_transition_retains_native_identity_and_all_exact_predicates(self):
        row = rehearsal_row(56)
        self.assertEqual(q.digest(row['original'].encode()), q.ENGINE56_REHEARSAL_ORIGINAL_SHA256)
        self.assertEqual(row['original'], rehearsal_row(55)['current'])
        self.assertEqual(row['current'], row['original'].replace(
            '"autotechno-canonical-engine.v55"', '"autotechno-canonical-engine.v56"'))
        self.assertIn('"6697de8de20cbdf6"', row['current'])
        q.validate_rehearsal_identity_template(row)
        result = q.readiness_transition(row['original'].encode(), row['current'].encode(),
            row['path'], compiled_engine='autotechno-canonical-engine.v56')
        self.assertFalse(result['actualInstalledPositiveNativeVerified'])
        for old, new in [('15_600', '0'), ('500_000', '500_001'),
                         ('"unavailable"', '"available"'),
                         ('6697de8de20cbdf6', '0000000000000000'),
                         ('report.omittedBarCount == 0', 'report.omittedBarCount >= 0')]:
            changed = dict(row, current=row['current'].replace(old, new))
            with self.subTest(old=old), self.assertRaises(ValueError):
                q.validate_rehearsal_identity_template(changed)
        for version in [None, 51, 52, 54, 55, 57]:
            engine = None if version is None else 'autotechno-canonical-engine.v' + str(version)
            with self.subTest(engine=engine), self.assertRaisesRegex(ValueError, 'compiled engine56'):
                q.readiness_transition(row['original'].encode(), row['current'].encode(),
                    row['path'], compiled_engine=engine)
        for version in [52, 54, 55]:
            older = rehearsal_row(version)
            with self.subTest(version=version), self.assertRaises(ValueError):
                q.readiness_transition(older['original'].encode(), row['current'].encode(),
                    row['path'], compiled_engine='autotechno-canonical-engine.v56')

    def test_engine56_catalogue_preserves_all_seven_historical_templates_exactly(self):
        import hashlib
        packed = json.dumps(q.READINESS['transitions'][:7], sort_keys=True,
                            separators=(',', ':')).encode()
        self.assertEqual(hashlib.sha256(packed).hexdigest(),
            'fedc63ba1bae79b44b81031f0d2ed752d6b8c18c704b5fedf8e487e567d885e1')
        self.assertEqual(q.READINESS['schema'],
            'autotechno-at0039-noncapture-readiness-transitions.v8')

    def test_engine55_transition_changes_only_version_after_unchanged_native_identity(self):
        row=rehearsal_row(55)
        self.assertEqual(q.digest(row['original'].encode()),q.ENGINE55_REHEARSAL_ORIGINAL_SHA256)
        self.assertEqual(row['current'],row['original'].replace(
            '"autotechno-canonical-engine.v54"','"autotechno-canonical-engine.v55"'))
        self.assertIn('"6697de8de20cbdf6"',row['original'])
        self.assertIn('"6697de8de20cbdf6"',row['current'])
        q.validate_rehearsal_identity_template(row)
        result=q.readiness_transition(row['original'].encode(),row['current'].encode(),
            row['path'],compiled_engine='autotechno-canonical-engine.v55')
        self.assertFalse(result['actualInstalledPositiveNativeVerified'])
        for old,new in [('15_600','0'),('500_000','500_001'),
                        ('"unavailable"','"available"'),
                        ('6697de8de20cbdf6','0000000000000000')]:
            with self.subTest(old=old),self.assertRaises(ValueError):
                q.validate_rehearsal_identity_template(dict(row,current=row['current'].replace(old,new)))
        for version in [None,52,54,56]:
            engine=None if version is None else 'autotechno-canonical-engine.v'+str(version)
            with self.subTest(engine=engine),self.assertRaisesRegex(ValueError,'compiled engine55'):
                q.readiness_transition(row['original'].encode(),row['current'].encode(),
                    row['path'],compiled_engine=engine)
        for version in [52,54]:
            old=rehearsal_row(version)
            with self.subTest(version=version),self.assertRaises(ValueError):
                q.readiness_transition(old['original'].encode(),row['current'].encode(),
                    row['path'],compiled_engine='autotechno-canonical-engine.v55')

    def test_engine54_entry_keeps_exact_original_method_and_all_nonidentity_guards(self):
        row = rehearsal_row(54)
        self.assertEqual(q.digest(row['original'].encode()),
                         '94090a7179958a2308effc6466948d0d71104dd5af74bc44a54e089d0e7a8d95')
        q.validate_rehearsal_identity_template(row)
        for old, new in [('15_600', '0'), ('500_000', '500_001'),
                         ('"unavailable"', '"available"'),
                         ('6697de8de20cbdf6', '0000000000000000'),
                         ('report.omittedBarCount == 0', 'report.omittedBarCount >= 0')]:
            changed = row['current'].replace(old, new)
            self.assertNotEqual(changed, row['current'])
            with self.subTest(value=old), self.assertRaises(ValueError):
                q.validate_rehearsal_identity_template(dict(row, current=changed))
        # Resealing both templates around a weakened generator is not a new
        # permitted original source. Its exact original digest stays mandatory.
        for field in ('original', 'current'):
            changed = dict(row)
            changed[field] = changed[field].replace('15_600', '0')
            with self.assertRaises(ValueError):
                q.validate_rehearsal_identity_template(changed)
        changed = dict(row, original=row['original'].replace('15_600', '0'),
                       current=row['current'].replace('15_600', '0'))
        with self.assertRaises(ValueError):
            q.validate_rehearsal_identity_template(changed)

    def test_engine54_entry_refuses_unbound_older_future_and_multihop_inputs(self):
        row = rehearsal_row(54)
        for engine in (None, 'autotechno-canonical-engine.v51',
                       'autotechno-canonical-engine.v52', 'autotechno-canonical-engine.v53',
                       'autotechno-canonical-engine.v55'):
            with self.subTest(engine=engine), self.assertRaisesRegex(ValueError, 'compiled engine54'):
                q.readiness_transition(row['original'].encode(), row['current'].encode(),
                                       row['path'], compiled_engine=engine)
        legacy = rehearsal_row(52)
        with self.assertRaises(ValueError):
            q.readiness_transition(legacy['original'].encode(), row['current'].encode(),
                                   row['path'], compiled_engine='autotechno-canonical-engine.v54')

    def test_only_nine_exact_forward_transitions_in_three_owners_are_admitted(self):
        for row in q.READINESS['transitions']:
            # Every surrounding byte stays exact, not just a file hash or label.
            original = b'prefix\n' + row['original'].encode() + b'\nsuffix'
            current = b'prefix\n' + row['current'].encode() + b'\nsuffix'
            result = q.readiness_transition(original, current, row['path'], compiled_engine=fixture_compiled_engine(row))
            self.assertEqual(result['symbol'], row['symbol'])
            self.assertFalse(result['actualInstalledPositiveNativeVerified'])
            for tampered in (current + b'changed capture helper', current.replace(b'#expect(', b'#expect(true || ', 1),
                             current + row['current'].encode(), original):
                with self.subTest(path=row['path']), self.assertRaises(ValueError):
                    q.readiness_transition(original, tampered, row['path'], compiled_engine=fixture_compiled_engine(row))

    def test_unlisted_test_and_reverse_transition_refuse(self):
        for row in q.READINESS['transitions']:
            with self.assertRaises(ValueError):
                q.readiness_transition(row['current'].encode(), row['original'].encode(), row['path'])
            with self.assertRaisesRegex(ValueError, 'compiled source/test changed'):
                q.readiness_transition(row['original'].encode(), row['current'].encode(),
                                      'Tests/AutoTechnoCoreTests/ProfessionalQualityCalibrationIntegrationTests.swift')

    def test_published_target_has_exact_current_templates_and_no_other_file_delta(self):
        self.assertEqual(len(q.READINESS['transitions']), 9)
        self.assertEqual(len({row['path'] for row in q.READINESS['transitions']}), 3)
        for relative in q.READINESS_OWNERS:
            raw = (ROOT / relative).read_text()
            rows = [row for row in q.READINESS['transitions'] if row['path'] == relative]
            latest = list({row['current']: row for row in rows if raw.count(row['current']) == 1}.values())
            self.assertEqual(len(latest), 1)
            self.assertNotIn(latest[0]['original'], raw)
            self.assertIn('allSatisfy', latest[0]['current'])
            if relative == q.ENGINE52_REHEARSAL_OWNER:
                self.assertIn('while state.memory.totalBars < 15_600', latest[0]['current'])
                self.assertIn('no-calibrated-long-horizon-policy', latest[0]['current'])
            else:
                self.assertIn('throws: LongHorizonProfessionalPolicyError.invalidEvidence', latest[0]['current'])
            self.assertIn('try ', latest[0]['current'])

    def test_unlisted_multihop_and_historical_admission_rollback_refuse(self):
        first, _, latest, _, _ = q.READINESS['transitions'][:5]
        self.assertEqual(first['current'], latest['original'])
        with self.assertRaises(ValueError):
            q.readiness_transition(first['original'].encode(), latest['current'].encode(), first['path'])
        for old, new in ((latest['current'], latest['original']),
                         (latest['original'], latest['current'].replace(
                             'throws: ProfessionalQualityCalibrationError.profileMismatch',
                             'throws: ProfessionalQualityCalibrationError.invalidIdentity'))):
            with self.assertRaises(ValueError):
                q.readiness_transition(old.encode(), new.encode(), latest['path'])

    def test_rehearsal_catalogue_cannot_declare_relaxed_generation_or_numeric_guards(self):
        row = rehearsal_row(52)
        q.validate_rehearsal_identity_template(row)
        for old, new in [('15_600', '0'), ('500_000', '500_001'),
                         ('"unavailable"', '"available"'), ('9cb5deaba047abf2', '0000000000000000')]:
            changed = row['current'].replace(old, new)
            self.assertNotEqual(changed, row['current'])
            with self.subTest(value=old), self.assertRaises(ValueError):
                q.validate_rehearsal_identity_template(dict(row, current=changed))

    def test_rehearsal_transition_refuses_unbound_or_engine51_source(self):
        row = rehearsal_row(52)
        for version in (None, 'autotechno-canonical-engine.v51', 'autotechno-canonical-engine.v53'):
            with self.subTest(version=version), self.assertRaisesRegex(ValueError, 'compiled engine52'):
                q.readiness_transition(row['original'].encode(), row['current'].encode(),
                                       row['path'], compiled_engine=version)
        for value in ('15_600', '500_000', 'no-calibrated-long-horizon-policy'):
            tampered = row['current'].replace(value, 'changed-gate')
            with self.subTest(value=value), self.assertRaises(ValueError):
                q.readiness_transition(row['original'].encode(), tampered.encode(), row['path'],
                                       compiled_engine='autotechno-canonical-engine.v52')

    def test_unchanged_compiler_inputs_remain_exact_outside_readiness_method(self):
        row = q.READINESS['transitions'][0]
        # A mutation to a calibration predicate elsewhere in the same owner refuses.
        original = b'func capture() { requireGate() }\n' + row['original'].encode()
        current = b'func capture() { skipGate() }\n' + row['current'].encode()
        with self.assertRaisesRegex(ValueError, 'exceeds the exact'):
            q.readiness_transition(original, current, row['path'], compiled_engine=fixture_compiled_engine(row))


class PrimaryInstallationScopeTests(unittest.TestCase):
    """Real Git/byte controls, with explicitly synthetic artifacts, never native proof."""
    def setUp(self):
        fixture = SourceClosureTests('test_synthetic_literal_installation_source_closure')
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        self.fixture = fixture
        long_path = q.LOADERS['long']
        (fixture.target / long_path).write_bytes((fixture.old / long_path).read_bytes())
        for kind in q.KINDS:
            (fixture.target / fixture.names['long', kind]).unlink()
        fixture.git('add', '-A'); fixture.commit()

    def check(self):
        f = self.fixture
        return q.primary_source_installation(f.target, f.source, f.context,
                                             {'primary': f.artifacts['primary']})

    def test_primary_prerequisite_leaves_unqualified_long_unchanged(self):
        result = self.check()
        self.assertEqual(set(result['installedResources']), {'primary'})
        self.assertEqual(len(result['installedResources']['primary']), 3)
        self.assertNotIn('currentQualitySourceApplicabilityVerified', result)

    def test_primary_artifacts_cannot_supply_the_full_two_study_installation(self):
        f = self.fixture
        with self.assertRaisesRegex(ValueError, 'both native artifact families'):
            q.source_installation(f.target, f.source, (f.context,),
                                  {'primary': f.artifacts['primary']})

    def test_primary_scope_cannot_select_a_long_artifact_family(self):
        f = self.fixture
        with self.assertRaisesRegex(ValueError, 'only the verified primary'):
            q.primary_source_installation(f.target, f.source, f.context, f.artifacts)

    def test_unselected_long_loader_comment_or_binding_mutation_refuses(self):
        f = self.fixture
        path = q.LOADERS['long']
        f.change(path, b'// Unselected Long change\n' + (f.target / path).read_bytes())
        with self.assertRaisesRegex(ValueError, 'unselected loader must remain byte-exact'):
            self.check()

    def test_new_long_resource_cannot_hide_as_a_primary_prerequisite(self):
        f = self.fixture
        f.change(q.RESOURCES + 'long-horizon-professional-profile-v91.json', b'{"not-qualified":true}')
        with self.assertRaisesRegex(ValueError, 'unqualified added resource'):
            self.check()

    def test_changed_primary_packaging_bytes_refuse(self):
        f = self.fixture
        f.change(f.names['primary', 'profile'], f.artifacts['primary']['bytes']['profile'] + b'\n\n')
        with self.assertRaisesRegex(ValueError, 'beyond one packaging LF'):
            self.check()

    def test_historical_resource_cannot_be_replaced_in_primary_scope(self):
        self.fixture.change(q.RESOURCES + 'historical.json', b'{"overwritten":true}')
        with self.assertRaisesRegex(ValueError, 'historical resource bytes'):
            self.check()

    def test_primary_prerequisite_cannot_change_compiled_musical_source(self):
        self.fixture.change('Sources/AutoTechnoCore/Example.swift', b'struct Altered {}\n')
        with self.assertRaisesRegex(ValueError, 'compiled source/test changed'):
            self.check()


class PrimaryPrerequisiteOriginalByteTests(unittest.TestCase):
    """Synthetic originals exercise archive mutation, never qualify real products."""
    def setUp(self):
        import gzip
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name); self.study = self.root / 'study'
        (self.study / 'capture').mkdir(parents=True)
        self.context = q.primary.Context(self.root, self.study, self.root, self.root,
            'cold.json', 'a'*64, 'b'*40, 'terminal.json', 'c'*64)
        self.result = dict(originalNativeProductsConsistent=True, originalColdOriginBound=True,
            profileFingerprint='1'*16, adversarialFingerprint='2'*16,
            holdoutFingerprint='3'*16, productSHA256={})
        for filename in ('offline-profile.json', 'continuous-adversarial-suite.json',
                         'continuous-holdout-qualification.json'):
            path = self.study / 'capture' / filename
            path.write_bytes(b'{"synthetic":true}')
            self.result['productSHA256'][str(path)] = q.primary.sha(path)
        self.rows = []
        for ordinal in range(46):
            partition = 'development' if ordinal < 40 else 'holdout'
            filename = f'{partition}-ordinal-{ordinal}.json'
            path = self.study / 'capture' / filename; path.write_bytes(b'{"synthetic":true}')
            archive = self.root / (filename + '.gz')
            archive.write_bytes(gzip.compress(path.read_bytes(), mtime=0))
            self.rows.append(dict(partition=partition, ordinal=ordinal, bytes=path.stat().st_size,
                                  sha256=q.primary.sha(path), archive=archive.name))
        self.write_terminal()

    def write_terminal(self):
        path = self.root / 'terminal.json'; path.write_text(json.dumps({'files': self.rows}))
        self.result['productSHA256'][str(path)] = q.primary.sha(path)
        self.context = replace(self.context, terminal_sha256=q.primary.sha(path))

    def extract(self):
        return q.primary_native_artifacts(self.context, self.result)

    def test_primary_bytes_and_all46_archive_bindings_are_retained(self):
        data, stable = self.extract()
        self.assertEqual(set(data), {'primary'})
        self.assertEqual(set(data['primary']['bytes']), set(q.KINDS))
        self.assertTrue(all(q.primary.sha(path) == digest for path, digest in stable.items()))
        self.assertIn(str(self.root / self.rows[-1]['archive']), stable)

    def test_failed_original_verification_cannot_extract_installation_bytes(self):
        self.result['originalNativeProductsConsistent'] = False
        with self.assertRaisesRegex(ValueError, 'complete original primary native'):
            self.extract()

    def test_missing_trajectory_archive_cannot_supply_a_primary_prerequisite(self):
        self.rows.pop(); self.write_terminal()
        with self.assertRaisesRegex(ValueError, 'complete original primary trajectory'):
            self.extract()

    def test_duplicate_ordinal_or_changed_partition_refuses(self):
        for mutation in ('duplicate', 'partition'):
            with self.subTest(mutation=mutation):
                old = dict(self.rows[-1])
                self.rows[-1]['ordinal' if mutation == 'duplicate' else 'partition'] = (
                    self.rows[0]['ordinal'] if mutation == 'duplicate' else 'development')
                self.write_terminal()
                with self.assertRaisesRegex(ValueError, 'complete original primary trajectory'):
                    self.extract()
                self.rows[-1] = old

    def test_changed_primary_product_after_native_verification_refuses(self):
        (self.study / 'capture/offline-profile.json').write_bytes(b'{"changed":true}')
        with self.assertRaisesRegex(ValueError, 'primary native product changed'):
            self.extract()

    def test_changed_original_trajectory_after_verification_refuses(self):
        (self.study / 'capture/development-ordinal-0.json').write_bytes(b'{"changed":true}')
        with self.assertRaisesRegex(ValueError, 'original primary trajectory changed'):
            self.extract()

    def test_changed_archived_trajectory_after_verification_refuses(self):
        import gzip
        (self.root / self.rows[0]['archive']).write_bytes(gzip.compress(b'{"changed":true}', mtime=0))
        with self.assertRaisesRegex(ValueError, 'original primary trajectory archive changed'):
            self.extract()


    def test_terminal_proof_cannot_change_after_original_verification(self):
        (self.root / 'terminal.json').write_text(json.dumps({'files': self.rows, 'forged': True}))
        with self.assertRaisesRegex(ValueError, 'primary terminal proof binding changed'):
            self.extract()

    def test_boolean_archive_size_cannot_alias_one_byte(self):
        self.rows[0]['bytes'] = True
        self.write_terminal()
        with self.assertRaisesRegex(ValueError, 'original primary trajectory archive changed'):
            self.extract()

    def test_missing_original_archive_refuses(self):
        (self.root / self.rows[0]['archive']).unlink()
        with self.assertRaises(ValueError):
            self.extract()


    def test_capture_parent_alias_cannot_substitute_original_product_paths(self):
        original = self.study / 'capture'
        moved = self.root / 'aliased-capture'
        original.rename(moved)
        original.symlink_to(moved, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'evidence symlink or escaped path'):
            self.extract()


class PrimaryPrerequisiteAuthorityTests(unittest.TestCase):
    def request(self, root):
        ctx = q.primary.Context(root, root, root, root,
            'cold.json', 'a'*64, 'b'*40, 'terminal.json', 'c'*64)
        value = {key: str(val) for key, val in asdict(ctx).items()}
        path = root / 'request.json'
        path.write_text(json.dumps(dict(schema=q.PRIMARY_INSTALLATION_SCHEMA,
                                        targetSource='b'*40, primary=value)))
        return path

    def test_generic_passed_result_and_two_study_request_refuse_primary_mode(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); path = self.request(root)
            for value in ({'passed': True}, dict(json.loads(path.read_bytes()), long={})):
                path.write_text(json.dumps(value))
                with patch.object(q.primary, 'verify') as native, self.assertRaisesRegex(ValueError, 'closed primary-installation'):
                    q.verify_primary_installation(root, path, q.primary.sha(path))
                native.assert_not_called()

    def test_primary_prerequisite_request_cannot_enter_final_verification(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); path = self.request(root)
            with patch.object(q.primary, 'verify') as native, self.assertRaisesRegex(ValueError, 'closed applicability'):
                q.verify(root, path, q.primary.sha(path))
            native.assert_not_called()

    def test_incomplete_original_primary_refuses_before_installation_check(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); path = self.request(root)
            with patch.object(q, 'clean_head'), patch.object(q, 'verify_implementation'), \
                 patch.object(q.primary.Context, 'inputs', return_value={}), \
                 patch.object(q.primary, 'verify', side_effect=ValueError('incomplete original primary')), \
                 patch.object(q, 'primary_source_installation') as install:
                with self.assertRaisesRegex(ValueError, 'incomplete original primary'):
                    q.verify_primary_installation(root, path, q.primary.sha(path))
                install.assert_not_called()

    def test_complete_orchestration_has_only_primary_prerequisite_authority(self):
        # Call-order/scope control with mocked verification, never native evidence.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); path = self.request(root)
            with patch.object(q, 'clean_head'), patch.object(q, 'verify_implementation'), \
                 patch.object(q.primary.Context, 'inputs', return_value={}), \
                 patch.object(q.primary, 'verify', return_value={'engine': 'synthetic'}) as native, \
                 patch.object(q.long, 'verify') as long_native, \
                 patch.object(q, 'primary_native_artifacts', return_value=({}, {})), \
                 patch.object(q, 'primary_source_installation', return_value={'targetSource': 'b'*40}) as install:
                result = q.verify_primary_installation(root, path, q.primary.sha(path))
                native.assert_called_once(); long_native.assert_not_called()
                self.assertEqual(install.call_count, 2)
                self.assertTrue(result['primarySourceResourceInstallationVerified'])
                for key in ('currentQualitySourceApplicabilityVerified', 'bothCompleteNativeStudiesVerified',
                            'installedPositiveNativeExecutionVerified', 'installedArtifactsVerified',
                            'freshCaptureConstructed', 'sealedCandidateProductsDecoded', 'longHorizonQualified',
                            'completeResourceQualification', 'fullPlatformQualified', 'runtimeQualification', 'item39Complete'):
                    self.assertIs(result[key], False)

    def test_target_drift_between_original_and_final_checks_refuses(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); path = self.request(root)
            with patch.object(q, 'clean_head'), patch.object(q, 'verify_implementation'), \
                 patch.object(q.primary.Context, 'inputs', return_value={}), \
                 patch.object(q.primary, 'verify', return_value={'engine': 'synthetic'}), \
                 patch.object(q, 'primary_native_artifacts', return_value=({}, {})), \
                 patch.object(q, 'primary_source_installation', side_effect=[{'targetSource': 'b'*40}, {'targetSource': 'c'*40}]):
                with self.assertRaisesRegex(ValueError, 'target primary source/resource inventory changed'):
                    q.verify_primary_installation(root, path, q.primary.sha(path))


if __name__ == '__main__':
    unittest.main()
