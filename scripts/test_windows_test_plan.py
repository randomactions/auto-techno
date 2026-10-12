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

    def test_missing_duplicate_unknown_and_invalid_banks_refuse(self):
        for mutate in [lambda d:d.pop('xctest'), lambda d:d.update(xctest=''),
                       lambda d:d.update(xctest=d['xctest']*2),
                       lambda d:d.update(xctest='warning: no discovery\n'),
                       lambda d:d.update(xctest='AutoTechnoCoreTests.ChangedFormat')]:
            inputs=self.fixture();mutate(inputs)
            with self.assertRaises(ValueError):plan(inputs,0,8)
        for bank,banks in [(True,8),(0,False),(-1,8),(8,8),(0,0),(0,33)]:
            with self.assertRaises(ValueError):plan(self.fixture(),bank,banks)


if __name__ == '__main__':unittest.main()
