"""Adversarial source/installation controls; synthetic data is never qualification."""
from dataclasses import asdict
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import at0039_quality_applicability as q

ROOT = Path(__file__).resolve().parents[1]


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
        raw = (ROOT / q.LOADERS['primary']).read_bytes()
        for changed in [
            raw.replace(b'"267051f651dcfdca"', b'"267051f651dcfdca" + ""'),
            raw.replace(b'"267051f651dcfdca"', b'computeSeal()'),
            raw.replace(b'"267051f651dcfdca"', b'nil /* unqualified */'),
            raw + b'\npackage static let expectedProfileFingerprint: String? = nil\n',
            raw.replace(b'professional-quality-primary-profile-v35', b'../foreign'),
            raw.replace(b'professional-quality-primary-profile-v35', b'professional-quality-primary-profile-v035'),
            raw + '\n// non-ASCII syntax \u2028\n'.encode(),
        ]:
            with self.subTest(changed=changed[-80:]), self.assertRaises(ValueError):
                q.loader(changed, 'primary')


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
                 engine='e', profileFingerprint='1'*16, adversarialFingerprint='2'*16,
                 holdoutFingerprint='3'*16)
        l = dict(originalNativeProductsConsistent=True, originalByteContextAuthenticated=True,
                 originalNativeExecutionBound=True, engine='e', originalFormat='v22-recovery')
        with patch.object(q.long.Context, 'inputs', return_value={'protocol': {'primarySeals': ['0'*16]*3}}):
            ctx = q.long.Context(Path('/a'), Path('/b'), Path('/c'), Path('/d'), '', '', '', '', '')
            with self.assertRaisesRegex(ValueError, 'Long study must use'):
                q.native_artifacts(None, ctx, p, l)

    def test_legacy_long_format_cannot_supply_current_applicability(self):
        p = dict(originalNativeProductsConsistent=True, originalColdOriginBound=True, engine='e')
        l = dict(originalNativeProductsConsistent=True, originalByteContextAuthenticated=True,
                 originalNativeExecutionBound=True, engine='e', originalFormat='v21')
        with self.assertRaisesRegex(ValueError, 'current recovery-study format'):
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
            engine='synthetic', profileFingerprint='1'*16, adversarialFingerprint='2'*16,
            holdoutFingerprint='3'*16, productSHA256={})
        for name in ('offline-profile.json', 'continuous-adversarial-suite.json',
                     'continuous-holdout-qualification.json'):
            p = self.pstudy / 'capture' / name
            p.write_bytes(b'{"synthetic":true}')
            self.presult['productSHA256'][str(p)] = q.primary.sha(p)
        (self.root / 'pterminal.json').write_text('{"files":[]}')
        self.lresult = dict(originalNativeProductsConsistent=True, originalByteContextAuthenticated=True,
            originalNativeExecutionBound=True, engine='synthetic', originalFormat='v22-recovery')
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


if __name__ == '__main__':
    unittest.main()
