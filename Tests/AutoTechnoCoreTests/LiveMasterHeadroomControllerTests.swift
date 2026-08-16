import AutoTechnoCore
import AutoTechnoDSP
import Foundation
import Testing

@Suite("Live master headroom controller")
struct LiveMasterHeadroomControllerTests {
    @Test("The larger calibrated excess owns attenuation")
    func takesMaximumOfLoudnessAndTruePeakExcess() throws {
        let pair = Self.aboveUpperPair
        let incoming = incomingState(for: pair.evidence)
        let proposal = LiveMasterHeadroomController.propose(
            evidence: pair.evidence,
            target: pair.target,
            incoming: incoming,
            earliestEligibleFutureSample: futureSample(after: pair.evidence)
        )
        let loudnessExcess = pair.evidence.maximumShortTermLoudnessLUFS -
            pair.target.loudnessUpperLUFS
        let truePeakExcess = pair.evidence.truePeakDBTP -
            pair.target.truePeakUpperDBTP
        let expectedExcess = max(loudnessExcess, truePeakExcess, 0)

        #expect(expectedExcess > 0.25)
        #expect(proposal.outcome == .attenuate)
        #expect(proposal.proposedTrimDB ==
                incoming.committedTrimDB -
                    min(LiveMasterHeadroomController.attackStepDB, expectedExcess))
        #expect(proposal.proposedCleanWindows == 0)
    }

    @Test("One source phrase attacks by at most one quarter decibel")
    func attackIsAtMostQuarterDB() throws {
        let pair = Self.aboveUpperPair
        let incoming = incomingState(for: pair.evidence, trimDB: -1.25)
        let proposal = propose(pair, incoming: incoming)

        #expect(proposal.outcome == .attenuate)
        #expect(proposal.proposedTrimDB == -1.5)
        #expect(incoming.committedTrimDB - proposal.proposedTrimDB <= 0.25)
    }

    @Test("An uncapped loudness excess applies its exact sub-quarter delta")
    func uncappedLoudnessExcessIsExact() {
        let pair = Self.loudnessDominantPair
        let incoming = incomingState(for: pair.evidence, trimDB: -1)
        let proposal = propose(pair, incoming: incoming)
        let loudnessExcess = pair.evidence.maximumShortTermLoudnessLUFS -
            pair.target.loudnessUpperLUFS
        let truePeakExcess = pair.evidence.truePeakDBTP -
            pair.target.truePeakUpperDBTP

        #expect(loudnessExcess > 0)
        #expect(loudnessExcess < 0.25)
        #expect(loudnessExcess > max(truePeakExcess, 0))
        #expect(proposal.outcome == .attenuate)
        #expect(proposal.proposedTrimDB ==
                incoming.committedTrimDB - loudnessExcess)
    }

    @Test("An uncapped true-peak excess applies its exact sub-quarter delta")
    func uncappedTruePeakExcessIsExact() {
        let pair = Self.truePeakDominantPair
        let incoming = incomingState(for: pair.evidence, trimDB: -1)
        let proposal = propose(pair, incoming: incoming)
        let loudnessExcess = pair.evidence.maximumShortTermLoudnessLUFS -
            pair.target.loudnessUpperLUFS
        let truePeakExcess = pair.evidence.truePeakDBTP -
            pair.target.truePeakUpperDBTP

        #expect(truePeakExcess > 0)
        #expect(truePeakExcess < 0.25)
        #expect(truePeakExcess > max(loudnessExcess, 0))
        #expect(proposal.outcome == .attenuate)
        #expect(proposal.proposedTrimDB ==
                incoming.committedTrimDB - truePeakExcess)
    }

    @Test("One source phrase cannot drive a second transition")
    func sourcePhraseAttacksAtMostOnce() {
        let pair = Self.aboveUpperPair
        let incoming = LiveMasterHeadroomContinuationState(
            revision: pair.evidence.controllerRevision,
            committedTrimDB: -0.5,
            consecutiveCleanWindows: 1,
            lastProposalFingerprint: "accepted-proposal",
            lastObservationFingerprint: "accepted-observation",
            lastAcceptedSourcePhraseIndex: pair.evidence.phraseIndex,
            earliestEligibleFutureSample: 40_000
        )
        let proposal = propose(pair, incoming: incoming)

        #expect(proposal.outcome == .unavailable)
        #expect(proposal.reasonCodes == [.staleProposal])
        #expect(proposal.proposedTrimDB == incoming.committedTrimDB)
        #expect(proposal.proposedCleanWindows ==
                incoming.consecutiveCleanWindows)
    }

    @Test("Recovery never raises the master above authored unity")
    func neverBoostsAboveUnity() throws {
        let pair = Self.belowMidpointsPair
        let incoming = incomingState(
            for: pair.evidence,
            trimDB: -0.05,
            cleanWindows: 1
        )
        let proposal = propose(pair, incoming: incoming)

        #expect(proposal.outcome == .recover)
        #expect(proposal.proposedTrimDB == 0)
        #expect(proposal.proposedTrimDB <=
                LiveMasterHeadroomController.maximumTrimDB)
    }

    @Test("Continued excess saturates at minus three decibels")
    func saturatesAtMinusThreeDB() throws {
        let pair = Self.aboveUpperPair
        let incoming = incomingState(for: pair.evidence, trimDB: -2.9)
        let proposal = propose(pair, incoming: incoming)

        #expect(proposal.outcome == .attenuate)
        #expect(proposal.proposedTrimDB == -3)
        #expect(proposal.proposedTrimDB >=
                LiveMasterHeadroomController.minimumTrimDB)

        let saturated = incomingState(for: pair.evidence, trimDB: -3)
        let held = propose(pair, incoming: saturated)
        #expect(held.outcome == .hold)
        #expect(held.reasonCodes == [
            .masterTrimSaturatedV1,
            .windowAccepted,
        ])
        #expect(held.proposedTrimDB == -3)
        #expect(held.proposedCleanWindows == 0)
    }

    @Test("The calibrated midpoint-to-upper deadband holds")
    func deadbandHolds() throws {
        let pair = Self.insideDeadbandPair
        let incoming = incomingState(
            for: pair.evidence,
            trimDB: -1,
            cleanWindows: 1
        )
        let proposal = propose(pair, incoming: incoming)

        #expect(pair.evidence.maximumShortTermLoudnessLUFS <=
                pair.target.loudnessUpperLUFS)
        #expect(pair.evidence.truePeakDBTP <= pair.target.truePeakUpperDBTP)
        #expect(pair.evidence.maximumShortTermLoudnessLUFS >
                    pair.target.loudnessMidpointLUFS ||
                pair.evidence.truePeakDBTP > pair.target.truePeakMidpointDBTP)
        #expect(proposal.outcome == .hold)
        #expect(proposal.proposedTrimDB == incoming.committedTrimDB)
        #expect(proposal.proposedCleanWindows == 0)
    }

    @Test("A second consecutive clean active window recovers one eighth dB")
    func twoCleanWindowsRecoverOneEighthDB() throws {
        let pair = Self.belowMidpointsPair
        let incoming = incomingState(
            for: pair.evidence,
            trimDB: -1,
            cleanWindows: 1
        )
        let proposal = propose(pair, incoming: incoming)

        #expect(pair.evidence.isActiveProgram)
        #expect(proposal.outcome == .recover)
        #expect(proposal.proposedTrimDB == -0.875)
        #expect(proposal.proposedCleanWindows == 0)
    }

    @Test("One clean active window only arms recovery")
    func oneCleanWindowDoesNotRecover() throws {
        let pair = Self.belowMidpointsPair
        let incoming = incomingState(for: pair.evidence, trimDB: -1)
        let proposal = propose(pair, incoming: incoming)

        #expect(pair.evidence.isActiveProgram)
        #expect(proposal.outcome == .hold)
        #expect(proposal.proposedTrimDB == -1)
        #expect(proposal.proposedCleanWindows == 1)
    }

    @Test("Missing and inactive evidence hold the exact incoming state")
    func unavailableEvidenceHolds() throws {
        let active = Self.aboveUpperPair
        let incoming = incomingState(
            for: active.evidence,
            trimDB: -0.75,
            cleanWindows: 1
        )
        let missingEvidence = LiveMasterHeadroomController.propose(
            evidence: nil,
            target: active.target,
            incoming: incoming,
            earliestEligibleFutureSample: futureSample(after: active.evidence)
        )
        let missingTarget = LiveMasterHeadroomController.propose(
            evidence: active.evidence,
            target: nil,
            incoming: incoming,
            earliestEligibleFutureSample: futureSample(after: active.evidence)
        )
        let inactive = Self.inactivePair
        let inactiveIncoming = incomingState(
            for: inactive.evidence,
            trimDB: -0.75,
            cleanWindows: 1
        )
        let inactiveProposal = propose(inactive, incoming: inactiveIncoming)

        for proposal in [missingEvidence, missingTarget, inactiveProposal] {
            #expect(proposal.outcome == .unavailable)
            #expect(proposal.proposedTrimDB == -0.75)
            #expect(proposal.proposedCleanWindows == 1)
        }
        #expect(missingEvidence.reasonCodes == [.windowIncomplete])
        #expect(missingTarget.reasonCodes == [.profileUnavailable])
        #expect(inactiveProposal.reasonCodes == [.windowIncomplete])
    }

    @Test("Route, source pairing, and revision mismatches hold")
    func routeAndRevisionMismatchHold() throws {
        let routeThree = Self.aboveUpperPair
        let routeFour = try Self.analyzePair(
            signal: routeThree.signal,
            plan: Self.defaultPlan(),
            routeGeneration: 4,
            controllerRevision: 4,
            playerSampleRange: nil
        )
        let incoming = incomingState(
            for: routeThree.evidence,
            trimDB: -0.5,
            cleanWindows: 1
        )
        let routeMismatch = LiveMasterHeadroomController.propose(
            evidence: routeThree.evidence,
            target: routeFour.target,
            incoming: incoming,
            earliestEligibleFutureSample: futureSample(after: routeThree.evidence)
        )
        let revisionMismatch = LiveMasterHeadroomController.propose(
            evidence: routeThree.evidence,
            target: routeThree.target,
            incoming: LiveMasterHeadroomContinuationState(
                revision: incoming.revision + 1,
                committedTrimDB: incoming.committedTrimDB,
                consecutiveCleanWindows: incoming.consecutiveCleanWindows
            ),
            earliestEligibleFutureSample: futureSample(after: routeThree.evidence)
        )

        #expect(routeMismatch.outcome == .unavailable)
        #expect(routeMismatch.reasonCodes == [.routeMismatch])
        #expect(routeMismatch.controllerPolicyVersion ==
                LiveFeedbackContract.controllerPolicyVersion)
        #expect(routeMismatch.targetFingerprint == routeFour.target.fingerprint)
        #expect(routeMismatch.proposedTrimDB == incoming.committedTrimDB)
        #expect(routeMismatch.proposedCleanWindows ==
                incoming.consecutiveCleanWindows)
        #expect(revisionMismatch.outcome == .unavailable)
        #expect(revisionMismatch.reasonCodes == [.staleProposal])
        #expect(revisionMismatch.proposedTrimDB == incoming.committedTrimDB)
        #expect(revisionMismatch.proposedCleanWindows ==
                incoming.consecutiveCleanWindows)
        let valid = propose(routeThree, incoming: incoming)
        #expect(valid.targetFingerprint == routeThree.target.fingerprint)
        #expect(valid.fingerprint != routeMismatch.fingerprint)
    }

    @Test("Identical transition inputs replay bit exactly")
    func deterministicReplayIsBitExact() throws {
        let pair = Self.aboveUpperPair
        let incoming = incomingState(
            for: pair.evidence,
            trimDB: -0.75,
            cleanWindows: 1
        )
        let first = propose(pair, incoming: incoming)
        let second = propose(pair, incoming: incoming)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        #expect(first == second)
        #expect(first.fingerprint == second.fingerprint)
        #expect(try encoder.encode(first) == encoder.encode(second))
        #expect(AutonomousTypedFingerprint.liveMasterHeadroomProposal(first) ==
                AutonomousTypedFingerprint.liveMasterHeadroomProposal(second))
    }

    @Test("Maximum revision and terminal sample boundary cannot overflow")
    func maximumRevisionAndBoundaryCannotOverflow() throws {
        let high = Self.aboveUpperPair
        let maximumRevision = try Self.analyzePair(
            signal: high.signal,
            plan: Self.defaultPlan(),
            routeGeneration: 3,
            controllerRevision: .max,
            playerSampleRange: nil
        )
        let revisionIncoming = incomingState(
            for: maximumRevision.evidence,
            trimDB: -0.5,
            cleanWindows: 1
        )
        let revisionProposal = propose(
            maximumRevision,
            incoming: revisionIncoming
        )

        let frameCount = try #require(
            LiveOutputWindowAnalyzer.frameCount(sampleRate: 44_100)
        )
        let terminalRange =
            (Int64.max - Int64(frameCount))..<Int64.max
        let terminal = try Self.analyzePair(
            signal: high.signal,
            plan: Self.defaultPlan(),
            routeGeneration: 3,
            controllerRevision: 4,
            playerSampleRange: terminalRange
        )
        let terminalIncoming = incomingState(
            for: terminal.evidence,
            trimDB: -0.5,
            cleanWindows: 1
        )
        let terminalProposal = LiveMasterHeadroomController.propose(
            evidence: terminal.evidence,
            target: terminal.target,
            incoming: terminalIncoming,
            earliestEligibleFutureSample: .max
        )

        #expect(revisionProposal.outcome == .unavailable)
        #expect(revisionProposal.reasonCodes == [.staleProposal])
        #expect(revisionProposal.proposedTrimDB ==
                revisionIncoming.committedTrimDB)
        #expect(revisionProposal.proposedCleanWindows ==
                revisionIncoming.consecutiveCleanWindows)
        #expect(terminalProposal.outcome == .unavailable)
        #expect(terminalProposal.reasonCodes == [.staleProposal])
        #expect(terminalProposal.proposedTrimDB ==
                terminalIncoming.committedTrimDB)
        #expect(terminalProposal.proposedCleanWindows ==
                terminalIncoming.consecutiveCleanWindows)
    }

    private enum Regime {
        case aboveUpper(excessDB: Double)
        case insideDeadband
        case belowMidpoints
    }

    private enum DrivingMetric {
        case loudness
        case truePeak
    }

    private struct Pair: Sendable {
        let signal: [Float]
        let evidence: LiveOutputWindowEvidence
        let target: LiveMasterHeadroomTarget
    }

    private struct TargetBounds: Sendable {
        let selectedLoudnessCheckpoint: CanonicalJourneyCheckpoint
        let selectedTruePeakCheckpoint: CanonicalJourneyCheckpoint
        let loudnessLowerLUFS: Double
        let loudnessUpperLUFS: Double
        let truePeakLowerDBTP: Double
        let truePeakUpperDBTP: Double

        init(_ target: LiveMasterHeadroomTarget) {
            selectedLoudnessCheckpoint = target.selectedLoudnessCheckpoint
            selectedTruePeakCheckpoint = target.selectedTruePeakCheckpoint
            loudnessLowerLUFS = target.loudnessLowerLUFS
            loudnessUpperLUFS = target.loudnessUpperLUFS
            truePeakLowerDBTP = target.truePeakLowerDBTP
            truePeakUpperDBTP = target.truePeakUpperDBTP
        }
    }

    private static let aboveUpperPair = requiredPair(.aboveUpper(excessDB: 0.8))
    private static let insideDeadbandPair = requiredPair(.insideDeadband)
    private static let belowMidpointsPair = requiredPair(.belowMidpoints)
    private static let inactivePair = requiredInactivePair()
    private static let loudnessDominantPair = requiredDominantPair(
        signal: testSignal(sampleRate: 44_100),
        metric: .loudness
    )
    private static let truePeakDominantPair = requiredDominantPair(
        signal: transientSignal(sampleRate: 44_100),
        metric: .truePeak
    )

    private static func requiredPair(_ regime: Regime) -> Pair {
        do {
            return try makePair(regime)
        } catch {
            fatalError("Unable to create live controller fixture: \(error)")
        }
    }

    private static func requiredInactivePair() -> Pair {
        do {
            return try makeInactivePair()
        } catch {
            fatalError("Unable to create inactive live controller fixture: \(error)")
        }
    }

    private static func requiredDominantPair(
        signal: [Float],
        metric: DrivingMetric
    ) -> Pair {
        do {
            return try makeDominantPair(signal: signal, metric: metric)
        } catch {
            fatalError("Unable to create dominant live fixture: \(error)")
        }
    }

    private static func makePair(
        _ regime: Regime,
        routeGeneration: Int = 3,
        controllerRevision: Int = 4,
        playerSampleRange: Range<Int64>? = nil
    ) throws -> Pair {
        let plan = Self.defaultPlan()
        let baseSignal = Self.testSignal(sampleRate: 44_100)
        let base = try analyzePair(
            signal: baseSignal,
            plan: plan,
            routeGeneration: routeGeneration,
            controllerRevision: controllerRevision,
            playerSampleRange: playerSampleRange
        )
        let gainDB: Double
        switch regime {
        case let .aboveUpper(excessDB):
            let currentExcess = max(
                base.evidence.maximumShortTermLoudnessLUFS -
                    base.target.loudnessUpperLUFS,
                base.evidence.truePeakDBTP - base.target.truePeakUpperDBTP
            )
            gainDB = excessDB - currentExcess
        case .insideDeadband:
            let upperEdge = min(
                base.target.loudnessUpperLUFS -
                    base.evidence.maximumShortTermLoudnessLUFS,
                base.target.truePeakUpperDBTP - base.evidence.truePeakDBTP
            )
            gainDB = upperEdge - 0.25
        case .belowMidpoints:
            gainDB = min(
                base.target.loudnessMidpointLUFS -
                    base.evidence.maximumShortTermLoudnessLUFS,
                base.target.truePeakMidpointDBTP - base.evidence.truePeakDBTP
            ) - 1
        }
        let linearGain = Float(pow(10, gainDB / 20))
        let scaled = baseSignal.map { $0 * linearGain }
        return try analyzePair(
            signal: scaled,
            plan: plan,
            routeGeneration: routeGeneration,
            controllerRevision: controllerRevision,
            playerSampleRange: playerSampleRange,
            targetBounds: TargetBounds(base.target)
        )
    }

    private static func makeInactivePair() throws -> Pair {
        let frameCount = try #require(
            LiveOutputWindowAnalyzer.frameCount(sampleRate: 44_100)
        )
        return try analyzePair(
            signal: [Float](repeating: 0, count: frameCount),
            plan: Self.defaultPlan(),
            routeGeneration: 3,
            controllerRevision: 4,
            playerSampleRange: nil
        )
    }

    private static func makeDominantPair(
        signal: [Float],
        metric: DrivingMetric
    ) throws -> Pair {
        let plan = Self.defaultPlan()
        let base = try analyzePair(
            signal: signal,
            plan: plan,
            routeGeneration: 3,
            controllerRevision: 4,
            playerSampleRange: nil
        )
        let targetBounds: TargetBounds
        let currentDifference: Double
        switch metric {
        case .loudness:
            let target = try #require(LiveFeedbackTestSupport.target(
                evidence: base.evidence,
                loudnessLowerLUFS:
                    base.evidence.maximumShortTermLoudnessLUFS - 1,
                loudnessUpperLUFS:
                    base.evidence.maximumShortTermLoudnessLUFS + 1,
                truePeakLowerDBTP: base.evidence.truePeakDBTP,
                truePeakUpperDBTP: base.evidence.truePeakDBTP + 2
            ))
            targetBounds = TargetBounds(target)
            currentDifference =
                base.evidence.maximumShortTermLoudnessLUFS -
                target.loudnessUpperLUFS
        case .truePeak:
            let target = try #require(LiveFeedbackTestSupport.target(
                evidence: base.evidence,
                loudnessLowerLUFS:
                    base.evidence.maximumShortTermLoudnessLUFS,
                loudnessUpperLUFS:
                    base.evidence.maximumShortTermLoudnessLUFS + 2,
                truePeakLowerDBTP: base.evidence.truePeakDBTP - 1,
                truePeakUpperDBTP: base.evidence.truePeakDBTP + 1
            ))
            targetBounds = TargetBounds(target)
            currentDifference = base.evidence.truePeakDBTP -
                target.truePeakUpperDBTP
        }
        let gainDB = 0.1 - currentDifference
        let gain = Float(pow(10, gainDB / 20))
        return try analyzePair(
            signal: signal.map { $0 * gain },
            plan: plan,
            routeGeneration: 3,
            controllerRevision: 4,
            playerSampleRange: nil,
            targetBounds: targetBounds
        )
    }

    private static func analyzePair(
        signal: [Float],
        plan: AutonomousPhrasePlan,
        routeGeneration: Int,
        controllerRevision: Int,
        playerSampleRange: Range<Int64>?,
        targetBounds: TargetBounds? = nil
    ) throws -> Pair {
        let range = playerSampleRange ??
            (80_000..<Int64(80_000 + signal.count))
        let evidence = try #require(LiveFeedbackTestSupport.analyze(
            signal: signal,
            plan: plan,
            sampleRate: 44_100,
            routeGeneration: routeGeneration,
            controllerRevision: controllerRevision,
            playerSampleRange: range
        ))
        let target = try #require(LiveFeedbackTestSupport.target(
            evidence: evidence,
            selectedLoudnessCheckpoint:
                targetBounds?.selectedLoudnessCheckpoint,
            selectedTruePeakCheckpoint:
                targetBounds?.selectedTruePeakCheckpoint,
            loudnessLowerLUFS: targetBounds?.loudnessLowerLUFS,
            loudnessUpperLUFS: targetBounds?.loudnessUpperLUFS,
            truePeakLowerDBTP: targetBounds?.truePeakLowerDBTP,
            truePeakUpperDBTP: targetBounds?.truePeakUpperDBTP
        ))
        return Pair(signal: signal, evidence: evidence, target: target)
    }

    private func propose(
        _ pair: Pair,
        incoming: LiveMasterHeadroomContinuationState
    ) -> LiveMasterHeadroomProposal {
        LiveMasterHeadroomController.propose(
            evidence: pair.evidence,
            target: pair.target,
            incoming: incoming,
            earliestEligibleFutureSample: futureSample(after: pair.evidence)
        )
    }

    private func incomingState(
        for evidence: LiveOutputWindowEvidence,
        trimDB: Double = 0,
        cleanWindows: Int = 0
    ) -> LiveMasterHeadroomContinuationState {
        LiveMasterHeadroomContinuationState(
            revision: evidence.controllerRevision,
            committedTrimDB: trimDB,
            consecutiveCleanWindows: cleanWindows
        )
    }

    private func futureSample(
        after evidence: LiveOutputWindowEvidence
    ) -> Int64 {
        let result = evidence.playerSampleRange.upperBound
            .addingReportingOverflow(1)
        return result.overflow ? .max : result.partialValue
    }

    private static func defaultPlan() -> AutonomousPhrasePlan {
        let director = AutonomousSessionDirector(rootSeed: 48_291)
        return director.plan(from: director.initialState())
    }

    private static func captureProvenance(
        frameCount: Int
    ) -> LiveOutputCaptureProvenance {
        let packetCount = (frameCount + 1_023) / 1_024
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

    private static func testSignal(sampleRate: Double) -> [Float] {
        (0..<Int(3 * sampleRate)).map { frame in
            Float(
                0.19 * sin(2 * Double.pi * 997 * Double(frame) / sampleRate) +
                0.06 * sin(
                    2 * Double.pi * 11_300 * Double(frame) / sampleRate + 0.31
                )
            )
        }
    }

    private static func transientSignal(sampleRate: Double) -> [Float] {
        let period = Int(sampleRate / 20)
        return (0..<Int(3 * sampleRate)).map { frame in
            switch frame % period {
            case 0: return 1
            case 1: return -0.4
            default: return 0
            }
        }
    }
}
