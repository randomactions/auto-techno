#!/usr/bin/env python3
"""Tests for performance_envelope_report.py."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil
import sys
import unittest
import uuid


SCRIPT_DIRECTORY = str(Path(__file__).resolve().parent)
if SCRIPT_DIRECTORY not in sys.path:
    sys.path.insert(0, SCRIPT_DIRECTORY)
import performance_envelope_report as report  # noqa: E402


class PerformanceEnvelopeReportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.root = report.repository_root()
        cls.corpus_path = cls.root / "docs/BASELINE_CORPUS.json"
        cls.corpus = json.loads(cls.corpus_path.read_text(encoding="utf-8"))
        cls.baseline = json.loads((
            cls.root / "docs/ROADMAP_EXECUTION_BASELINE.json"
        ).read_text(encoding="utf-8"))

    def valid_raw(self) -> dict:
        high_water = 64 * 1_024 * 1_024
        preparation = []
        for fixture in self.corpus["cases"]:
            if fixture["id"] != report.MEASUREMENT_CASE_ID:
                continue
            for route in self.corpus["routes"]:
                frame_count = round(240 / 130 * route["sampleRate"]) * 4
                audio_ns = round(
                    frame_count / route["sampleRate"] * 1_000_000_000
                )
                for trial in range(3):
                    before = high_water
                    high_water += 1_024
                    preparation.append({
                        "id": f"{fixture['id']}--{route['id']}--trial-{trial}",
                        "caseId": fixture["id"],
                        "routeId": route["id"],
                        "rootSeed": fixture["rootSeed"],
                        "checkpoint": fixture["checkpoint"],
                        "continuationClass": fixture["continuationClass"],
                        "trialIndex": trial,
                        "phraseIndex": 0,
                        "startBar": 0,
                        "barCount": 4,
                        "frameCount": frame_count,
                        "sampleRate": route["sampleRate"],
                        "channelCount": route["channelCount"],
                        "renderPassCount": 1,
                        "planningNanoseconds": 10 + trial,
                        "renderEvaluationNanoseconds": 1_000 + trial,
                        "longHorizonNanoseconds": 20 + trial,
                        "longHorizonUpdateAvailable": False,
                        "presentationNanoseconds": 30 + trial,
                        "completePreparationNanoseconds": 1_100 + trial,
                        "audioDurationNanoseconds": audio_ns,
                        "calculatedPeakWorkingBytes": 20 * 1_024 * 1_024,
                        "calculatedMaximumPeakWorkingBytes": 30 * 1_024 * 1_024,
                        "processHighWaterBytesBefore": before,
                        "processHighWaterBytesAfter": high_water,
                        "planFingerprint": "plan",
                        "replayFingerprint": "replay",
                        "directSampleHash": "sample",
                        "completeSampleHash": "sample",
                        "directEvaluationFingerprint": "evaluation",
                        "completeEvaluationFingerprint": "evaluation",
                        "exactIdentityMatch": True,
                    })
        producer = []
        for frame_count in report.EXPECTED_FRAME_COUNTS:
            for trial in range(9):
                producer.append({
                    "id": f"native-stereo-{frame_count}--trial-{trial}",
                    "frameCount": frame_count,
                    "trialIndex": trial,
                    "operationCount": 128,
                    "batchNanoseconds": frame_count * 128 + trial,
                    "droppedPacketDelta": 0,
                    "rejectedPacketDelta": 0,
                    "exactRoundTrip": True,
                })
        return {
            "schema": report.RAW_SCHEMA,
            "observationVersion": 1,
            "corpusSha256": hashlib.sha256(
                self.corpus_path.read_bytes()
            ).hexdigest(),
            "contractBaselineFingerprint": self.baseline["snapshotFingerprint"],
            "sourceFingerprint": report.source_fingerprint(self.root),
            "gitHead": "fixture-head",
            "engineVersion": "fixture-engine",
            "buildConfiguration": "release",
            "clock": {
                "kind": "dispatch-uptime-monotonic",
                "unit": "nanoseconds",
                "samplingLocation": "detached-test-process",
            },
            "memory": {
                "kind": "getrusage-ru_maxrss",
                "unit": "bytes",
                "scope": "whole-test-process-high-water",
                "attribution": "monotonic-process-bound-not-phase-exclusive",
            },
            "machine": {
                "operatingSystem": "macOS",
                "operatingSystemVersion": "fixture-os",
                "hardwareModel": "fixture-model",
                "processor": "fixture-processor",
                "activeProcessorCount": 8,
                "physicalMemoryBytes": 16 * 1_024 * 1_024 * 1_024,
                "lowPowerModeEnabled": False,
                "thermalState": "nominal",
            },
            "trialPolicy": {
                "preparationWarmupCount": 1,
                "preparationTimedTrialCount": 3,
                "producerWarmupBatchCount": 2,
                "producerTimedTrialCount": 9,
                "producerOperationsPerBatch": 128,
                "producerFrameCounts": list(report.EXPECTED_FRAME_COUNTS),
                "measurementCaseId": report.MEASUREMENT_CASE_ID,
                "selectionRule": "largest-existing-baseline-frame-count",
                "ordering": "case-route-trial-ascending",
            },
            "preparationObservations": preparation,
            "producerObservations": producer,
        }

    def test_valid_raw_covers_the_exact_matrix(self) -> None:
        preparation, producer = report.validate_raw(
            self.valid_raw(), self.corpus, self.root
        )
        self.assertEqual(len(preparation), 6)
        self.assertEqual(len(producer), 36)

    def test_timing_quantiles_use_nearest_rank(self) -> None:
        self.assertEqual(report.timing_summary([9, 1, 5, 3]), {
            "minimum": 1,
            "p50": 3,
            "p95": 9,
            "maximum": 9,
        })

    def test_nonpositive_timing_fails_closed(self) -> None:
        raw = self.valid_raw()
        raw["preparationObservations"][0]["planningNanoseconds"] = 0
        with self.assertRaisesRegex(report.PerformanceEnvelopeError, "integer >= 1"):
            report.validate_raw(raw, self.corpus, self.root)

    def test_identity_mutation_fails_closed(self) -> None:
        raw = self.valid_raw()
        raw["preparationObservations"][0]["completeSampleHash"] = "changed"
        with self.assertRaisesRegex(report.PerformanceEnvelopeError, "identity pair"):
            report.validate_raw(raw, self.corpus, self.root)

    def test_process_high_water_must_be_monotonic(self) -> None:
        raw = self.valid_raw()
        raw["preparationObservations"][1]["processHighWaterBytesBefore"] = 1
        with self.assertRaisesRegex(report.PerformanceEnvelopeError, "non-monotonic"):
            report.validate_raw(raw, self.corpus, self.root)

    def test_queue_loss_is_not_accepted_as_underrun_evidence(self) -> None:
        raw = self.valid_raw()
        raw["producerObservations"][0]["droppedPacketDelta"] = 1
        with self.assertRaisesRegex(report.PerformanceEnvelopeError, "queue loss"):
            report.validate_raw(raw, self.corpus, self.root)

    def test_external_trace_reports_callback_and_poi_separately(self) -> None:
        directory = self.make_trace_directory(with_overload=True)
        try:
            evidence = report.trace_evidence(
                self.root, directory, "AutoTechno", 48_000, 2
            )
        finally:
            shutil.rmtree(directory)
        self.assertEqual(evidence["callbackCycleCount"], 2)
        self.assertEqual(evidence["callbackDurationNanoseconds"]["maximum"], 50_000)
        self.assertEqual(evidence["minimumObservedFrameCount"], 512)
        self.assertEqual(evidence["relevantDeadlinePointCount"], 1)
        self.assertEqual(evidence["underrunEvidence"], "relevant-point-observed")
        self.assertEqual(evidence["nonNormalCallbackCycleCount"], 0)

    def test_report_without_trace_keeps_live_facts_unavailable(self) -> None:
        directory = self.root / "docs/local/reports/performance-envelope-v1" / (
            "test-" + uuid.uuid4().hex
        )
        directory.mkdir(parents=True)
        raw_path = directory / "raw.json"
        raw_path.write_text(json.dumps(self.valid_raw()), encoding="utf-8")
        try:
            generated = report.build_report(
                self.root, raw_path, None, "AutoTechno", None, None
            )
        finally:
            shutil.rmtree(directory)
        self.assertEqual(
            generated["qualification"]["status"],
            "partial-live-evidence-unavailable",
        )
        self.assertEqual(generated["liveMacOS"]["availability"], "unavailable")
        self.assertFalse(generated["qualification"]["releaseReadinessClaim"])

    def make_trace_directory(self, with_overload: bool) -> Path:
        directory = self.root / "docs/local/reports/performance-envelope-v1" / (
            "test-" + uuid.uuid4().hex
        )
        directory.mkdir(parents=True)
        (directory / report.TRACE_FILENAMES["toc"]).write_text(
            "<trace-toc/>", encoding="utf-8"
        )
        (directory / report.TRACE_FILENAMES["clientCycles"]).write_text(
            """<trace-query-result><node><schema name="audio-hal-client-io-cycle"/>
