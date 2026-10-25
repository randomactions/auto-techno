#!/usr/bin/env python3
"""Partition every native discovered test identity; never infer execution from discovery."""
import argparse
import hashlib
import json
from pathlib import Path
import re

IDENTIFIER = re.compile(r'^(?P<module>[A-Za-z_][A-Za-z_0-9]*Tests)\.(?P<suite>[A-Za-z_][A-Za-z_0-9]*)/(?P<test>\S.*)$')
SWIFT_SOURCE_LOCATION = re.compile(r'(?P<method>.+)/[^/\r\n]+\.swift:[1-9][0-9]*:[1-9][0-9]*$')


def plan(discoveries, bank, banks, *, isolated_identity=None, isolated_identities=()):
    if type(bank) is not int or type(banks) is not int or not 1 <= banks <= 32 or not 0 <= bank < banks:
        raise ValueError('invalid bank bounds')
    if isolated_identity is not None and (not isinstance(isolated_identity, str) or
            not isolated_identity or banks < 2):
        raise ValueError('invalid isolated native identity')
    if (not isinstance(isolated_identities, (tuple, list)) or
            any(not isinstance(v, str) or not v for v in isolated_identities) or
            len(set(isolated_identities)) != len(isolated_identities) or
            (isolated_identity is not None and isolated_identities)):
        raise ValueError('invalid isolated native identities')
    isolated = tuple(isolated_identities) if isolated_identity is None else (isolated_identity,)
    if len(isolated) >= banks:
        raise ValueError('isolation must retain an ordinary bank')
    if set(discoveries) != {'xctest', 'swift-testing'}:
        raise ValueError('both native frameworks must be discovered')
    all_cases = []
    matched_isolated = set()
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
                # A Swift Testing discovery ID carries a source location after
                # its method token. Match optional isolation by the method while
                # retaining the exact discovered ID in selectors and coverage.
                # Ordinary hashing (including Windows' default plan) stays exact.
                location = SWIFT_SOURCE_LOCATION.fullmatch(test) if library == 'swift-testing' else None
                method_identity = (library + ':' + suite + '/' + location['method']
                                   if location else identity)
                isolated_key = identity if identity in isolated else method_identity
                if isolated_key in isolated:
                    matched_isolated.add(isolated_key)
                # Reserve one complete bank per expensive identity, in caller
                # order from the final bank. Windows retains its default plan.
                ordinary_banks = banks - len(isolated)
                assignment = (banks - 1 - isolated.index(isolated_key) if isolated_key in isolated else
                              int.from_bytes(hashlib.sha256(identity.encode()).digest()[:8], 'big') % ordinary_banks)
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
    if matched_isolated != set(isolated):
        raise ValueError('configured isolated native identity missing from discovery')
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
