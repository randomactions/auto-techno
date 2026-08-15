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
    ]
    private let holdoutSeeds: [UInt64] = [161_803, 271_828, 314_159, 424_242]

    /// This deliberately expensive, explicit development harness renders the
    /// complete canonical journey at 44.1 and 48 kHz. Normal CI validates the
    /// frozen historical and current-engine paired artifacts; regeneration is
    /// opt-in so every source-bank change is intentional and reviewable.
    @Test("Generate complete representative-rate profile and adversarial identity")
    func generateRepresentativeProfile() throws {
        guard ProcessInfo.processInfo.environment[
            "AUTOTECHNO_RUN_PROFILE_CALIBRATION"
        ] == "1" else { return }

        let calibrationTrajectories = try calibrationSeeds.map(
            renderTrajectory(seed:)
        )
        let holdoutTrajectories = try holdoutSeeds.map(
            renderTrajectory(seed:)
        )
        let calibrationCorpus = try ProfessionalQualityCalibrationCorpus(
            trajectories: calibrationTrajectories
        )
        let holdoutCorpus = try ProfessionalQualityCalibrationCorpus(
            trajectories: holdoutTrajectories
        )
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
                )
            progress(
                "calibration-source=\(trajectory.sourceBankFingerprint) " +
                "local=\(localFailures.joined(separator: ";")) " +
                "relationships=\(relationshipFailures.count)"
            )
        }
        let adversarial = try ProfessionalQualityAdversarialSuiteReport(
            profile: profile,
            sourceCorpus: calibrationCorpus
        )
        progress("adversarial-ready fingerprint=\(adversarial.fingerprint)")
        let policy = try ProfessionalQualityDevelopmentPolicy(
            profile: profile,
            adversarialSuite: adversarial
        )
        let qualification = try policy.evaluate(
            observations: try #require(
                calibrationTrajectories.first
            ).observations
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
                    "\(failure.lowerBound)...\(failure.upperBound)"
                )
            }
        }
        let pairedEvaluator = try ProfessionalQualityPairedCandidateEvaluator(
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
        #expect(profile.sourceTrajectoryCount == calibrationSeeds.count)
        #expect(adversarial.passed)
        #expect(qualification.qualified)
        #expect(holdout.qualified)
        #expect(holdout.holdoutTrajectoryCount == holdoutSeeds.count)
        #expect(holdout.overlappingSourceBankCount == 0)
        #expect(pairedEvaluator.requiresPairedCandidates)
        #expect(pairedEvaluator.policyVersion.contains(profile.fingerprint))
        #expect(pairedEvaluator.policyVersion.contains(adversarial.fingerprint))
        #expect(!profile.fingerprint.isEmpty)
        #expect(!adversarial.fingerprint.isEmpty)

        let profileJSON = try #require(String(
            data: profile.deterministicJSON(), encoding: .utf8
        ))
        let adversarialJSON = try #require(String(
            data: adversarial.deterministicJSON(), encoding: .utf8
        ))
        let qualificationJSON = try #require(String(
            data: qualification.deterministicJSON(), encoding: .utf8
        ))
        let holdoutJSON = try #require(String(
            data: holdout.deterministicJSON(), encoding: .utf8
        ))
        try writePairedArtifacts(
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
        print("AUTOTECHNO_DEVELOPMENT_QUALIFICATION_JSON_BEGIN")
        print(qualificationJSON)
        print("AUTOTECHNO_DEVELOPMENT_QUALIFICATION_JSON_END")
        print("AUTOTECHNO_CALIBRATION_PROFILE_FINGERPRINT=\(profile.fingerprint)")
        print("AUTOTECHNO_ADVERSARIAL_SUITE_FINGERPRINT=\(adversarial.fingerprint)")
        print("AUTOTECHNO_HOLDOUT_QUALIFICATION_FINGERPRINT=\(holdout.fingerprint)")
    }

    private func renderTrajectory(seed: UInt64) throws
        -> ProfessionalQualityCalibrationTrajectory {
        if let cached = try cachedTrajectory(seed: seed) {
            progress("cache-hit seed=\(seed)")
            return cached
        }
        var reports: [CanonicalJourneyQualificationReport] = []
        for sampleRate in ProfessionalQualityCalibrationProfile
            .requiredSampleRates {
            reports.append(contentsOf: try renderJourney(
                seed: seed,
                sampleRate: sampleRate
            ))
        }
        let trajectory = try ProfessionalQualityCalibrationTrajectory(
            bank: ProfessionalEvidenceReportBank(reports: reports)
        )
        try cache(trajectory: trajectory, seed: seed)
        return trajectory
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
                    ).count
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
                .count
            progress(
                "leave-one-out=\(seeds[holdoutIndex]) " +
                "accepted=\(accepted)/14 relationships=\(relationships)"
            )
        }
    }

    private func cachedTrajectory(
        seed: UInt64
    ) throws -> ProfessionalQualityCalibrationTrajectory? {
        guard let url = cacheURL(seed: seed),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(
            ProfessionalQualityCalibrationTrajectory.self,
            from: data
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard decoded.isComplete,
              decoded.engineVersion == QualityQualificationContract.engineVersion,
              try encoder.encode(decoded) == data else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        return decoded
    }

    private func cache(
        trajectory: ProfessionalQualityCalibrationTrajectory,
        seed: UInt64
    ) throws {
        guard let url = cacheURL(seed: seed) else { return }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(trajectory).write(to: url, options: .atomic)
    }

    private func cacheURL(seed: UInt64) -> URL? {
        guard let directory = ProcessInfo.processInfo.environment[
            "AUTOTECHNO_CALIBRATION_CACHE_DIRECTORY"
        ], !directory.isEmpty else { return nil }
        return URL(fileURLWithPath: directory, isDirectory: true)
            .appendingPathComponent("journey-\(seed).json")
    }

    private func renderJourney(
        seed: UInt64,
        sampleRate: Double,
        maximumPhrases: Int = 128
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
            let candidates = director.candidates(from: state)
            let neverCancelled: @Sendable () -> Bool = { false }
            let preparedResult = AutonomousPhrasePreparer.prepareIfNotCancelled(
                candidates: candidates,
                sessionSeed: state.rootSeed,
                memory: state.memory,
                sampleRate: sampleRate,
                incomingRenderState: renderState,
                incomingGraphState: graphState,
                previousGraph: previousGraph,
                incomingQualityState: state.quality,
                cancellationRequested: neverCancelled
            )
            let prepared = try #require(preparedResult)
            let plan = prepared.plan
            let checkpoints = checkpoints(
                plan: plan,
                previousChapter: previousChapter
            ).filter { !seen.contains($0) }
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
            state.advance(
                using: prepared.plan,
                quality: prepared.qualityContinuationState
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

    private func writePairedArtifacts(
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
                "\(ProfessionalQualityPairedArtifacts.profileResource).json"
            ),
            options: .atomic
        )
        try adversarial.deterministicJSON().write(
            to: directory.appendingPathComponent(
                "\(ProfessionalQualityPairedArtifacts.adversarialResource).json"
            ),
            options: .atomic
        )
        try holdout.deterministicJSON().write(
            to: directory.appendingPathComponent(
                "\(ProfessionalQualityPairedArtifacts.holdoutResource).json"
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
