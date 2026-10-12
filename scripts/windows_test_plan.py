#!/usr/bin/env python3
"""Partition every native discovered test identity; never infer execution from discovery."""
import argparse
import hashlib
import json
from pathlib import Path
import re

IDENTIFIER = re.compile(r'^(?P<module>[A-Za-z_][A-Za-z_0-9]*Tests)\.(?P<suite>[A-Za-z_][A-Za-z_0-9]*)/(?P<test>\S.*)$')


def plan(discoveries, bank, banks):
    if type(bank) is not int or type(banks) is not int or not 1 <= banks <= 32 or not 0 <= bank < banks:
        raise ValueError('invalid bank bounds')
    if set(discoveries) != {'xctest', 'swift-testing'}:
        raise ValueError('both native frameworks must be discovered')
    all_cases = []
    slices = []
    suite_count = 0
    for library in sorted(discoveries):
        identifiers = []
        owners = {}
        for line in discoveries[library].splitlines():
            line = line.strip()
            if not line:
                continue
            match = IDENTIFIER.fullmatch(line)
            if not match:
                # SwiftPM prints progress/warnings on stderr, which the runner
                # does not redirect into these files. Fail closed on new formats.
                raise ValueError('unrecognized discovery line: ' + line[:120])
            if line in identifiers:
                raise ValueError('duplicate discovery identifier')
            identifiers.append(line)
            owners.setdefault(match['suite'], []).append(line)
        if not identifiers:
            raise ValueError('empty discovery: ' + library)
        suite_count += len(owners)
        for suite, cases in sorted(owners.items()):
            groups = {}
            for case in cases:
                test = IDENTIFIER.fullmatch(case)['test']
                # Equal suite/method names across modules must stay together:
                # SwiftPM's cross-framework filter can match either module.
                identity = library + ':' + suite + '/' + test
                assignment = int.from_bytes(hashlib.sha256(identity.encode()).digest()[:8], 'big') % banks
                groups.setdefault(assignment, []).append(case)
            for assignment, selected_cases in sorted(groups.items()):
                tests = sorted({IDENTIFIER.fullmatch(case)['test'] for case in selected_cases})
                # Swift Testing appends a source-location component to its
                # runtime ID. Permit that slash, never a longer method token.
                # All parameterized cases of one discovered method stay intact.
                selector = (r'(^|\.)' + re.escape(suite) + r'[./](?:' +
                            '|'.join(re.escape(test) for test in tests) + r')(/|$)')
                slices.append(dict(library=library, suite=suite, selector=selector,
                                   bank=assignment, identifiers=sorted(selected_cases)))
        all_cases.extend(library + ':' + item for item in sorted(identifiers))
    return dict(schema='autotechno-windows-test-bank-plan.v2', bank=bank, banks=banks,
                discoverySHA256=hashlib.sha256('\n'.join(sorted(all_cases)).encode()).hexdigest(),
                discoveredIdentifiers=len(all_cases), discoveredSuites=suite_count,
                partitionUnit="discovered-test-identity",
                selected=[item for item in slices if item['bank'] == bank],
                nativeExecutionProven=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--xctest', type=Path, required=True)
    parser.add_argument('--swift-testing', type=Path, required=True)
    parser.add_argument('--bank', type=int, required=True)
    parser.add_argument('--banks', type=int, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = plan({key: getattr(args, key.replace('-', '_')).read_text(encoding='utf-8-sig')
                   for key in ('xctest', 'swift-testing')}, args.bank, args.banks)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print(json.dumps(result, sort_keys=True))
