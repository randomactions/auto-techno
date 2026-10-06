import AutoTechnoCore
import AutoTechnoDSP
import Foundation
import Testing
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WinSDK)
import WinSDK
#endif

@Suite("Representative professional quality calibration", .serialized)
struct ProfessionalQualityCalibrationIntegrationTests {
    private let calibrationSeeds: [UInt64] = [
        7, 13, 17, 42, 10_101, 11_111, 20_202, 22_222,
        30_303, 33_333, 40_404, 48_291, 50_505, 55_555, 60_606,
        66_666, 70_707, 77_777, 80_808, 88_888, 90_909, 99_999,
        123_456, 135_791, 19, 44_444, 121_212, 246_810,
        112_358, 141_421, 173_205, 223_606,
        161_803, 264_575, 271_828, 866_025,
    ]
    private let holdoutSeeds: [UInt64] = [577_215, 618_034, 707_106, 314_159]

    func freshCoverageFixtures() throws -> (
        development: [CanonicalCalibrationCoverageFixture],
        holdout: [CanonicalCalibrationCoverageFixture]
    ) {
        let harness = CanonicalJourneyQualificationHarness(
            engineVersion: QualityQualificationContract.engineVersion,
            routeFingerprint: "score-only-coverage-selection", routeGeneration: 0)
        let oldRoots = Set((0..<775).map(CanonicalJourneyQualificationHarness.windowRootSeed))
            .union(calibrationSeeds + holdoutSeeds)
        let development = harness.coverageFixtures(ordinals: 775..<1031,
            generalCount: 36, fourBarCount: 4, excludedRoots: oldRoots)
        let holdout = harness.coverageFixtures(ordinals: 1031..<1287,
            generalCount: 4, fourBarCount: 2,
            excludedRoots: oldRoots.union(development.map(\.rootSeed)))
        guard development.count == 40, holdout.count == 6 else {
            throw ProfessionalQualityCalibrationError.incompleteCheckpointCoverage
        }
        return (development, holdout)
    }

