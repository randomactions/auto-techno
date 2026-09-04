#!/usr/bin/env python3
"""Tests for the local identity-blind controlled-listening protocol."""

from __future__ import annotations

import copy
import importlib.util
import io
import json
import math
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("controlled_listening_protocol.py")
SPEC = importlib.util.spec_from_file_location("controlled_listening_protocol", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
protocol_module = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = protocol_module
SPEC.loader.exec_module(protocol_module)


class ControlledListeningProtocolTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        source = MODULE_PATH.parents[1] / "docs/CONTROLLED_LISTENING_PROTOCOL.json"
        self.protocol = json.loads(source.read_text(encoding="utf-8"))
        self.write_json("docs/CONTROLLED_LISTENING_PROTOCOL.json", self.protocol)
        self.manifest_path = self.root / "docs/local/reports/listening-sessions/test/manifest.json"
        self.manifest_path.parent.mkdir(parents=True, exist_ok=True)
        self.manifest_path.write_text('{"manifest":"fixture"}\n', encoding="utf-8")
        self.first_audio = self.root / "docs/local/audio/listening-sessions/test/one.wav"
        self.second_audio = self.root / "docs/local/audio/listening-sessions/test/two.wav"
        self.first_audio.parent.mkdir(parents=True, exist_ok=True)
        self.first_audio.write_bytes(b"RIFF-first-fixture")
        self.second_audio.write_bytes(b"RIFF-second-fixture")

    def write_json(self, relative: str, value: object) -> None:
        destination = self.root / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(
            json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )

    def relative(self, path: Path) -> str:
        return path.relative_to(self.root).as_posix()

    def condition(self, identifier: str, path: Path, pcm: str) -> dict[str, object]:
        return {
            "sourceId": identifier,
            "manifestPath": self.relative(self.manifest_path),
            "manifestSha256": protocol_module.file_digest(self.manifest_path),
            "pcmSha256": pcm,
            "engineVersion": "autotechno-canonical-engine.v48",
            "buildConfiguration": "release",
            "routeId": "native-stereo-44100",
            "sampleRate": 44_100,
            "channelCount": 2,
            "frameCount": 1024,
            "auditionPath": self.relative(path),
            "auditionSha256": protocol_module.file_digest(path),
            "appliedGainDB": 0.0,
        }

    def request(self, seed: int = 42, repetitions: int = 4) -> dict[str, object]:
        return {
            "schema": protocol_module.REQUEST_SCHEMA,
            "protocolVersion": 1,
            "sessionId": "test-session-001",
            "randomizationSeed": seed,
            "attribute": "groove-coherence",
            "attributePrompt": "Which condition sustains the intended pulse more coherently?",
            "repetitions": repetitions,
            "durationLimitMinutes": 20,
            "conditionOne": self.condition("candidate-secret-one", self.first_audio, "a" * 64),
            "conditionTwo": self.condition("candidate-secret-two", self.second_audio, "b" * 64),
            "environment": {
                "listenerId": "listener-local-1",
                "transducerType": "headphones",
                "transducerModel": "documented-headphones",
                "connection": "wired",
                "roomOrLocation": "quiet-local-room",
                "outputDevice": "built-in-output",
                "routeId": "native-stereo-44100",
                "sampleRate": 44_100,
                "channelCount": 2,
                "levelMethod": "locked-device-setting",
                "levelReference": "comfortable familiar reference",
                "lockedSetting": "system-output-40-percent",
                "calibratedSPLDB": None,
            },
        }

    def package(self) -> tuple[dict[str, object], dict[str, object], dict[str, object]]:
        request = self.request()
        self.assertEqual(
            protocol_module.validate_request(request, self.protocol, self.root), []
        )
        plan, key = protocol_module.create_plan_and_key(request, self.protocol)
        result = protocol_module.new_result(plan)
        return plan, key, result

    @staticmethod
    def reseal(value: dict[str, object], field: str) -> None:
        value[field] = protocol_module.fingerprint(value, field)

    def observed_result(
        self, plan: dict[str, object], key: dict[str, object]
    ) -> dict[str, object]:
        result = protocol_module.new_result(plan)
        result["status"] = "observed"
        result["limitation"] = "One local expert observation; no population inference."
        method = result["method"]
        assert isinstance(method, dict)
        method["actualDurationMinutes"] = 12.5
        method["familiarizationCompleted"] = True
        method["levelLocked"] = True
        observations = result["observations"]
        assert isinstance(observations, list)
        for item in observations:
            assert isinstance(item, dict)
            item["completed"] = True
            item["audibility"] = "audible"
            item["preferredToken"] = item["presentedOrder"][0]
            item["confidence"] = "medium"
            item["note"] = "The first opaque condition felt less crowded in this trial."
        reveal = result["reveal"]
        assert isinstance(reveal, dict)
        reveal["status"] = "revealed"
        reveal["revealedAtUTC"] = "2026-09-04T15:00:00Z"
        reveal["keyFingerprint"] = key["keyFingerprint"]
        result["hypotheses"] = [{
            "id": "HYP-test-001",
            "observationSummary": "A repeatable preference appeared after identity reveal.",
            "checkpoint": "whole-mix PCM at one selected phrase",
            "measurableDeficit": "Compare low-band overlap prevalence by condition.",
            "automatedComparison": "Use exact paired PCM collision evidence before any implementation.",
            "roadmapDisposition": "proposed-not-authorized",
        }]
        self.reseal(result, "resultFingerprint")
        return result

    def test_render_and_check_are_deterministic(self) -> None:
        output = io.StringIO()
        self.assertEqual(protocol_module.run_render(self.root, output), 0)
        first = protocol_module.report_path(self.root).read_bytes()
        self.assertEqual(protocol_module.run_render(self.root, io.StringIO()), 0)
        self.assertEqual(first, protocol_module.report_path(self.root).read_bytes())
        checked = io.StringIO()
        self.assertEqual(protocol_module.run_check(self.root, checked), 0)
        self.assertIn("10 attributes, 32 trial maximum", checked.getvalue())

    def test_protocol_rejects_promotion_authority(self) -> None:
        changed = copy.deepcopy(self.protocol)
        changed["purpose"]["promotionAuthorized"] = True
        self.assertTrue(any("may not authorize promotion" in error for error in protocol_module.validate_protocol(changed)))

    def test_same_request_and_seed_reproduce_byte_identical_package(self) -> None:
        request = self.request()
        first = protocol_module.create_plan_and_key(request, self.protocol)
        second = protocol_module.create_plan_and_key(request, self.protocol)
        self.assertEqual(first, second)
        self.assertEqual(protocol_module.canonical_bytes(first[0]), protocol_module.canonical_bytes(second[0]))

    def test_different_seed_changes_opaque_identity_and_order_plan(self) -> None:
        first, _ = protocol_module.create_plan_and_key(self.request(seed=42), self.protocol)
        second, _ = protocol_module.create_plan_and_key(self.request(seed=43), self.protocol)
        self.assertNotEqual(first["conditionTokens"], second["conditionTokens"])
        self.assertNotEqual(first["planFingerprint"], second["planFingerprint"])

    def test_plan_is_balanced_bounded_and_identity_blind(self) -> None:
        request = self.request()
        plan, key = protocol_module.create_plan_and_key(request, self.protocol)
        self.assertEqual(protocol_module.validate_plan(plan, self.protocol), [])
        firsts = [trial["presentedOrder"][0] for trial in plan["trials"]]
        self.assertEqual(firsts.count(plan["conditionTokens"][0]), 2)
        self.assertEqual(firsts.count(plan["conditionTokens"][1]), 2)
        serialized = json.dumps(plan, sort_keys=True)
        for condition in (request["conditionOne"], request["conditionTwo"]):
            for field in (
                "sourceId", "manifestPath", "manifestSha256", "pcmSha256",
                "engineVersion", "buildConfiguration", "auditionPath", "auditionSha256",
            ):
                self.assertNotIn(condition[field], serialized)
        self.assertEqual(protocol_module.validate_key(key, self.protocol, self.root), [])

    def test_draft_package_round_trips_conservatively(self) -> None:
        plan, key, result = self.package()
        self.assertEqual(
            protocol_module.validate_package(plan, key, result, self.protocol, self.root), []
        )
        self.assertEqual(result["status"], "draft")
        self.assertFalse(result["qualification"]["promotionAuthorized"])
        self.assertIsNone(result["qualification"]["qualityRank"])

    def test_completed_observation_and_falsifiable_hypothesis_pass(self) -> None:
        plan, key, _ = self.package()
        result = self.observed_result(plan, key)
        self.assertEqual(
            protocol_module.validate_package(plan, key, result, self.protocol, self.root), []
        )

    def test_identical_pcm_conditions_are_rejected(self) -> None:
        request = self.request()
        request["conditionTwo"]["pcmSha256"] = request["conditionOne"]["pcmSha256"]
        self.assertTrue(any("must not have identical PCM" in error for error in protocol_module.validate_request(request, self.protocol, self.root)))

    def test_mutated_source_file_is_rejected(self) -> None:
        request = self.request()
        self.first_audio.write_bytes(b"mutated")
        self.assertTrue(any("auditionSha256 does not match" in error for error in protocol_module.validate_request(request, self.protocol, self.root)))

    def test_route_and_geometry_mismatch_are_rejected(self) -> None:
        request = self.request()
        request["conditionTwo"]["sampleRate"] = 48_000
        errors = protocol_module.validate_request(request, self.protocol, self.root)
        self.assertTrue(any("conditions must match sampleRate" in error for error in errors))

    def test_headphones_cannot_claim_calibrated_loudspeaker_spl(self) -> None:
        request = self.request()
        environment = request["environment"]
        environment["levelMethod"] = "calibrated-loudspeaker-spl"
        environment["calibratedSPLDB"] = 73.0
        errors = protocol_module.validate_request(request, self.protocol, self.root)
        self.assertTrue(any("requires loudspeakers" in error for error in errors))

    def test_nonfinite_gain_is_rejected(self) -> None:
        request = self.request()
        request["conditionOne"]["appliedGainDB"] = math.nan
        self.assertTrue(any("appliedGainDB" in error for error in protocol_module.validate_request(request, self.protocol, self.root)))

    def test_unbalanced_recomputed_plan_is_rejected(self) -> None:
        plan, _, _ = self.package()
        token_one, token_two = plan["conditionTokens"]
        for trial in plan["trials"]:
            trial["presentedOrder"] = [token_one, token_two]
        self.reseal(plan, "planFingerprint")
        errors = protocol_module.validate_plan(plan, self.protocol)
        self.assertTrue(any("first positions must be balanced" in error for error in errors))

    def test_package_rejects_identity_leak_even_with_valid_plan_fingerprint(self) -> None:
        plan, key, result = self.package()
        plan["attributePrompt"] = key["mappings"][0]["condition"]["sourceId"]
        self.reseal(plan, "planFingerprint")
        key["planFingerprint"] = plan["planFingerprint"]
        self.reseal(key, "keyFingerprint")
        result["planFingerprint"] = plan["planFingerprint"]
        self.reseal(result, "resultFingerprint")
        errors = protocol_module.validate_package(plan, key, result, self.protocol, self.root)
        self.assertTrue(any("leaks condition sourceId" in error for error in errors))

    def test_result_order_mutation_is_rejected(self) -> None:
        plan, _, result = self.package()
        result["observations"][0]["presentedOrder"].reverse()
        self.reseal(result, "resultFingerprint")
        self.assertTrue(any("presentedOrder must match plan" in error for error in protocol_module.validate_result(result, plan, self.protocol)))

    def test_observed_result_requires_completed_trials_and_method(self) -> None:
        plan, _, result = self.package()
        result["status"] = "observed"
        result["method"]["actualDurationMinutes"] = 10
        result["limitation"] = "One local observation."
        self.reseal(result, "resultFingerprint")
        errors = protocol_module.validate_result(result, plan, self.protocol)
        self.assertTrue(any("requires familiarization and locked level" in error for error in errors))
        self.assertTrue(any("requires every trial" in error for error in errors))

    def test_hypothesis_requires_post_observation_reveal(self) -> None:
        plan, key, _ = self.package()
        result = self.observed_result(plan, key)
        result["reveal"] = {"status": "concealed", "revealedAtUTC": None, "keyFingerprint": None}
        self.reseal(result, "resultFingerprint")
        self.assertTrue(any("hypotheses require" in error for error in protocol_module.validate_result(result, plan, self.protocol)))

    def test_revealed_package_requires_exact_key_fingerprint(self) -> None:
        plan, key, _ = self.package()
        result = self.observed_result(plan, key)
        result["reveal"]["keyFingerprint"] = "c" * 64
        self.reseal(result, "resultFingerprint")
        errors = protocol_module.validate_package(plan, key, result, self.protocol, self.root)
        self.assertTrue(any("must match key" in error for error in errors))

    def test_forbidden_promotion_claim_is_rejected(self) -> None:
        plan, _, result = self.package()
        result["limitation"] = "release ready"
        self.reseal(result, "resultFingerprint")
        self.assertTrue(any("forbidden promotion claim" in error for error in protocol_module.validate_result(result, plan, self.protocol)))

    def test_note_length_is_bounded(self) -> None:
        plan, _, result = self.package()
        result["observations"][0]["note"] = "x" * 2001
        self.reseal(result, "resultFingerprint")
        self.assertTrue(any("note exceeds" in error for error in protocol_module.validate_result(result, plan, self.protocol)))

    def test_unhashable_plan_values_are_rejected_without_exception(self) -> None:
        plan, _, _ = self.package()
        plan["conditionTokens"] = [{"not": "a-token"}, "condition-bad"]
        plan["trials"][0]["presentedOrder"] = [{"not": "a-token"}, "condition-bad"]
        self.reseal(plan, "planFingerprint")
        errors = protocol_module.validate_plan(plan, self.protocol)
        self.assertTrue(any("conditionTokens" in error for error in errors))
        self.assertTrue(any("presentedOrder" in error for error in errors))

    def test_malformed_cross_record_values_fail_closed_without_exception(self) -> None:
        plan, key, result = self.package()
        plan["durationLimitMinutes"] = {"not": "a-number"}
        plan["conditionTokens"] = [{"not": "a-token"}, "condition-bad"]
        self.reseal(plan, "planFingerprint")
        key["planFingerprint"] = plan["planFingerprint"]
        key["mappings"][0]["token"] = {"not": "a-token"}
        self.reseal(key, "keyFingerprint")
        result["status"] = "observed"
        result["planFingerprint"] = plan["planFingerprint"]
        result["method"]["actualDurationMinutes"] = 1
        result["reveal"] = ["not-an-object"]
        self.reseal(result, "resultFingerprint")
        errors = protocol_module.validate_package(
            plan, key, result, self.protocol, self.root, verify_files=False
        )
        self.assertTrue(any("durationLimitMinutes" in error for error in errors))
        self.assertTrue(any("result.reveal must be an object" in error for error in errors))
        self.assertTrue(any("key mappings" in error for error in errors))

    def test_stale_markdown_is_rejected(self) -> None:
        self.assertEqual(protocol_module.run_render(self.root, io.StringIO()), 0)
        protocol_module.report_path(self.root).write_text("stale\n", encoding="utf-8")
        output = io.StringIO()
        self.assertEqual(protocol_module.run_check(self.root, output), 1)
        self.assertIn("generated Markdown is stale", output.getvalue())


if __name__ == "__main__":
    unittest.main()
