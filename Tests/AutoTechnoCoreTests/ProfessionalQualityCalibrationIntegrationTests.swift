import AutoTechnoCore
import AutoTechnoDSP
import Foundation
import Testing

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

    private func git(_ arguments: [String]) throws -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", repositoryRoot.path] + arguments
        process.standardOutput = output
        try process.run()
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
            guard localReports.count ==
                    CanonicalJourneyCheckpoint.allCases.count *
                    ProfessionalQualityCalibrationProfile.requiredSampleRates.count,
                  maskingReports.count == localReports.count,
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

    private func renderJourney(
        seed: UInt64,
        sampleRate: Double,
        maximumPhrases: Int = 128,
        windowFixture: CanonicalCalibrationWindowFixture? = nil
    ) throws -> [CanonicalJourneyQualificationReport] {
        let director = AutonomousSessionDirector(rootSeed: seed)
        var state = director.initialState()
        var renderState = RenderState()
        var graphState = GeneratedDSPContinuationState()
        var previousGraph: DSPGraphPlan?
        var previousChapter: InterlockChapter?
        var reports: [CanonicalJourneyQualificationReport] = []
        var seen = Set<CanonicalJourneyCheckpoint>()

        for _ in 0..<maximumPhrases {
            let plan = director.plan(from: state)
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
            let checkpoints = checkpoints(
                plan: plan,
                previousChapter: previousChapter
            ).filter { checkpoint in
                guard !seen.contains(checkpoint) else { return false }
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
            if seen.count == CanonicalJourneyCheckpoint.allCases.count { break }
        }
        #expect(seen == Set(CanonicalJourneyCheckpoint.allCases))
        return reports
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
