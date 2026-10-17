"""Synthetic reader attacks only; fixtures supply no native qualification."""
import copy
import json
import math
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import at0039_algorithmic_verification as audit
import test_hosted_macos_verification as native


def masking():
    rows, summaries = [], []
    for rate in audit.RATES:
        for family, split in audit.FAMILIES.items():
            for scenario, (overlap, ratio, active, cancelled, missing) in audit.SCENARIOS.items():
                rows.append(dict(family=family, split=split, sampleRate=rate, scenario=scenario,
                    expectedOverlap=overlap, observedOverlap=overlap, activePairWindows=active,
                    absoluteError=0, expectedLinearSumEnergyRatio=ratio, linearSumEnergyRatio=ratio,
                    exactCancellation=cancelled, missingRequiredCompanion=missing, replayExact=True))
            summaries.append(dict(family=family, split=split, sampleRate=rate, rowCount=6,
                meanAbsoluteError=0, rootMeanSquareError=0, meanSignedError=0))
    return dict(schema=audit.MASKING, scope='constructed-linear-signals-no-score-or-perceptual-qualification',
        uncertainty='not-estimated-fixed-families-not-random-independent-listeners',
        unavailable=['score-to-render-fidelity', 'shared-nonlinear-mix-damage',
            'perceptual-masking-harm', 'musical-preference', 'groove-quality'],
        rows=rows, summaries=summaries, failures=[])


def filters():
    rows = []
    def errors(count):
        return dict(count=count, meanAbsoluteError=0, rootMeanSquareError=0,
                    meanSignedError=0, maximumAbsoluteError=0)
    for rate in audit.RATES:
        for family, split in [('step', 'development'), ('impulse', 'held-out-construction'),
                              ('alternating', 'held-out-construction')]:
            for band in ['sub', 'low-mid', 'mid', 'high']:
                bounds = [n / (1 - n) for n in
                          [op * 4097 * sys.float_info.epsilon for op in (32, 128)]]
                rows.append(dict(family=family, split=split, sampleRate=rate, band=band,
                    samples=errors(4096), windowEnergies=errors(16),
                    sampleAbsoluteErrorBound=bounds[0], energyAbsoluteErrorBound=bounds[1]))
    return dict(schema=audit.FILTER, scope='declared-causal-filter-transfer-and-window-energy-only',
        uncertainty='fixed-constructions-no-population-interval-or-fitted-classifier',
        unavailable=['perceptual-masking-harm', 'score-to-render-fidelity',
                     'nonlinear-full-mix-quality', 'general-frequency-response-calibration'],
        rows=rows, failures=[])


def body(schema, value, interleaved=False):
    name = audit.TESTS[schema][1]
    raw = json.dumps(value, sort_keys=True, separators=(',', ':'))
    passed = f'✔ Test "{name}" passed after 0.1 seconds.\n'
    if interleaved:
        index = raw.index('meanAbsoluteError') + 7
        raw = raw[:index] + passed + raw[index:] + '\n'
    else:
        raw += '\n' + passed
    return f'◇ Test "{name}" started.\n' + raw


def fixture():
    bundle = native.fixture()
    discovery = copy.deepcopy(bundle['banks'][0]['receipt']['discovery'])
    discovery['swift-testing'] += '\n' + '\n'.join(audit.OWNER + row[0] for row in audit.TESTS.values())
    logs = {}
    for row in bundle['banks']:
        r = row['receipt']; bank = r['bank']
        r['discovery'] = discovery
        r['plan'] = audit.hosted.plan(discovery, bank, 16)
        r['completedSlices'] = [dict(selection=s, reportedTests=len(s['identifiers']),
            explicitlySkippedTests=0, executedTests=len(s['identifiers']), skippedIdentifiers=[],
            exitCode=0, logSHA256='b'*64) for s in r['plan']['selected']]
        text = native.native_log(r).decode()
        for s in r['plan']['selected']:
            marker = f"BEGIN native slice {bank}:{s['library']}:{s['suite']}\n"
            for schema, make in [(audit.MASKING, masking), (audit.FILTER, filters)]:
                if audit.OWNER + audit.TESTS[schema][0] in s['identifiers']:
                    text = text.replace(marker, marker + body(schema, make()))
        logs[bank] = text.encode()
        row['originalLogSHA256'] = audit.hosted.sha(logs[bank])
    return bundle, logs


