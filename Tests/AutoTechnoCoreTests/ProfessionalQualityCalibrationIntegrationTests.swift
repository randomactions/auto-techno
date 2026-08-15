import AutoTechnoCore
import AutoTechnoDSP
import Foundation
import Testing

@Suite("Representative professional quality calibration", .serialized)
struct ProfessionalQualityCalibrationIntegrationTests {
    /// This deliberately expensive, explicit development harness renders the
    /// complete canonical journey at 44.1 and 48 kHz. Normal CI validates the
    /// frozen historical and current-engine paired artifacts; regeneration is
    /// opt-in so every source-bank change is intentional and reviewable.
    @Test("Generate complete representative-rate profile and adversarial identity")
    func generateRepresentativeProfile() throws {
        guard ProcessInfo.processInfo.environment[
            "AUTOTECHNO_RUN_PROFILE_CALIBRATION"
        ] == "1" else { return }

        var reports: [CanonicalJourneyQualificationReport] = []
        for sampleRate in ProfessionalQualityCalibrationProfile
            .requiredSampleRates {
            reports.append(contentsOf: try renderJourney(sampleRate: sampleRate))
        }
        let bank = try ProfessionalEvidenceReportBank(reports: reports)
        let frozen = try ProfessionalQualityFrozenArtifacts.load()
        let frozenQualification = try frozen.policy.evaluate(bank: bank)
        let profile = try ProfessionalQualityCalibrationProfile(bank: bank)
        let observations = try bank.reports.map(ProfessionalQualityObservation.init)
        let adversarial = try ProfessionalQualityAdversarialSuiteReport(
            profile: profile,
            sourceObservations: observations
        )
        let policy = try ProfessionalQualityDevelopmentPolicy(
            profile: profile,
            adversarialSuite: adversarial
        )
        let qualification = try policy.evaluate(bank: bank)
        let pairedEvaluator = try ProfessionalQualityPairedCandidateEvaluator(
            profile: profile,
            adversarialSuite: adversarial
        )

        #expect(bank.sourceReportCount ==
                CanonicalJourneyCheckpoint.allCases.count *
                    ProfessionalQualityCalibrationProfile.requiredSampleRates.count)
        #expect(frozenQualification.calibrationSourceEngineVersion ==
                "autotechno-canonical-engine.v10")
        #expect(frozenQualification.evaluatedEngineVersion ==
                QualityQualificationContract.engineVersion)
        #expect(!frozenQualification.qualified)
        #expect(frozenQualification.acceptedObservationCount == 8)
        #expect(profile.isComplete)
        #expect(adversarial.passed)
        #expect(qualification.qualified)
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
        let frozenQualificationJSON = try #require(String(
            data: frozenQualification.deterministicJSON(), encoding: .utf8
        ))
        try writePairedArtifacts(
            profile: profile,
            adversarial: adversarial
        )
        print("AUTOTECHNO_CALIBRATION_PROFILE_JSON_BEGIN")
        print(profileJSON)
        print("AUTOTECHNO_CALIBRATION_PROFILE_JSON_END")
        print("AUTOTECHNO_ADVERSARIAL_SUITE_JSON_BEGIN")
        print(adversarialJSON)
        print("AUTOTECHNO_ADVERSARIAL_SUITE_JSON_END")
        print("AUTOTECHNO_DEVELOPMENT_QUALIFICATION_JSON_BEGIN")
        print(qualificationJSON)
        print("AUTOTECHNO_DEVELOPMENT_QUALIFICATION_JSON_END")
        print("AUTOTECHNO_FROZEN_COMPATIBILITY_JSON_BEGIN")
        print(frozenQualificationJSON)
        print("AUTOTECHNO_FROZEN_COMPATIBILITY_JSON_END")
        print("AUTOTECHNO_FROZEN_COMPATIBILITY_ACCEPTED_COUNT=" +
              "\(frozenQualification.acceptedObservationCount)")
        print("AUTOTECHNO_CALIBRATION_PROFILE_FINGERPRINT=\(profile.fingerprint)")
        print("AUTOTECHNO_ADVERSARIAL_SUITE_FINGERPRINT=\(adversarial.fingerprint)")
    }

    private func renderJourney(
        sampleRate: Double,
        maximumPhrases: Int = 128
    ) throws -> [CanonicalJourneyQualificationReport] {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
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
                    "begin rate=\(Int(sampleRate)) " +
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
                    "rate=\(Int(sampleRate)) checkpoint=\(checkpoint.rawValue) " +
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
        adversarial: ProfessionalQualityAdversarialSuiteReport
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
