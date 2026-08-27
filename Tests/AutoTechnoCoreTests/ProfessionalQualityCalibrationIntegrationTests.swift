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
    private let holdoutSeeds: [UInt64] = [112_358, 141_421, 173_205, 223_606]

    /// This deliberately expensive, explicit calibration harness renders the
    /// complete canonical journey at 44.1 and 48 kHz. Normal CI validates the
    /// current primary artifacts; regeneration is opt-in so every source-bank
    /// change is intentional and reviewable.
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
                )
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
        #expect(profile.schemaVersion == 14)
        #expect(profile.observationVersion ==
                ProfessionalQualityObservation.observationVersion)
        #expect(profile.sourceTrajectoryCount == calibrationSeeds.count)
        #expect(adversarial.passed)
        #expect(adversarial.schemaVersion == 15)
        #expect(adversarial.cases.count ==
                ProfessionalQualityAdversarialScenario.allCases.count)
        #expect(holdout.qualified)
        #expect(holdout.schemaVersion == 13)
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

    @Test("Render one explicitly selected calibration diagnostic journey")
    func renderSelectedDiagnosticJourney() throws {
        guard let rawSeed = ProcessInfo.processInfo.environment[
            "AUTOTECHNO_CALIBRATION_DIAGNOSTIC_SEED"
        ], let seed = UInt64(rawSeed) else { return }

        let trajectory = try renderTrajectory(seed: seed)
        progress(
            "diagnostic-seed=\(seed) source=" +
            trajectory.sourceBankFingerprint
        )
        for observation in trajectory.observations {
            guard let peak = observation[.rmsTrajectoryDeltaPeakDB],
                  let mean = observation[.rmsTrajectoryDeltaMeanDB],
                  let activeKickFoundationBarRatio = observation[
                    .activeKickFoundationBarRatio
                  ],
                  let kickOverFoundationActiveDBMean = observation[
                    .kickOverFoundationActiveDBMean
                  ] else {
                continue
            }
            progress(
                "diagnostic-seed=\(seed) checkpoint=" +
                "\(observation.checkpoint.rawValue) rate=" +
                "\(Int(observation.sampleRate)) rms-trajectory-mean-db=" +
                "\(mean) rms-trajectory-peak-db=\(peak) " +
                "active-kick-foundation-bar-ratio=" +
                "\(activeKickFoundationBarRatio) " +
                "kick-over-foundation-active-db-mean=" +
                "\(kickOverFoundationActiveDBMean)"
            )
        }
    }

    private func renderTrajectory(seed: UInt64) throws
        -> ProfessionalQualityCalibrationTrajectory {
        try resolvedTrajectory(
            seed: seed,
            cacheDirectory: cacheDirectory()
        ) {
            var reports: [CanonicalJourneyQualificationReport] = []
            for sampleRate in ProfessionalQualityCalibrationProfile
                .requiredSampleRates {
                reports.append(contentsOf: try renderJourney(
                    seed: seed,
                    sampleRate: sampleRate
                ))
            }
            return reports
        }
    }

    func resolvedTrajectory(
        seed: UInt64,
        cacheDirectory: URL?,
        generateReports: () throws -> [CanonicalJourneyQualificationReport]
    ) throws -> ProfessionalQualityCalibrationTrajectory {
        if let cacheDirectory,
           let cached = try cachedTrajectory(
               seed: seed,
               directory: cacheDirectory
           ) {
            progress("cache-hit seed=\(seed)")
            return cached
        }
        let reports = try generateReports()
        let trajectory = try ProfessionalQualityCalibrationTrajectory(
            bank: ProfessionalEvidenceReportBank(reports: reports)
        )
        if let cacheDirectory {
            try cache(
                reports: reports,
                seed: seed,
                directory: cacheDirectory
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

    func cachedTrajectory(
        seed: UInt64,
        directory: URL
    ) throws -> ProfessionalQualityCalibrationTrajectory? {
        let url = cacheURL(seed: seed, directory: directory)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let fileSize = values.fileSize,
              fileSize > 0,
              fileSize <= CachedJourneyReportBank.maximumEncodedBytes,
              let data = try? Data(contentsOf: url) else { return nil }
        return try decodedCacheTrajectory(data, requestedSeed: seed)
    }

    func decodedCacheTrajectory(
        _ data: Data,
        requestedSeed: UInt64
    ) throws -> ProfessionalQualityCalibrationTrajectory? {
        guard !data.isEmpty,
              data.count <= CachedJourneyReportBank.maximumEncodedBytes,
              let decoded = try? JSONDecoder().decode(
                  CachedJourneyReportBank.self,
                  from: data
              ),
              decoded.schemaVersion == CachedJourneyReportBank.schemaVersion,
              decoded.identity == CachedJourneyIdentity.current(
                  rootSeed: requestedSeed
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
        directory: URL
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
            reportJSON: try reports.map { try $0.deterministicJSON() }
        )
        let data = try encoder.encode(cache)
        guard data.count <= CachedJourneyReportBank.maximumEncodedBytes,
              try decodedCacheTrajectory(data, requestedSeed: seed) != nil else {
            throw ProfessionalQualityCalibrationError.profileMismatch
        }
        try data.write(to: url, options: .atomic)
    }

    /// Cache only complete candidate-derived reports. Observation JSON is an
    /// intentionally non-decodable reduction and cannot be trusted as a
    /// substitute for report validation during deterministic regeneration.
    struct CachedJourneyReportBank: Codable {
        static let schemaVersion = 2
        static let expectedReportCount =
            CanonicalJourneyCheckpoint.allCases.count *
                ProfessionalQualityCalibrationProfile.requiredSampleRates.count
        static let maximumEncodedBytes =
            ProfessionalEvidenceReportBank.maximumEncodedBytes

        let schemaVersion: Int
        let identity: CachedJourneyIdentity
        let reportJSON: [Data]

        init(identity: CachedJourneyIdentity, reportJSON: [Data]) {
            schemaVersion = Self.schemaVersion
            self.identity = identity
            self.reportJSON = reportJSON
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
            let plan = director.plan(from: state)
            let neverCancelled: @Sendable () -> Bool = { false }
            let preparedResult = AutonomousPhrasePreparer.prepareIfNotCancelled(
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
            let prepared = try #require(preparedResult)
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
