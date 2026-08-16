import AutoTechnoCore
import AutoTechnoDSP
import Foundation
import Testing

@Suite("Live output window evidence")
struct LiveOutputWindowEvidenceTests {
    @Test("Capture lifetime count is independent of bounded queue occupancy")
    func acceptsExactWindowsAcrossPacketSizes() throws {
        for sampleRate in [44_100.0, 48_000.0] {
            let signal = testSignal(sampleRate: sampleRate)
            for packetFrameCount in [64, 128, 256, 512, 1_024] {
                let capture = captureProvenance(
                    frameCount: signal.count,
                    packetFrameCount: packetFrameCount
                )
                let evidence = try #require(analyze(
                    left: signal,
                    right: signal,
                    sampleRate: sampleRate,
                    capture: capture
                ))

                #expect(evidence.complete)
                #expect(evidence.captureProvenance.packetCount ==
                        (signal.count + packetFrameCount - 1) /
                        packetFrameCount)
                #expect(packetFrameCount == 1_024 ||
                        evidence.captureProvenance.packetCount >
                            evidence.captureProvenance.queueCapacity)
                #expect(evidence.captureProvenance.coveredFrameCount ==
                        signal.count)
            }
        }
    }

    @Test("Plan semantics and canonical fingerprint have one constructor")
    func planSemanticsAndFingerprintCannotBeMixed() throws {
        let plans = realDirectorPlansWithDifferentKinds()
        let first = LiveOutputPlanSourceIdentity(plan: plans.first)
        let second = LiveOutputPlanSourceIdentity(plan: plans.second)

        #expect(first.planFingerprint ==
                AutonomousTypedFingerprint.plan(plans.first))
        #expect(second.planFingerprint ==
                AutonomousTypedFingerprint.plan(plans.second))
        #expect(first.phraseIndex == plans.first.phraseIndex)
        #expect(second.phraseIndex == plans.second.phraseIndex)
        #expect(first.phraseKind == plans.first.kind)
        #expect(second.phraseKind == plans.second.kind)
        #expect(first.planFingerprint != second.planFingerprint)
        #expect(first.phraseKind != second.phraseKind)
    }

    @Test("Exact three-second windows reuse the complete BS.1770 audit")
    func threeSecondWindowMatchesExistingBS1770() throws {
        for sampleRate in [44_100.0, 48_000.0] {
            let signal = testSignal(sampleRate: sampleRate)
            let evidence = try #require(analyze(
                left: signal,
                right: signal,
                sampleRate: sampleRate
            ))
            let existing = BS1770LoudnessMeasurement(
                left: signal,
                right: signal,
                sampleRate: sampleRate
            )

            #expect(evidence.frameCount == Int(sampleRate * 3))
            #expect(evidence.integratedLoudnessLUFS == existing.integratedLoudness)
            #expect(evidence.maximumMomentaryLoudnessLUFS ==
                    existing.maximumMomentaryLoudness)
            #expect(evidence.maximumShortTermLoudnessLUFS ==
                    existing.maximumShortTermLoudness)
            #expect(evidence.loudnessRangeLU == existing.loudnessRange)
            #expect(evidence.momentaryBlockCount == existing.momentaryBlockCount)
            #expect(evidence.absoluteGatedBlockCount ==
                    existing.absoluteGatedBlockCount)
            #expect(evidence.relativeGatedBlockCount ==
                    existing.relativeGatedBlockCount)
            #expect(evidence.shortTermBlockCount == existing.shortTermBlockCount)
            #expect(evidence.loudnessMaximumBufferedFrameCount ==
                    existing.maximumBufferedFrameCount)
            #expect(evidence.loudnessPeakWorkingByteCount ==
                    existing.peakWorkingByteCount)
            #expect(evidence.shortTermBlockCount == 1)
            #expect(evidence.isActiveProgram)
            #expect(evidence.captureBounded)
            #expect(evidence.captureProvenance.packetCount ==
                    (signal.count + 1_023) / 1_024)
            #expect(evidence.captureProvenance.firstPacketSequence == 500)
            #expect(evidence.captureProvenance.lastPacketSequence ==
                    500 + UInt64(evidence.captureProvenance.packetCount - 1))
            #expect(evidence.captureProvenance.droppedPacketDelta == 0)
            #expect(evidence.captureProvenance.rejectedPacketDelta == 0)
            #expect(evidence.captureProvenance.queueCapacity == 256)
            #expect(evidence.captureProvenance.maximumPacketFrameCount == 1_024)
            #expect(evidence.captureProvenance.workingMemoryByteCount ==
                    signal.count * 2 * MemoryLayout<Float>.stride)
            #expect(evidence.captureProvenance.coveredFrameCount == signal.count)
            #expect(evidence.captureProvenance.sampleDiscontinuityCount == 0)
            #expect(evidence.captureProvenance.gapFrameCount == 0)
            #expect(evidence.captureProvenance.overlapFrameCount == 0)
            #expect(evidence.complete)
            #expect(evidence.isStructurallyValid)
        }
    }

    @Test("Live true peak is the existing chunk-independent Annex 2 result")
    func annexTwoTruePeakMatchesChunkedAnalyzer() throws {
        let sampleRate = 48_000.0
        let left = testSignal(sampleRate: sampleRate)
        let right = left.enumerated().map { index, sample in
            index.isMultiple(of: 3) ? sample * -0.75 : sample * 0.75
        }
        let cut = 61_337
        let existing = try #require(BS1770AudioEvidence.stereoTruePeak(
            leftChunks: [Array(left[..<cut]), Array(left[cut...])],
            rightChunks: [Array(right[..<cut]), Array(right[cut...])]
        ))
        let evidence = try #require(analyze(
            left: left,
            right: right,
            sampleRate: sampleRate
        ))

        #expect(evidence.leftTruePeakLinear == existing.left)
        #expect(evidence.rightTruePeakLinear == existing.right)
        #expect(evidence.maximumTruePeakLinear == max(existing.left, existing.right))
        #expect(evidence.leftTruePeakDBTP ==
                BS1770AudioEvidence.decibelsTruePeak(amplitude: existing.left))
        #expect(evidence.rightTruePeakDBTP ==
                BS1770AudioEvidence.decibelsTruePeak(amplitude: existing.right))
        #expect(evidence.truePeakDBTP ==
                BS1770AudioEvidence.decibelsTruePeak(
                    amplitude: max(existing.left, existing.right)
                ))
    }

    @Test("Silence is complete evidence but never active programme")
    func silenceCannotBecomeRecoveryEvidence() throws {
        let sampleRate = 44_100.0
        let silence = [Float](repeating: 0, count: Int(sampleRate * 3))
        let artifacts = try ProfessionalQualityPrimaryArtifacts.load()
        let evidence = try #require(analyze(
            left: silence,
            right: silence,
            sampleRate: sampleRate,
            artifacts: artifacts
        ))
        let target = try #require(LiveOutputWindowAnalyzer.target(
            evidence: evidence,
            artifacts: artifacts
        ))

        #expect(evidence.complete)
        #expect(evidence.absoluteGatedBlockCount == 0)
        #expect(evidence.relativeGatedBlockCount == 0)
        #expect(evidence.maximumShortTermLoudnessLUFS == -120)
        #expect(!evidence.isActiveProgram)
        #expect(target.isStructurallyValid(sourceEvidence: evidence))
    }

    @Test("Observation fingerprint binds every source and analyzer identity")
    func observationBindsRouteRangeAndPCM() throws {
        let sampleRate = 44_100.0
        let signal = testSignal(sampleRate: sampleRate)
        let baseline = try #require(analyze(
            left: signal,
            right: signal,
            sampleRate: sampleRate
        ))
        let replay = try #require(analyze(
            left: signal,
            right: signal,
            sampleRate: sampleRate
        ))
        var changedPCM = signal
        changedPCM[777] = -changedPCM[777]
        let changed = try #require(analyze(
            left: changedPCM,
            right: signal,
            sampleRate: sampleRate
        ))
        let changedRoute = try #require(analyze(
            left: signal,
            right: signal,
            sampleRate: sampleRate,
            routeGeneration: baseline.routeGeneration + 1
        ))
        let changedController = try #require(analyze(
            left: signal,
            right: signal,
            sampleRate: sampleRate,
            controllerRevision: baseline.controllerRevision + 1
        ))
        let changedRange = try #require(analyze(
            left: signal,
            right: signal,
            sampleRate: sampleRate,
            playerSampleRange: 90_000..<Int64(90_000 + signal.count)
        ))

        #expect(baseline.fingerprint == replay.fingerprint)
        #expect(baseline.pcmFingerprint == replay.pcmFingerprint)
        #expect(changed.pcmFingerprint != baseline.pcmFingerprint)
        #expect(changed.fingerprint != baseline.fingerprint)
        #expect(changedRoute.fingerprint != baseline.fingerprint)
        #expect(changedController.fingerprint != baseline.fingerprint)
        #expect(changedRange.fingerprint != baseline.fingerprint)
        #expect(baseline.analyzerVersion == LiveOutputWindowAnalyzer.analyzerVersion)
        #expect(baseline.engineVersion == QualityQualificationContract.engineVersion)
        #expect(baseline.evidenceVersion ==
                ProfessionalEvidenceReportBank.evidenceVersion)
        #expect(baseline.controllerPolicyVersion ==
                LiveOutputWindowAnalyzer.controllerPolicyVersion)
        #expect(!baseline.qualityPolicyVersion.isEmpty)
        #expect(baseline.evaluatorVersion ==
                ProfessionalQualityPrimaryEvaluator.evaluatorVersionIdentifier)
    }

    @Test("Wrong geometry, invalid capture, and non-finite PCM are unavailable")
    func nonFiniteOrWrongLengthIsUnavailable() throws {
        let signal = testSignal(sampleRate: 48_000)
        var nonFinite = signal
        nonFinite[12_345] = .nan

        #expect(analyze(
            left: Array(signal.dropLast()),
            right: Array(signal.dropLast()),
            sampleRate: 48_000
        ) == nil)
        #expect(analyze(
            left: signal,
            right: Array(signal.dropLast()),
            sampleRate: 48_000
        ) == nil)
        #expect(analyze(
            left: signal,
            right: signal,
            sampleRate: 96_000
        ) == nil)
        #expect(analyze(
            left: nonFinite,
            right: signal,
            sampleRate: 48_000
        ) == nil)

        let valid = captureProvenance(frameCount: signal.count)
        #expect(analyze(
            left: signal,
            right: signal,
            sampleRate: 48_000,
            capture: capture(
                from: valid,
                droppedPacketDelta: 1
            )
        ) == nil)
        #expect(analyze(
            left: signal,
            right: signal,
            sampleRate: 48_000,
            capture: capture(
                from: valid,
                rejectedPacketDelta: 1
            )
        ) == nil)
        #expect(analyze(
            left: signal,
            right: signal,
            sampleRate: 48_000,
            capture: capture(
                from: valid,
                packetCount: 0
            )
        ) == nil)
        #expect(analyze(
            left: signal,
            right: signal,
            sampleRate: 48_000,
            capture: capture(
                from: valid,
                lastPacketSequence: valid.lastPacketSequence + 1
            )
        ) == nil)
        #expect(analyze(
            left: signal,
            right: signal,
            sampleRate: 48_000,
            capture: capture(
                from: valid,
                queueCapacity: 255
            )
        ) == nil)
        #expect(analyze(
            left: signal,
            right: signal,
            sampleRate: 48_000,
            capture: capture(
                from: valid,
                maximumPacketFrameCount: 1_023
            )
        ) == nil)
        #expect(analyze(
            left: signal,
            right: signal,
            sampleRate: 48_000,
            capture: capture(
                from: valid,
                workingMemoryByteCount: valid.workingMemoryByteCount + 1
            )
        ) == nil)
        #expect(analyze(
            left: signal,
            right: signal,
            sampleRate: 48_000,
            capture: capture(
                from: valid,
                coveredFrameCount: valid.coveredFrameCount - 1
            )
        ) == nil)
        #expect(analyze(
            left: signal,
            right: signal,
            sampleRate: 48_000,
            capture: capture(
                from: valid,
                sampleDiscontinuityCount: 1
            )
        ) == nil)
        #expect(analyze(
            left: signal,
            right: signal,
            sampleRate: 48_000,
            capture: capture(
                from: valid,
                gapFrameCount: 1
            )
        ) == nil)
        #expect(analyze(
            left: signal,
            right: signal,
            sampleRate: 48_000,
            capture: capture(
                from: valid,
                overlapFrameCount: 1
            )
        ) == nil)
    }

    @Test("PCM fingerprint cancellation is bounded and deterministic")
    func pcmFingerprintCancellationIsDeterministic() throws {
        let signal = testSignal(sampleRate: 44_100)
        let completed = CancellationCounter(cancelAt: .max)
        let fingerprint = try #require(
            AutonomousTypedFingerprint.liveOutputPCM(
                left: signal,
                right: signal,
                cancellationRequested: completed.isCancelled
            )
        )
        let cancelAt = max(2, completed.callCount / 2)
        let first = CancellationCounter(cancelAt: cancelAt)
        let second = CancellationCounter(cancelAt: cancelAt)

        #expect(!fingerprint.isEmpty)
        #expect(AutonomousTypedFingerprint.liveOutputPCM(
            left: signal,
            right: signal,
            cancellationRequested: first.isCancelled
        ) == nil)
        #expect(AutonomousTypedFingerprint.liveOutputPCM(
            left: signal,
            right: signal,
            cancellationRequested: second.isCancelled
        ) == nil)
        #expect(first.callCount == cancelAt)
        #expect(second.callCount == cancelAt)
        #expect(analyze(
            left: signal,
            right: signal,
            sampleRate: 44_100,
            cancellationRequested: { true }
        ) == nil)
    }

    @Test("Each metric keeps the bounds belonging to its strictest checkpoint")
    func strictestCheckpointUpperBoundWins() throws {
        let artifacts = try ProfessionalQualityPrimaryArtifacts.load()
        let signal = testSignal(sampleRate: 48_000)
        let plan = realDirectorPlan {
            LiveOutputPlanSourceIdentity(plan: $0)
                .applicableCheckpoints.count >= 2
        }
        let evidence = try #require(analyze(
            left: signal,
            right: signal,
            sampleRate: 48_000,
            plan: plan,
            artifacts: artifacts
        ))
        let target = try #require(LiveOutputWindowAnalyzer.target(
            evidence: evidence,
            artifacts: artifacts
        ))
        let loudness = try strictestBounds(
            metric: .maximumShortTermLoudnessLUFS,
            checkpoints: evidence.applicableCheckpoints,
            profile: artifacts.profile
        )
        let truePeak = try strictestBounds(
            metric: .truePeakDBTP,
            checkpoints: evidence.applicableCheckpoints,
            profile: artifacts.profile
        )

        #expect(target.selectedLoudnessCheckpoint == loudness.checkpoint)
        #expect(target.loudnessLowerLUFS == loudness.bounds.lower)
        #expect(target.loudnessUpperLUFS == loudness.bounds.upper)
        #expect(target.loudnessMidpointLUFS ==
                (loudness.bounds.lower + loudness.bounds.upper) / 2)
        #expect(target.selectedTruePeakCheckpoint == truePeak.checkpoint)
        #expect(target.truePeakLowerDBTP == truePeak.bounds.lower)
        #expect(target.truePeakUpperDBTP == truePeak.bounds.upper)
        #expect(target.truePeakMidpointDBTP ==
                (truePeak.bounds.lower + truePeak.bounds.upper) / 2)
        #expect(target.sourceObservationFingerprint == evidence.fingerprint)
        #expect(target.profileFingerprint == artifacts.profile.fingerprint)
        #expect(target.isStructurallyValid(sourceEvidence: evidence))
    }

    @Test("An ordinary lock uses the calibrated long-continuation envelope")
    func ordinaryLockUsesLongContinuation() throws {
        let artifacts = try ProfessionalQualityPrimaryArtifacts.load()
        let signal = testSignal(sampleRate: 44_100)
        let plan = realDirectorPlan { plan in
            let identity = LiveOutputPlanSourceIdentity(plan: plan)
            return plan.kind == .lock && plan.phraseIndex > 0 &&
                plan.phraseIndex < 16 && !identity.chapterChanged
        }
        let evidence = try #require(analyze(
            left: signal,
            right: signal,
            sampleRate: 44_100,
            plan: plan,
            artifacts: artifacts
        ))
        let target = try #require(LiveOutputWindowAnalyzer.target(
            evidence: evidence,
            artifacts: artifacts
        ))
        let long = try #require(artifacts.profile[.longContinuation])
        let loudness = try #require(long[.maximumShortTermLoudnessLUFS])
        let truePeak = try #require(long[.truePeakDBTP])

        #expect(evidence.applicableCheckpoints == [.longContinuation])
        #expect(target.applicableCheckpoints == [.longContinuation])
        #expect(target.selectedLoudnessCheckpoint == .longContinuation)
        #expect(target.selectedTruePeakCheckpoint == .longContinuation)
        #expect(target.loudnessLowerLUFS == loudness.lower)
        #expect(target.loudnessUpperLUFS == loudness.upper)
        #expect(target.truePeakLowerDBTP == truePeak.lower)
        #expect(target.truePeakUpperDBTP == truePeak.upper)

        let profile = artifacts.profile
        let profileData = try profile.deterministicJSON()
        let profileJSON = String(decoding: profileData, as: UTF8.self)
        let foreignBankJSON = profileJSON.replacingOccurrences(
            of: profile.sourceBankFingerprint,
            with: "foreign-calibration-bank"
        )
        let foreignBank = try ProfessionalQualityCalibrationProfile
            .decodeDeterministicJSON(Data(foreignBankJSON.utf8))
        #expect(foreignBank.fingerprint !=
                ProfessionalQualityPrimaryArtifacts.expectedProfileFingerprint)
    }

    @Test("A target rejects every mismatched source-observation pairing")
    func targetRejectsForgedObservationPairing() throws {
        let artifacts = try ProfessionalQualityPrimaryArtifacts.load()
        let signal44 = testSignal(sampleRate: 44_100)
        let baselinePlan = defaultDirectorPlan()
        let changedPhrasePlan = realDirectorPlan { $0.phraseIndex == 1 }
        let changedPlanSamePhrase = defaultDirectorPlan(rootSeed: 48_292)
        let changedCheckpointPlan = realDirectorPlansWithDifferentKinds().second
        let baseline = try #require(analyze(
            left: signal44,
            right: signal44,
            sampleRate: 44_100,
            plan: baselinePlan,
            artifacts: artifacts
        ))
        let target = try #require(LiveOutputWindowAnalyzer.target(
            evidence: baseline,
            artifacts: artifacts
        ))
        let changedPhrase = try #require(analyze(
            left: signal44,
            right: signal44,
            sampleRate: 44_100,
            plan: changedPhrasePlan,
            artifacts: artifacts
        ))
        let changedPlan = try #require(analyze(
            left: signal44,
            right: signal44,
            sampleRate: 44_100,
            plan: changedPlanSamePhrase,
            artifacts: artifacts
        ))
        let signal48 = testSignal(sampleRate: 48_000)
        let changedRate = try #require(analyze(
            left: signal48,
            right: signal48,
            sampleRate: 48_000,
            plan: baselinePlan,
            artifacts: artifacts
        ))
        let changedCheckpoint = try #require(analyze(
            left: signal44,
            right: signal44,
            sampleRate: 44_100,
            plan: changedCheckpointPlan,
            artifacts: artifacts
        ))
        var changedPCM = signal44
        changedPCM[4_096] = -changedPCM[4_096]
        let changedObservation = try #require(analyze(
            left: changedPCM,
            right: signal44,
            sampleRate: 44_100,
            plan: baselinePlan,
            artifacts: artifacts
        ))

        #expect(changedPhrase.phraseIndex != baseline.phraseIndex)
        #expect(changedPlan.phraseIndex == baseline.phraseIndex)
        #expect(changedPlan.planFingerprint != baseline.planFingerprint)
        #expect(changedCheckpoint.applicableCheckpoints !=
                baseline.applicableCheckpoints)

        #expect(target.isStructurallyValid(sourceEvidence: baseline))
        #expect(!target.isStructurallyValid(sourceEvidence: changedPhrase))
        #expect(!target.isStructurallyValid(sourceEvidence: changedPlan))
        #expect(!target.isStructurallyValid(sourceEvidence: changedRate))
        #expect(!target.isStructurallyValid(sourceEvidence: changedCheckpoint))
        #expect(!target.isStructurallyValid(sourceEvidence: changedObservation))
    }

    private func analyze(
        left: [Float],
        right: [Float],
        sampleRate: Double,
        plan: AutonomousPhrasePlan? = nil,
        routeGeneration: Int = 3,
        controllerRevision: Int = 4,
        playerSampleRange: Range<Int64>? = nil,
        artifacts: ProfessionalQualityPrimaryArtifacts? = nil,
        capture: LiveOutputCaptureProvenance? = nil,
        cancellationRequested: @escaping @Sendable () -> Bool = { false }
    ) -> LiveOutputWindowEvidence? {
        let range = playerSampleRange ??
            (Int64(80_000)..<Int64(80_000 + left.count))
        let planIdentity = LiveOutputPlanSourceIdentity(
            plan: plan ?? defaultDirectorPlan()
        )
        return LiveOutputWindowAnalyzer.analyze(
            left: left,
            right: right,
            planIdentity: planIdentity,
            routeGeneration: routeGeneration,
            controllerRevision: controllerRevision,
            playerSampleRange: range,
            sampleRate: sampleRate,
            captureProvenance: capture ?? captureProvenance(frameCount: left.count),
            artifacts: artifacts ?? installedArtifacts(),
            cancellationRequested: cancellationRequested
        )
    }

    private func captureProvenance(
        frameCount: Int,
        packetFrameCount: Int = 1_024
    ) -> LiveOutputCaptureProvenance {
        let packetCount = max(
            1,
            (frameCount + packetFrameCount - 1) / packetFrameCount
        )
        let firstSequence: UInt64 = 500
        return LiveOutputCaptureProvenance(
            packetCount: packetCount,
            firstPacketSequence: firstSequence,
            lastPacketSequence: firstSequence + UInt64(packetCount - 1),
            droppedPacketDelta: 0,
            rejectedPacketDelta: 0,
            queueCapacity: 256,
            maximumPacketFrameCount: 1_024,
            workingMemoryByteCount:
                frameCount * 2 * MemoryLayout<Float>.stride,
            coveredFrameCount: frameCount,
            sampleDiscontinuityCount: 0,
            gapFrameCount: 0,
            overlapFrameCount: 0
        )
    }

    private func capture(
        from source: LiveOutputCaptureProvenance,
        packetCount: Int? = nil,
        lastPacketSequence: UInt64? = nil,
        droppedPacketDelta: UInt64? = nil,
        rejectedPacketDelta: UInt64? = nil,
        queueCapacity: Int? = nil,
        maximumPacketFrameCount: Int? = nil,
        workingMemoryByteCount: Int? = nil,
        coveredFrameCount: Int? = nil,
        sampleDiscontinuityCount: Int? = nil,
        gapFrameCount: Int? = nil,
        overlapFrameCount: Int? = nil
    ) -> LiveOutputCaptureProvenance {
        LiveOutputCaptureProvenance(
            packetCount: packetCount ?? source.packetCount,
            firstPacketSequence: source.firstPacketSequence,
            lastPacketSequence: lastPacketSequence ?? source.lastPacketSequence,
            droppedPacketDelta: droppedPacketDelta ?? source.droppedPacketDelta,
            rejectedPacketDelta: rejectedPacketDelta ?? source.rejectedPacketDelta,
            queueCapacity: queueCapacity ?? source.queueCapacity,
            maximumPacketFrameCount: maximumPacketFrameCount ??
                source.maximumPacketFrameCount,
            workingMemoryByteCount: workingMemoryByteCount ??
                source.workingMemoryByteCount,
            coveredFrameCount: coveredFrameCount ?? source.coveredFrameCount,
            sampleDiscontinuityCount: sampleDiscontinuityCount ??
                source.sampleDiscontinuityCount,
            gapFrameCount: gapFrameCount ?? source.gapFrameCount,
            overlapFrameCount: overlapFrameCount ?? source.overlapFrameCount
        )
    }

    private func realDirectorPlansWithDifferentKinds() -> (
        first: AutonomousPhrasePlan,
        second: AutonomousPhrasePlan
    ) {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        var state = director.initialState()
        let first = director.plan(from: state)
        state.advance(using: first)
        for _ in 0..<96 {
            let candidate = director.plan(from: state)
            if candidate.kind != first.kind {
                return (first, candidate)
            }
            state.advance(using: candidate)
        }
        Issue.record("Expected two real director plans with different kinds")
        fatalError("Canonical director did not reach a second phrase kind")
    }

    private func realDirectorPlan(
        rootSeed: UInt64 = 48_291,
        matching predicate: (AutonomousPhrasePlan) -> Bool
    ) -> AutonomousPhrasePlan {
        let director = AutonomousSessionDirector(rootSeed: rootSeed)
        var state = director.initialState()
        for _ in 0..<96 {
            let plan = director.plan(from: state)
            if predicate(plan) { return plan }
            state.advance(using: plan)
        }
        Issue.record("Expected a real director plan matching the predicate")
        fatalError("Canonical director did not reach the required plan")
    }

    private func installedArtifacts() -> ProfessionalQualityPrimaryArtifacts {
        do {
            return try ProfessionalQualityPrimaryArtifacts.load()
        } catch {
            Issue.record("Unable to load installed primary artifacts: \(error)")
            fatalError("Primary quality artifacts are required by this test")
        }
    }

    private func defaultDirectorPlan(
        rootSeed: UInt64 = 48_291
    ) -> AutonomousPhrasePlan {
        let director = AutonomousSessionDirector(rootSeed: rootSeed)
        return director.plan(from: director.initialState())
    }

    private func testSignal(sampleRate: Double) -> [Float] {
        (0..<Int(3 * 48_000)).prefix(Int(3 * sampleRate)).map { frame in
            Float(
                0.19 * sin(2 * Double.pi * 997 * Double(frame) / sampleRate) +
                0.06 * sin(
                    2 * Double.pi * 11_300 * Double(frame) / sampleRate + 0.31
                )
            )
        }
    }

    private func strictestBounds(
        metric: ProfessionalQualityMetric,
        checkpoints: [CanonicalJourneyCheckpoint],
        profile: ProfessionalQualityCalibrationProfile
    ) throws -> (
        checkpoint: CanonicalJourneyCheckpoint,
        bounds: ProfessionalQualityMetricBounds
    ) {
        try #require(checkpoints.compactMap { checkpoint in
            profile[checkpoint]?[metric].map { (checkpoint, $0) }
        }.min { $0.1.upper < $1.1.upper })
    }
}

private final class CancellationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private let cancelAt: Int
    private var calls = 0

    init(cancelAt: Int) {
        self.cancelAt = cancelAt
    }

    func isCancelled() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        calls += 1
        return calls >= cancelAt
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }
}
