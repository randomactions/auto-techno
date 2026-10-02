#!/usr/bin/env python3
"""Tests for the evidence-ranked deficit register."""

from __future__ import annotations

import copy
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("deficit_register.py")
SPEC = importlib.util.spec_from_file_location("deficit_register", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
register_module = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = register_module
SPEC.loader.exec_module(register_module)
REPOSITORY_ROOT = MODULE_PATH.parents[1]


class DeficitRegisterTests(unittest.TestCase):
    def setUp(self) -> None:
        self.register = json.loads(
            (REPOSITORY_ROOT / "docs/DEFICIT_REGISTER.json").read_text(encoding="utf-8")
        )

    @staticmethod
    def reseal(value: dict[str, object]) -> None:
        value["registerFingerprint"] = register_module.fingerprint(
            value, "registerFingerprint"
        )

    def roadmap_items(self) -> dict[str, dict[str, str]]:
        return {
            link["id"]: {"status": "queued", "outcome": link["outcome"]}
            for entry in self.register["entries"]
            for link in entry["nearestRoadmapItems"]
        }

    def test_checked_register_is_structurally_valid(self) -> None:
        self.assertEqual(register_module.validate_register(self.register), [])

    def test_render_and_canonical_bytes_are_deterministic(self) -> None:
        first = register_module.render_markdown(self.register)
        second = register_module.render_markdown(copy.deepcopy(self.register))
        self.assertEqual(first, second)
        self.assertEqual(
            register_module.canonical_bytes(self.register),
            register_module.canonical_bytes(copy.deepcopy(self.register)),
        )
        self.assertIn("Current calibrated auditory defects: **0**", first)

    def test_current_register_keeps_dimensions_separate(self) -> None:
        self.assertEqual(len(self.register["entries"]), 9)
        self.assertIsNone(self.register["rankingPolicy"]["aggregateScore"])
        self.assertEqual(
            self.register["qualification"]["calibratedAuditoryDefectCount"], 0
        )
        for entry in self.register["entries"]:
            self.assertIn("prevalence", entry)
            self.assertIn("severity", entry)
            self.assertIn("confidence", entry)
            self.assertIn("owner", entry)
            self.assertIn("nearestRoadmapItems", entry)
            self.assertFalse(entry["qualityClaim"])
            self.assertFalse(entry["promotionAuthorized"])

    def test_source_and_observation_counts_are_explicit(self) -> None:
        entries = {entry["id"]: entry for entry in self.register["entries"]}
        self.assertEqual(
            (
                entries["DEF-0007"]["prevalence"]["numerator"],
                entries["DEF-0007"]["prevalence"]["denominator"],
            ),
            (22_330, 340_230_030),
        )
        observations = {
            item["id"]: item for item in self.register["quarantinedObservations"]
        }
        self.assertIn("288/652", observations["OBS-0001"]["observation"])
        self.assertIn("10/75", observations["OBS-0005"]["observation"])

    def test_content_mutation_breaks_register_fingerprint(self) -> None:
        changed = copy.deepcopy(self.register)
        changed["entries"][0]["title"] += " changed"
        errors = register_module.validate_register(changed)
        self.assertTrue(any("registerFingerprint" in error for error in errors))

    def test_weighted_aggregate_score_is_rejected(self) -> None:
        changed = copy.deepcopy(self.register)
        changed["rankingPolicy"]["aggregateScore"] = 99
        self.reseal(changed)
        errors = register_module.validate_register(changed)
        self.assertTrue(any("aggregate score" in error for error in errors))

    def test_priority_order_is_reconstructed_not_trusted(self) -> None:
        changed = copy.deepcopy(self.register)
        changed["entries"][0], changed["entries"][1] = (
            changed["entries"][1], changed["entries"][0]
        )
        self.reseal(changed)
        errors = register_module.validate_register(changed)
        self.assertTrue(any("priority order" in error for error in errors))

    def test_prevalence_ratio_cannot_diverge_from_counts(self) -> None:
        changed = copy.deepcopy(self.register)
        changed["entries"][0]["prevalence"]["ratio"] = 0.5
        self.reseal(changed)
        errors = register_module.validate_register(changed)
        self.assertTrue(any("ratio does not match" in error for error in errors))

    def test_severity_and_confidence_ordinals_are_fixed(self) -> None:
        for field in ("severity", "confidence"):
            with self.subTest(field=field):
                changed = copy.deepcopy(self.register)
                changed["entries"][0][field]["ordinal"] = 99
                self.reseal(changed)
                errors = register_module.validate_register(changed)
                self.assertTrue(any(f".{field} is not canonical" in error for error in errors))

    def test_entry_source_fingerprint_must_match_bound_source(self) -> None:
        changed = copy.deepcopy(self.register)
        changed["entries"][0]["evidence"][0]["reportFingerprint"] = "f" * 64
        self.reseal(changed)
        errors = register_module.validate_register(changed)
        self.assertTrue(any("reportFingerprint is stale" in error for error in errors))

    def test_duplicate_deficit_id_is_rejected(self) -> None:
        changed = copy.deepcopy(self.register)
        changed["entries"][1]["id"] = changed["entries"][0]["id"]
        self.reseal(changed)
        errors = register_module.validate_register(changed)
        self.assertTrue(any("deficit IDs must be unique" in error for error in errors))

    def test_quality_or_promotion_authority_is_rejected(self) -> None:
        for field in ("qualityClaim", "promotionAuthorized"):
            with self.subTest(field=field):
                changed = copy.deepcopy(self.register)
                changed["entries"][0][field] = True
                self.reseal(changed)
                errors = register_module.validate_register(changed)
                self.assertTrue(any("may not claim quality or promotion" in error for error in errors))

    def test_roadmap_links_bind_open_exact_outcomes(self) -> None:
        roadmap = self.roadmap_items()
        self.assertEqual(register_module.validate_register(self.register, roadmap), [])
        target_id = self.register["entries"][0]["nearestRoadmapItems"][0]["id"]
        changed_status = copy.deepcopy(roadmap)
        changed_status[target_id]["status"] = "completed"
        self.assertTrue(any(
            "is not open roadmap work" in error
            for error in register_module.validate_register(self.register, changed_status)
        ))
        changed_outcome = copy.deepcopy(roadmap)
        changed_outcome[target_id]["outcome"] = "stale"
        self.assertTrue(any(
            "outcome is stale" in error
            for error in register_module.validate_register(self.register, changed_outcome)
        ))

    def test_generated_register_links_only_to_open_roadmap_work(self) -> None:
        # Exercise real entry generation with synthetic, non-audio source facts.
        # Clean hosted checkouts have neither private exports nor the local roadmap.
        reports = {
            source["id"]: {"reportFingerprint": source["reportFingerprint"]}
            for source in self.register["generatedFrom"]["sources"]
        }
        asset_id = "ATBC-V1-001-INITIAL--native-stereo-44100::whole"
        reports["rhythmic"]["assets"] = [{"assetId": asset_id,
            "evidence": {"scoreBindingStatus": "unavailable-fixture"}}]
        reports["kick-foundation-collision"]["entries"] = [{
            "caseId": "fixture", "routeId": "native-stereo-44100",
            "evidence": {"events": [{"collisionClass": "low-band-overlap"}]}}]
        reports["spectral"]["assets"] = [{"assetId": asset_id,
            "evidence": {"summary": {"windowCount": 1}}}]
        reports["score-motif"]["assets"] = [{"caseId": "fixture",
            "routeId": "native-stereo-44100",
            "evidence": {"summary": {"availableComparisonCount": 1}}}]
        reports["section-boundary"]["summary"] = {"boundaryCount": 1}
        reports["long-horizon"].update(summary={
            "realizedSignalAvailability": "unavailable",
            "payoffMarkerCount": 1, "unresolvedPayoffCount": 1},
            entries=[{"caseId": "fixture"}])
        reports["signal-integrity"]["assets"] = [{"assetId": asset_id,
            "evidence": {"combined": {"sampleCount": 100,
                "subnormalSampleCount": 1}}}]
        reports["performance-envelope"].update(
            coverage={"hostClasses": [{"status": "observed"},
                {"status": "unavailable"}]},
            qualification={"physicalSoakClaim": False})
        outcomes = {
            39: "Calibrate kick/bass masking and groove metrics against independent fixtures",
            40: "Calibrate transient, density, and fatigue evidence",
            41: "Calibrate timbral motion, harshness, dullness, and spectral-crowding evidence",
            44: "Calibrate motif identity, variation, phrase grammar, and arrangement contrast evidence",
            45: "Calibrate transition preparation, consequence, and recovery evidence",
            46: "Calibrate long-horizon arc, peak scarcity, return, reset, and landing evidence",
            60: "Preallocate and bound the canonical DSP graph and per-session resources",
            67: "Build deterministic long-run scheduling and resource-soak harnesses",
            355: "Qualify supported sample rates, buffer sizes, channel layouts, and route changes",
            358: "Bound CPU, memory, battery/thermal pressure, disk use, and preparation lead time",
            361: "Run multi-hour foreground/background, sleep/wake, interruption, and route-churn soak",
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "roadmap.md"
            path.write_text("".join(
                f"| AT-{number:04d} | `{status}` | fixture | {outcomes.get(number, 'Unused fixture item')} |\n"
                for number in range(1, 391)
                for status in ["completed" if number in (36, 38) else "queued"]
            ), encoding="utf-8")
            roadmap = register_module.parse_roadmap_items(path)
        generated = register_module.build_register(
            reports, self.register["generatedFrom"])
        self.assertEqual(len(generated["entries"]), 9)
        self.assertEqual(register_module.validate_register(generated, roadmap), [])
        linked_ids = {
            link["id"] for entry in generated["entries"]
            for link in entry["nearestRoadmapItems"]
        }
        self.assertEqual(linked_ids, {f"AT-{number:04d}" for number in outcomes})
        self.assertNotIn("AT-0038", linked_ids)
        self.assertNotIn("AT-0036", linked_ids)

    def test_unknown_quarantined_source_is_rejected(self) -> None:
        changed = copy.deepcopy(self.register)
        changed["quarantinedObservations"][0]["sourceId"] = "unknown"
        self.reseal(changed)
        errors = register_module.validate_register(changed)
        self.assertTrue(any("sourceId is unknown" in error for error in errors))

    def test_malformed_nested_json_fails_closed_without_exception(self) -> None:
        mutations = (
            ("deficitKind", {"bad": True}),
            ("actionClass", {"id": ["bad"], "ordinal": 0}),
            ("severity", {"level": ["bad"], "ordinal": 0, "impactDomain": "x", "basis": "x"}),
            ("confidence", {"level": ["bad"], "ordinal": 0, "basis": "x", "scopeLimit": "x"}),
        )
        for field, value in mutations:
            with self.subTest(field=field):
                changed = copy.deepcopy(self.register)
                changed["entries"][0][field] = value
                self.reseal(changed)
                self.assertTrue(register_module.validate_register(changed))
        changed = copy.deepcopy(self.register)
        changed["entries"][0]["evidence"][0]["sourceId"] = ["bad"]
        changed["quarantinedObservations"][0]["sourceId"] = ["bad"]
        self.reseal(changed)
        self.assertTrue(register_module.validate_register(changed))

    def test_report_fingerprint_validation_is_exact(self) -> None:
        report = {"schema": "fixture", "reportFingerprint": ""}
        report["reportFingerprint"] = register_module.fingerprint(
            report, "reportFingerprint"
        )
        self.assertTrue(register_module.report_fingerprint_valid(report))
        report["schema"] = "mutated"
        self.assertFalse(register_module.report_fingerprint_valid(report))

    def test_asset_identity_helpers_do_not_invent_values(self) -> None:
        value = "ATBC-V1-006-LONG-CONTINUATION--native-stereo-48000::whole"
        self.assertEqual(
            register_module.case_id_from_asset_id(value),
            "ATBC-V1-006-LONG-CONTINUATION",
        )
        self.assertEqual(
            register_module.route_id_from_asset_id(value), "native-stereo-48000"
        )
        self.assertIsNone(register_module.case_id_from_asset_id({"bad": True}))
        self.assertIsNone(register_module.route_id_from_asset_id("unknown"))


if __name__ == "__main__":
    unittest.main()
