"""Bounded negative controls for actual exporter receipts; no synthetic qualification."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import baseline_producer_witness as producer
import baseline_dependency_contract as dependency
import test_baseline_dependency_contract as fixtures


class ProducerWitnessTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.image = self.root / 'AutoTechnoCoreTests'
        self.image.write_bytes(b'actual fixture image bytes')
        self.corpus_name = 'docs/local/private-corpus.json'
        path = self.root / self.corpus_name
        path.parent.mkdir(parents=True)
        self.corpus = {'cases': [{'id': 'private', 'rootSeed': 2**64 - 1}], 'routes': [
            {'id': 'native', 'sampleRate': 48000, 'channelCount': 2, 'routeGeneration': 3, 'routeRecovery': True}]}
        path.write_text(json.dumps(self.corpus))
        states = [{'id': 'private--native', 'rootSeedHex': 'ffffffffffffffff',
                   'sampleRate': 48000, 'channelCount': 2, 'routeGeneration': 3, 'routeRecovery': True,
                   'sessionStateFingerprint': '1'*16, 'renderStateFingerprint': '2'*16, 'graphStateFingerprint': '3'*16}]
        self.probe = {'schema': producer.PROBE_SCHEMA, 'probeOnly': True,
            'artifactCurrencyEstablished': False, 'promotionAuthorized': False,
            'compiledImagePath': str(self.image), 'compiledImageSha256': producer.file_hash(self.image),
            'captureCorpusPath': self.corpus_name, 'captureCorpusSha256': producer.file_hash(path),
            'captureEnvironmentSha256': 'a'*64, 'actualEnvironmentSha256': 'b'*64,
            'initialStateFingerprint': dependency.digest(states), 'initialStates': states,
            'actualArguments': ['native-testing-helper', '--testing-library', 'swift-testing'],
            'engineVersion': 'fixture-engine'}

    def validate(self, value=None):
        producer.validate_probe(self.root, value or self.probe, image=self.image, corpus_name=self.corpus_name)

    def test_exact_private_initialization_routes_and_unsigned_seed_are_preserved(self):
        self.validate()
        self.assertFalse(self.probe['artifactCurrencyEstablished'])

    def test_changed_loaded_image_rejects_even_when_source_label_same(self):
        self.image.write_bytes(b'other compiled image')
        with self.assertRaisesRegex(producer.ProducerWitnessError, 'freshly built'):
            self.validate()

    def test_substitute_host_image_rejects(self):
        value = copy.deepcopy(self.probe)
        value['compiledImagePath'] = str(self.root / 'host-runner')
        with self.assertRaises(producer.ProducerWitnessError): self.validate(value)

    def test_changed_private_corpus_and_duration_rejects(self):
        self.corpus['cases'][0]['resolvedBarCount'] = 8
        (self.root / self.corpus_name).write_text(json.dumps(self.corpus))
        with self.assertRaisesRegex(producer.ProducerWitnessError, 'corpus bytes'):
            self.validate()

    def test_resealed_missing_duplicate_or_false_state_routes_reject(self):
        for mutate in [lambda x: x.clear(), lambda x: x.append(copy.deepcopy(x[0])),
                       lambda x: x[0].update(rootSeedHex='7fffffffffffffff'),
                       lambda x: x[0].update(sampleRate=44100),
                       lambda x: x[0].update(routeRecovery=1),
                       lambda x: x[0].update(graphStateFingerprint='not-observed')]:
            value = copy.deepcopy(self.probe)
            mutate(value['initialStates'])
            value['initialStateFingerprint'] = dependency.digest(value['initialStates'])
            with self.assertRaises(producer.ProducerWitnessError): self.validate(value)

    def test_probe_cannot_claim_currency_or_promotion(self):
        for key in ['artifactCurrencyEstablished', 'promotionAuthorized', 'probeOnly']:
            value = copy.deepcopy(self.probe)
            value[key] = not value[key]
            with self.assertRaises(producer.ProducerWitnessError): self.validate(value)

    def test_missing_process_hash_or_arguments_rejects(self):
        for key in ['captureEnvironmentSha256', 'actualEnvironmentSha256', 'actualArguments']:
            value = copy.deepcopy(self.probe)
            del value[key]
            with self.assertRaises((producer.ProducerWitnessError, dependency.DependencyContractError, producer.transaction.CaptureTransactionError)):
                self.validate(value)

    def test_symlink_image_and_size_bound_reject(self):
        link = self.root / 'link'
        link.symlink_to(self.image)
        with self.assertRaises(producer.ProducerWitnessError): producer.file_hash(link)
        with self.assertRaises(producer.ProducerWitnessError): producer.file_hash(self.image, 2)

    def test_non_ascii_canonical_values_fail_closed(self):
        self.assertEqual(producer.ascii_canonical({'a/b': 'x'}), b'{"a/b":"x"}')
        with self.assertRaises(producer.ProducerWitnessError): producer.ascii_canonical({'path': 'caf\u00e9'})

    def test_independent_witness_refuses_manifest_and_declaration_tampering(self):
        artifact = 'docs/local/reports/manifest.json'
        (self.root / artifact).parent.mkdir(parents=True, exist_ok=True)
        (self.root / artifact).write_bytes(b'{"manifestVersion":1}')
        declared = {key: self.probe[key] for key in ['compiledImagePath', 'compiledImageSha256',
                    'captureCorpusSha256', 'captureEnvironmentSha256', 'initialStates']}
        declared.update(familyId='whole-mix-render', gitHead='0'*40,
                        contractBaselineFingerprint='c'*64, dependencySnapshotFingerprint='d'*64,
                        producerFingerprint='e'*64)
        witness = dict(declared, schema=producer.WITNESS_SCHEMA,
            qualification=dict(dependency.QUALIFICATION), actualArguments=['actual-exporter'],
            declarationSha256=hashlib.sha256(producer.ascii_canonical(declared)).hexdigest(),
            artifactSha256=producer.file_hash(self.root / artifact))
        producer.verify_witness(self.root, witness, declared, artifact_name=artifact, actual_arguments=['actual-exporter'])
        for key in ['artifactSha256', 'declarationSha256', 'producerFingerprint', 'actualArguments']:
            changed = copy.deepcopy(witness)
            changed[key] = ['other-command'] if key == 'actualArguments' else 'f'*64
            with self.assertRaises(producer.ProducerWitnessError):
                producer.verify_witness(self.root, changed, declared, artifact_name=artifact, actual_arguments=['actual-exporter'])
        (self.root / artifact).write_bytes(b'changed after producer')
        with self.assertRaises(producer.ProducerWitnessError):
            producer.verify_witness(self.root, witness, declared, artifact_name=artifact, actual_arguments=['actual-exporter'])

    def test_dirty_build_source_refuses_before_any_build(self):
        fixture = fixtures.DependencyContractTests()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        before = producer.source_freeze(fixture.root)
        fixture.write('Sources/Owner.swift', 'dirty')
        with self.assertRaisesRegex(producer.ProducerWitnessError, 'clean committed'):
            producer.require_same_source(fixture.root, before)

    def test_committed_source_movement_refuses_frozen_build_receipt(self):
        fixture = fixtures.DependencyContractTests()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        before = producer.source_freeze(fixture.root)
        fixture.write('Sources/Owner.swift', 'changed')
        fixture.capture()
        with self.assertRaisesRegex(producer.ProducerWitnessError, 'source changed'):
            producer.require_same_source(fixture.root, before)


if __name__ == '__main__': unittest.main()