    @Test("Fresh score-only coverage retains every checkpoint, quotas and disjoint ordinal domains")
    func freshCoverageSelectionIsOutcomeBlind() throws {
        let fixtures = try freshCoverageFixtures()
        let replay = try freshCoverageFixtures()
        #expect(fixtures.development == replay.development)
        #expect(fixtures.holdout == replay.holdout)
        let all = fixtures.development + fixtures.holdout
        #expect(Set(all.map(\.rootSeed)).count == 46)
        #expect(fixtures.development.filter { $0.requiredMajorBreakBarCount == 4 }.count == 4)
        #expect(fixtures.holdout.filter { $0.requiredMajorBreakBarCount == 4 }.count == 2)
        #expect(fixtures.development.allSatisfy { (775..<1031).contains($0.ordinal) })
        #expect(fixtures.holdout.allSatisfy { (1031..<1287).contains($0.ordinal) })
        #expect(Set(calibrationSeeds + holdoutSeeds).isDisjoint(with: all.map(\.rootSeed)))
        for fixture in all {
            #expect(fixture.rootSeed == CanonicalJourneyQualificationHarness.windowRootSeed(fixture.ordinal))
            #expect(Set(fixture.checkpoints.map(\.checkpoint)) == Set(CanonicalJourneyCheckpoint.allCases))
            #expect(fixture.checkpoints.allSatisfy { $0.phraseIndex < 128 && $0.planFingerprint.count == 16 })
            if fixture.requiredMajorBreakBarCount == 4 {
                let major = try #require(fixture.checkpoints.first { $0.checkpoint == .majorBreak })
                let release = try #require(fixture.checkpoints.first { $0.checkpoint == .release })
                #expect(major.resolvedBarCount == 4)
                #expect(release.phraseIndex > major.phraseIndex)
            }
        }
        let harness = CanonicalJourneyQualificationHarness(
            engineVersion: QualityQualificationContract.engineVersion,
            routeFingerprint: "score-only-coverage-selection", routeGeneration: 0)
        let first = try #require(fixtures.development.first)
        #expect(harness.coverageFixtures(ordinals: 775..<(first.ordinal + 1),
            generalCount: 1, fourBarCount: 0, excludedRoots: [first.rootSeed]).isEmpty)
        #expect(harness.coverageFixtures(ordinals: 775..<776,
            generalCount: 36, fourBarCount: 4, excludedRoots: []).isEmpty)
        #expect(harness.coverageFixtures(ordinals: 775..<1032,
            generalCount: 36, fourBarCount: 4, excludedRoots: []).isEmpty)
    }

    /// Freeze score recipes and predicted sample geometry, not measured body
    /// energy or quality. Keep late events in the cohort, even when their
    /// required windows cannot be measured by the current bar-local owner.
    private func modalScoreGeometry(
        fixture: CanonicalCalibrationCoverageFixture,
        timingCache: inout [String: [[String: Any]]]
    ) throws -> [[String: Any]] {
        let director = AutonomousSessionDirector(rootSeed: fixture.rootSeed)
        var state = director.initialState()
        var result: [[String: Any]] = []
        let last = fixture.checkpoints.map(\.phraseIndex).max() ?? -1
        guard (0..<128).contains(last) else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        for _ in 0...last {
            let plan = director.plan(from: state)
            for checkpoint in fixture.checkpoints where checkpoint.phraseIndex == plan.phraseIndex {
                guard checkpoint.planFingerprint == AutonomousCandidateFingerprint.plan(plan),
                      checkpoint.resolvedBarCount == plan.resolvedBars.count,
                      checkpoint.startBar == plan.startBar, checkpoint.phraseKind == plan.kind
                else { throw ProfessionalQualityCalibrationError.profileMismatch }
                var events: [[String: Any]] = []
                for bar in plan.resolvedBars {
                    for event in bar.modalPercussionArticulations {
                        for rate in ProfessionalQualityCalibrationProfile.requiredSampleRates {
                            let frames = max(1, Int((240 / plan.scene.bpm * rate).rounded()))
                            let offset = VoiceRenderer.timingOffsetInSteps(
                                for: .tunedTom, step: event.step, dna: plan.dna)
                            let onset = Int(((Double(event.step) + offset) * Double(frames) / 16).rounded())
                            let key = "\(rate):\(frames):\(onset)"
                            if timingCache[key] == nil {
                                let pcm = [Float](repeating: 0, count: frames)
                                let full = [Float](repeating: 0, count: Int(rate * 0.3) + 2)
                                timingCache[key] = [(0.0, 0.010), (0.020, 0.080), (0.120, 0.240)]
                                    .enumerated().map { index, range in
                                        let actual = DeterministicSignalFixtures.timestampWindow(
                                            samples: pcm, onsetFrame: onset, sampleRate: rate,
                                            startSeconds: range.0, endSeconds: range.1).count
                                        let complete = DeterministicSignalFixtures.timestampWindow(
                                            samples: full, onsetFrame: 0, sampleRate: rate,
                                            startSeconds: range.0, endSeconds: range.1).count
                                        return ["window": index, "predictedSampleCount": actual,
                                            "fullSampleCount": complete,
                                            "predictedAvailability": actual == 0 ? "missing" :
                                                (actual == complete ? "complete" : "partial")]
                                    }
                            }
                            events.append(["bar": bar.performance.bar,
                                "scoreEventIndex": event.scoreEventIndex, "step": event.step,
                                "sampleRate": rate, "frameCount": frames, "startFrame": onset,
                                "timingOffsetInSteps": offset, "material": event.material.rawValue,
                                "fundamentalHz": event.fundamentalHz, "excitation": event.excitation,
                                "damping": event.damping, "brightness": event.brightness,
                                "inharmonicity": event.inharmonicity, "coupling": event.coupling,
                                "seed": event.seed, "predictedWindows": timingCache[key] ?? []])
                        }
                    }
                }
                result.append(["checkpoint": checkpoint.checkpoint.rawValue,
                    "phraseIndex": plan.phraseIndex, "planFingerprint": checkpoint.planFingerprint,
                    "noScoreModalEvents": events.isEmpty, "geometryOnly": true,
                    "positiveBodyQualification": "unavailable-before-PCM", "events": events])
            }
            state.advancePlanning(using: plan)
        }
        guard result.count == CanonicalJourneyCheckpoint.allCases.count else {
            throw ProfessionalQualityCalibrationError.incompleteCheckpointCoverage
        }
        return result
    }

    @Test("Continuous execution closes the actual final successor and separates frozen planning continuation")
    func continuousJourneyExecutionControl() throws {
        let seed: UInt64 = 48_300
        let harness = CanonicalJourneyQualificationHarness(
            engineVersion: QualityQualificationContract.engineVersion,
            routeFingerprint: "score-only-coverage-selection", routeGeneration: 0)
        let planned = try #require(harness.planCheckpoints(
            director: AutonomousSessionDirector(rootSeed: seed)).first)
        let execution = try executeJourney(seed: seed, sampleRate: 8_000,
            maximumPhrases: planned.phraseIndex + 2, frozenCheckpoints: [planned],
            requiresActualSuccessors: true)
        let report = try #require(execution.reports.first)
        let receipt = try #require(execution.successors.first)
        #expect(execution.reports.count == 1)
        #expect(execution.successors.count == 1)
        #expect(execution.renderedPhraseCount == planned.phraseIndex + 2)
        #expect(report.selectedCandidateEvidence.planFingerprint == planned.planFingerprint)
        #expect(report.fixtureFingerprint == planned.fixtureFingerprint)
        #expect(report.incomingState.revision == planned.phraseIndex)
        #expect(report.outgoingState.revision == report.incomingState.revision + 1)
        #expect(planned.qualityRevision == 0)
        #expect(planned.continuationFingerprint.hasSuffix("quality-r0"))
        #expect(receipt.sourceOutgoingRenderDSPFingerprint == report.commitProvenance.outgoingRenderDSPFingerprint)
        #expect(receipt.successorIncomingQualityFingerprint == report.commitProvenance.outgoingQualityStateFingerprint)
        let observation = try ProfessionalQualityObservation(continuousReport: report, successor: receipt)
        #expect(observation.measurementScope == .continuousModalWindow)
        #expect(observation.continuousModalSource != nil)
        // A reduced one-checkpoint control cannot manufacture a native-rate
        // complete calibration trajectory or independent population evidence.
        #expect(throws: ProfessionalEvidenceReportBankError.incompleteJourneyCoverage) {
            try ProfessionalEvidenceReportBank(reports: execution.reports)
        }
    }

    @Test("Continuous execution retains intervening acceptance and exact legacy original-report evidence")
    func continuousJourneyExecutionLegacyPrefixEquality() throws {
        let seed: UInt64 = 48_300
        let harness = CanonicalJourneyQualificationHarness(
            engineVersion: QualityQualificationContract.engineVersion,
            routeFingerprint: "score-only-coverage-selection", routeGeneration: 0)
        let planned = try #require(harness.planCheckpoints(
            director: AutonomousSessionDirector(rootSeed: seed)).first { $0.phraseIndex > 0 })
        let continuous = try executeJourney(seed: seed, sampleRate: 8_000,
            maximumPhrases: planned.phraseIndex + 2, frozenCheckpoints: [planned],
            requiresActualSuccessors: true)
        let legacy = try executeJourney(seed: seed, sampleRate: 8_000,
            maximumPhrases: planned.phraseIndex + 1, frozenCheckpoints: [planned])
        let report = try #require(continuous.reports.first)
        #expect(continuous.reports == legacy.reports)
        #expect(continuous.renderedPhraseCount == legacy.renderedPhraseCount + 1)
        #expect(legacy.successors.isEmpty)
        #expect(continuous.successors.count == 1)
        #expect(report.incomingState.revision == planned.phraseIndex)
        #expect(report.incomingState.revision > planned.qualityRevision)
        #expect(report.continuationFingerprint != planned.continuationFingerprint)
        #expect(report.fixtureFingerprint == planned.fixtureFingerprint)
        #expect(report.selectedCandidateEvidence.planFingerprint == planned.planFingerprint)
        #expect(planned.qualityRevision == 0)
    }

    @Test("Continuous execution rejects changed frozen planning identity and insufficient successor bounds before rendering")
    func continuousJourneyExecutionRejectsPlanningMutation() throws {
        let seed: UInt64 = 48_300
        let harness = CanonicalJourneyQualificationHarness(
            engineVersion: QualityQualificationContract.engineVersion,
            routeFingerprint: "score-only-coverage-selection", routeGeneration: 0)
        let planned = try #require(harness.planCheckpoints(
            director: AutonomousSessionDirector(rootSeed: seed)).first)
        let changed = CanonicalJourneyPlanCheckpoint(checkpoint: planned.checkpoint,
            phraseIndex: planned.phraseIndex, startBar: planned.startBar,
            phraseKind: planned.phraseKind, qualityRevision: 1,
            resolvedBarCount: planned.resolvedBarCount, planFingerprint: planned.planFingerprint,
            fixtureFingerprint: planned.fixtureFingerprint,
            continuationFingerprint: planned.continuationFingerprint)
        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try executeJourney(seed: seed, sampleRate: 8_000,
                maximumPhrases: planned.phraseIndex + 2, frozenCheckpoints: [changed],
                requiresActualSuccessors: true)
        }
        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try executeJourney(seed: seed, sampleRate: 8_000,
                maximumPhrases: planned.phraseIndex + 1, frozenCheckpoints: [planned],
                requiresActualSuccessors: true)
        }
        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try executeJourney(seed: seed, sampleRate: 8_000,
                frozenCheckpoints: [planned, planned], requiresActualSuccessors: true)
        }
    }

    private struct FrozenCoverageCohort: Decodable {
        let schema: String
        let engineVersion: String
        let gitHead: String
        let acceptedInputObjects: [String]
        let maximumPhrases: Int
        let sampleRates: [Double]
        let development: [CanonicalCalibrationCoverageFixture]
        let holdout: [CanonicalCalibrationCoverageFixture]
    }

    /// Authenticate the unchanged score-only cohort before the first new-root
    /// preparation. Its historical input objects and quality-r0 identities
    /// remain untouched; current execution gets a separate accepted binding.
    private func validatedFreshCoverageCohort() throws -> (FrozenCoverageCohort, [String: Any]) {
        let relative = "docs/local/reports/AT-0039-fresh-modal-coverage-cohort-v1/cohort.json"
        guard try git(["hash-object", relative]) == "da849a3ae636316afbbea231570d7c809de35d95"
        else { throw ProfessionalQualityCalibrationError.invalidIdentity }
        let data = try Data(contentsOf: repositoryRoot.appendingPathComponent(relative))
        guard data.count <= 8 * 1_024 * 1_024 else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        let frozen = try JSONDecoder().decode(FrozenCoverageCohort.self, from: data)
        let original = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let expected = try freshCoverageFixtures()
        guard frozen.schema == "autotechno-frozen-calibration-coverage-cohort.v1",
              frozen.engineVersion == QualityQualificationContract.engineVersion,
              frozen.maximumPhrases == 128,
              frozen.sampleRates == ProfessionalQualityCalibrationProfile.requiredSampleRates,
              frozen.development == expected.development, frozen.holdout == expected.holdout,
              frozen.acceptedInputObjects.count == 6 else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        // Replay all original checkpoint recipes and complete modal geometry,
        // without rendering musical PCM or relabelling historical context.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var timingCache: [String: [[String: Any]]] = [:]
        for (name, fixtures) in [("development", frozen.development), ("holdout", frozen.holdout)] {
            let originalEntries = try #require(original[name] as? [[String: Any]])
            guard originalEntries.count == fixtures.count else {
                throw ProfessionalQualityCalibrationError.incompleteCheckpointCoverage
            }
            for (fixture, originalEntry) in zip(fixtures, originalEntries) {
                var replay = try #require(JSONSerialization.jsonObject(with: encoder.encode(fixture)) as? [String: Any])
                replay["modalScoreGeometry"] = try modalScoreGeometry(fixture: fixture, timingCache: &timingCache)
                guard try canonicalCacheJSON(replay) == canonicalCacheJSON(originalEntry),
                      fixture.checkpoints.count == CanonicalJourneyCheckpoint.allCases.count,
                      fixture.checkpoints.allSatisfy({ $0.phraseIndex < frozen.maximumPhrases - 1 }) else {
                    throw ProfessionalQualityCalibrationError.profileMismatch
                }
            }
        }
        return (frozen, original)
    }

    @Test("Replay every immutable fresh planning entry and modal geometry before continuous execution")
    func validateFrozenContinuousCoverageExecutionInputs() throws {
        guard ProcessInfo.processInfo.environment["AUTOTECHNO_VALIDATE_CONTINUOUS_FROZEN_COHORT"] == "1"
        else { return }
        let (frozen, _) = try validatedFreshCoverageCohort()
        #expect(frozen.development.count == 40)
        #expect(frozen.holdout.count == 6)
        let developmentCheckpointCount: Int = frozen.development.reduce(0) {
            $0 + $1.checkpoints.count
        }
        let holdoutCheckpointCount: Int = frozen.holdout.reduce(0) {
            $0 + $1.checkpoints.count
        }
        let totalCheckpointCount: Int = developmentCheckpointCount + holdoutCheckpointCount
        #expect(totalCheckpointCount == 322)
    }

    private static let currentStudyPublishedRef = "refs/remotes/origin/codex/rms-trajectory-floor"

    private func currentContinuousExecutionProtocol(
        head: String, objects: [String], contract: String,
        selectionProtocolBlob: String, cohortBlob: String, qualificationRequested: Bool
    ) -> [String: Any] {
        let scope = ProfessionalQualityMeasurementScope.continuousModalWindow
        return ["schema": "autotechno-current-continuous-execution-protocol.v2",
            "engineVersion": QualityQualificationContract.engineVersion,
            "acceptedExecutionHead": head, "acceptedExecutionInputObjects": objects,
            "contractBaselineFingerprint": contract,
            "publishedExecutionRef": Self.currentStudyPublishedRef,
            "selectionProtocolBlob": selectionProtocolBlob, "cohortBlob": cohortBlob,
            "selectionRule": "ascending-ordinal-complete-score-then-remaining-four-bar.v1",
            "developmentRoots": 40, "holdoutRoots": 6, "planningCheckpoints": 322,
            "maximumPhrases": 128,
            "sampleRates": ProfessionalQualityCalibrationProfile.requiredSampleRates,
            "originalNativeReportCount": 644, "actualSuccessorReceiptCount": 644,
            "sourceAuthority": "fresh typed original reports and immediate actual prepared successors",
            "producer": "ProfessionalQualityCalibrationIntegrationTests.executeJourney",
            "actualContinuation": "advance accepted Core quality/live/render/DSP/graph every phrase",
            "finalSuccessorRequired": true, "archiveImport": false,
            "scope": scope.rawValue, "evidenceVersion": ProfessionalEvidenceReportBank.evidenceVersion,
            "observationVersion": scope.observationVersion,
            "profileVersion": scope.profileVersion, "profileSchema": scope.profileSchema,
            "primaryPolicyFamily": ProfessionalQualityPrimaryEvaluator.policyFamilyVersion,
            "adversarialSchema": 24, "adversarialVersion": "autotechno-professional-quality-adversarial.v25",
            "adversarialCaseCount": 34, "distinctAcceptedLiveBaselines": 2,
            "fixedLiveSeed": 42, "fixedLiveRate": 44_100,
            "holdoutSchema": 21, "holdoutVersion": "autotechno-professional-quality-holdout.v21",
            "holdoutObservationCount": 84,
            "qualificationRequested": qualificationRequested,
            "maximumRenderPasses": QualityQualificationContract.maximumRenderPasses,
            "maximumPeakWorkingBytes": AutonomousPreparationResourceBudget.maximumPeakWorkingByteCount,
            "runtimeActivation": false, "installedResourcesChanged": false,
            "fullRuntimeQualification": false]
    }

    private func requireCurrentContinuousExecutionProtocol(
        _ object: [String: Any], head: String, objects: [String], contract: String,
        selectionProtocolBlob: String, cohortBlob: String, qualificationRequested: Bool
    ) throws {
        let identities = [head, selectionProtocolBlob, cohortBlob] + objects
        guard objects.count == 6,
              identities.allSatisfy({ $0.count == 40 && $0.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) }),
              contract.count == 64,
              contract.allSatisfy({ $0.isHexDigit && !$0.isUppercase }),
              ProfessionalQualityMeasurementScope.continuousModalWindow.profileVersion ==
                ProfessionalQualityPrimaryEvaluator.requiredProfileVersion,
              try canonicalCacheJSON(object) == canonicalCacheJSON(currentContinuousExecutionProtocol(
                head: head, objects: objects, contract: contract,
                selectionProtocolBlob: selectionProtocolBlob, cohortBlob: cohortBlob,
                qualificationRequested: qualificationRequested)) else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
    }

    @Test("Current continuous launch rejects stale identities, partial matrices, archive import and promotion claims")
    func currentContinuousExecutionProtocolRefusesMutation() throws {
        let head = String(repeating: "a", count: 40)
        let objects = (0..<6).map { String(repeating: String($0), count: 40) }
        let contract = String(repeating: "b", count: 64)
        let selection = String(repeating: "c", count: 40)
        let cohort = String(repeating: "d", count: 40)
        let expected = currentContinuousExecutionProtocol(head: head, objects: objects,
            contract: contract, selectionProtocolBlob: selection, cohortBlob: cohort,
            qualificationRequested: true)
        try requireCurrentContinuousExecutionProtocol(expected, head: head, objects: objects,
            contract: contract, selectionProtocolBlob: selection, cohortBlob: cohort,
            qualificationRequested: true)
        let mutations: [(String, Any)] = [
            ("engineVersion", "autotechno-canonical-engine.v48"),
            ("acceptedExecutionHead", "HEAD"), ("acceptedExecutionInputObjects", Array(objects.reversed())),
            ("contractBaselineFingerprint", "current"), ("publishedExecutionRef", "refs/heads/main"),
            ("selectionProtocolBlob", cohort), ("cohortBlob", selection),
            ("developmentRoots", 36), ("holdoutRoots", 4), ("planningCheckpoints", 321),
            ("maximumPhrases", 129), ("sampleRates", [8_000]),
            ("originalNativeReportCount", 643), ("actualSuccessorReceiptCount", 0),
            ("sourceAuthority", "imported archives"), ("producer", "cold checkpoints"),
            ("finalSuccessorRequired", false), ("archiveImport", true),
            ("scope", "legacy"), ("profileVersion", "autotechno-professional-quality-profile.v32"),
            ("adversarialCaseCount", 33), ("distinctAcceptedLiveBaselines", 1),
            ("holdoutObservationCount", 83), ("qualificationRequested", false),
            ("maximumRenderPasses", 3), ("maximumPeakWorkingBytes", 256 * 1_024 * 1_024),
            ("runtimeActivation", true), ("installedResourcesChanged", true),
            ("fullRuntimeQualification", true), ("unknownAuthority", "passed")]
        for (key, value) in mutations {
            var changed = expected
            changed[key] = value
            #expect(throws: ProfessionalQualityCalibrationError.self) {
                try requireCurrentContinuousExecutionProtocol(changed, head: head, objects: objects,
                    contract: contract, selectionProtocolBlob: selection, cohortBlob: cohort,
                    qualificationRequested: true)
            }
        }
    }

    private struct CurrentContinuousLaunch {
        let inputs: CurrentCoverageExecutionInputs
        let protocolURL: URL
        let protocolBlob: String
        let output: URL
        let qualificationRequested: Bool
    }

    private func validatedCurrentContinuousLaunch() throws -> CurrentContinuousLaunch {
        let environment = ProcessInfo.processInfo.environment
        let inputs = try validatedCurrentCoverageExecutionInputs()
        let context = inputs.context
        guard environment["AUTOTECHNO_CONTINUOUS_EXECUTION_ACCEPTED_HEAD"] == context.head,
              environment["AUTOTECHNO_CONTINUOUS_EXECUTION_CONTRACT_FINGERPRINT"] == context.contract,
              let protocolPath = environment["AUTOTECHNO_CONTINUOUS_EXECUTION_PROTOCOL"],
              let blob = environment["AUTOTECHNO_CONTINUOUS_EXECUTION_PROTOCOL_BLOB"],
              let outputPath = environment["AUTOTECHNO_CONTINUOUS_EXECUTION_OUTPUT_DIRECTORY"] else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        let protocolURL = URL(fileURLWithPath: protocolPath).standardizedFileURL
        let output = URL(fileURLWithPath: outputPath, isDirectory: true).standardizedFileURL
        let prefix = repositoryRoot.appendingPathComponent("docs/local/reports/").path + "/"
        guard protocolURL.path.hasPrefix(prefix), output.path.hasPrefix(prefix),
              protocolURL.resolvingSymlinksInPath() == protocolURL,
              output.resolvingSymlinksInPath() == output,
              !FileManager.default.fileExists(atPath: output.path),
              !protocolURL.path.hasPrefix(output.path + "/"),
              !inputs.cohortURL.path.hasPrefix(output.path + "/"),
              !context.protocolURL.path.hasPrefix(output.path + "/") else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        let data = try Data(contentsOf: protocolURL)
        guard data.count <= 64 * 1_024 else { throw ProfessionalQualityCalibrationError.invalidIdentity }
        try requireCoverageGitBlob(data, expected: blob)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let qualification = environment["AUTOTECHNO_RUN_CONTINUOUS_ADVERSARIAL_QUALIFICATION"] == "1"
        try requireCurrentContinuousExecutionProtocol(object, head: context.head, objects: context.objects,
            contract: context.contract, selectionProtocolBlob: context.protocolBlob,
            cohortBlob: inputs.cohortBlob, qualificationRequested: qualification)
        // The external owner fresh-fetches this exact branch immediately before
        // freezing launch inputs. This test never performs network I/O.
        guard try git(["rev-parse", Self.currentStudyPublishedRef]) == context.head,
              try git(["rev-parse", "HEAD"]) == context.head,
              try git(["status", "--porcelain", "--untracked-files=all"]).isEmpty,
              try Data(contentsOf: repositoryRoot.appendingPathComponent(
                "docs/ROADMAP_EXECUTION_BASELINE.json")) == context.baselineData,
              try git(["hash-object", inputs.cohortURL.path]) == inputs.cohortBlob,
              try git(["hash-object", context.protocolURL.path]) == context.protocolBlob,
              try git(["hash-object", protocolURL.path]) == blob else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        return CurrentContinuousLaunch(inputs: inputs, protocolURL: protocolURL,
            protocolBlob: blob, output: output, qualificationRequested: qualification)
    }

    @Test("Authenticate the complete current continuous-study launch without creating output or PCM")
    func validateCurrentContinuousExecutionLaunchInputs() throws {
        guard ProcessInfo.processInfo.environment["AUTOTECHNO_VALIDATE_CURRENT_CONTINUOUS_LAUNCH"] == "1" else { return }
        let launch = try validatedCurrentContinuousLaunch()
        #expect(!FileManager.default.fileExists(atPath: launch.output.path))
        #expect(launch.inputs.frozen.development.count == 40)
        #expect(launch.inputs.frozen.holdout.count == 6)
        progress("current-continuous-launch-validated head=\(launch.inputs.context.head) no-PCM=true")
    }

    /// One OS operation claims the absent leaf; it cannot adopt another writer's
    /// directory. Parents must already exist from the private input preparation.
    private func claimCurrentContinuousOutput(_ output: URL) throws {
        #if canImport(Darwin) || canImport(Glibc)
        let claimed = output.path.withCString { mkdir($0, 0o700) == 0 }
        #elseif canImport(WinSDK)
        let claimed = output.path.withCString(encodedAs: UTF16.self) {
            CreateDirectoryW($0, nil) != 0
        }
        #else
        let claimed = false
        #endif
        guard claimed else { throw ProfessionalQualityCalibrationError.invalidIdentity }
    }

    @Test("An exclusive study output claim preserves a competing writer without rendering")
    func currentContinuousOutputClaimRefusesCompetingWriter() throws {
        let manager = FileManager.default
        let parent = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: parent, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: parent) }
        let output = parent.appendingPathComponent("study", isDirectory: true)
        // The launch precondition held, then another writer won before claim.
        #expect(!manager.fileExists(atPath: output.path))
        try manager.createDirectory(at: output, withIntermediateDirectories: false)
        let otherManifest = output.appendingPathComponent("execution.json")
        let otherBytes = Data("competing-writer-manifest".utf8)
        try otherBytes.write(to: otherManifest, options: .withoutOverwriting)
        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try claimCurrentContinuousOutput(output)
        }
        #expect(try Data(contentsOf: otherManifest) == otherBytes)
        #expect(try manager.contentsOfDirectory(atPath: output.path) == ["execution.json"])
        let fresh = parent.appendingPathComponent("fresh", isDirectory: true)
        try claimCurrentContinuousOutput(fresh)
        #expect(try manager.contentsOfDirectory(atPath: fresh.path).isEmpty)
        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try claimCurrentContinuousOutput(fresh)
        }
        #expect(try manager.contentsOfDirectory(atPath: fresh.path).isEmpty)
    }

    @Test("Execute the current authenticated native cohort through actual persistent successor preparation")
    func executeFreshContinuousCoverageCohort() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["AUTOTECHNO_RUN_CONTINUOUS_CALIBRATION_COVERAGE"] == "1" else { return }
        let launch = try validatedCurrentContinuousLaunch()
        let frozen = launch.inputs.frozen, original = launch.inputs.original
        let context = launch.inputs.context
        let acceptedHead = context.head, objects = context.objects
        let contractFingerprint = context.contract, output = launch.output
        let protocolBlob = launch.protocolBlob
        let qualificationRequested = launch.qualificationRequested
        func guardAcceptedInputs() throws {
            guard try git(["rev-parse", "HEAD"]) == acceptedHead,
                  try git(["status", "--porcelain", "--untracked-files=all"]).isEmpty,
                  try git(["rev-parse"] + ["Package.swift", "Sources", "Tests", "scripts",
                    "docs/BASELINE_CORPUS.json", "docs/ROADMAP_EXECUTION_BASELINE.json"].map { "HEAD:\($0)" })
                    .split(separator: "\n").map(String.init) == objects,
                  try Data(contentsOf: repositoryRoot.appendingPathComponent(
                    "docs/ROADMAP_EXECUTION_BASELINE.json")) == context.baselineData,
                  try git(["hash-object", launch.inputs.cohortURL.path]) == launch.inputs.cohortBlob,
                  try git(["hash-object", context.protocolURL.path]) == context.protocolBlob,
                  try git(["hash-object", launch.protocolURL.path]) == protocolBlob,
                  try git(["rev-parse", Self.currentStudyPublishedRef]) == acceptedHead else {
                throw ProfessionalQualityCalibrationError.invalidIdentity
            }
        }
        try guardAcceptedInputs()
        try claimCurrentContinuousOutput(output)
        var manifest: [String: Any] = ["schema": "autotechno-fresh-continuous-calibration-execution.v2",
            "status": "running", "acceptedExecutionHead": acceptedHead,
            "acceptedExecutionInputObjects": objects, "contractBaselineFingerprint": contractFingerprint,
            "protocolBlob": protocolBlob, "frozenCohortBlob": launch.inputs.cohortBlob,
            "selectionProtocolBlob": context.protocolBlob,
            "frozenCohortHead": frozen.gitHead, "frozenAcceptedInputObjects": frozen.acceptedInputObjects,
            "historicalContextRetagged": false, "planningCheckpointCount": 322,
            "maximumPhrases": frozen.maximumPhrases, "sampleRates": frozen.sampleRates,
            "observationVersion": ProfessionalQualityMeasurementContract.continuousModalObservationVersion,
            "replacementQualification": "unavailable-not-activated", "completedTrajectories": []]
        if qualificationRequested {
            manifest["continuousQualificationProtocolBlob"] = protocolBlob
            manifest["offlineContinuousQualification"] = ["status": "pending", "runtimeActivation": false]
        }
        func saveManifest() throws {
            try canonicalCacheJSON(manifest).write(to: output.appendingPathComponent("execution.json"), options: .atomic)
        }
        try saveManifest()
        var development: [ProfessionalQualityCalibrationTrajectory] = []
        var holdout: [ProfessionalQualityCalibrationTrajectory] = []
        var completed: [[String: Any]] = []
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        for (partition, fixtures) in [("development", frozen.development), ("holdout", frozen.holdout)] {
            let originalEntries = try #require(original[partition] as? [[String: Any]])
            for (fixture, originalEntry) in zip(fixtures, originalEntries) {
                try guardAcceptedInputs()
                var reports: [CanonicalJourneyQualificationReport] = []
                var receipts: [ProfessionalQualityModalSuccessorEvidence] = []
                var phraseCounts: [String: Int] = [:]
                for rate in frozen.sampleRates {
                    manifest["activeNativeRoute"] = ["partition": partition, "ordinal": fixture.ordinal,
                        "rootSeed": fixture.rootSeed, "sampleRate": rate]
                    try saveManifest()
                    let execution: JourneyExecution
                    do {
                        execution = try executeJourney(seed: fixture.rootSeed, sampleRate: rate,
                            maximumPhrases: frozen.maximumPhrases, frozenCheckpoints: fixture.checkpoints,
                            requiredMajorBreakBarCount: fixture.requiredMajorBreakBarCount,
                            requiresActualSuccessors: true)
                    } catch {
                        manifest["status"] = "native-construction-refused"
                        manifest["nativeConstructionRefusal"] = String(describing: error)
                        manifest["freshCohortRendered"] = false
                        try saveManifest()
                        throw error
                    }
                    reports.append(contentsOf: execution.reports)
                    receipts.append(contentsOf: execution.successors)
                    phraseCounts[String(Int(rate))] = execution.renderedPhraseCount
                    try guardAcceptedInputs()
                }
                let bank = try ProfessionalEvidenceReportBank(reports: reports)
                let trajectory = try ProfessionalQualityCalibrationTrajectory(continuousBank: bank, successors: receipts)
                guard trajectory.isComplete, reports.count == 14, receipts.count == reports.count else {
                    throw ProfessionalQualityCalibrationError.incompleteCheckpointCoverage
                }
                let unavailable = trajectory.observations.filter { observation in
                    ProfessionalQualityMeasurementContract.modalMetrics.contains {
                        observation.measurementApplicability($0) == .unavailable
                    }
                }.count
                let filename = "\(partition)-ordinal-\(fixture.ordinal).json"
                let artifact: [String: Any] = ["frozenPlanningEntry": originalEntry,
                    "actualReportBank": try JSONSerialization.jsonObject(with: bank.deterministicJSON()),
                    "actualSuccessorReceipts": try JSONSerialization.jsonObject(with: encoder.encode(receipts)),
                    "continuousTrajectory": try JSONSerialization.jsonObject(with: encoder.encode(trajectory)),
                    "renderedPhraseCounts": phraseCounts,
                    "requiredUnavailableObservationCount": unavailable,
                    "constructionAuthority": "actual typed products; diagnostic serialization cannot replace source reconstruction"]
                try canonicalCacheJSON(artifact).write(to: output.appendingPathComponent(filename), options: .withoutOverwriting)
                if partition == "development" { development.append(trajectory) } else { holdout.append(trajectory) }
                completed.append(["partition": partition, "ordinal": fixture.ordinal, "artifact": filename,
                    "originalBankFingerprint": trajectory.sourceBankFingerprint,
                    "originalReportCount": reports.count, "actualSuccessorCount": receipts.count,
                    "requiredUnavailableObservationCount": unavailable])
                manifest["completedTrajectories"] = completed
                try saveManifest()
            }
        }
        let developmentCorpus = try ProfessionalQualityCalibrationCorpus(trajectories: development)
        let holdoutCorpus = try ProfessionalQualityCalibrationCorpus(trajectories: holdout)
        guard development.count == 40, holdout.count == 6,
              developmentCorpus.sourceBankFingerprints.isDisjoint(with: holdoutCorpus.sourceBankFingerprints) else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        try developmentCorpus.deterministicJSON().write(to: output.appendingPathComponent("development-corpus.json"), options: .withoutOverwriting)
        try holdoutCorpus.deterministicJSON().write(to: output.appendingPathComponent("holdout-corpus.json"), options: .withoutOverwriting)
        do {
            let profile = try ProfessionalQualityCalibrationProfile(corpus: developmentCorpus)
            try profile.deterministicJSON().write(to: output.appendingPathComponent("offline-profile.json"), options: .withoutOverwriting)
            manifest["fitStatus"] = "complete-offline-unqualified"
            manifest["profileFingerprint"] = profile.fingerprint
            if qualificationRequested {
                manifest["offlineContinuousQualification"] = try qualifyFreshContinuousCorpora(
                    profile: profile, development: developmentCorpus,
                    holdout: holdoutCorpus, output: output)
            }
        } catch let error as ProfessionalQualityCalibrationError {
            // A coverage/fit failure is preserved, not a license to replace a
            // root, drop an event, broaden a bound or hide independent failures.
            manifest["fitStatus"] = "refused"
            manifest["fitRefusal"] = String(describing: error)
            if qualificationRequested {
                manifest["offlineContinuousQualification"] = ["status": "fit-refused",
                    "reason": String(describing: error), "runtimeActivation": false]
            }
        }
        try guardAcceptedInputs()
        manifest.removeValue(forKey: "activeNativeRoute")
        manifest["status"] = "captured-not-activated"
        manifest["originalNativeReportCount"] = 644
        manifest["actualSuccessorReceiptCount"] = 644
        manifest["freshCohortRendered"] = true
        try saveManifest()
    }

    /// Qualification consumes only the fresh in-memory typed corpora from the
    /// existing persistent journey executor. Saved diagnostics cannot enter.
    private func qualifyFreshContinuousCorpora(
        profile: ProfessionalQualityCalibrationProfile,
        development: ProfessionalQualityCalibrationCorpus,
        holdout: ProfessionalQualityCalibrationCorpus,
        output: URL
    ) throws -> [String: Any] {
        var result: [String: Any] = ["schema": "autotechno-offline-continuous-qualification.v1",
            "status": "running", "runtimeActivation": false, "archiveImport": false,
            "fixedLiveSeed": 42, "fixedLiveRate": 44_100,
            "profileFingerprint": profile.fingerprint,
            "developmentCorpusFingerprint": development.fingerprint,
            "holdoutCorpusFingerprint": holdout.fingerprint]
        func save() throws {
            try canonicalCacheJSON(result).write(to: output.appendingPathComponent(
                "offline-continuous-qualification.json"), options: .atomic)
        }
        // The new protocol freezes inputs, geometry and producers before PCM.
        // Its outputs are derived from these fresh typed products, never from
        // a prior archive or a retagged expected output fingerprint.
        let outputIdentityMatches =
            profile.profileVersion == ProfessionalQualityPrimaryEvaluator.requiredProfileVersion &&
            profile.sourceBankFingerprint == development.fingerprint &&
            profile.sourceTrajectoryCount == development.sourceTrajectoryCount &&
            profile.engineVersion == QualityQualificationContract.engineVersion &&
            development.engineVersion == profile.engineVersion && holdout.engineVersion == profile.engineVersion &&
            profile.evidenceVersion == ProfessionalEvidenceReportBank.evidenceVersion &&
            profile.isComplete && profile.usesDiverseCalibration
        guard profile.measurementScope == .continuousModalWindow, outputIdentityMatches,
              development.sourceTrajectoryCount == 40, holdout.sourceTrajectoryCount == 6,
              development.sourceObservationCount == 560, holdout.sourceObservationCount == 84,
              development.isComplete, holdout.isComplete,
              development.sourceBankFingerprints.isDisjoint(with: holdout.sourceBankFingerprints) else {
            result["status"] = "source-binding-refused"
            try save()
            return result
        }
        try save()
        do {
            let live = try LiveFeedbackTestSupport.renderContinuousLiveSourceProducts()
            let suite = try ProfessionalQualityAdversarialSuiteReport(
                continuousProfile: profile, sourceCorpus: development,
                liveCandidateChain: live.chain,
                attenuationReports: live.attenuationReports,
                attenuationSuccessor: live.attenuationSuccessor,
                recoveryReports: live.recoveryReports,
                recoverySuccessor: live.recoverySuccessor)
            try suite.deterministicJSON().write(to: output.appendingPathComponent(
                "continuous-adversarial-suite.json"), options: .withoutOverwriting)
            result["adversarialFingerprint"] = suite.fingerprint
            result["adversarialPassed"] = suite.passed
            result["adversarialCaseCount"] = suite.cases.count
            result["distinctLiveBaselineCount"] = Set(suite.liveBaselineObservationFingerprints).count
            guard suite.passed, suite.schemaVersion == 24,
                  suite.suiteVersion == "autotechno-professional-quality-adversarial.v25",
                  suite.cases.count == 34,
                  Set(suite.liveBaselineObservationFingerprints).count == 2 else {
                result["status"] = "adversarial-failed"
                result["holdoutStatus"] = "not-run-adversarial-prerequisite"
                try save()
                return result
            }
            let qualification = try ProfessionalQualityHoldoutQualification(profile: profile,
                adversarialSuite: suite, calibrationCorpus: development, holdoutCorpus: holdout)
            try qualification.deterministicJSON().write(to: output.appendingPathComponent(
                "continuous-holdout-qualification.json"), options: .withoutOverwriting)
            result["holdoutFingerprint"] = qualification.fingerprint
            result["holdoutQualified"] = qualification.qualified
            result["holdoutAcceptedObservationCount"] = qualification.acceptedObservationCount
            result["holdoutSourceObservationCount"] = qualification.sourceObservationCount
            let completeCurrentHoldout = qualification.qualified &&
                qualification.schemaVersion == 21 &&
                qualification.qualificationVersion == "autotechno-professional-quality-holdout.v21" &&
                qualification.engineVersion == QualityQualificationContract.engineVersion &&
                qualification.sourceObservationCount == 84 && qualification.acceptedObservationCount == 84
            result["status"] = completeCurrentHoldout
                ? "offline-adversarial-and-holdout-passed-not-activated" : "holdout-rejected"
        } catch let error as ProfessionalQualityCalibrationError {
            result["status"] = "construction-refused"
            result["reason"] = String(describing: error)
        }
        try save()
        return result
    }

    /// This is a planning protocol, never measured quality or admission evidence.
    /// Exact source and the inherited outcome-blind quotas are frozen before PCM.
    private func currentCoverageSelectionProtocol(
        head: String, inputObjects: [String], contractFingerprint: String
    ) -> [String: Any] {
        ["schema": "autotechno-score-only-coverage-selection-protocol.v2",
         "engineVersion": QualityQualificationContract.engineVersion,
         "gitHead": head, "acceptedInputObjects": inputObjects,
         "contractBaselineFingerprint": contractFingerprint,
         "selectionRule": "ascending-ordinal-complete-score-then-remaining-four-bar.v1",
         "developmentOrdinals": [775, 1031], "holdoutOrdinals": [1031, 1287],
         "excludedOrdinalUpperBound": 775,
         "developmentGeneralCount": 36, "developmentFourBarCount": 4,
         "holdoutGeneralCount": 4, "holdoutFourBarCount": 2,
         "maximumPhrases": 128,
         "sampleRates": ProfessionalQualityCalibrationProfile.requiredSampleRates,
         "routeFingerprint": "score-only-coverage-selection", "routeGeneration": 0,
         "originalCheckpointCount": 322, "qualityRevision": 0,
         "pcmRendered": false, "runtimeActivation": false,
         "replacementQualification": "unavailable-not-activated"]
    }

    private func requireCurrentCoverageSelectionProtocol(
        _ object: [String: Any], head: String, inputObjects: [String],
        contractFingerprint: String
    ) throws {
        guard head.count == 40, head.allSatisfy({ $0.isHexDigit && !$0.isUppercase }),
              inputObjects.count == 6,
              inputObjects.allSatisfy({ $0.count == 40 && $0.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) }),
              contractFingerprint.count == 64,
              contractFingerprint.allSatisfy({ $0.isHexDigit && !$0.isUppercase }),
              try canonicalCacheJSON(object) == canonicalCacheJSON(
                currentCoverageSelectionProtocol(head: head, inputObjects: inputObjects,
                    contractFingerprint: contractFingerprint)) else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
    }

    @Test("Current score-only freeze refuses historical identities, changed quotas and quality claims")
    func currentCoverageSelectionProtocolRefusesMutation() throws {
        let head = String(repeating: "a", count: 40)
        let objects = (0..<6).map { String(repeating: String($0), count: 40) }
        let contract = String(repeating: "b", count: 64)
        let expected = currentCoverageSelectionProtocol(head: head,
            inputObjects: objects, contractFingerprint: contract)
        try requireCurrentCoverageSelectionProtocol(expected, head: head,
            inputObjects: objects, contractFingerprint: contract)
        let mutations: [(String, Any)] = [
            ("engineVersion", "autotechno-canonical-engine.v48"),
            ("schema", "autotechno-score-only-coverage-selection-protocol.v1"),
            ("gitHead", String(repeating: "c", count: 40)),
            ("acceptedInputObjects", Array(objects.reversed())),
            ("contractBaselineFingerprint", String(repeating: "c", count: 64)),
            ("developmentOrdinals", [774, 1031]), ("holdoutOrdinals", [1030, 1287]),
            ("excludedOrdinalUpperBound", 774), ("developmentGeneralCount", 35),
            ("developmentFourBarCount", 5), ("holdoutGeneralCount", 5),
            ("holdoutFourBarCount", 1), ("maximumPhrases", 129),
            ("sampleRates", [8_000]), ("routeFingerprint", "other-route"),
            ("routeGeneration", 1), ("originalCheckpointCount", 321),
            ("qualityRevision", 1), ("pcmRendered", true), ("runtimeActivation", true),
            ("replacementQualification", "passed"), ("unknownAuthority", "passed")]
        for (key, value) in mutations {
            var changed = expected
            changed[key] = value
            #expect(throws: ProfessionalQualityCalibrationError.self) {
                try requireCurrentCoverageSelectionProtocol(changed, head: head,
                    inputObjects: objects, contractFingerprint: contract)
            }
        }
        for (badHead, badObjects, badContract) in [
            ("HEAD", objects, contract), (head, Array(objects.prefix(5)), contract),
            (head, objects, "current")
        ] {
            #expect(throws: ProfessionalQualityCalibrationError.self) {
                try requireCurrentCoverageSelectionProtocol(expected, head: badHead,
                    inputObjects: badObjects, contractFingerprint: badContract)
            }
        }
    }

    private func requireCoverageGitBlob(_ data: Data, expected: String) throws {
        guard data.count <= 8 * 1_024 * 1_024,
              expected.count == 40,
              expected.allSatisfy({ $0.isHexDigit && !$0.isUppercase }),
              try git(["hash-object", "--stdin"], input: data) == expected else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
    }

    @Test("Coverage identities bind parsed bytes even when their path changes and is restored")
    func currentCoverageParsedByteBindingRejectsPathMutation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("protocol.json")
        let first = Data("{\"version\":1}".utf8)
        let second = Data("{\"version\":2}".utf8)
        try first.write(to: file)
        let capturedFirst = try Data(contentsOf: file)
        let firstBlob = try git(["hash-object", file.path])
        try second.write(to: file)
        let capturedSecond = try Data(contentsOf: file)
        let secondBlob = try git(["hash-object", file.path])
        #expect(firstBlob != secondBlob)
        try requireCoverageGitBlob(capturedFirst, expected: firstBlob)
        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try requireCoverageGitBlob(capturedFirst, expected: secondBlob)
        }
        try first.write(to: file)
        #expect(try git(["hash-object", file.path]) == firstBlob)
        try requireCoverageGitBlob(capturedSecond, expected: secondBlob)
        #expect(throws: ProfessionalQualityCalibrationError.self) {
            try requireCoverageGitBlob(capturedSecond, expected: firstBlob)
        }
    }

    private func currentCoverageSelectionContext() throws -> CoverageSelectionContext {
        guard try git(["status", "--porcelain", "--untracked-files=all"]).isEmpty else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        let head = try git(["rev-parse", "HEAD"])
        let objects = try git(["rev-parse"] + ["Package.swift", "Sources", "Tests", "scripts",
            "docs/BASELINE_CORPUS.json", "docs/ROADMAP_EXECUTION_BASELINE.json"].map { "HEAD:\($0)" })
            .split(separator: "\n").map(String.init)
        let baselineURL = repositoryRoot.appendingPathComponent("docs/ROADMAP_EXECUTION_BASELINE.json")
        let baselineData = try Data(contentsOf: baselineURL)
        let baseline = try #require(JSONSerialization.jsonObject(with: baselineData) as? [String: Any])
        let contract = try #require(baseline["snapshotFingerprint"] as? String)
        let environment = ProcessInfo.processInfo.environment
        guard let protocolPath = environment["AUTOTECHNO_CALIBRATION_COVERAGE_PROTOCOL"],
              let expectedProtocolBlob = environment["AUTOTECHNO_CALIBRATION_COVERAGE_PROTOCOL_BLOB"],
              expectedProtocolBlob.count == 40,
              expectedProtocolBlob.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        let protocolURL = URL(fileURLWithPath: protocolPath).standardizedFileURL
        let reportPrefix = repositoryRoot.appendingPathComponent("docs/local/reports/").path + "/"
        guard protocolURL.path.hasPrefix(reportPrefix),
              protocolURL.resolvingSymlinksInPath() == protocolURL,
              FileManager.default.fileExists(atPath: protocolURL.path) else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        let protocolData = try Data(contentsOf: protocolURL)
        guard protocolData.count <= 64 * 1_024,
              try git(["hash-object", protocolURL.path]) == expectedProtocolBlob else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        try requireCoverageGitBlob(protocolData, expected: expectedProtocolBlob)
        let selectionProtocol = try #require(JSONSerialization.jsonObject(with: protocolData) as? [String: Any])
        try requireCurrentCoverageSelectionProtocol(selectionProtocol, head: head,
            inputObjects: objects, contractFingerprint: contract)
        return (head, objects, baselineData, contract, protocolURL, expectedProtocolBlob)
    }

    private typealias CoverageSelectionContext = (
        head: String, objects: [String], baselineData: Data, contract: String,
        protocolURL: URL, protocolBlob: String
    )

    private struct CurrentCoverageExecutionInputs {
        let frozen: FrozenCoverageCohort
        let original: [String: Any]
        let context: CoverageSelectionContext
        let cohortURL: URL
        let cohortBlob: String
    }

    private func validatedCurrentCoverageExecutionInputs() throws -> CurrentCoverageExecutionInputs {
        let environment = ProcessInfo.processInfo.environment
        let context = try currentCoverageSelectionContext()
        guard let path = environment["AUTOTECHNO_CALIBRATION_COVERAGE_COHORT"],
              let blob = environment["AUTOTECHNO_CALIBRATION_COVERAGE_COHORT_BLOB"],
              blob.count == 40, blob.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard url.path.hasPrefix(repositoryRoot.appendingPathComponent("docs/local/reports/").path + "/"),
              url.resolvingSymlinksInPath() == url,
              try git(["hash-object", url.path]) == blob else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        let data = try Data(contentsOf: url)
        guard data.count <= 8 * 1_024 * 1_024 else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        try requireCoverageGitBlob(data, expected: blob)
        let original = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let frozen = try JSONDecoder().decode(FrozenCoverageCohort.self, from: data)
        let fixtures = try freshCoverageFixtures()
        guard frozen.schema == "autotechno-frozen-calibration-coverage-cohort.v2",
              frozen.engineVersion == QualityQualificationContract.engineVersion,
              frozen.gitHead == context.head, frozen.acceptedInputObjects == context.objects,
              frozen.maximumPhrases == 128,
              frozen.sampleRates == ProfessionalQualityCalibrationProfile.requiredSampleRates,
              frozen.development == fixtures.development, frozen.holdout == fixtures.holdout,
              original["protocolBlob"] as? String == context.protocolBlob,
              original["contractBaselineFingerprint"] as? String == context.contract,
              original["pcmRendered"] as? Bool == false,
              original["runtimeActivation"] as? Bool == false,
              original["historicalCohortsRetagged"] as? Bool == false,
              original["replacementQualification"] as? String == "unavailable-not-activated",
              original["selectionRule"] as? String == "ascending-ordinal-complete-score-then-remaining-four-bar.v1",
              Set(original.keys) == Set(["schema", "engineVersion", "gitHead", "acceptedInputObjects",
                "maximumPhrases", "protocolBlob", "contractBaselineFingerprint", "pcmRendered",
                "runtimeActivation", "historicalCohortsRetagged", "selectionRule", "sampleRates",
                "replacementQualification", "development", "holdout"]) else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var cache: [String: [[String: Any]]] = [:]
        var count = 0
        for (name, entries) in [("development", fixtures.development), ("holdout", fixtures.holdout)] {
            let originals = try #require(original[name] as? [[String: Any]])
            guard originals.count == entries.count else {
                throw ProfessionalQualityCalibrationError.incompleteCheckpointCoverage
            }
            for (fixture, originalEntry) in zip(entries, originals) {
                var replay = try #require(JSONSerialization.jsonObject(with: encoder.encode(fixture)) as? [String: Any])
                replay["modalScoreGeometry"] = try modalScoreGeometry(fixture: fixture, timingCache: &cache)
                guard try canonicalCacheJSON(replay) == canonicalCacheJSON(originalEntry),
                      fixture.checkpoints.count == CanonicalJourneyCheckpoint.allCases.count,
                      fixture.checkpoints.allSatisfy({ $0.phraseIndex < 127 && $0.qualityRevision == 0 }) else {
                    throw ProfessionalQualityCalibrationError.profileMismatch
                }
                count += fixture.checkpoints.count
            }
        }
        guard count == 322, try git(["hash-object", url.path]) == blob,
              try git(["hash-object", context.protocolURL.path]) == context.protocolBlob,
              try git(["rev-parse", "HEAD"]) == context.head,
              try Data(contentsOf: repositoryRoot.appendingPathComponent(
                "docs/ROADMAP_EXECUTION_BASELINE.json")) == context.baselineData,
              try git(["status", "--porcelain", "--untracked-files=all"]).isEmpty else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        progress("current-coverage-replayed head=\(context.head) checkpoints=\(count) no-PCM=true")
        return CurrentCoverageExecutionInputs(frozen: frozen, original: original,
            context: context, cohortURL: url, cohortBlob: blob)
    }

    @Test("Replay immutable current-source score cohort and every native modal geometry without rendering")
    func validateFrozenCurrentCoverageExecutionInputs() throws {
        guard ProcessInfo.processInfo.environment["AUTOTECHNO_VALIDATE_CURRENT_CALIBRATION_COVERAGE"] == "1" else { return }
        _ = try validatedCurrentCoverageExecutionInputs()
    }

    @Test("Freeze fresh complete score coverage on accepted clean source before any new-root PCM")
    func freezeFreshCoverageCohort() throws {
        guard ProcessInfo.processInfo.environment["AUTOTECHNO_FREEZE_CALIBRATION_COVERAGE"] == "1"
        else { return }
        guard try git(["status", "--porcelain", "--untracked-files=all"]).isEmpty,
              let path = ProcessInfo.processInfo.environment["AUTOTECHNO_CALIBRATION_COVERAGE_COHORT"]
        else { throw ProfessionalQualityCalibrationError.invalidIdentity }
        let destination = URL(fileURLWithPath: path).standardizedFileURL
        guard destination.path.hasPrefix(repositoryRoot.appendingPathComponent(
            "docs/local/reports/", isDirectory: true).path + "/"),
              !FileManager.default.fileExists(atPath: destination.path)
        else { throw ProfessionalQualityCalibrationError.invalidIdentity }
        let context = try currentCoverageSelectionContext()
        let head = context.head, objects = context.objects
        let baselineURL = repositoryRoot.appendingPathComponent("docs/ROADMAP_EXECUTION_BASELINE.json")
        let baselineData = context.baselineData, contract = context.contract
        let protocolURL = context.protocolURL, expectedProtocolBlob = context.protocolBlob
        guard destination.resolvingSymlinksInPath() == destination, protocolURL != destination else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        let fixtures = try freshCoverageFixtures()
        guard (fixtures.development + fixtures.holdout).allSatisfy({
            $0.checkpoints.count == CanonicalJourneyCheckpoint.allCases.count &&
                $0.checkpoints.allSatisfy({ $0.phraseIndex < 127 && $0.qualityRevision == 0 })
        }) else { throw ProfessionalQualityCalibrationError.incompleteCheckpointCoverage }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var cache: [String: [[String: Any]]] = [:]
        func entries(_ fixtures: [CanonicalCalibrationCoverageFixture]) throws -> [[String: Any]] {
            try fixtures.map { fixture in
                var object = try #require(JSONSerialization.jsonObject(with:
                    encoder.encode(fixture)) as? [String: Any])
                object["modalScoreGeometry"] = try modalScoreGeometry(fixture: fixture, timingCache: &cache)
                return object
            }
        }
        let object: [String: Any] = ["schema": "autotechno-frozen-calibration-coverage-cohort.v2",
            "engineVersion": QualityQualificationContract.engineVersion,
            "gitHead": head, "acceptedInputObjects": objects, "maximumPhrases": 128,
            "protocolBlob": expectedProtocolBlob,
            "contractBaselineFingerprint": contract,
            "pcmRendered": false, "runtimeActivation": false,
            "historicalCohortsRetagged": false,
            "selectionRule": "ascending-ordinal-complete-score-then-remaining-four-bar.v1",
            "sampleRates": ProfessionalQualityCalibrationProfile.requiredSampleRates,
            "replacementQualification": "unavailable-not-activated",
            "development": try entries(fixtures.development), "holdout": try entries(fixtures.holdout)]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
        guard data.count <= 8 * 1024 * 1024,
              try git(["hash-object", protocolURL.path]) == expectedProtocolBlob,
              try git(["rev-parse"] + ["Package.swift", "Sources", "Tests", "scripts",
                "docs/BASELINE_CORPUS.json", "docs/ROADMAP_EXECUTION_BASELINE.json"].map { "HEAD:\($0)" })
                .split(separator: "\n").map(String.init) == objects,
              try Data(contentsOf: baselineURL) == baselineData,
              try git(["rev-parse", "HEAD"]) == head,
              try git(["status", "--porcelain", "--untracked-files=all"]).isEmpty
        else { throw ProfessionalQualityCalibrationError.invalidIdentity }
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try data.write(to: destination, options: .withoutOverwriting)
        progress("fresh-coverage-frozen head=\(head) development=40 holdout=6 bytes=\(data.count)")
    }

    func fourBarWindowFixtures() throws -> (
        development: [CanonicalCalibrationWindowFixture],
        holdout: [CanonicalCalibrationWindowFixture]
    ) {
        let harness = CanonicalJourneyQualificationHarness(
            engineVersion: QualityQualificationContract.engineVersion,
            routeFingerprint: "score-only-window-selection", routeGeneration: 0
        )
        let excluded = Set(calibrationSeeds + holdoutSeeds)
        let development = harness.windowFixtures(
            ordinals: 263..<519, checkpoint: .majorBreak,
            resolvedBarCount: 4, requestedCount: 4, excludedRoots: excluded
        )
        let holdout = harness.windowFixtures(
            ordinals: 519..<775, checkpoint: .majorBreak,
            resolvedBarCount: 4, requestedCount: 2,
            excludedRoots: excluded.union(development.map(\.rootSeed))
        )
        guard development.count == 4, holdout.count == 2 else {
            throw ProfessionalQualityCalibrationError.incompleteCheckpointCoverage
        }
        return (development, holdout)
    }

    @Test("Four-bar support is selected before outcomes from disjoint score-only domains")
    func fourBarWindowSelectionIsOutcomeBlindAndDisjoint() throws {
        let fixtures = try fourBarWindowFixtures()
        let all = fixtures.development + fixtures.holdout
        #expect(Set(all.map(\.rootSeed)).count == 6)
        #expect(Set(calibrationSeeds + holdoutSeeds)
            .isDisjoint(with: all.map(\.rootSeed)))
        for fixture in all {
            #expect(fixture.planned.checkpoint == .majorBreak)
            #expect(fixture.planned.phraseKind == .majorBreak)
            #expect(fixture.planned.resolvedBarCount == 4)
            #expect(fixture.followingRelease.checkpoint == .release)
            #expect(fixture.followingRelease.phraseIndex > fixture.planned.phraseIndex)
            #expect(fixture.followingRelease.phraseIndex < 128)
            #expect(fixture.planned.planFingerprint.count == 16)
            // Original AT-0039 cohorts occupy ordinals at most 262.
            #expect(fixture.ordinal > 262)
            progress("four-bar-score ordinal=\(fixture.ordinal) root=\(fixture.rootSeed) phrase=\(fixture.planned.phraseIndex) release=\(fixture.followingRelease.phraseIndex) plan=\(fixture.planned.planFingerprint)")
        }
        let harness = CanonicalJourneyQualificationHarness(
            engineVersion: QualityQualificationContract.engineVersion,
            routeFingerprint: "score-only-window-selection", routeGeneration: 0
        )
        // An exhausted eligible prefix fails closed instead of shrinking.
        let first = try #require(fixtures.development.first)
        let remaining = harness.windowFixtures(
            ordinals: 263..<(first.ordinal + 1), checkpoint: .majorBreak,
            resolvedBarCount: 4, requestedCount: 1,
            excludedRoots: Set(calibrationSeeds + holdoutSeeds).union([first.rootSeed])
        )
        #expect(remaining.isEmpty)
        #expect(harness.windowFixtures(
            ordinals: 263..<520, checkpoint: .majorBreak,
            resolvedBarCount: 4, requestedCount: 1, excludedRoots: []
        ).isEmpty)
    }

    struct FrozenWindowCohort: Codable, Equatable {
        let schemaVersion: Int
        let selectionRule: String
        let maximumPhrases: Int
        let engineVersion: String
        let sampleRates: [Double]
        let gitHead: String
        let acceptedInputObjects: [String]
        let contractBaselineFingerprint: String
        let originalCohortBlob: String
        let development: [CanonicalCalibrationWindowFixture]
        let holdout: [CanonicalCalibrationWindowFixture]
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }

    private func git(_ arguments: [String], input: Data? = nil) throws -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", repositoryRoot.path] + arguments
        process.standardOutput = output
        let inputPipe = input.map { _ in Pipe() }
        if let inputPipe { process.standardInput = inputPipe }
        try process.run()
        if let input, let inputPipe {
            try inputPipe.fileHandleForWriting.write(contentsOf: input)
            try inputPipe.fileHandleForWriting.close()
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        return String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func currentWindowCohort() throws -> FrozenWindowCohort {
        guard try git(["status", "--porcelain", "--untracked-files=all"]).isEmpty
        else { throw ProfessionalQualityCalibrationError.invalidIdentity }
        let head = try git(["rev-parse", "HEAD"])
        let objects = try git(["rev-parse"] + [
            "Package.swift", "Sources", "Tests", "scripts",
            "docs/BASELINE_CORPUS.json", "docs/ROADMAP_EXECUTION_BASELINE.json",
        ].map { "HEAD:\($0)" }).split(separator: "\n").map(String.init)
        let baseline = try JSONSerialization.jsonObject(with: Data(contentsOf:
            repositoryRoot.appendingPathComponent("docs/ROADMAP_EXECUTION_BASELINE.json")
        )) as? [String: Any]
        let fingerprint = try #require(baseline?["snapshotFingerprint"] as? String)
        let original = try git(["hash-object",
            "docs/local/reports/AT-0039-foundation-cohort-v1/corpus.json"])
        let fixtures = try fourBarWindowFixtures()
        guard try git(["rev-parse", "HEAD"]) == head,
              try git(["status", "--porcelain", "--untracked-files=all"]).isEmpty
        else { throw ProfessionalQualityCalibrationError.invalidIdentity }
        return FrozenWindowCohort(
            schemaVersion: 1,
            selectionRule: "ascending-ordinal-first-four-bar-major-break-and-following-release.v3",
            maximumPhrases: 128,
            engineVersion: QualityQualificationContract.engineVersion,
            sampleRates: ProfessionalQualityCalibrationProfile.requiredSampleRates,
            gitHead: head, acceptedInputObjects: objects,
            contractBaselineFingerprint: fingerprint, originalCohortBlob: original,
            development: fixtures.development, holdout: fixtures.holdout
        )
    }

    private func windowCohortURL() throws -> URL {
        guard let path = ProcessInfo.processInfo.environment[
            "AUTOTECHNO_CALIBRATION_WINDOW_COHORT"
        ], !path.isEmpty else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard url.path.hasPrefix(repositoryRoot.appendingPathComponent(
            "docs/local/reports/", isDirectory: true
        ).path + "/") else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        return url
    }

    @Test("Freeze four-bar calibration windows on accepted clean source before rendering")
    func freezeFourBarWindowCohort() throws {
        guard ProcessInfo.processInfo.environment[
            "AUTOTECHNO_FREEZE_CALIBRATION_WINDOWS"
        ] == "1" else { return }
        let cohort = try currentWindowCohort()
        let destination = try windowCohortURL()
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(cohort)
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destination, options: .withoutOverwriting)
        progress("four-bar-cohort-frozen head=\(cohort.gitHead) development=4 holdout=2")
    }

    private func frozenWindowCohort() throws -> FrozenWindowCohort {
        let url = try windowCohortURL()
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard (1...1_048_576).contains(size) else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        let cohort = try JSONDecoder().decode(
            FrozenWindowCohort.self, from: Data(contentsOf: url)
        )
        guard cohort == (try currentWindowCohort()) else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        return cohort
    }

    func windowReportsMatch(
        _ reports: [CanonicalJourneyQualificationReport],
        fixture: CanonicalCalibrationWindowFixture?
    ) -> Bool {
        guard let fixture else { return true }
        return [fixture.planned, fixture.followingRelease].allSatisfy { planned in
            let selected = reports.filter { $0.checkpoint == planned.checkpoint }
            return selected.count == 2 && Set(selected.map(\.sampleRate)) ==
                Set(ProfessionalQualityCalibrationProfile.requiredSampleRates) &&
                selected.allSatisfy { report in
                    let evidence = report.selectedCandidateEvidence
                    return report.fixtureFingerprint == planned.fixtureFingerprint &&
                        evidence.planFingerprint == planned.planFingerprint &&
                        evidence.symbolic.phraseIndex == planned.phraseIndex &&
                        evidence.symbolic.startBar == planned.startBar &&
                        evidence.symbolic.phraseKind == planned.phraseKind.rawValue &&
                        evidence.phraseComposition.count == planned.resolvedBarCount
                }
        }
    }

    /// This deliberately expensive, explicit calibration harness renders the
    /// complete canonical journey at 44.1 and 48 kHz. Normal CI validates the
    /// current primary artifacts; regeneration is opt-in so every source-bank
    /// change is intentional and reviewable.
    @Test("Generate complete representative-rate profile and adversarial identity")
    func generateRepresentativeProfile() async throws {
        guard ProcessInfo.processInfo.environment[
            "AUTOTECHNO_RUN_PROFILE_CALIBRATION"
        ] == "1" else { return }

        if let requested = ProcessInfo.processInfo.environment[
            "AUTOTECHNO_CALIBRATION_SINGLE_SEED"
        ], let seed = UInt64(requested) {
            _ = try renderTrajectory(seed: seed)
            progress("single-seed-ready seed=\(seed)")
            return
        }

        let cohort = try frozenWindowCohort()
        let calibrationSeeds = self.calibrationSeeds + cohort.development.map(\.rootSeed)
        let holdoutSeeds = self.holdoutSeeds + cohort.holdout.map(\.rootSeed)
        let calibrationTrajectories = try await renderTrajectories(
            seeds: calibrationSeeds, windowFixtures: cohort.development
        )
        let holdoutTrajectories = try await renderTrajectories(
            seeds: holdoutSeeds, windowFixtures: cohort.holdout
        )
        let calibrationCorpus = try ProfessionalQualityCalibrationCorpus(
            trajectories: calibrationTrajectories
        )
        let holdoutCorpus = try ProfessionalQualityCalibrationCorpus(
            trajectories: holdoutTrajectories
        )
        for (seed, trajectory) in zip(holdoutSeeds, holdoutTrajectories) {
            progress(
                "holdout-seed=\(seed) source=" +
                trajectory.sourceBankFingerprint
            )
        }
        try printLeaveTwoOutResults(
            seeds: calibrationSeeds + holdoutSeeds,
            trajectories: calibrationTrajectories + holdoutTrajectories
        )
        try printLeaveOneOutResults(
            seeds: calibrationSeeds + holdoutSeeds,
            trajectories: calibrationTrajectories + holdoutTrajectories
        )
        let profile = try ProfessionalQualityCalibrationProfile(
            corpus: calibrationCorpus
        )
        progress("profile-ready fingerprint=\(profile.fingerprint)")
        for trajectory in calibrationCorpus.trajectories {
            let localFailures = trajectory.observations.compactMap {
                observation -> String? in
                let verdict = ProfessionalQualityProfileEvaluator.evaluate(
                    observation,
                    against: profile
                )
                return verdict.accepted ? nil : [
                    observation.checkpoint.rawValue,
                    String(Int(observation.sampleRate)),
                    verdict.failedMetrics.map(\.rawValue).joined(separator: ","),
                ].joined(separator: ":")
            }
            let relationshipFailures = ProfessionalQualityRelationshipEvaluator
                .evaluate(
                    observations: trajectory.observations,
                    against: profile
                ).failures
            progress(
                "calibration-source=\(trajectory.sourceBankFingerprint) " +
                "local=\(localFailures.joined(separator: ";")) " +
                "relationships=\(relationshipFailures.count)"
            )
            for observation in trajectory.observations {
                let verdict = ProfessionalQualityProfileEvaluator.evaluate(
                    observation,
                    against: profile
                )
                for metric in verdict.failedMetrics {
                    guard let value = observation[metric],
                          let bounds = profile[observation.checkpoint]?[metric]
                    else { continue }
                    progress(
                        "calibration-local-detail=\(metric.rawValue) " +
                        "value=\(value) bounds=\(bounds.lower)..." +
                        "\(bounds.upper) checkpoint=" +
                        "\(observation.checkpoint.rawValue) rate=" +
                        "\(Int(observation.sampleRate))"
                    )
                }
            }
            try #require(localFailures.isEmpty && relationshipFailures.isEmpty,
                         "Every development observation and relationship must qualify before promotion")
        }
        let liveCandidates = try renderLiveAdversarialCandidates()
        progress("live-candidates-ready causal=\(liveCandidates.isCausal)")
        for (label, candidate) in [
            ("attenuation", liveCandidates.attenuation),
            ("recovery", liveCandidates.recovery),
        ] {
            guard let kind = AutonomousPhraseKind(
                rawValue: candidate.symbolic.phraseKind
            ) else { continue }
            for checkpoint in CanonicalJourneyCheckpoint.applicable(
                phraseIndex: candidate.symbolic.phraseIndex,
                phraseKind: kind,
                chapterChanged: candidate.symbolic.chapterChanged
            ) {
                let observation = try ProfessionalQualityObservation(
                    candidate: candidate,
                    engineVersion: QualityQualificationContract.engineVersion,
                    checkpoint: checkpoint
                )
                let verdict = ProfessionalQualityProfileEvaluator.evaluate(
                    observation,
                    against: profile
                )
                progress(
                    "live-candidate=\(label) checkpoint=\(checkpoint.rawValue) " +
                    "accepted=\(verdict.accepted) failed=" +
                    verdict.failedMetrics.map(\.rawValue).joined(separator: ",")
                )
                for metric in verdict.failedMetrics {
                    guard let value = observation[metric],
                          let bounds = profile[checkpoint]?[metric] else {
                        continue
                    }
                    progress(
                        "live-candidate-detail=\(label) " +
                        "metric=\(metric.rawValue) value=\(value) " +
                        "bounds=\(bounds.lower)...\(bounds.upper)"
                    )
                }
            }
        }
        let adversarial = try ProfessionalQualityAdversarialSuiteReport(
            profile: profile,
            sourceCorpus: calibrationCorpus,
            liveCandidateChain: liveCandidates
        )
        progress("adversarial-ready fingerprint=\(adversarial.fingerprint)")
        for result in adversarial.cases where !result.passed {
            progress(
                "adversarial-failure=\(result.scenario.rawValue) " +
                "rejected=\(result.rejected) expected=" +
                result.expectedReasons.map(\.rawValue).joined(separator: ",") +
                " actual=" +
                result.actualReasons.map(\.rawValue).joined(separator: ",") +
                " metrics=" +
                result.failedMetrics.map(\.rawValue).joined(separator: ",")
            )
        }
        for trajectory in holdoutCorpus.trajectories {
            let relationshipFailures = ProfessionalQualityRelationshipEvaluator
                .evaluate(
                    observations: trajectory.observations,
                    against: profile
                ).failures
            for observation in trajectory.observations {
                let verdict = ProfessionalQualityProfileEvaluator.evaluate(
                    observation,
                    against: profile
                )
                for metric in verdict.failedMetrics {
                    guard let value = observation[metric],
                          let bounds = profile[observation.checkpoint]?[metric]
                    else { continue }
                    progress(
                        "holdout-preflight-local-detail=\(metric.rawValue) " +
                        "value=\(value) bounds=\(bounds.lower)..." +
                        "\(bounds.upper) checkpoint=" +
                        "\(observation.checkpoint.rawValue) rate=" +
                        "\(Int(observation.sampleRate)) source=" +
                        trajectory.sourceBankFingerprint
                    )
                }
            }
            for failure in relationshipFailures {
                progress(
                    "holdout-preflight-relationship-detail=" +
                    "\(failure.kind.rawValue):\(failure.metric.rawValue) " +
                    "value=\(failure.observedDelta) bounds=" +
                    "\(failure.lowerBound)...\(failure.upperBound) " +
                    "checkpoint=" +
                    (failure.checkpoint?.rawValue ?? "none") +
                    " source=\(trajectory.sourceBankFingerprint)"
                )
            }
        }
        let holdoutOverlap = calibrationCorpus.sourceBankFingerprints
            .intersection(holdoutCorpus.sourceBankFingerprints)
        progress(
            "holdout-preflight-contract " +
            "profile-diverse=\(profile.usesDiverseCalibration) " +
            "adversarial-schema=" +
            "\(adversarial.schemaVersion == ProfessionalQualityAdversarialSuiteReport.schemaVersion) " +
            "adversarial-version=" +
            "\(adversarial.suiteVersion == ProfessionalQualityAdversarialSuiteReport.suiteVersion) " +
            "adversarial-passed=\(adversarial.passed) " +
            "adversarial-profile=" +
            "\(adversarial.profileFingerprint == profile.fingerprint) " +
            "calibration-complete=\(calibrationCorpus.isComplete) " +
            "holdout-complete=\(holdoutCorpus.isComplete) " +
            "calibration-profile=" +
            "\(calibrationCorpus.fingerprint == profile.sourceBankFingerprint) " +
            "calibration-trajectories=" +
            "\(calibrationCorpus.sourceTrajectoryCount)/\(profile.sourceTrajectoryCount) " +
            "holdout-trajectories=" +
            "\(holdoutCorpus.sourceTrajectoryCount)/" +
            "\(ProfessionalQualityHoldoutQualification.minimumHoldoutTrajectoryCount) " +
            "calibration-engine=" +
            "\(calibrationCorpus.engineVersion == profile.engineVersion) " +
            "holdout-engine=" +
            "\(holdoutCorpus.engineVersion == profile.engineVersion) " +
            "calibration-evidence=" +
            "\(calibrationCorpus.evidenceVersion == profile.evidenceVersion) " +
            "holdout-evidence=" +
            "\(holdoutCorpus.evidenceVersion == profile.evidenceVersion) " +
            "overlap=\(holdoutOverlap.count)"
        )
        let holdout = try ProfessionalQualityHoldoutQualification(
            profile: profile,
            adversarialSuite: adversarial,
            calibrationCorpus: calibrationCorpus,
            holdoutCorpus: holdoutCorpus
        )
        let holdoutRelationshipFailureCount = holdout.trajectories.reduce(0) {
            $0 + $1.relationshipFailures.count
        }
        let localFailureCounts = Dictionary(grouping:
            holdout.trajectories.flatMap { trajectory in
                trajectory.verdicts.flatMap(\.failedMetrics)
            }, by: { $0 }
        ).mapValues(\.count)
        let relationshipFailureCounts = Dictionary(grouping:
            holdout.trajectories.flatMap(\.relationshipFailures),
            by: { "\($0.kind.rawValue):\($0.metric.rawValue)" }
        ).mapValues(\.count)
        progress(
            "holdout-ready qualified=\(holdout.qualified) " +
            "accepted=\(holdout.acceptedObservationCount)/" +
            "\(holdout.sourceObservationCount) relationships=" +
            "\(holdoutRelationshipFailureCount)"
        )
        progress("holdout-local-failures=\(localFailureCounts)")
        progress("holdout-relationship-failures=\(relationshipFailureCounts)")
        for trajectory in holdout.trajectories {
            progress(
                "holdout-source=\(trajectory.sourceBankFingerprint) " +
                "accepted=\(trajectory.acceptedObservationCount)/" +
                "\(trajectory.sourceObservationCount) relationships=" +
                "\(trajectory.relationshipFailures.count)"
            )
            for verdict in trajectory.verdicts where !verdict.accepted {
                guard let observation = holdoutCorpus.trajectories.first(where: {
                    $0.sourceBankFingerprint == trajectory.sourceBankFingerprint
                })?.observations.first(where: {
                    $0.sampleRate == verdict.sampleRate &&
                        $0.checkpoint == verdict.checkpoint
                }), let checkpointProfile = profile[verdict.checkpoint] else {
                    continue
                }
                for metric in verdict.failedMetrics {
                    guard let value = observation[metric],
                          let bounds = checkpointProfile[metric] else { continue }
                    progress(
                        "holdout-local-detail=\(metric.rawValue) " +
                        "value=\(value) bounds=\(bounds.lower)..." +
                        "\(bounds.upper) checkpoint=" +
                        "\(verdict.checkpoint.rawValue) rate=" +
                        "\(Int(verdict.sampleRate))"
                    )
                }
            }
            for failure in trajectory.relationshipFailures {
                progress(
                    "holdout-relationship-detail=\(failure.kind.rawValue):" +
                    "\(failure.metric.rawValue) value=" +
                    "\(failure.observedDelta) bounds=" +
                    "\(failure.lowerBound)...\(failure.upperBound) " +
                    "checkpoint=" +
                    (failure.checkpoint?.rawValue ?? "none")
                )
            }
        }
        guard profile.profileVersion ==
                ProfessionalQualityPrimaryEvaluator.requiredProfileVersion else {
            #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
                try ProfessionalQualityPrimaryEvaluator(
                    profile: profile,
                    adversarialSuite: adversarial,
                    holdoutQualification: holdout
                )
            }
            return
        }
        let primaryEvaluator = try ProfessionalQualityPrimaryEvaluator(
            profile: profile,
            adversarialSuite: adversarial,
            holdoutQualification: holdout
        )

        #expect(calibrationCorpus.sourceObservationCount ==
                calibrationSeeds.count *
                    CanonicalJourneyCheckpoint.allCases.count *
                    ProfessionalQualityCalibrationProfile.requiredSampleRates.count)
        #expect(profile.isComplete)
        #expect(profile.usesDiverseCalibration)
        #expect(profile.schemaVersion == 22)
        #expect(profile.observationVersion ==
                ProfessionalQualityObservation.observationVersion)
        #expect(profile.sourceTrajectoryCount == calibrationSeeds.count)
        #expect(adversarial.passed)
        #expect(adversarial.schemaVersion == 22)
        #expect(adversarial.cases.count ==
                ProfessionalQualityAdversarialScenario.allCases.count)
        #expect(holdout.qualified)
        #expect(holdout.schemaVersion == 20)
        #expect(holdout.holdoutTrajectoryCount == holdoutSeeds.count)
        #expect(holdout.overlappingSourceBankCount == 0)
        #expect(primaryEvaluator.policyVersion.contains(profile.fingerprint))
        #expect(primaryEvaluator.policyVersion.contains(adversarial.fingerprint))
        #expect(!profile.fingerprint.isEmpty)
        #expect(!adversarial.fingerprint.isEmpty)

        let profileJSON = try #require(String(
            data: profile.deterministicJSON(), encoding: .utf8
        ))
        let adversarialJSON = try #require(String(
            data: adversarial.deterministicJSON(), encoding: .utf8
        ))
        let holdoutJSON = try #require(String(
            data: holdout.deterministicJSON(), encoding: .utf8
        ))
        try writePrimaryArtifacts(
            profile: profile,
            adversarial: adversarial,
            holdout: holdout
        )
        print("AUTOTECHNO_CALIBRATION_PROFILE_JSON_BEGIN")
        print(profileJSON)
        print("AUTOTECHNO_CALIBRATION_PROFILE_JSON_END")
        print("AUTOTECHNO_ADVERSARIAL_SUITE_JSON_BEGIN")
        print(adversarialJSON)
        print("AUTOTECHNO_ADVERSARIAL_SUITE_JSON_END")
        print("AUTOTECHNO_HOLDOUT_QUALIFICATION_JSON_BEGIN")
        print(holdoutJSON)
        print("AUTOTECHNO_HOLDOUT_QUALIFICATION_JSON_END")
        print("AUTOTECHNO_CALIBRATION_PROFILE_FINGERPRINT=\(profile.fingerprint)")
        print("AUTOTECHNO_ADVERSARIAL_SUITE_FINGERPRINT=\(adversarial.fingerprint)")
        print("AUTOTECHNO_HOLDOUT_QUALIFICATION_FINGERPRINT=\(holdout.fingerprint)")
    }

    @Test("Render selected calibration diagnostic journeys")
    func renderSelectedDiagnosticJourney() throws {
        let environment = ProcessInfo.processInfo.environment
        let selectedSeeds: [UInt64]
        if let raw = environment["AUTOTECHNO_CALIBRATION_DIAGNOSTIC_SEEDS"] {
            if raw == "all-calibration" {
                selectedSeeds = calibrationSeeds
            } else {
                selectedSeeds = try raw.split(separator: ",").map { value in
                    guard let seed = UInt64(value.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )) else {
                        throw ProfessionalQualityCalibrationError
                            .invalidLocalFeatureEvidence
                    }
                    return seed
                }
            }
        } else if let raw = environment[
            "AUTOTECHNO_CALIBRATION_DIAGNOSTIC_SEED"
        ], let seed = UInt64(raw) {
            selectedSeeds = [seed]
        } else {
            return
        }
        guard !selectedSeeds.isEmpty,
              Set(selectedSeeds).count == selectedSeeds.count else {
            throw ProfessionalQualityCalibrationError.invalidLocalFeatureEvidence
        }

        let verifiesCohort = environment["AUTOTECHNO_AT0038_VERIFY_NATIVE_COHORT"] == "1"
        guard !verifiesCohort || selectedSeeds == calibrationSeeds else {
            throw AT0038AcceptanceError.invalidCohortMembership
        }
        var cohortAudit = try AT0038LocalCohortAudit(expectedSeeds: selectedSeeds)

        var reports: [(seed: UInt64,
                       report: ProfessionalQualityKickFoundationLocalEvidence)] = []
        for seed in selectedSeeds {
            var sourceReports: [CanonicalJourneyQualificationReport] = []
            for sampleRate in ProfessionalQualityCalibrationProfile
                .requiredSampleRates {
                sourceReports.append(contentsOf: try renderJourney(
                    seed: seed,
                    sampleRate: sampleRate
                ))
            }
            let bank = try ProfessionalEvidenceReportBank(reports: sourceReports)
            let trajectory = try ProfessionalQualityCalibrationTrajectory(
                bank: bank
            )
            let localReports = try bank.kickFoundationLocalFeatureReports()
            let maskingReports = try bank.maskingLocalFeatureReports()
            // Verify the original typed source before emitting diagnostics.
            // This bounded reconstruction cannot grant roadmap admission.
            let localWitnesses = try AT0038LocalEvidenceAcceptanceSupport.reconstruct(bank)
            guard localWitnesses.map(\.kick) == localReports,
                  localWitnesses.map(\.masking) == maskingReports else {
                throw AT0038AcceptanceError.invalidProjection
            }
            if verifiesCohort { try cohortAudit.append(seed: seed, bank: bank) }
            let modalWindows = try bank.modalWindowFeatureReports()
            guard localReports.count ==
                    CanonicalJourneyCheckpoint.allCases.count *
                    ProfessionalQualityCalibrationProfile.requiredSampleRates.count,
                  maskingReports.count == localReports.count,
                  modalWindows.count == localReports.count,
                  maskingReports.allSatisfy({ report in
                      report.observationCount == report.sourceBarCount *
                          AutonomousCandidateEvaluationVector
                              .maximumMaskingObservationsPerBar
                  })
            else {
                throw ProfessionalQualityCalibrationError
                    .invalidLocalFeatureEvidence
            }
            progress(
                "diagnostic-seed=\(seed) source=" +
                trajectory.sourceBankFingerprint +
                " local-reports=\(localReports.count)"
            )
            let modalEncoder = JSONEncoder()
            modalEncoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            for modal in modalWindows {
                progress("modal-window-evidence seed=\(seed) json=" +
                    String(decoding: try modalEncoder.encode(modal), as: UTF8.self))
            }
            reports.append(contentsOf: localReports.map { (seed, $0) })
            for local in localReports {
                let mean = local.meanDB.map { String($0) } ?? "unavailable"
                let spread = local.spreadDB.map { String($0) } ?? "unavailable"
                let minimum = local.barMeasurements.min {
                    $0.kickOverFoundationDB < $1.kickOverFoundationDB
                }
                let maximum = local.barMeasurements.max {
                    $0.kickOverFoundationDB < $1.kickOverFoundationDB
                }
                let extrema: String
                if let minimum, let maximum {
                    extrema = "min-bar=\(minimum.bar):" +
                        "\(minimum.kickOverFoundationDB) " +
                        "max-bar=\(maximum.bar):" +
                        "\(maximum.kickOverFoundationDB)"
                } else {
                    extrema = "extrema=unavailable"
                }
                progress(
                    "diagnostic-seed=\(seed) checkpoint=" +
                    "\(local.checkpoint.rawValue) rate=\(Int(local.sampleRate)) " +
                    "source-bars=\(local.sourceBarCount) " +
                    "paired-bars=\(local.pairedBarCount) " +
                    "availability=\(local.availability.rawValue) " +
                    "mean-db=\(mean) spread-db=\(spread) \(extrema)"
                )
            }
        }

        for key in Set(reports.map {
            "\($0.report.checkpoint.rawValue)|\(Int($0.report.sampleRate))"
        }).sorted() {
            let values = reports.filter {
                "\($0.report.checkpoint.rawValue)|" +
                    "\(Int($0.report.sampleRate))" == key
            }
            func summary(_ samples: [Double]) -> String {
                let sorted = samples.sorted()
                guard let first = sorted.first, let last = sorted.last else {
                    return "unavailable"
                }
                let median = sorted[sorted.count / 2]
                return "min=\(first),median=\(median),max=\(last)"
            }
            let means = values.compactMap { $0.report.meanDB }
            let estimableSpreads = values.compactMap { value in
                value.report.pairedBarCount >= 2 ? value.report.spreadDB : nil
            }
            let pairedCounts = Dictionary(grouping: values) {
                $0.report.pairedBarCount
            }.keys.sorted().map { count in
                let journeys = values.filter {
                    $0.report.pairedBarCount == count
                }.count
                return "\(count):\(journeys)"
            }.joined(separator: ",")
            progress(
                "diagnostic-distribution group=\(key) " +
                "journeys=\(values.count) " +
                "paired-bar-counts=\(pairedCounts) " +
                "spread-estimable-journeys=\(estimableSpreads.count) " +
                "mean-db.{\(summary(means))} " +
                "spread-db-paired-bars-ge-2.{\(summary(estimableSpreads))}"
            )
        }

        if verifiesCohort {
            // The original plan's fourteen extrema subjects plus its explicitly
            // requested seed33333 outlier rerender. Current extrema are additive.
            let historical: [UInt64] = [90_909, 48_291, 161_803, 13, 7, 141_421,
                30_303, 20_202, 866_025, 80_808, 42, 121_212, 40_404, 99_999, 33_333]
            let required = try cohortAudit.requiredRerenderSeeds(historical: historical)
            for seed in required {
                var sourceReports: [CanonicalJourneyQualificationReport] = []
                for rate in ProfessionalQualityCalibrationProfile.requiredSampleRates {
                    sourceReports.append(contentsOf: try renderJourney(seed: seed, sampleRate: rate))
                }
                try cohortAudit.verifyRerender(seed: seed,
                    bank: ProfessionalEvidenceReportBank(reports: sourceReports))
            }
            let groups = try cohortAudit.finish()
            let reportBytes = try cohortAudit.encodedCompletedReport()
            progress("at0038-descriptive-cohort-report json=" + String(decoding: reportBytes, as: UTF8.self))
            progress("at0038-descriptive-cohort journeys=\(calibrationSeeds.count) " +
                "groups=\(groups.count) rerendered=\(required.count) " +
                "authority=unavailable-full-item-matrix-still-required")
        }
    }

    @Test("Render one explicitly selected planned boundary")
    func renderSelectedPlannedBoundary() throws {
        guard let rawSeed = ProcessInfo.processInfo.environment[
            "AUTOTECHNO_CALIBRATION_BOUNDARY_SEED"
        ], let seed = UInt64(rawSeed),
        let rawPhrase = ProcessInfo.processInfo.environment[
            "AUTOTECHNO_CALIBRATION_BOUNDARY_PHRASE"
        ], let phraseIndex = Int(rawPhrase), phraseIndex >= 0 else { return }

        let director = AutonomousSessionDirector(rootSeed: seed)
        var state = director.initialState()
        while state.phraseIndex < phraseIndex {
            state.advancePlanning(using: director.plan(from: state))
        }
        let plan = director.plan(from: state)
        var renderState = RenderState()
        renderState.barIndex = plan.startBar
        let outcome = AutonomousPhrasePreparer.prepareDiagnosingIfNotCancelled(
            plan: plan,
            sessionSeed: seed,
            memory: state.memory,
            sampleRate: 44_100,
            incomingRenderState: renderState,
            incomingGraphState: GeneratedDSPContinuationState(),
            previousGraph: nil,
            incomingQualityState: state.quality,
            evaluator: ProfessionalEvidenceOnlyEvaluator(),
            cancellationRequested: { false }
        )
        if let failure = outcome.failure {
            progress(
                "boundary-failed seed=\(seed) phrase=\(phraseIndex) " +
                "bar=\(plan.startBar) kind=\(plan.kind.rawValue) " +
                "stage=\(failure.stage.rawValue) code=\(failure.code.rawValue) " +
                "details=\(failure.details.joined(separator: ","))"
            )
        }
        #expect(outcome.preparedPhrase != nil)
    }

    @Test("Trace one explicitly selected accumulated journey")
    func traceSelectedAccumulatedJourney() throws {
        guard let rawSeed = ProcessInfo.processInfo.environment[
            "AUTOTECHNO_CALIBRATION_TRACE_SEED"
        ], let seed = UInt64(rawSeed) else { return }

        let director = AutonomousSessionDirector(rootSeed: seed)
        var state = director.initialState()
        var renderState = RenderState()
        var graphState = GeneratedDSPContinuationState()
        var previousGraph: DSPGraphPlan?
        for _ in 0..<32 {
            let plan = director.plan(from: state)
            progress(
                "trace-begin seed=\(seed) phrase=\(plan.phraseIndex) " +
                    "bar=\(plan.startBar) kind=\(plan.kind.rawValue)"
            )
            let outcome = AutonomousPhrasePreparer.prepareDiagnosingIfNotCancelled(
                plan: plan,
                sessionSeed: seed,
                memory: state.memory,
                sampleRate: 44_100,
                incomingRenderState: renderState,
                incomingGraphState: graphState,
                previousGraph: previousGraph,
                incomingQualityState: state.quality,
                evaluator: ProfessionalEvidenceOnlyEvaluator(),
                cancellationRequested: { false }
            )
            guard let prepared = outcome.preparedPhrase else {
                if let failure = outcome.failure {
                    progress(
                        "trace-failed seed=\(seed) phrase=\(plan.phraseIndex) " +
                            "bar=\(plan.startBar) kind=\(plan.kind.rawValue) " +
                            "stage=\(failure.stage.rawValue) " +
                            "code=\(failure.code.rawValue) " +
                            "details=\(failure.details.joined(separator: ","))"
                    )
                }
                Issue.record("Accumulated journey preparation failed")
                return
            }
            progress(
                "trace-pass seed=\(seed) phrase=\(plan.phraseIndex) " +
                    "graph=\(prepared.graph.revision)"
            )
            state = state.advance(
                using: prepared.plan,
                quality: prepared.qualityContinuationState,
                liveMasterHeadroom:
                    prepared.liveMasterHeadroomContinuationState
            )
            renderState = prepared.endingRenderState
            graphState = prepared.endingGraphState
            previousGraph = prepared.graph
        }
    }

    private func renderTrajectory(
        seed: UInt64, windowFixture: CanonicalCalibrationWindowFixture? = nil
    ) throws
        -> ProfessionalQualityCalibrationTrajectory {
        try resolvedTrajectory(
            seed: seed,
            cacheDirectory: cacheDirectory(),
            windowFixture: windowFixture
        ) {
            var reports: [CanonicalJourneyQualificationReport] = []
            for sampleRate in ProfessionalQualityCalibrationProfile
                .requiredSampleRates {
                reports.append(contentsOf: try renderJourney(
                    seed: seed,
                    sampleRate: sampleRate, windowFixture: windowFixture
                ))
            }
            return reports
        }
    }

    /// Bounded parallelism reduces wall time for this opt-in multi-hour
    /// harness. Indexed collection preserves the canonical seed order, so
    /// corpus fingerprints and artifact bytes remain deterministic.
    private func renderTrajectories(
        seeds: [UInt64], windowFixtures: [CanonicalCalibrationWindowFixture] = []
    ) async throws
        -> [ProfessionalQualityCalibrationTrajectory] {
        let maximumConcurrentTrajectories = 4
        return try await withThrowingTaskGroup(
            of: (Int, ProfessionalQualityCalibrationTrajectory).self
        ) { group in
            var next = seeds.enumerated().makeIterator()
            for _ in 0..<min(maximumConcurrentTrajectories, seeds.count) {
                guard let (index, seed) = next.next() else { break }
                group.addTask {
                    (index, try self.renderTrajectory(
                        seed: seed, windowFixture: windowFixtures.first { $0.rootSeed == seed }
                    ))
                }
            }

            var ordered = Array<ProfessionalQualityCalibrationTrajectory?>(
                repeating: nil,
                count: seeds.count
            )
            while let (index, trajectory) = try await group.next() {
                ordered[index] = trajectory
                if let (nextIndex, nextSeed) = next.next() {
                    group.addTask {
                        (nextIndex, try self.renderTrajectory(
                            seed: nextSeed, windowFixture: windowFixtures.first { $0.rootSeed == nextSeed }
                        ))
                    }
                }
            }
            return try ordered.map { trajectory in
                guard let trajectory else {
                    throw ProfessionalQualityCalibrationError
                        .incompleteCheckpointCoverage
                }
                return trajectory
            }
        }
    }

    @Test("Journey cache identity separates rendered inputs from artifact versions")
    func cachedJourneyIdentityTracksRenderedInputs() throws {
        let current = CachedJourneyIdentity.current(rootSeed: 42)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: encoder.encode(current))
                as? [String: Any]
        )
        legacyObject["profileVersion"] =
            "autotechno-professional-quality-profile.v29"
        legacyObject["profileSchemaVersion"] = 21
        legacyObject["adversarialSuiteVersion"] =
            "autotechno-professional-quality-adversarial.v22"
        let legacy = try JSONDecoder().decode(
            CachedJourneyIdentity.self,
            from: canonicalCacheJSON(legacyObject)
        )
        #expect(legacy.matchesRenderedJourneyContract(current))

        legacyObject["engineVersion"] = "autotechno-canonical-engine.v47"
        let staleRender = try JSONDecoder().decode(
            CachedJourneyIdentity.self,
            from: canonicalCacheJSON(legacyObject)
        )
        #expect(!staleRender.matchesRenderedJourneyContract(current))
    }

    @Test("Completed report cache survives calibration artifact version changes")
    func completedJourneyCacheSurvivesArtifactVersionChanges() throws {
        guard let directoryPath = ProcessInfo.processInfo.environment[
            "AUTOTECHNO_CALIBRATION_CACHE_DIRECTORY"
        ], !directoryPath.isEmpty else { return }
        let directory = URL(fileURLWithPath: directoryPath, isDirectory: true)
        let seeds = [UInt64(7), 60_606, 66_666].filter {
            FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("journey-\($0).json").path
            )
        }
        guard seeds.contains(7) else {
            Issue.record("Opt-in cache directory is missing the completed seed-7 report")
            return
        }
        for seed in seeds {
            var attemptedRendering = false
            let trajectory = try resolvedTrajectory(seed: seed,
                                                    cacheDirectory: directory) {
                attemptedRendering = true
                throw ProfessionalQualityCalibrationError.profileMismatch
            }
            #expect(!attemptedRendering)
            #expect(trajectory.isComplete)
        }
    }

    @Test("Frozen window geometry gates both decoded caches and freshly generated banks")
    func frozenWindowGeometryRejectsMismatchedReports() throws {
        guard let directoryPath = ProcessInfo.processInfo.environment[
            "AUTOTECHNO_CALIBRATION_CACHE_DIRECTORY"
        ], !directoryPath.isEmpty else { return }
        let data = try Data(contentsOf: cacheURL(
            seed: 7, directory: URL(fileURLWithPath: directoryPath)
        ))
        let cached = try JSONDecoder().decode(CachedJourneyReportBank.self, from: data)
        let reports = try cached.reportJSON.map(
            CanonicalJourneyQualificationReport.decodeDeterministicJSON
        )
        let report = try #require(reports.first { $0.checkpoint == .majorBreak })
        let evidence = report.selectedCandidateEvidence
        let planned = CanonicalJourneyPlanCheckpoint(
            checkpoint: .majorBreak,
            phraseIndex: evidence.symbolic.phraseIndex,
            startBar: evidence.symbolic.startBar,
            phraseKind: .majorBreak, qualityRevision: report.incomingState.revision,
            resolvedBarCount: evidence.phraseComposition.count,
            planFingerprint: evidence.planFingerprint,
            fixtureFingerprint: report.fixtureFingerprint,
            continuationFingerprint: report.continuationFingerprint
        )
        let releaseReport = try #require(reports.first { $0.checkpoint == .release })
        let releaseEvidence = releaseReport.selectedCandidateEvidence
        let release = CanonicalJourneyPlanCheckpoint(
            checkpoint: .release,
            phraseIndex: releaseEvidence.symbolic.phraseIndex,
            startBar: releaseEvidence.symbolic.startBar,
            phraseKind: .energyRelease, qualityRevision: releaseReport.incomingState.revision,
            resolvedBarCount: releaseEvidence.phraseComposition.count,
            planFingerprint: releaseEvidence.planFingerprint,
            fixtureFingerprint: releaseReport.fixtureFingerprint,
            continuationFingerprint: releaseReport.continuationFingerprint
        )
        let fixture = CanonicalCalibrationWindowFixture(
            ordinal: 0, rootSeed: 7, planned: planned, followingRelease: release
        )
        #expect(windowReportsMatch(reports, fixture: fixture))
        #expect(!windowReportsMatch(reports.filter { $0.sampleRate == 44_100 },
                                   fixture: fixture))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let scoped = try encoder.encode(CachedJourneyReportBank(
            identity: cached.identity, reportJSON: cached.reportJSON,
            windowFixture: fixture
        ))
        #expect(try decodedCacheTrajectory(scoped, requestedSeed: 7,
                                           windowFixture: fixture) != nil)
        #expect(try decodedCacheTrajectory(scoped, requestedSeed: 7) == nil)
        // A valid complete old bank cannot satisfy a new frozen window by
        // merely acquiring metadata. Its actual candidate score must match.
        var object = try #require(JSONSerialization.jsonObject(with:
            encoder.encode(fixture)) as? [String: Any])
        var planObject = try #require(object["planned"] as? [String: Any])
        planObject["resolvedBarCount"] = 4
        planObject["planFingerprint"] = "0000000000000000"
        object["planned"] = planObject
        let mismatch = try JSONDecoder().decode(CanonicalCalibrationWindowFixture.self,
                                                from: canonicalCacheJSON(object))
        #expect(!windowReportsMatch(reports, fixture: mismatch))
        let forgedScope = try encoder.encode(CachedJourneyReportBank(
            identity: cached.identity, reportJSON: cached.reportJSON,
            windowFixture: mismatch
        ))
        #expect(try decodedCacheTrajectory(forgedScope, requestedSeed: 7,
                                           windowFixture: mismatch) == nil)
        var releaseObject = try #require(object["followingRelease"] as? [String: Any])
        releaseObject["phraseIndex"] = planned.phraseIndex
        var releaseMismatchObject = try #require(JSONSerialization.jsonObject(with:
            encoder.encode(fixture)) as? [String: Any])
        releaseMismatchObject["followingRelease"] = releaseObject
        let releaseMismatch = try JSONDecoder().decode(CanonicalCalibrationWindowFixture.self,
            from: canonicalCacheJSON(releaseMismatchObject))
        #expect(!windowReportsMatch(reports, fixture: releaseMismatch))
        #expect(throws: ProfessionalQualityCalibrationError.profileMismatch) {
            try resolvedTrajectory(seed: 7, cacheDirectory: nil,
                                   windowFixture: mismatch) { reports }
        }
    }

    func resolvedTrajectory(
        seed: UInt64,
        cacheDirectory: URL?,
        windowFixture: CanonicalCalibrationWindowFixture? = nil,
        generateReports: () throws -> [CanonicalJourneyQualificationReport]
    ) throws -> ProfessionalQualityCalibrationTrajectory {
        if let cacheDirectory,
           let cached = try cachedTrajectory(
               seed: seed,
               directory: cacheDirectory, windowFixture: windowFixture
           ) {
            progress("cache-hit seed=\(seed)")
            return cached
        }
        let reports = try generateReports()
        guard windowReportsMatch(reports, fixture: windowFixture) else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        let trajectory = try ProfessionalQualityCalibrationTrajectory(
            bank: ProfessionalEvidenceReportBank(reports: reports)
        )
        if let cacheDirectory {
            try cache(
                reports: reports,
                seed: seed,
                directory: cacheDirectory, windowFixture: windowFixture
            )
        }
        return trajectory
    }

    private func renderLiveAdversarialCandidates() throws ->
        ProfessionalQualityLiveCandidateChain {
        try LiveFeedbackTestSupport.renderLiveTransitionCandidates()
    }

    private func printLeaveTwoOutResults(
        seeds: [UInt64],
        trajectories: [ProfessionalQualityCalibrationTrajectory]
    ) throws {
        guard seeds.count == trajectories.count, seeds.count == 5 else { return }
        for firstHoldout in 0..<(seeds.count - 1) {
            for secondHoldout in (firstHoldout + 1)..<seeds.count {
                let holdoutIndices = Set([firstHoldout, secondHoldout])
                let calibration = try ProfessionalQualityCalibrationCorpus(
                    trajectories: trajectories.enumerated().compactMap {
                        holdoutIndices.contains($0.offset) ? nil : $0.element
                    }
                )
                let profile = try ProfessionalQualityCalibrationProfile(
                    corpus: calibration
                )
                let holdouts = holdoutIndices.sorted().map { trajectories[$0] }
                let accepted = holdouts.flatMap(\.observations).filter {
                    ProfessionalQualityProfileEvaluator.evaluate(
                        $0, against: profile
                    ).accepted
                }.count
                let relationships = holdouts.reduce(0) { result, trajectory in
                    result + ProfessionalQualityRelationshipEvaluator.evaluate(
                        observations: trajectory.observations,
                        against: profile
                    ).failures.count
                }
                progress(
                    "leave-two-out=\(seeds[firstHoldout])," +
                    "\(seeds[secondHoldout]) accepted=\(accepted)/28 " +
                    "relationships=\(relationships)"
                )
            }
        }
    }

    private func printLeaveOneOutResults(
        seeds: [UInt64],
        trajectories: [ProfessionalQualityCalibrationTrajectory]
    ) throws {
        guard seeds.count == trajectories.count, seeds.count == 5 else { return }
        for holdoutIndex in seeds.indices {
            let calibration = try ProfessionalQualityCalibrationCorpus(
                trajectories: trajectories.enumerated().compactMap {
                    $0.offset == holdoutIndex ? nil : $0.element
                }
            )
            let profile = try ProfessionalQualityCalibrationProfile(
                corpus: calibration
            )
            let holdout = trajectories[holdoutIndex]
            let accepted = holdout.observations.filter {
                ProfessionalQualityProfileEvaluator.evaluate(
                    $0, against: profile
                ).accepted
            }.count
            let relationships = ProfessionalQualityRelationshipEvaluator
                .evaluate(observations: holdout.observations, against: profile)
                .failures.count
            progress(
                "leave-one-out=\(seeds[holdoutIndex]) " +
                "accepted=\(accepted)/14 relationships=\(relationships)"
            )
        }
    }

    func cachedTrajectory(
        seed: UInt64,
        directory: URL,
        windowFixture: CanonicalCalibrationWindowFixture? = nil
    ) throws -> ProfessionalQualityCalibrationTrajectory? {
        let url = cacheURL(seed: seed, directory: directory)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let fileSize = values.fileSize,
              fileSize > 0,
              fileSize <= CachedJourneyReportBank.maximumEncodedBytes,
              let data = try? Data(contentsOf: url) else { return nil }
        return try decodedCacheTrajectory(data, requestedSeed: seed, windowFixture: windowFixture)
    }

    func decodedCacheTrajectory(
        _ data: Data,
        requestedSeed: UInt64,
        windowFixture: CanonicalCalibrationWindowFixture? = nil
    ) throws -> ProfessionalQualityCalibrationTrajectory? {
        guard !data.isEmpty,
              data.count <= CachedJourneyReportBank.maximumEncodedBytes,
              let decoded = try? JSONDecoder().decode(
                  CachedJourneyReportBank.self,
                  from: data
              ),
              [2, CachedJourneyReportBank.schemaVersion].contains(decoded.schemaVersion),
              decoded.windowFixture == windowFixture,
              (decoded.schemaVersion != 2 || decoded.windowFixture == nil),
              decoded.identity.matchesRenderedJourneyContract(
                  CachedJourneyIdentity.current(rootSeed: requestedSeed)
              ),
              decoded.reportJSON.count ==
                CachedJourneyReportBank.expectedReportCount,
              decoded.reportJSON.allSatisfy({
                  !$0.isEmpty &&
                      $0.count <= CanonicalJourneyQualificationReport
                        .maximumEncodedBytes
              }) else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let canonicalData = try? encoder.encode(decoded),
              canonicalData == data,
              let reports = try? decoded.reportJSON.map(
                  CanonicalJourneyQualificationReport.decodeDeterministicJSON
              ),
              windowReportsMatch(reports, fixture: windowFixture),
              reports.allSatisfy({ report in
                  report.schemaVersion == decoded.identity
                    .qualitySchemaVersion &&
                      report.engineVersion == decoded.identity.engineVersion &&
                      report.policyVersion == decoded.identity.policyVersion &&
                      report.evidenceScope == decoded.identity.evidenceScope &&
                      report.selectedCandidateEvidence.schemaVersion ==
                        decoded.identity.candidateSchemaVersion &&
                      report.candidateEvaluation.schemaVersion ==
                        decoded.identity.transactionSchemaVersion &&
                      report.commitProvenance.schemaVersion ==
                        decoded.identity.commitSchemaVersion &&
                      decoded.identity.sampleRates.contains(report.sampleRate) &&
                      report.fixtureFingerprint.hasPrefix(
                          "seed-\(requestedSeed)."
                      )
              }),
              let bank = try? ProfessionalEvidenceReportBank(reports: reports),
              bank.schemaVersion == decoded.identity.reportBankSchemaVersion,
              bank.evidenceVersion == decoded.identity.evidenceVersion,
              bank.engineVersion == decoded.identity.engineVersion,
              bank.policyVersion == decoded.identity.policyVersion,
              bank.evaluatorVersion == decoded.identity.evaluatorVersion,
              bank.sampleRates == decoded.identity.sampleRates,
              bank.sourceReportCount ==
                CachedJourneyReportBank.expectedReportCount,
              let trajectory = try? ProfessionalQualityCalibrationTrajectory(
                  bank: bank
              ),
              trajectory.isComplete else { return nil }
        return trajectory
    }

    func cache(
        reports: [CanonicalJourneyQualificationReport],
        seed: UInt64,
        directory: URL,
        windowFixture: CanonicalCalibrationWindowFixture? = nil
    ) throws {
        let url = cacheURL(seed: seed, directory: directory)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let cache = CachedJourneyReportBank(
            identity: CachedJourneyIdentity.current(rootSeed: seed),
            reportJSON: try reports.map { try $0.deterministicJSON() },
            windowFixture: windowFixture
        )
        let data = try encoder.encode(cache)
        guard data.count <= CachedJourneyReportBank.maximumEncodedBytes,
              try decodedCacheTrajectory(
                  data, requestedSeed: seed, windowFixture: windowFixture
              ) != nil else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        try data.write(to: url, options: .atomic)
    }

    /// Cache only complete candidate-derived reports. Observation JSON is an
    /// intentionally non-decodable reduction and cannot be trusted as a
    /// substitute for report validation during deterministic regeneration.
    struct CachedJourneyReportBank: Codable {
        static let schemaVersion = 3
        static let expectedReportCount =
            CanonicalJourneyCheckpoint.allCases.count *
                ProfessionalQualityCalibrationProfile.requiredSampleRates.count
        static let maximumEncodedBytes =
            ProfessionalEvidenceReportBank.maximumEncodedBytes

        let schemaVersion: Int
        let identity: CachedJourneyIdentity
        let reportJSON: [Data]
        let windowFixture: CanonicalCalibrationWindowFixture?

        init(
            identity: CachedJourneyIdentity, reportJSON: [Data],
            windowFixture: CanonicalCalibrationWindowFixture? = nil
        ) {
            schemaVersion = Self.schemaVersion
            self.identity = identity
            self.reportJSON = reportJSON
            self.windowFixture = windowFixture
        }
    }

    struct CachedJourneyIdentity: Codable, Equatable {
        let rootSeed: UInt64
        let maximumPhrases: Int
        let qualitySchemaVersion: Int
        let engineVersion: String
        let policyVersion: String
        let evaluatorVersion: String
        let candidateSchemaVersion: Int
        let transactionSchemaVersion: Int
        let commitSchemaVersion: Int
        let reportBankSchemaVersion: Int
        let evidenceVersion: String
        let evidenceScope: String
        let observationSchemaVersion: Int
        let observationVersion: String
        let profileSchemaVersion: Int
        let profileVersion: String
        let primaryEvaluatorVersion: String
        let primaryPolicyVersion: String
        let adversarialSchemaVersion: Int
        let adversarialSuiteVersion: String
        let holdoutSchemaVersion: Int
        let holdoutQualificationVersion: String
        let sampleRates: [Double]
        let checkpoints: [String]

        /// The cached rows are rendered with `ProfessionalEvidenceOnlyEvaluator`.
        /// Profile, primary-evaluator, adversarial, and holdout identities are
        /// recorded for provenance but do not affect those report rows. Keep
        /// every render and report contract exact while allowing cached PCM
        /// evidence to feed a newly versioned calibration artifact set.
        func matchesRenderedJourneyContract(
            _ current: CachedJourneyIdentity
        ) -> Bool {
            rootSeed == current.rootSeed &&
                maximumPhrases == current.maximumPhrases &&
                qualitySchemaVersion == current.qualitySchemaVersion &&
                engineVersion == current.engineVersion &&
                policyVersion == current.policyVersion &&
                evaluatorVersion == current.evaluatorVersion &&
                candidateSchemaVersion == current.candidateSchemaVersion &&
                transactionSchemaVersion == current.transactionSchemaVersion &&
                commitSchemaVersion == current.commitSchemaVersion &&
                reportBankSchemaVersion == current.reportBankSchemaVersion &&
                evidenceVersion == current.evidenceVersion &&
                evidenceScope == current.evidenceScope &&
                observationSchemaVersion == current.observationSchemaVersion &&
                observationVersion == current.observationVersion &&
                sampleRates == current.sampleRates &&
                checkpoints == current.checkpoints
        }

        static func current(rootSeed: UInt64) -> CachedJourneyIdentity {
            CachedJourneyIdentity(
                rootSeed: rootSeed,
                maximumPhrases: 128,
                qualitySchemaVersion: QualityQualificationContract.schemaVersion,
                engineVersion: QualityQualificationContract.engineVersion,
                policyVersion:
                    QualityQualificationContract.uncalibratedPolicyVersion,
                evaluatorVersion:
                    QualityQualificationContract.uncalibratedEvaluatorVersion,
                candidateSchemaVersion:
                    AutonomousCandidateEvaluationVector.schemaVersion,
                transactionSchemaVersion:
                    AutonomousCandidateEvaluationTransaction.schemaVersion,
                commitSchemaVersion:
                    AutonomousPreparedCommitProvenance.schemaVersion,
                reportBankSchemaVersion: ProfessionalEvidenceReportBank.schemaVersion,
                evidenceVersion: ProfessionalEvidenceReportBank.evidenceVersion,
                evidenceScope:
                    CanonicalJourneyQualificationReport.currentEvidenceScope,
                observationSchemaVersion: ProfessionalQualityObservation.schemaVersion,
                observationVersion:
                    ProfessionalQualityObservation.observationVersion,
                profileSchemaVersion:
                    ProfessionalQualityCalibrationProfile.schemaVersion,
                profileVersion:
                    ProfessionalQualityCalibrationProfile.profileVersion,
                primaryEvaluatorVersion:
                    ProfessionalQualityPrimaryEvaluator.evaluatorVersionIdentifier,
                primaryPolicyVersion:
                    ProfessionalQualityPrimaryEvaluator.policyFamilyVersion,
                adversarialSchemaVersion:
                    ProfessionalQualityAdversarialSuiteReport.schemaVersion,
                adversarialSuiteVersion:
                    ProfessionalQualityAdversarialSuiteReport.suiteVersion,
                holdoutSchemaVersion:
                    ProfessionalQualityHoldoutQualification.schemaVersion,
                holdoutQualificationVersion:
                    ProfessionalQualityHoldoutQualification.qualificationVersion,
                sampleRates:
                    ProfessionalQualityCalibrationProfile.requiredSampleRates,
                checkpoints: CanonicalJourneyCheckpoint.allCases.map(\.rawValue)
            )
        }
    }

    func canonicalCacheJSON(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    }

    private func cacheDirectory() -> URL? {
        guard let directory = ProcessInfo.processInfo.environment[
            "AUTOTECHNO_CALIBRATION_CACHE_DIRECTORY"
        ], !directory.isEmpty else { return nil }
        return URL(fileURLWithPath: directory, isDirectory: true)
    }

    func cacheURL(seed: UInt64, directory: URL) -> URL {
        directory
            .appendingPathComponent("journey-\(seed).json")
    }

    private struct JourneyExecution {
        let reports: [CanonicalJourneyQualificationReport]
        let successors: [ProfessionalQualityModalSuccessorEvidence]
        let renderedPhraseCount: Int
    }

    private func renderJourney(
        seed: UInt64,
        sampleRate: Double,
        maximumPhrases: Int = 128,
        windowFixture: CanonicalCalibrationWindowFixture? = nil
    ) throws -> [CanonicalJourneyQualificationReport] {
        try executeJourney(seed: seed, sampleRate: sampleRate,
            maximumPhrases: maximumPhrases, windowFixture: windowFixture).reports
    }

    /// One persistent producer for legacy captures and explicit continuous
    /// execution. Original checkpoint membership never includes successors.
    /// Frozen planning quality labels remain separate from actual accepted
    /// quality/live/render/DSP/graph continuation, which advances every phrase.
    private func executeJourney(
        seed: UInt64,
        sampleRate: Double,
        maximumPhrases: Int = 128,
        windowFixture: CanonicalCalibrationWindowFixture? = nil,
        frozenCheckpoints: [CanonicalJourneyPlanCheckpoint]? = nil,
        requiredMajorBreakBarCount: Int? = nil,
        requiresActualSuccessors: Bool = false
    ) throws -> JourneyExecution {
        guard (1...128).contains(maximumPhrases),
              requiredMajorBreakBarCount == nil || requiredMajorBreakBarCount == 4,
              !(windowFixture != nil && frozenCheckpoints != nil) else {
            throw ProfessionalQualityCalibrationError.invalidIdentity
        }
        let director = AutonomousSessionDirector(rootSeed: seed)
        let requiredCheckpoints = frozenCheckpoints.map {
            Set($0.map(\.checkpoint))
        } ?? Set(CanonicalJourneyCheckpoint.allCases)
        if let frozen = frozenCheckpoints {
            let planning = CanonicalJourneyQualificationHarness(
                engineVersion: QualityQualificationContract.engineVersion,
                routeFingerprint: "score-only-coverage-selection", routeGeneration: 0)
                .planCheckpoints(director: director, maximumPhrases: maximumPhrases,
                    requiredBarCounts: requiredMajorBreakBarCount.map { [.majorBreak: $0] } ?? [:])
                .filter { requiredCheckpoints.contains($0.checkpoint) }
            guard !frozen.isEmpty, frozen.count <= CanonicalJourneyCheckpoint.allCases.count,
                  requiredCheckpoints.count == frozen.count,
                  frozen == planning,
                  !requiresActualSuccessors || frozen.allSatisfy({ $0.phraseIndex < maximumPhrases - 1 })
            else { throw ProfessionalQualityCalibrationError.profileMismatch }
        }
        var state = director.initialState()
        var renderState = RenderState()
        var graphState = GeneratedDSPContinuationState()
        var previousGraph: DSPGraphPlan?
        var previousChapter: InterlockChapter?
        var reports: [CanonicalJourneyQualificationReport] = []
        var seen = Set<CanonicalJourneyCheckpoint>()
        var pending: [CanonicalJourneyQualificationReport] = []
        var successors: [ProfessionalQualityModalSuccessorEvidence] = []
        var renderedPhraseCount = 0

        func matchesFrozenScore(_ plan: AutonomousPhrasePlan,
                                expected: CanonicalJourneyPlanCheckpoint) -> Bool {
            plan.phraseIndex == expected.phraseIndex && plan.kind == expected.phraseKind &&
                plan.startBar == expected.startBar &&
                plan.resolvedBars.count == expected.resolvedBarCount &&
                AutonomousCandidateFingerprint.plan(plan) == expected.planFingerprint
        }

        for _ in 0..<maximumPhrases {
            let plan = director.plan(from: state)
            for expected in frozenCheckpoints ?? [] where expected.phraseIndex == plan.phraseIndex {
                guard matchesFrozenScore(plan, expected: expected) else {
                    throw ProfessionalQualityCalibrationError.profileMismatch
                }
            }
            if let fixture = windowFixture,
               let expected = [fixture.planned, fixture.followingRelease].first(where: {
                   $0.phraseIndex == plan.phraseIndex
               }) {
                guard plan.kind == expected.phraseKind,
                      plan.startBar == expected.startBar,
                      plan.resolvedBars.count == expected.resolvedBarCount,
                      AutonomousCandidateFingerprint.plan(plan) ==
                        expected.planFingerprint else {
                    throw ProfessionalQualityCalibrationError.profileMismatch
                }
            }
            progress(
                "prepare-begin seed=\(seed) rate=\(Int(sampleRate)) " +
                "phrase=\(plan.phraseIndex) bar=\(plan.startBar) " +
                "kind=\(plan.kind.rawValue)"
            )
            let neverCancelled: @Sendable () -> Bool = { false }
            let outcome = AutonomousPhrasePreparer.prepareDiagnosingIfNotCancelled(
                plan: plan,
                sessionSeed: state.rootSeed,
                memory: state.memory,
                sampleRate: sampleRate,
                incomingRenderState: renderState,
                incomingGraphState: graphState,
                previousGraph: previousGraph,
                incomingQualityState: state.quality,
                evaluator: ProfessionalEvidenceOnlyEvaluator(),
                cancellationRequested: neverCancelled
            )
            progress(
                "prepare-end seed=\(seed) rate=\(Int(sampleRate)) " +
                "phrase=\(plan.phraseIndex)"
            )
            if let failure = outcome.failure {
                progress(
                    "failed seed=\(seed) rate=\(Int(sampleRate)) " +
                    "phrase=\(plan.phraseIndex) bar=\(plan.startBar) " +
                    "kind=\(plan.kind.rawValue) stage=\(failure.stage.rawValue) " +
                    "code=\(failure.code.rawValue) " +
                    "details=\(failure.details.joined(separator: ","))"
                )
            }
            let prepared = try #require(outcome.preparedPhrase)
            renderedPhraseCount += 1
            for expected in frozenCheckpoints ?? [] where expected.phraseIndex == plan.phraseIndex {
                guard matchesFrozenScore(prepared.plan, expected: expected),
                      prepared.selectedCandidateEvidence.planFingerprint == expected.planFingerprint
                else { throw ProfessionalQualityCalibrationError.profileMismatch }
            }
            // Construct and reconstruct each receipt while the real immutable
            // successor is present. No source-free cache or diagnostic mean
            // can stand in for this accepted preparation transaction.
            for original in pending {
                let receipt = try ProfessionalQualityModalSuccessorEvidence(
                    source: original, successor: prepared)
                let reconstructed = try ProfessionalQualityModalSuccessorEvidence.decodeValidated(
                    receipt.deterministicJSON(), source: original, successor: prepared)
                guard reconstructed == receipt else {
                    throw ProfessionalQualityCalibrationError.profileMismatch
                }
                _ = try ProfessionalQualityObservation(continuousReport: original, successor: receipt)
                successors.append(receipt)
            }
            pending.removeAll(keepingCapacity: true)
            let checkpoints = checkpoints(
                plan: plan,
                previousChapter: previousChapter
            ).filter { checkpoint in
                guard requiredCheckpoints.contains(checkpoint), !seen.contains(checkpoint) else { return false }
                if let frozen = frozenCheckpoints {
                    return frozen.contains { $0.checkpoint == checkpoint && $0.phraseIndex == plan.phraseIndex }
                }
                guard let fixture = windowFixture,
                      let expected = [fixture.planned, fixture.followingRelease].first(where: {
                          $0.checkpoint == checkpoint
                      }) else { return true }
                return plan.phraseIndex == expected.phraseIndex
            }
            let harness = CanonicalJourneyQualificationHarness(
                engineVersion: QualityQualificationContract.engineVersion,
                routeFingerprint: prepared.selectedCandidateEvidence
                    .routeContinuation.routeFingerprint,
                routeGeneration: prepared.selectedCandidateEvidence
                    .routeContinuation.routeGeneration
            )
            for checkpoint in checkpoints {
                progress(
                    "begin seed=\(seed) rate=\(Int(sampleRate)) " +
                    "checkpoint=\(checkpoint.rawValue) " +
                    "phrase=\(plan.phraseIndex)"
                )
                let report = try harness.report(
                    checkpoint: checkpoint,
                    prepared: prepared,
                    fixtureFingerprint: [
                        "seed-\(state.rootSeed)",
                        "phrase-\(plan.phraseIndex)",
                        "bar-\(plan.startBar)",
                        "kind-\(plan.kind.rawValue)",
                    ].joined(separator: "."),
                    continuationFingerprint: [
                        "phrase-\(state.phraseIndex)",
                        "bars-\(state.memory.totalBars)",
                        "quality-r\(state.quality.revision)",
                    ].joined(separator: ".")
                )
                _ = try ProfessionalQualityObservation(report: report)
                reports.append(report)
                if requiresActualSuccessors { pending.append(report) }
                guard pending.count <= CanonicalJourneyCheckpoint.allCases.count else {
                    throw ProfessionalQualityCalibrationError.incompleteCheckpointCoverage
                }
                seen.insert(checkpoint)
                progress(
                    "seed=\(seed) rate=\(Int(sampleRate)) " +
                    "checkpoint=\(checkpoint.rawValue) " +
                    "phrase=\(plan.phraseIndex)"
                )
            }

            previousChapter = plan.resolvedBars.last?.interlockChapter ??
                previousChapter
            state = state.advance(
                using: prepared.plan,
                quality: prepared.qualityContinuationState,
                liveMasterHeadroom:
                    prepared.liveMasterHeadroomContinuationState
            )
            renderState = prepared.endingRenderState
            graphState = prepared.endingGraphState
            previousGraph = prepared.graph
            if seen == requiredCheckpoints && pending.isEmpty { break }
        }
        guard seen == requiredCheckpoints, pending.isEmpty,
              !requiresActualSuccessors || successors.count == reports.count else {
            throw ProfessionalQualityCalibrationError.incompleteCheckpointCoverage
        }
        return JourneyExecution(reports: reports, successors: successors,
            renderedPhraseCount: renderedPhraseCount)
    }

    private func progress(_ message: String) {
        guard let data = "AUTOTECHNO_CALIBRATION_PROGRESS \(message)\n"
            .data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }

    private func writePrimaryArtifacts(
        profile: ProfessionalQualityCalibrationProfile,
        adversarial: ProfessionalQualityAdversarialSuiteReport,
        holdout: ProfessionalQualityHoldoutQualification
    ) throws {
        guard let outputDirectory = ProcessInfo.processInfo.environment[
            "AUTOTECHNO_CALIBRATION_RESOURCE_DIRECTORY"
        ], !outputDirectory.isEmpty else { return }
        let directory = URL(fileURLWithPath: outputDirectory,
                            isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try profile.deterministicJSON().write(
            to: directory.appendingPathComponent(
                "\(ProfessionalQualityPrimaryArtifacts.profileResource).json"
            ),
            options: .atomic
        )
        try adversarial.deterministicJSON().write(
            to: directory.appendingPathComponent(
                "\(ProfessionalQualityPrimaryArtifacts.adversarialResource).json"
            ),
            options: .atomic
        )
        try holdout.deterministicJSON().write(
            to: directory.appendingPathComponent(
                "\(ProfessionalQualityPrimaryArtifacts.holdoutResource).json"
            ),
            options: .atomic
        )
    }

    private func checkpoints(
        plan: AutonomousPhrasePlan,
        previousChapter: InterlockChapter?
    ) -> [CanonicalJourneyCheckpoint] {
        let chapters = plan.resolvedBars.map(\.interlockChapter)
        let changesInsidePhrase = zip(chapters, chapters.dropFirst()).contains {
            $0.0 != $0.1
        }
        let changesAtBoundary = previousChapter.map { previous in
            chapters.first.map { $0 != previous } ?? false
        } ?? false
        return CanonicalJourneyCheckpoint.applicable(
            phraseIndex: plan.phraseIndex,
            phraseKind: plan.kind,
            chapterChanged: changesInsidePhrase || changesAtBoundary
        )
    }
}
