#!/usr/bin/env python3
"""Tests for baseline_lifecycle_policy.py."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("baseline_lifecycle_policy.py")
SPEC = importlib.util.spec_from_file_location("baseline_lifecycle_policy", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
lifecycle = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = lifecycle
SPEC.loader.exec_module(lifecycle)


class BaselineLifecyclePolicyTests(unittest.TestCase):
    def policy(self) -> dict[str, object]:
        return copy.deepcopy(lifecycle.build_policy())

    def reseal(self, policy: dict[str, object]) -> None:
        policy["policyFingerprint"] = lifecycle.fingerprint(
            policy, "policyFingerprint"
        )

    def envelope(self, **overrides: object) -> dict[str, object]:
        value: dict[str, object] = {
            "schema": lifecycle.ENVELOPE_SCHEMA,
            "familyId": "signal-baseline",
            "artifactSchema": "autotechno-signal-baseline-report.v1",
            "artifactVersion": 1,
            "artifactFingerprint": "a" * 64,
            "contractBaselineFingerprint": "b" * 64,
            "sourceFingerprint": "c" * 64,
            "corpusSha256": "d" * 64,
            "engineVersion": "autotechno-canonical-engine.v48",
            "buildConfiguration": "release",
            "routeIdentity": "native-stereo-v1",
        }
        value.update(overrides)
        return value

    def set_path(self, target: dict[str, object], path: str, value: object) -> None:
        current = target
        parts = path.split(".")
        for component in parts[:-1]:
            child = current.setdefault(component, {})
            self.assertIsInstance(child, dict)
            current = child  # type: ignore[assignment]
        current[parts[-1]] = value

    def write_artifacts(self, root: Path, policy: dict[str, object]) -> None:
        corpus = {"schema": "fixture"}
        (root / "docs").mkdir(parents=True, exist_ok=True)
        (root / lifecycle.CORPUS_PATH).write_text(
            json.dumps(corpus), encoding="utf-8"
        )
        corpus_sha = hashlib.sha256(
            (root / lifecycle.CORPUS_PATH).read_bytes()
        ).hexdigest()
        contract = "1" * 64
        (root / lifecycle.BASELINE_PATH).write_text(
            json.dumps({"snapshotFingerprint": contract}), encoding="utf-8"
        )
        for node in policy["nodes"]:  # type: ignore[union-attr]
            document: dict[str, object] = {"schema": node["schema"]}
            self.set_path(document, str(node["versionField"]), node["version"])
            field = node["artifactFingerprintField"]
            if field is not None:
                self.set_path(document, str(field), "2" * 64)
            for path in node["contractFingerprintFields"]:
                self.set_path(document, path, contract)
            for path in node["sourceFingerprintFields"]:
                self.set_path(document, path, "3" * 64)
            for path in node["corpusFingerprintFields"]:
                self.set_path(document, path, corpus_sha)
            for path in node["engineVersionFields"]:
                self.set_path(document, path, "autotechno-canonical-engine.v48")
            for path in node["buildConfigurationFields"]:
                self.set_path(document, path, "release")
            route_paths = node["routeIdentityFields"]
            for path in route_paths:
                self.set_path(document, path, "same-route")
            artifact_path = root / str(node["artifactPath"])
            artifact_path.parent.mkdir(parents=True, exist_ok=True)
            artifact_path.write_text(json.dumps(document), encoding="utf-8")

    def test_generated_policy_is_valid_and_complete(self) -> None:
        policy = self.policy()
        self.assertEqual(lifecycle.validate_policy(policy), [])
        self.assertEqual(len(policy["nodes"]), 15)
        self.assertEqual(policy["registeredMigrations"], [])

    def test_order_is_deterministic_and_dependency_safe(self) -> None:
        policy = self.policy()
        first = lifecycle.topological_order(policy["nodes"])
        second = lifecycle.topological_order(policy["nodes"])
        self.assertEqual(first, second)
        self.assertLess(first.index("whole-mix-render"), first.index("signal-baseline"))
        self.assertLess(first.index("signal-baseline"), first.index("deficit-register"))

    def test_unknown_missing_and_duplicate_nodes_fail(self) -> None:
        for mutate in ("missing", "duplicate", "unknown"):
            policy = self.policy()
            if mutate == "missing":
                policy["nodes"].pop()  # type: ignore[union-attr]
            elif mutate == "duplicate":
                policy["nodes"].append(copy.deepcopy(policy["nodes"][0]))  # type: ignore[index,union-attr]
            else:
                policy["nodes"][0]["dependencies"] = ["unknown"]  # type: ignore[index]
            self.reseal(policy)
            self.assertTrue(lifecycle.validate_policy(policy), mutate)

    def test_cycle_is_rejected(self) -> None:
        policy = self.policy()
        policy["nodes"][0]["dependencies"] = ["deficit-register"]  # type: ignore[index]
        self.reseal(policy)
        self.assertTrue(any("cycle" in item for item in lifecycle.validate_policy(policy)))

    def test_policy_fingerprint_detects_mutation(self) -> None:
        policy = self.policy()
        policy["nodes"][0]["label"] = "mutated"  # type: ignore[index]
        self.assertTrue(any("policyFingerprint" in item for item in lifecycle.validate_policy(policy)))

    def test_markdown_render_is_byte_stable(self) -> None:
        policy = self.policy()
        first = lifecycle.render_markdown(policy)
        self.assertEqual(first, lifecycle.render_markdown(policy))
        self.assertIn(policy["policyFingerprint"], first)
        self.assertIn("metadata-never", json.dumps(policy))

    def test_exact_identity_is_current_metadata(self) -> None:
        envelope = self.envelope()
        result = lifecycle.classify_pair(self.policy(), envelope, copy.deepcopy(envelope))
        self.assertEqual(result["state"], "current-metadata")

    def test_source_contract_and_artifact_changes_are_comparable(self) -> None:
        before = self.envelope()
        after = self.envelope(
            artifactFingerprint="e" * 64,
            contractBaselineFingerprint="f" * 64,
            sourceFingerprint="0" * 64,
        )
        result = lifecycle.classify_pair(self.policy(), before, after)
        self.assertEqual(result["state"], "comparable")
        self.assertEqual(
            result["changedDimensions"], lifecycle.EXPLICIT_DIFFERENCE_DIMENSIONS
        )

    def test_immutable_context_changes_are_incompatible(self) -> None:
        for key, value in (
            ("corpusSha256", "e" * 64),
            ("engineVersion", "engine.v49"),
            ("buildConfiguration", "debug"),
            ("routeIdentity", "other-route"),
        ):
            result = lifecycle.classify_pair(
                self.policy(), self.envelope(), self.envelope(**{key: value})
            )
            self.assertEqual(result["state"], "incompatible", key)
            self.assertIn(key, result["changedDimensions"])

    def test_unknown_schema_transition_is_incompatible(self) -> None:
        after = self.envelope(
            artifactSchema="autotechno-signal-baseline-report.v2",
            artifactVersion=2,
        )
        result = lifecycle.classify_pair(self.policy(), self.envelope(), after)
        self.assertEqual(result["state"], "incompatible")

    def test_registered_lossless_transition_requires_migration(self) -> None:
        policy = self.policy()
        policy["registeredMigrations"] = [{
            "familyId": "signal-baseline",
            "sourceSchema": "autotechno-signal-baseline-report.v1",
            "sourceVersion": 1,
            "targetSchema": "autotechno-signal-baseline-report.v2",
            "targetVersion": 2,
            "compatibility": "lossless-additive",
            "transformer": "python3 scripts/migrate_signal_v1_v2.py",
            "postValidator": "python3 scripts/signal_baseline_report.py check",
        }]
        self.reseal(policy)
        self.assertEqual(lifecycle.validate_policy(policy), [])
        after = self.envelope(
            artifactSchema="autotechno-signal-baseline-report.v2",
            artifactVersion=2,
        )
        self.assertEqual(
            lifecycle.classify_pair(policy, self.envelope(), after)["state"],
            "migration-required",
        )

    def test_registered_breaking_transition_is_incompatible(self) -> None:
        policy = self.policy()
        policy["registeredMigrations"] = [{
            "familyId": "signal-baseline",
            "sourceSchema": "autotechno-signal-baseline-report.v1",
            "sourceVersion": 1,
            "targetSchema": "autotechno-signal-baseline-report.v2",
            "targetVersion": 2,
            "compatibility": "breaking-rebaseline",
            "transformer": "python3 scripts/migrate_signal_v1_v2.py",
            "postValidator": "python3 scripts/signal_baseline_report.py check",
        }]
        self.reseal(policy)
        after = self.envelope(
            artifactSchema="autotechno-signal-baseline-report.v2",
            artifactVersion=2,
        )
        self.assertEqual(
            lifecycle.classify_pair(policy, self.envelope(), after)["state"],
            "incompatible",
        )

    def test_migration_requires_transformer_and_post_validator(self) -> None:
        policy = self.policy()
        policy["registeredMigrations"] = [{
            "familyId": "signal-baseline",
            "sourceSchema": "autotechno-signal-baseline-report.v1",
            "sourceVersion": 1,
            "targetSchema": "autotechno-signal-baseline-report.v2",
            "targetVersion": 2,
            "compatibility": "lossless-additive",
            "transformer": "",
            "postValidator": "",
        }]
        self.reseal(policy)
        errors = lifecycle.validate_policy(policy)
        self.assertTrue(any("transformer" in item for item in errors))
        self.assertTrue(any("postValidator" in item for item in errors))

    def test_assessment_marks_all_current_metadata_but_not_content_validated(self) -> None:
        policy = self.policy()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.write_artifacts(root, policy)
            result = lifecycle.assess(root, policy)
        self.assertEqual(result["summary"]["current-metadata"], 15)
        self.assertFalse(result["qualification"]["contentValidatorsExecuted"])
        self.assertEqual(lifecycle.validate_assessment(result), [])

    def test_stale_contract_and_missing_parent_are_explicit(self) -> None:
        policy = self.policy()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.write_artifacts(root, policy)
            first = policy["nodes"][0]
            path = root / first["artifactPath"]
            document = json.loads(path.read_text())
            self.set_path(document, first["contractFingerprintFields"][0], "9" * 64)
            path.write_text(json.dumps(document), encoding="utf-8")
            result = lifecycle.assess(root, policy)
        states = {item["id"]: item["state"] for item in result["nodes"]}
        self.assertEqual(states["whole-mix-render"], "regeneration-required")
        self.assertEqual(states["signal-baseline"], "blocked-by-dependency")

    def test_malformed_and_unhashable_json_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.json"
            path.write_text("[]", encoding="utf-8")
            with self.assertRaises(lifecycle.BaselineLifecycleError):
                lifecycle.load_json(path, "fixture")
        envelope = self.envelope(familyId=["unhashable"])
        self.assertTrue(lifecycle.validate_envelope(envelope))

    def test_checked_repository_policy_is_current(self) -> None:
        root = lifecycle.repository_root()
        policy = lifecycle.load_json(root / lifecycle.POLICY_PATH, "policy")
        self.assertEqual(lifecycle.validate_policy(policy), [])
        self.assertEqual(
            (root / lifecycle.MARKDOWN_PATH).read_text(encoding="utf-8"),
            lifecycle.render_markdown(policy),
        )


if __name__ == "__main__":
    unittest.main()