class AlgorithmicVerificationTests(unittest.TestCase):
    def test_linear_relations_are_paired_not_independent_rate_samples(self):
        self.assertEqual(audit.masking(masking()), dict(rows=36, sourceFamilies=3,
            pairedRates=[44100, 48000], summaries=6, cancellationWitnesses=6,
            missingCompanionWitnesses=6))

    def test_missing_duplicate_reordered_or_foreign_rows_refuse(self):
        for change in [lambda r: r['rows'].pop(), lambda r: r['rows'].append(r['rows'][0]),
                       lambda r: r['rows'].reverse(), lambda r: r['rows'][0].update(sampleRate=96000),
                       lambda r: r['rows'][0].update(split='held-out-family')]:
            r = masking(); change(r)
            with self.assertRaises(ValueError): audit.masking(r)

    def test_oracle_and_observation_cannot_be_changed_together(self):
        r = masking(); r['rows'][0].update(expectedOverlap=.5, observedOverlap=.5)
        with self.assertRaises(ValueError): audit.masking(r)

    def test_energy_bound_is_independent_of_reported_expected_value(self):
        for change in [dict(linearSumEnergyRatio=4.001),
                       dict(linearSumEnergyRatio=100, expectedLinearSumEnergyRatio=100)]:
            r = masking(); r['rows'][0].update(change)
            with self.assertRaises(ValueError): audit.masking(r)

    def test_cancellation_absence_deletion_and_replay_remain_separate(self):
        for index, field in [(1, 'exactCancellation'), (4, 'missingRequiredCompanion'),
                             (5, 'missingRequiredCompanion'), (0, 'replayExact')]:
            r = masking(); r['rows'][index][field] = not r['rows'][index][field]
            with self.assertRaises(ValueError): audit.masking(r)

    def test_zero_summaries_are_recomputed_from_each_family_rate(self):
        r = masking(); r['summaries'][2]['meanSignedError'] = 1e-20
        with self.assertRaises(ValueError): audit.masking(r)

    def test_unavailable_dimensions_cannot_be_promoted_or_omitted(self):
        for function, make in [(audit.masking, masking), (audit.filters, filters)]:
            for change in [lambda r: r['unavailable'].pop(), lambda r: r.update(scope='quality-qualified'),
                           lambda r: r.update(failures=['unexplained']), lambda r: r.update(passed=True)]:
                r = make(); change(r)
                with self.assertRaises(ValueError): function(r)

    def test_booleans_nonfinite_null_and_malformed_numbers_refuse(self):
        for field, value in [('sampleRate', True), ('activePairWindows', True),
                             ('absoluteError', False), ('observedOverlap', None),
                             ('linearSumEnergyRatio', math.inf), ('linearSumEnergyRatio', math.nan),
                             ('family', {})]:
            r = masking(); r['rows'][0][field] = value
            with self.assertRaises(ValueError): audit.masking(r)

    def test_all_causal_counts_and_bounds_are_rederived(self):
        result = audit.filters(filters())
        self.assertEqual(result['rows'], 24)
        self.assertFalse(result['rawPerSampleErrorsIndependentlyRecomputed'])
        for change in [lambda r: r['rows'][0]['samples'].update(count=4095),
                       lambda r: r['rows'][0].update(energyAbsoluteErrorBound=1e-3),
                       lambda r: r['rows'][0].update(band='foreign'),
                       lambda r: r['rows'].pop()]:
            r = filters(); change(r)
            with self.assertRaises(ValueError): audit.filters(r)

    def test_error_summaries_cannot_hide_out_of_bound_or_inconsistent_errors(self):
        for change in [dict(maximumAbsoluteError=1e-3), dict(meanSignedError=1e-15),
                       dict(meanAbsoluteError=1e-15), dict(rootMeanSquareError=1e-15),
                       dict(maximumAbsoluteError=-1), dict(meanSignedError=True)]:
            r = filters(); r['rows'][0]['samples'].update(change)
            with self.assertRaises(ValueError): audit.filters(r)

    def test_original_annotation_interleaved_inside_json_key_is_explicit(self):
        value = masking(); raw = body(audit.MASKING, value, interleaved=True)
        timestamped = ''.join('2026-10-17T00:00:00.0000000Z ' + line for line in raw.splitlines(keepends=True))
        self.assertEqual(audit.report_from_native(timestamped, audit.MASKING), value)

    def test_unrecognized_text_truncation_and_duplicate_reports_refuse(self):
        raw = body(audit.MASKING, masking())
        for changed in [raw.replace('meanAbsoluteError', 'meanForeignText!AbsoluteError', 1),
                        raw + raw, raw.replace('"failures":[]', '"failures":[],"failures":[]'),
                        raw.replace('"rows":[', '"rows":[NaN,', 1), raw[:100]]:
            with self.assertRaises(ValueError):
                audit.masking(audit.report_from_native(changed, audit.MASKING))

    def test_missing_actual_named_start_or_terminal_pass_refuses(self):
        raw = body(audit.MASKING, masking())
        for changed in [raw.replace('started.', 'pending.'), raw.replace('passed after', 'failed after')]:
            with self.assertRaises(ValueError): audit.report_from_native(changed, audit.MASKING)

    def test_reports_before_start_after_pass_or_inside_other_json_do_not_count(self):
        name = audit.TESTS[audit.MASKING][1]
        report = json.dumps(masking(), sort_keys=True)
        start = f'◇ Test "{name}" started.\n'
        passed = f'✔ Test "{name}" passed after 0.1 seconds.\n'
        for raw in [report+'\n'+start+passed, start+passed+report+'\n',
                    start+'{"foreign-wrapper":'+report+'}\n'+passed]:
            with self.assertRaises(ValueError): audit.report_from_native(raw, audit.MASKING)

    def test_energy_roundoff_has_only_the_original_numerical_envelope(self):
        r = masking(); rate = r['rows'][0]['sampleRate']
        nu = 8*(rate//4)*sys.float_info.epsilon; bound = nu/(1-nu)*4
        r['rows'][0]['linearSumEnergyRatio'] += bound/2
        audit.masking(r)
        r['rows'][0]['linearSumEnergyRatio'] += bound
        with self.assertRaises(ValueError): audit.masking(r)

    def test_adversarial_report_failure_cannot_hide_behind_full_platform_success(self):
        bundle, logs = fixture()
        bank = next(bank for bank, raw in logs.items() if audit.MASKING.encode() in raw)
        original = json.dumps(masking(), sort_keys=True, separators=(',', ':')).encode()
        bad = masking(); bad['rows'][0]['observedOverlap'] = .5
        logs[bank] = logs[bank].replace(original, json.dumps(bad, sort_keys=True, separators=(',', ':')).encode())
        next(row for row in bundle['banks'] if row['receipt']['bank'] == bank)['originalLogSHA256'] = audit.hosted.sha(logs[bank])
        self.assertTrue(audit.hosted.verify(bundle, native.SOURCE, logs)['originalJobLogsVerified'])
        with self.assertRaises(ValueError): audit.verify(bundle, native.SOURCE, logs)

    def test_complete_original_platform_bundle_precedes_benchmark_checks(self):
        bundle, logs = fixture(); result = audit.verify(bundle, native.SOURCE, logs)
        self.assertTrue(result['constructedLinearEvidenceVerified'])
        for flag in ['fullAlgorithmicAcceptanceVerified', 'runtimeQualification', 'item39Complete']:
            self.assertFalse(result[flag])
        self.assertEqual(result['scope'], audit.SCOPE)
        self.assertNotEqual(result['originalLogBindings']['masking']['bank'],
                            result['originalLogBindings']['causalFilter']['bank'])

    def test_platform_success_without_required_algorithmic_output_is_insufficient(self):
        bundle = native.fixture(); logs = native.original_logs(bundle)
        self.assertTrue(audit.hosted.verify(bundle, native.SOURCE, logs)['completeNativeSuitesAndReleaseBuild'])
        with self.assertRaises(ValueError): audit.verify(bundle, native.SOURCE, logs)

    def test_foreign_source_partial_banks_or_modified_original_logs_refuse(self):
        bundle, logs = fixture()
        for change in [lambda b, l: b.update(source='c'*40),
                       lambda b, l: b['banks'].pop(), lambda b, l: l.update({0: l[0]+b'changed'})]:
            b, l = copy.deepcopy(bundle), dict(logs); change(b, l)
            with self.assertRaises(ValueError): audit.verify(b, native.SOURCE, l)


if __name__ == '__main__':
    unittest.main()
