import re
import unittest
from windows_test_plan import plan


class NativeWindowsBankPlanTests(unittest.TestCase):
    def fixture(self):
        return {'xctest': 'AutoTechnoCoreTests.TrimTests/testTrim\n',
                'swift-testing': '\n'.join(['AutoTechnoCoreTests.RecoveryTests/initial()',
                    'AutoTechnoCoreTests.RecoveryTests/continuation()',
                    'AutoTechnoCoreTests.RecoveryTestsExtra/notTheSameSuite()',
                    'AutoTechnoCoreTests.ParityTests/compare()',
                    'OtherTests.ParityTests/another()'])}

    def test_partition_is_exhaustive_disjoint_and_order_independent(self):
        inputs = self.fixture()
        rows = [plan(inputs, i, 8) for i in range(8)]
        selected = [(suite['library'], case) for row in rows for suite in row['selected']
                    for case in suite['identifiers']]
        expected = {(library, case) for library, text in inputs.items() for case in text.splitlines()}
        self.assertEqual(set(selected), expected)
        self.assertEqual(len(selected), len(expected))
        self.assertEqual(len({row['discoverySHA256'] for row in rows}), 1)
        for i, row in enumerate(rows):
            self.assertFalse(row['nativeExecutionProven'])
            reversed_inputs = {key: '\n'.join(reversed(value.splitlines())) for key,value in inputs.items()}
            self.assertEqual(row, plan(reversed_inputs, i, 8))

    def test_selectors_match_only_the_complete_owner(self):
        inputs = self.fixture()
        selected = plan(inputs, 0, 1)['selected']
        for suite in selected:
            actual = {case for case in inputs[suite['library']].splitlines()
                      if re.search(suite['selector'], case)}
            self.assertEqual(actual, set(suite['identifiers']))
            for case in suite['identifiers']:
                self.assertRegex(case.replace('/', '.'), suite['selector'])

    def test_large_owner_is_distributed_without_losing_or_splitting_methods(self):
        inputs = self.fixture()
        inputs['swift-testing'] = '\n'.join(
            f'{module}.HeavyTests/case{index}(sampleRate:)'
            for module in ['FirstTests', 'SecondTests'] for index in range(128))
        rows = [plan(inputs, bank, 8) for bank in range(8)]
        self.assertEqual({row['schema'] for row in rows}, {'autotechno-windows-test-bank-plan.v2'})
        self.assertEqual({row['partitionUnit'] for row in rows}, {'discovered-test-identity'})
        owners = {}
        for row in rows:
            selected = [item for item in row['selected'] if item['suite'] == 'HeavyTests']
            self.assertEqual(len(selected), 1)
            for case in selected[0]['identifiers']:
                owners.setdefault(case.split('/', 1)[1], []).append(row['bank'])
        self.assertEqual(len(owners), 128)
        self.assertTrue(all(len(banks) == 2 and banks[0] == banks[1] for banks in owners.values()))
        self.assertEqual({row['discoveredSuites'] for row in rows}, {2})
        self.assertEqual({row['discoveredIdentifiers'] for row in rows}, {257})

    def test_every_bank_selector_matches_only_its_discovered_methods(self):
        inputs = self.fixture()
        inputs['swift-testing'] += '\n' + '\n'.join([
            'AutoTechnoCoreTests.RecoveryTests/initial(value:)',
            'AutoTechnoCoreTests.RecoveryTests/initialExtra()',
        ])
        for bank in range(8):
            for item in plan(inputs, bank, 8)['selected']:
                candidates = inputs[item['library']].splitlines()
                self.assertEqual({case for case in candidates if re.search(item['selector'], case)},
                                 set(item['identifiers']))
                for case in item['identifiers']:
                    self.assertRegex(case + '/TestFile.swift:20:3', item['selector'])
                    self.assertNotRegex(case + 'Extra', item['selector'])
                    self.assertNotRegex(case.replace(item['suite'] + '/', item['suite'] + 'Unexpected/', 1), item['selector'])

    def test_complete_method_token_is_escaped_and_source_suffix_supported(self):
        inputs = {'xctest': 'AutoTechnoCoreTests.TrimTests/testTrim',
                  'swift-testing': 'AutoTechnoCoreTests.OwnerTests/fault(rate:mode:)'}
        item = next(item for item in plan(inputs, 0, 1)['selected']
                    if item['library'] == 'swift-testing')
        self.assertRegex(inputs['swift-testing'], item['selector'])
        self.assertRegex(inputs['swift-testing'] + '/Fixture.swift:42:5', item['selector'])
        self.assertNotRegex('AutoTechnoCoreTests.OwnerTests/faultXrate:mode:Y', item['selector'])
        self.assertNotRegex(inputs['swift-testing'] + 'Suffix', item['selector'])

    def test_default_windows_assignment_is_unchanged_by_optional_isolation(self):
        import hashlib
        for bank in range(8):
            for row in plan(self.fixture(), bank, 8)['selected']:
                for case in row['identifiers']:
                    identity = row['library'] + ':' + row['suite'] + '/' + case.split('/', 1)[1]
                    expected = int.from_bytes(hashlib.sha256(identity.encode()).digest()[:8], 'big') % 8
                    self.assertEqual(bank, expected)
        for value, banks in [('', 8), (True, 8), ('swift-testing:OwnerTests/heavy()', 1)]:
            with self.assertRaises(ValueError):
                plan(self.fixture(), 0, banks, isolated_identity=value)

    def test_multiple_isolation_refuses_ambiguous_or_exhausted_banks(self):
        for identities, banks in [('invalid', 8), ([True], 8), ([''], 8),
                                  (['a', 'a'], 8), (['a', 'b'], 2)]:
            with self.assertRaises(ValueError):
                plan(self.fixture(), 0, banks, isolated_identities=identities)
        with self.assertRaises(ValueError):
            plan(self.fixture(), 0, 8, isolated_identity='a', isolated_identities=['b'])
        for bank in range(8):
            self.assertEqual(plan(self.fixture(), bank, 8, isolated_identity='swift-testing:ParityTests/compare()'),
                             plan(self.fixture(), bank, 8, isolated_identities=['swift-testing:ParityTests/compare()']))

    def test_missing_duplicate_unknown_and_invalid_banks_refuse(self):
        for mutate in [lambda d:d.pop('xctest'), lambda d:d.update(xctest=''),
                       lambda d:d.update(xctest=d['xctest']*2),
                       lambda d:d.update(xctest='warning: no discovery\n'),
                       lambda d:d.update(xctest='AutoTechnoCoreTests.ChangedFormat')]:
            inputs=self.fixture();mutate(inputs)
            with self.assertRaises(ValueError):plan(inputs,0,8)
        for bank,banks in [(True,8),(0,False),(-1,8),(8,8),(0,0),(0,33)]:
            with self.assertRaises(ValueError):plan(self.fixture(),bank,banks)

    def test_source_locations_do_not_defeat_isolation_or_split_module_variants(self):
        identities = ['swift-testing:HeavyTests/compare(rate:)',
                      'swift-testing:HeavyTests/faults()']
        heavy = ['FirstTests.HeavyTests/compare(rate:)/One.swift:42:5',
                 'SecondTests.HeavyTests/compare(rate:)/Two.swift:81:9']
        faults = 'FirstTests.HeavyTests/faults()/One.swift:90:5'
        neighbors = ['FirstTests.HeavyTests/compareExtra(rate:)/One.swift:43:5',
                     'FirstTests.HeavyTests/compare(rate:mode:)/One.swift:44:5',
                     'FirstTests.HeavyTestsExtra/compare(rate:)/One.swift:45:5']
        inputs = {'xctest': 'FirstTests.TrimTests/testTrim',
                  'swift-testing': '\n'.join(heavy + [faults] + neighbors)}
        rows = [plan(inputs, i, 8, isolated_identities=identities) for i in range(8)]
        selected = [(r['bank'], item, case) for r in rows for item in r['selected']
                    for case in item['identifiers']]
        self.assertEqual(sorted(case for bank, _, case in selected if bank == 7), sorted(heavy))
        self.assertEqual([case for bank, _, case in selected if bank == 6], [faults])
        self.assertEqual(len(selected), sum(len(text.splitlines()) for text in inputs.values()))
        self.assertEqual(len(selected), len({(item['library'], case) for _, item, case in selected}))
        for _, item, _ in selected:
            self.assertEqual({case for case in inputs[item['library']].splitlines()
                              if re.search(item['selector'], case)}, set(item['identifiers']))
        reversed_inputs = {k: '\n'.join(reversed(v.splitlines())) for k, v in inputs.items()}
        self.assertEqual(rows, [plan(reversed_inputs, i, 8, isolated_identities=identities)
                                for i in range(8)])

    def test_missing_or_malformed_source_located_isolation_refuses(self):
        for method in ['heavyExtra()/File.swift:12:4', 'heavy()/File.swift:0:4',
                       'heavy()/File.swift:12:x', 'heavy()/File.swift:12:4junk']:
            inputs = {'xctest': 'FirstTests.TrimTests/testTrim',
                      'swift-testing': 'FirstTests.HeavyTests/' + method}
            with self.assertRaisesRegex(ValueError, 'isolated native identity missing'):
                plan(inputs, 7, 8, isolated_identity='swift-testing:HeavyTests/heavy()')
        with self.assertRaisesRegex(ValueError, 'isolated native identity missing'):
            plan(self.fixture(), 0, 8, isolated_identity='swift-testing:MissingTests/absent()')

    def test_default_windows_assignment_retains_source_located_identity_hash(self):
        import hashlib
        inputs = self.fixture()
        inputs['swift-testing'] = '\n'.join(case + '/Fixture.swift:42:5'
                                              for case in inputs['swift-testing'].splitlines())
        for bank in range(8):
            for row in plan(inputs, bank, 8)['selected']:
                for case in row['identifiers']:
                    identity = row['library'] + ':' + row['suite'] + '/' + case.split('/', 1)[1]
                    expected = int.from_bytes(hashlib.sha256(identity.encode()).digest()[:8], 'big') % 8
                    self.assertEqual(bank, expected)


if __name__ == '__main__':unittest.main()