<row><start-time>100</start-time><duration>40000</duration><process fmt="AutoTechno (7)"/><event-concept fmt="Normal"/></row>
<row><start-time>11000000</start-time><duration>50000</duration><process ref="p"/><event-concept ref="normal"/></row>
<row><start-time>22000000</start-time><duration>90000</duration><process id="other" fmt="Other (8)"/><event-concept ref="normal"/></row>
<process id="p" fmt="AutoTechno (7)"/><event-concept id="normal" fmt="Normal"/>
</node></trace-query-result>""",
            encoding="utf-8",
        )
        (directory / report.TRACE_FILENAMES["deviceCycles"]).write_text(
            """<trace-query-result><node><schema name="audio-hal-io-cycle"/>
<row><duration>900000</duration><thread fmt="audio IO: Fixture"/><uint32>512</uint32><event-concept fmt="Normal"/></row>
<row><duration>1000000</duration><thread ref="thread"/><uint32 ref="frames"/><event-concept ref="normal"/></row>
<thread id="thread" fmt="audio IO: Fixture"/><uint32 id="frames">512</uint32><event-concept id="normal" fmt="Normal"/>
</node></trace-query-result>""",
            encoding="utf-8",
        )
        client_point = (
            "<row><event-time fmt=\"00:00.1\"/><narrative fmt=\"Processor overload\"/>"
            "<event-concept fmt=\"Warning\"/><detail fmt=\"deadline missed\"/></row>"
            if with_overload else ""
        )
        (directory / report.TRACE_FILENAMES["clientPoints"]).write_text(
            "<trace-query-result><node><schema name=\"audio-hal-client-poi\"/>" +
            client_point + "</node></trace-query-result>",
            encoding="utf-8",
        )
        (directory / report.TRACE_FILENAMES["devicePoints"]).write_text(
            "<trace-query-result><node><schema name=\"audio-hal-poi\"/>"
            "</node></trace-query-result>",
            encoding="utf-8",
        )
        return directory


if __name__ == "__main__":
    unittest.main()
