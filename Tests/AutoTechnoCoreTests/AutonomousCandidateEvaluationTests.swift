@testable import AutoTechnoDSP
import AutoTechnoCore
import Foundation
import Testing

@Suite("Autonomous candidate evaluation provenance")
struct AutonomousCandidateEvaluationTests {
    @Test("Reduced vector JSON and FNV fingerprints are deterministic and round trip")
    func deterministicVector() throws {
        let first = fixtureVector(slot: .primary)
        let second = fixtureVector(slot: .primary)

        #expect(first.isComplete)
        #expect(first.isFinite)
        #expect(first.hardGatesPassed)
        #expect(first == second)
        #expect(try first.deterministicJSON() == second.deterministicJSON())
        #expect(first.fingerprint == second.fingerprint)
        #expect(!first.fingerprint.isEmpty)
        let decoded = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: first.deterministicJSON()
        )
        #expect(decoded == first)
        #expect(decoded.preGraphUpperTimbreEvidence ==
                decoded.postGraphUpperTimbreEvidence)
        #expect(decoded.playbackGateUpperTimbreEvidence ==
                decoded.postGraphUpperTimbreEvidence)
    }

    @Test("Groove-pulse evidence is lean, bounded, deterministic, and required per bar")
    func groovePulseEvidenceContract() throws {
        let event = fixtureGroovePulseEvent()
        let bar = AutonomousGroovePulseBarEvidence(
            bar: 0,
            sourceScoreEventCount: 1,
            sourceRenderEventCount: 1,
            events: [event]
        )
        let vector = fixtureVector(slot: .primary, groovePulseBar: bar)

        #expect(event.isComplete(sampleRate: 8_000))
        #expect(event.isFinite)
        #expect(bar.isComplete(sampleRate: 8_000))
        #expect(vector.schemaVersion == 3)
        #expect(QualityQualificationContract.schemaVersion == 5)
        #expect(QualityQualificationContract.engineVersion ==
                "autotechno-canonical-engine.v3")
        #expect(vector.isComplete)
        #expect(vector.isFinite)
        #expect(vector.fingerprint != fixtureVector(slot: .primary).fingerprint)
        #expect(vector.selectionEvidence ==
                fixtureVector(slot: .primary).selectionEvidence)

        let ghostVector = fixtureVector(
            slot: .primary,
            planFingerprintOverride: "plan-primary-ghost",
            groovePulseBar: AutonomousGroovePulseBarEvidence(
                bar: 0,
                sourceScoreEventCount: 1,
                sourceRenderEventCount: 1,
                events: [fixtureGroovePulseEvent(
                    intensity: 0.30,
                    sampleHash: "0000000000000030",
                    sourceRMS: 0.007
                )]
            )
        )
        let accentVector = fixtureVector(
            slot: .primary,
            planFingerprintOverride: "plan-primary-accent",
            groovePulseBar: AutonomousGroovePulseBarEvidence(
                bar: 0,
                sourceScoreEventCount: 1,
                sourceRenderEventCount: 1,
                events: [fixtureGroovePulseEvent(
                    intensity: 0.72,
                    sampleHash: "0000000000000072",
                    sourceRMS: 0.017
                )]
            )
        )
        #expect(ghostVector.isComplete && accentVector.isComplete)
        #expect(ghostVector.fingerprint != accentVector.fingerprint)
        let ghostSelection = ghostVector.selectionEvidence
        let accentSelectionWithMaximumMovement = AutonomousCandidateEvidence(
            symbolicValid: accentVector.selectionEvidence.symbolicValid,
            safetyValid: accentVector.selectionEvidence.safetyValid,
            interesting: accentVector.selectionEvidence.interesting,
            combinedScore: accentVector.selectionEvidence.combinedScore + 0.18
        )
        #expect(ghostSelection != accentSelectionWithMaximumMovement)
        #expect(!AutonomousCandidateSelector.needsAlternate(primary: ghostSelection))
        #expect(!AutonomousCandidateSelector.needsAlternate(
            primary: accentSelectionWithMaximumMovement
        ))
        #expect(AutonomousCandidateSelector.choose(
            primary: ghostSelection,
            alternate: nil,
            qualityComparison: .unavailable
        ) == .primary)
        #expect(AutonomousCandidateSelector.choose(
            primary: accentSelectionWithMaximumMovement,
            alternate: nil,
            qualityComparison: .unavailable
        ) == .primary)

        let data = try vector.deterministicJSON()
        let decoded = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: data
        )
        #expect(decoded == vector)
        #expect(decoded.fingerprint == vector.fingerprint)

        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let grooveBars = try #require(object["groovePulse"] as? [[String: Any]])
        let events = try #require(grooveBars.first?["events"] as? [[String: Any]])
        let serializedEvent = try #require(events.first)
        #expect(Set(serializedEvent.keys) == Set([
            "step", "intensity", "strikeZone", "damping",
            "timbreMicrovariation", "renderedFrameCount", "sampleHash",
            "sourceRMS", "spectralCentroidHz", "tailToAttackDB", "finite",
        ]))

        var forgedObject = object
        var forgedBars = grooveBars
        var forgedBar = forgedBars[0]
        var forgedEvents = events
        var forgedEvent = serializedEvent
        forgedEvent["sourceRMS"] = 1e300
        forgedEvents[0] = forgedEvent
        forgedBar["events"] = forgedEvents
        forgedBars[0] = forgedBar
        forgedObject["groovePulse"] = forgedBars
        let forgedVector = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedObject)
        )
        #expect(!forgedVector.isComplete)
        #expect(forgedVector.fingerprint != vector.fingerprint)

        var oversizedEventObject = object
        var oversizedEventBars = grooveBars
        var oversizedEventBar = oversizedEventBars[0]
        let decodedOversizedEvents: [[String: Any]] = (0..<9).map { step in
            var copy = serializedEvent
            copy["step"] = step
            copy["sampleHash"] = String(format: "%016x", step + 1)
            return copy
        }
        oversizedEventBar["sourceScoreEventCount"] = 9
        oversizedEventBar["sourceRenderEventCount"] = 9
        oversizedEventBar["events"] = decodedOversizedEvents
        oversizedEventBars[0] = oversizedEventBar
        oversizedEventObject["groovePulse"] = oversizedEventBars
        let decodedOversizedEventVector = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: oversizedEventObject)
        )
        #expect(decodedOversizedEventVector.groovePulse[0].events.count == 9)
        #expect(!decodedOversizedEventVector.recordIsStructurallyValid)

        var oversizedBarObject = object
        let decodedOversizedBars: [[String: Any]] = (0..<17).map { bar in
            var copy = grooveBars[0]
            copy["bar"] = bar
            return copy
        }
        oversizedBarObject["sourceGroovePulseBarCount"] = 17
        oversizedBarObject["groovePulse"] = decodedOversizedBars
        let decodedOversizedBarVector = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: oversizedBarObject)
        )
        #expect(decodedOversizedBarVector.groovePulse.count == 17)
        #expect(!decodedOversizedBarVector.recordIsStructurallyValid)

        let excessiveEvents = (0..<9).map {
            fixtureGroovePulseEvent(step: $0, sampleHash: String(format: "%016x", $0))
        }
        let truncated = AutonomousGroovePulseBarEvidence(
            bar: 0,
            sourceScoreEventCount: excessiveEvents.count,
            sourceRenderEventCount: excessiveEvents.count,
            events: excessiveEvents
        )
        #expect(truncated.events.count ==
                AutonomousCandidateEvaluationVector.maximumGroovePulseEventsPerBar)
        #expect(!truncated.isComplete(sampleRate: 8_000))

        let mismatchedSources = AutonomousGroovePulseBarEvidence(
            bar: 0,
            sourceScoreEventCount: 1,
            sourceRenderEventCount: 0,
            events: [event]
        )
        #expect(!mismatchedSources.isComplete(sampleRate: 8_000))

        let duplicateSteps = AutonomousGroovePulseBarEvidence(
            bar: 0,
            sourceScoreEventCount: 2,
            sourceRenderEventCount: 2,
            events: [event, event]
        )
        #expect(!duplicateSteps.isComplete(sampleRate: 8_000))

        #expect(!fixtureGroovePulseEvent(
            renderedFrameCount: 359
        ).isComplete(sampleRate: 8_000))
        #expect(!fixtureGroovePulseEvent(sampleHash: "NOT-A-PCM-HASH!!")
            .isComplete(sampleRate: 8_000))
        #expect(!fixtureGroovePulseEvent(sourceRMS: 1e300)
            .isComplete(sampleRate: 8_000))
        #expect(!fixtureGroovePulseEvent(spectralCentroidHz: 4_001)
            .isComplete(sampleRate: 8_000))
        #expect(!fixtureGroovePulseEvent(tailToAttackDB: 121)
            .isComplete(sampleRate: 8_000))
        #expect(!fixtureGroovePulseEvent(finite: false).isFinite)
    }

    @Test("Masking and stem payloads are bounded and malformed vectors are incomplete")
    func malformedBoundedEvidence() throws {
        let excessiveMasking = fixtureVector(
            slot: .primary,
            maskingSourceCount: 13,
            maskingObservationCount: 13
        )
        #expect(excessiveMasking.masking[0].observations.count == 12)
        #expect(!excessiveMasking.isComplete)
        #expect(excessiveMasking.recordIsStructurallyValid)

        let missingStem = fixtureVector(
            slot: .primary,
            stemSourceRoleCount: 4,
            stemRoleCount: 4
        )
        #expect(missingStem.stems[0].roles.count == 4)
        #expect(!missingStem.isComplete)
        #expect(missingStem.recordIsStructurallyValid)

        let excessiveStem = fixtureVector(
            slot: .primary,
            stemSourceRoleCount: 6,
            stemRoleCount: 6
        )
        #expect(excessiveStem.stems[0].roles.count == 5)
        #expect(!excessiveStem.isComplete)
        #expect(excessiveStem.recordIsStructurallyValid)

        let bar = AutonomousBarFullMixEvidence(
            bar: 0,
            loudness: -14,
            spectralCentroid: 800,
            transientDensity: 1.5,
            crestFactor: 2.5,
            finite: true
        )
        let oversizedFullMix = AutonomousFullMixEvidence(
            sourceBarCount: 1,
            analyzedFrameCount: 1,
            sampleHash: "oversized-bars",
            peak: 0.5,
            truePeakEstimate: 0.55,
            rms: 0.2,
            loudnessEstimate: -0.691 + 20 * log10(0.2),
            maximumMomentaryLoudness: -0.691 + 20 * log10(0.2),
            maximumShortTermLoudness: -0.691 + 20 * log10(0.2),
            loudnessRange: 0,
            momentaryBlockCount: 1,
            absoluteGatedBlockCount: 1,
            relativeGatedBlockCount: 1,
            shortTermBlockCount: 0,
            dcOffset: 0,
            stereoCorrelation: 1,
            lowStereoCorrelation: 1,
            maximumBoundaryDelta: 0.01,
            movementScore: 0.5,
            bars: Array(repeating: bar, count: 17)
        )
        #expect(oversizedFullMix.sourceEvidenceBarCount == 17)
        #expect(oversizedFullMix.bars.count ==
                AutonomousCandidateEvaluationVector.maximumBarCount)
        #expect(!oversizedFullMix.isComplete)

        let sourceVector = fixtureVector(slot: .primary)
        var graphObject = try #require(JSONSerialization.jsonObject(
            with: sourceVector.deterministicJSON()
        ) as? [String: Any])
        var graph = try #require(graphObject["graph"] as? [String: Any])
        graph["violations"] = Array(
            repeating: "forged-violation",
            count: AutonomousGraphEvidence.maximumViolationCount + 1
        )
        graph["sourceViolationCount"] = AutonomousGraphEvidence.maximumViolationCount + 1
        graphObject["graph"] = graph
        let decoder = JSONDecoder()
        let forgedGraph = try decoder.decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: graphObject)
        )
        #expect(!forgedGraph.recordIsStructurallyValid)

        var velocityObject = try #require(JSONSerialization.jsonObject(
            with: sourceVector.deterministicJSON()
        ) as? [String: Any])
        var preGraph = try #require(
            velocityObject["preGraphUpperTimbreEvidence"] as? [String: Any]
        )
        let velocityEvent: [String: Any] = [
            "onsetFrame": 0,
            "analyzedEndFrame": 1,
            "analyzedFrameCount": 1,
            "velocity": 0.5,
            "appliedStartFrequency": 110.0,
            "spectralEnvelopeScale": 1.0,
            "decayScale": 1.0,
            "sourceRMS": 0.1,
            "attackHighBandRatio": 0.1,
            "tailToAttackDB": -6.0,
            "complete": true,
        ]
        preGraph["velocityExpression"] = Array(
            repeating: velocityEvent,
            count: UpperTimbreEvidenceAnalyzer.maximumVelocityExpressionEvents + 1
        )
        velocityObject["preGraphUpperTimbreEvidence"] = preGraph
        let forgedVelocity = try decoder.decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: velocityObject)
        )
        #expect(!forgedVelocity.recordIsStructurallyValid)

        var barRangeObject = try #require(JSONSerialization.jsonObject(
            with: sourceVector.deterministicJSON()
        ) as? [String: Any])
        var symbolic = try #require(barRangeObject["symbolic"] as? [String: Any])
        symbolic["startBar"] = 8
        barRangeObject["symbolic"] = symbolic
        let forgedBarRange = try decoder.decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: barRangeObject)
        )
        #expect(!forgedBarRange.isComplete)

        var routeObject = try #require(JSONSerialization.jsonObject(
            with: sourceVector.deterministicJSON()
        ) as? [String: Any])
        var route = try #require(
            routeObject["routeContinuation"] as? [String: Any]
        )
        route["routeFingerprint"] = "forged-route"
        routeObject["routeContinuation"] = route
        let forgedRoute = try decoder.decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: routeObject)
        )
        #expect(!forgedRoute.isComplete)

        var forgedStandardObject = try #require(JSONSerialization.jsonObject(
            with: sourceVector.deterministicJSON()
        ) as? [String: Any])
        var forgedStandardFullMix = try #require(
            forgedStandardObject["fullMix"] as? [String: Any]
        )
        forgedStandardFullMix["loudnessStandard"] = "rms-estimate"
        forgedStandardObject["fullMix"] = forgedStandardFullMix
        let forgedStandard = try decoder.decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedStandardObject)
        )
        #expect(!forgedStandard.isComplete)

        forgedStandardFullMix["loudnessStandard"] =
            BS1770LoudnessMeasurement.standard
        forgedStandardFullMix["analyzedFrameCount"] = 63
        forgedStandardObject["fullMix"] = forgedStandardFullMix
        let forgedFrameCoverage = try decoder.decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedStandardObject)
        )
        #expect(!forgedFrameCoverage.isComplete)

        var forgedAttributionObject = try #require(JSONSerialization.jsonObject(
            with: sourceVector.deterministicJSON()
        ) as? [String: Any])
        var forgedMaskingBars = try #require(
            forgedAttributionObject["masking"] as? [[String: Any]]
        )
        var forgedMaskingBar = forgedMaskingBars[0]
        var forgedObservations = try #require(
            forgedMaskingBar["observations"] as? [[String: Any]]
        )
        forgedObservations[0]["firstRole"] = MaskingRole.upper.rawValue
        forgedMaskingBar["observations"] = forgedObservations
        forgedMaskingBars[0] = forgedMaskingBar
        forgedAttributionObject["masking"] = forgedMaskingBars
        let forgedAttribution = try decoder.decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedAttributionObject)
        )
        #expect(!forgedAttribution.isComplete)

        var unsafeObject = try #require(JSONSerialization.jsonObject(
            with: sourceVector.deterministicJSON()
        ) as? [String: Any])
        var unsafeFullMix = try #require(
            unsafeObject["fullMix"] as? [String: Any]
        )
        unsafeFullMix["truePeakEstimate"] = 2.0
        unsafeObject["fullMix"] = unsafeFullMix
        let forgedSafety = try decoder.decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: unsafeObject)
        )
        #expect(!forgedSafety.isComplete)
        #expect(!forgedSafety.hardGatesPassed)

        var forgedGateObject = try #require(JSONSerialization.jsonObject(
            with: sourceVector.deterministicJSON()
        ) as? [String: Any])
        var forgedGates = try #require(
            forgedGateObject["hardGates"] as? [String: Any]
        )
        forgedGates["allSamplesFinite"] = false
        forgedGateObject["hardGates"] = forgedGates
        let forgedGateFailure = try decoder.decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedGateObject)
        )
        #expect(!forgedGateFailure.recordIsStructurallyValid)

        forgedGates["allSamplesFinite"] = true
        forgedGates["blockChannelsAligned"] = false
        forgedGateObject["hardGates"] = forgedGates
        let forgedChannelFailure = try decoder.decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedGateObject)
        )
        #expect(!forgedChannelFailure.recordIsStructurallyValid)

        var impossibleUpperObject = try #require(JSONSerialization.jsonObject(
            with: sourceVector.deterministicJSON()
        ) as? [String: Any])
        var impossibleUpper = try #require(
            impossibleUpperObject["postGraphUpperTimbreEvidence"] as? [String: Any]
        )
        impossibleUpper["rms"] = 1e300
        impossibleUpperObject["postGraphUpperTimbreEvidence"] = impossibleUpper
        let forgedUpperMagnitude = try decoder.decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: impossibleUpperObject)
        )
        #expect(!forgedUpperMagnitude.recordIsStructurallyValid)

        var wrongRateObject = try #require(JSONSerialization.jsonObject(
            with: sourceVector.deterministicJSON()
        ) as? [String: Any])
        var wrongRateUpper = try #require(
            wrongRateObject["preGraphUpperTimbreEvidence"] as? [String: Any]
        )
        wrongRateUpper["sampleRate"] = 44_100.0
        wrongRateObject["preGraphUpperTimbreEvidence"] = wrongRateUpper
        let forgedUpperRate = try decoder.decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: wrongRateObject)
        )
        #expect(!forgedUpperRate.recordIsStructurallyValid)

        var wrongSchemaObject = try #require(JSONSerialization.jsonObject(
            with: sourceVector.deterministicJSON()
        ) as? [String: Any])
        var wrongSchemaUpper = try #require(
            wrongSchemaObject["preGraphUpperTimbreEvidence"] as? [String: Any]
        )
        wrongSchemaUpper["schemaVersion"] =
            UpperTimbreEvidenceAnalyzer.schemaVersion + 1
        wrongSchemaObject["preGraphUpperTimbreEvidence"] = wrongSchemaUpper
        let forgedUpperSchema = try decoder.decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: wrongSchemaObject)
        )
        #expect(!forgedUpperSchema.recordIsStructurallyValid)

        var mismatchedFramesObject = try #require(JSONSerialization.jsonObject(
            with: sourceVector.deterministicJSON()
        ) as? [String: Any])
        var mismatchedFramesUpper = try #require(
            mismatchedFramesObject["preGraphUpperTimbreEvidence"] as? [String: Any]
        )
        mismatchedFramesUpper["analyzedFrameCount"] = 2
        mismatchedFramesObject["preGraphUpperTimbreEvidence"] =
            mismatchedFramesUpper
        let forgedUpperFrames = try decoder.decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: mismatchedFramesObject)
        )
        #expect(!forgedUpperFrames.recordIsStructurallyValid)

        let impossibleStem = AutonomousRoleStemEvidence(
            role: MixRole.atmosphere.rawValue,
            rms: 1e300,
            activeRMS: 1e300,
            onsetRMS: 1e300,
            peak: 1e300,
            crestFactor: 1,
            occupancy: 1,
            bands: MixBand.allCases.map {
                AutonomousStemBandEvidence(band: $0.rawValue, energy: 1e300)
            }
        )
        #expect(!impossibleStem.isComplete)

        let impossibleGraph = AutonomousGraphEvidence(
            graphFingerprint: "impossible-graph",
            revision: 1,
            nodeCount: 3,
            branchCount: 3,
            maximumDepth: 2,
            lowEndProtected: true,
            protectedRoutingValid: true,
            validationValid: true,
            sourceViolationCount: 0,
            violations: [],
            mutationKind: DSPGraphMutationKind.insert.rawValue,
            mutatedNodeCount: 2
        )
        #expect(!impossibleGraph.isComplete)
        let unknownMutationGraph = AutonomousGraphEvidence(
            graphFingerprint: "unknown-mutation-graph",
            revision: 1,
            nodeCount: 4,
            branchCount: 2,
            maximumDepth: 2,
            lowEndProtected: true,
            protectedRoutingValid: true,
            validationValid: true,
            sourceViolationCount: 0,
            violations: [],
            mutationKind: "forged-kind",
            mutatedNodeCount: 0
        )
        #expect(!unknownMutationGraph.isComplete)
        #expect(!AutonomousCandidatePlanFingerprints(
            primary: "same-plan",
            alternate: "same-plan",
            fallback: "fallback-plan"
        ).isComplete)
    }

    @Test("Failed candidate evidence remains structurally retainable")
    func failedAttemptIsRetainable() {
        let vector = fixtureVector(slot: .alternate, nonFinite: true)
        let attempt = AutonomousCandidateAttempt(
            kind: .initialRender,
            reasonCodes: [.evidenceNonFiniteV1, .hardGateFailedV1, .evidenceNonFiniteV1],
            vector: vector
        )

        #expect(!vector.isFinite)
        #expect(!vector.hardGatesPassed)
        #expect(attempt.isStructurallyComplete)
        #expect(!attempt.evidenceComplete)
        #expect(attempt.reasonCodes.map(\.rawValue) == [
            QualityReasonCode.evidenceNonFiniteV1.rawValue,
            QualityReasonCode.hardGateFailedV1.rawValue,
        ].sorted())
    }

    @Test("Reports preserve a non-finite rejected attempt beside a finite fallback")
    func rejectedAttemptReportRoundTrip() throws {
        let rejected = AutonomousCandidateAttempt(
            kind: .initialRender,
            reasonCodes: [.evidenceNonFiniteV1, .hardGateFailedV1],
            vector: fixtureVector(slot: .primary, nonFinite: true)
        )
        let rejectedAlternate = AutonomousCandidateAttempt(
            kind: .initialRender,
            reasonCodes: [.evidenceNonFiniteV1, .hardGateFailedV1],
            vector: fixtureVector(slot: .alternate, nonFinite: true)
        )
        let fallback = AutonomousCandidateAttempt(
            kind: .initialRender,
            forceSafeGraph: true,
            reasonCodes: [],
            vector: fixtureVector(slot: .fallback)
        )
        let transaction = AutonomousCandidateEvaluationTransaction(
            engineVersion: QualityQualificationContract.engineVersion,
            policyVersion: QualityQualificationContract.uncalibratedPolicyVersion,
            evaluatorVersion: QualityQualificationContract.uncalibratedEvaluatorVersion,
            planFingerprints: fixturePlanFingerprints,
            attempts: [rejected, rejectedAlternate, fallback],
            selectedAttemptIndex: 2,
            selectedSlot: .fallback,
            comparison: .unavailable,
            correctionCount: 0
        )
        #expect(transaction.isComplete)

        let report = try CanonicalJourneyQualificationReport(
            engineVersion: QualityQualificationContract.engineVersion,
            fixtureFingerprint: "fixture-non-finite-rejected",
            continuationFingerprint: "continuation-non-finite-rejected",
            checkpoint: .establishment,
            routeFingerprint: fallback.vector.routeContinuation.routeFingerprint,
            routeGeneration: 0,
            selectedCandidateEvidence: fallback.vector,
            candidateEvaluation: transaction,
            sampleHash: fallback.vector.fullMix.sampleHash,
            usedFallback: true
        )
        let json = try report.deterministicJSON()
        #expect(String(decoding: json, as: UTF8.self).contains("NaN"))
        let decoded = try CanonicalJourneyQualificationReport
            .decodeDeterministicJSON(json)
        #expect(try decoded.deterministicJSON() == json)
        #expect(decoded.selectedCandidateEvidence == report.selectedCandidateEvidence)
        #expect(decoded.commitProvenance == report.commitProvenance)
        #expect(decoded.candidateEvaluation.attempts.count == 3)
        #expect(decoded.reasonCodes.contains(.conservativeFallbackV1))
    }

    @Test("Transactions retain three candidates and one correction only")
    func boundedTransaction() throws {
        let primary = AutonomousCandidateAttempt(
            kind: .initialRender,
            reasonCodes: [],
            vector: fixtureVector(slot: .primary)
        )
        let failedPrimary = AutonomousCandidateAttempt(
            kind: .initialRender,
            reasonCodes: [.evidenceNonFiniteV1, .hardGateFailedV1],
            vector: fixtureVector(slot: .primary, nonFinite: true)
        )
        let alternate = AutonomousCandidateAttempt(
            kind: .initialRender,
            reasonCodes: [.evidenceNonFiniteV1, .hardGateFailedV1],
            vector: fixtureVector(slot: .alternate, nonFinite: true)
        )
        let fallback = AutonomousCandidateAttempt(
            kind: .initialRender,
            forceSafeGraph: true,
            reasonCodes: [],
            vector: fixtureVector(slot: .fallback)
        )
        let correction = AutonomousCandidateAttempt(
            kind: .correctionRender,
            forceHomeUpperTimbre: true,
            reasonCodes: [],
            vector: fixtureVector(slot: .primary)
        )
        let failedCorrection = AutonomousCandidateAttempt(
            kind: .correctionRender,
            forceHomeUpperTimbre: true,
            reasonCodes: [.evidenceNonFiniteV1, .hardGateFailedV1],
            vector: fixtureVector(slot: .primary, nonFinite: true)
        )
        let plans = fixturePlanFingerprints
        let transaction = AutonomousCandidateEvaluationTransaction(
            engineVersion: "engine.test.v1",
            policyVersion: "policy.test.v1",
            evaluatorVersion: "evaluator.test.v1",
            planFingerprints: plans,
            attempts: [failedPrimary, alternate, failedCorrection, fallback],
            selectedAttemptIndex: 3,
            selectedSlot: .fallback,
            comparison: .primary,
            correctionCount: 1
        )

        #expect(transaction.isComplete)
        #expect(transaction.attempts.count == 4)
        #expect(transaction.correctionCount == 1)
        #expect(transaction.attempts[1].evidenceComplete == false)
        #expect(transaction.attempts[2].forceHomeUpperTimbre)
        #expect(transaction.attempts[3].forceSafeGraph)
        #expect(transaction.planFingerprints == plans)
        #expect(transaction.fingerprint == transaction.fingerprint)
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "+Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        let decoded = try decoder.decode(
            AutonomousCandidateEvaluationTransaction.self,
            from: transaction.deterministicJSON()
        )
        #expect(try decoded.deterministicJSON() == transaction.deterministicJSON())

        let correctionTransaction = AutonomousCandidateEvaluationTransaction(
            engineVersion: "engine.test.v1",
            policyVersion: "policy.test.v1",
            evaluatorVersion: "evaluator.test.v1",
            planFingerprints: plans,
            attempts: [primary, correction],
            selectedAttemptIndex: 1,
            selectedSlot: .primary,
            comparison: .unavailable,
            correctionCount: 1
        )
        #expect(!correctionTransaction.isComplete)
        var forgedObject = try #require(JSONSerialization.jsonObject(
            with: correctionTransaction.deterministicJSON()
        ) as? [String: Any])
        var forgedAttempts = try #require(forgedObject["attempts"] as? [[String: Any]])
        forgedAttempts.append(forgedAttempts[1])
        forgedObject["attempts"] = forgedAttempts
        forgedObject["sourceAttemptCount"] = 3
        forgedObject["correctionCount"] = 2
        forgedObject["boundsValid"] = true
        let forged = try decoder.decode(
            AutonomousCandidateEvaluationTransaction.self,
            from: JSONSerialization.data(withJSONObject: forgedObject)
        )
        #expect(!forged.isComplete)

        let paired = AutonomousCandidateEvaluationTransaction(
            engineVersion: "engine.test.v1",
            policyVersion: "policy.test.v1",
            evaluatorVersion: "evaluator.test.v1",
            planFingerprints: plans,
            attempts: [primary, alternate],
            selectedAttemptIndex: 0,
            selectedSlot: .primary,
            comparison: .primary,
            correctionCount: 0
        )
        #expect(paired.isComplete)

        let impossibleFallback = AutonomousCandidateEvaluationTransaction(
            engineVersion: "engine.test.v1",
            policyVersion: "policy.test.v1",
            evaluatorVersion: "evaluator.test.v1",
            planFingerprints: plans,
            attempts: [primary, alternate, fallback],
            selectedAttemptIndex: 2,
            selectedSlot: .fallback,
            comparison: .primary,
            correctionCount: 0
        )
        #expect(!impossibleFallback.isComplete)
        var crossRouteObject = try #require(JSONSerialization.jsonObject(
            with: paired.deterministicJSON()
        ) as? [String: Any])
        var crossRouteAttempts = try #require(
            crossRouteObject["attempts"] as? [[String: Any]]
        )
        var alternateAttempt = crossRouteAttempts[1]
        var alternateVector = try #require(
            alternateAttempt["vector"] as? [String: Any]
        )
        var alternateRoute = try #require(
            alternateVector["routeContinuation"] as? [String: Any]
        )
        alternateRoute["sampleRate"] = 48_000.0
        alternateRoute["routeGeneration"] = 1
        alternateRoute["routeFingerprint"] = AutonomousCandidateFingerprint.route(
            sampleRate: 48_000,
            generation: 1
        )
        alternateRoute["incomingContinuationFingerprint"] = "different-incoming"
        alternateVector["routeContinuation"] = alternateRoute
        alternateAttempt["vector"] = alternateVector
        crossRouteAttempts[1] = alternateAttempt
        crossRouteObject["attempts"] = crossRouteAttempts
        let crossRoute = try decoder.decode(
            AutonomousCandidateEvaluationTransaction.self,
            from: JSONSerialization.data(withJSONObject: crossRouteObject)
        )
        #expect(!crossRoute.isComplete)

        let overbound = AutonomousCandidateEvaluationTransaction(
            engineVersion: "engine.test.v1",
            policyVersion: "policy.test.v1",
            evaluatorVersion: "evaluator.test.v1",
            planFingerprints: plans,
            attempts: [primary, alternate, correction, fallback, correction],
            selectedAttemptIndex: 3,
            selectedSlot: .primary,
            comparison: .primary,
            correctionCount: 2
        )
        #expect(overbound.sourceAttemptCount == 5)
        #expect(overbound.attempts.count == 4)
        #expect(overbound.correctionCount == 1)
        #expect(!overbound.boundsValid)
        #expect(!overbound.isComplete)

        let correctionOnly = AutonomousCandidateEvaluationTransaction(
            engineVersion: "engine.test.v1",
            policyVersion: "policy.test.v1",
            evaluatorVersion: "evaluator.test.v1",
            planFingerprints: plans,
            attempts: [correction],
            selectedAttemptIndex: 0,
            selectedSlot: .primary,
            comparison: .unavailable,
            correctionCount: 1
        )
        #expect(!correctionOnly.isComplete)

        let correctionBeforeInitial = AutonomousCandidateEvaluationTransaction(
            engineVersion: "engine.test.v1",
            policyVersion: "policy.test.v1",
            evaluatorVersion: "evaluator.test.v1",
            planFingerprints: plans,
            attempts: [correction, primary],
            selectedAttemptIndex: 0,
            selectedSlot: .primary,
            comparison: .unavailable,
            correctionCount: 1
        )
        #expect(!correctionBeforeInitial.isComplete)

        let correctionAfterFallback = AutonomousCandidateEvaluationTransaction(
            engineVersion: "engine.test.v1",
            policyVersion: "policy.test.v1",
            evaluatorVersion: "evaluator.test.v1",
            planFingerprints: plans,
            attempts: [primary, alternate, fallback, correction],
            selectedAttemptIndex: 3,
            selectedSlot: .primary,
            comparison: .primary,
            correctionCount: 1
        )
        #expect(!correctionAfterFallback.isComplete)
    }

    @Test("Uncalibrated replay rejects paired and correction histories it cannot emit")
    func uncalibratedHistoryReplay() throws {
        let primaryVector = fixtureVector(slot: .primary)
        let alternateVector = fixtureVector(slot: .alternate)
        let primary = AutonomousCandidateAttempt(
            kind: .initialRender,
            reasonCodes: [],
            vector: primaryVector
        )
        let alternate = AutonomousCandidateAttempt(
            kind: .initialRender,
            reasonCodes: [],
            vector: alternateVector
        )
        let unnecessaryPair = AutonomousCandidateEvaluationTransaction(
            engineVersion: QualityQualificationContract.engineVersion,
            policyVersion: QualityQualificationContract.uncalibratedPolicyVersion,
            evaluatorVersion: QualityQualificationContract.uncalibratedEvaluatorVersion,
            planFingerprints: fixturePlanFingerprints,
            attempts: [primary, alternate],
            selectedAttemptIndex: 0,
            selectedSlot: .primary,
            comparison: .unavailable,
            correctionCount: 0
        )
        #expect(!unnecessaryPair.isComplete)

        var object = try #require(JSONSerialization.jsonObject(
            with: primaryVector.deterministicJSON()
        ) as? [String: Any])
        var hardGates = try #require(object["hardGates"] as? [String: Any])
        hardGates["upperTimbreFinite"] = false
        object["hardGates"] = hardGates
        var postGraph = try #require(
            object["postGraphUpperTimbreEvidence"] as? [String: Any]
        )
        postGraph["finite"] = false
        object["postGraphUpperTimbreEvidence"] = postGraph
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "+Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        let repairableVector = try decoder.decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        let repairablePrimary = AutonomousCandidateAttempt(
            kind: .initialRender,
            reasonCodes: [.evidenceNonFiniteV1, .hardGateFailedV1],
            vector: repairableVector
        )
        let correction = AutonomousCandidateAttempt(
            kind: .correctionRender,
            forceHomeUpperTimbre: true,
            reasonCodes: [],
            vector: primaryVector
        )
        let impossibleCorrection = AutonomousCandidateEvaluationTransaction(
            engineVersion: QualityQualificationContract.engineVersion,
            policyVersion: QualityQualificationContract.uncalibratedPolicyVersion,
            evaluatorVersion: QualityQualificationContract.uncalibratedEvaluatorVersion,
            planFingerprints: fixturePlanFingerprints,
            attempts: [repairablePrimary, alternate, correction],
            selectedAttemptIndex: 2,
            selectedSlot: .primary,
            comparison: .unavailable,
            correctionCount: 1
        )
        #expect(!impossibleCorrection.isComplete)
    }

    @Test("Rejected signed upper evidence still has a total deterministic fingerprint")
    func malformedUpperFingerprintIsTotal() throws {
        let source = UpperTimbreEvidenceAnalyzer.analyze(UpperTimbreAnalysisInput(
            left: [0, 0],
            right: [0, 0],
            sampleRate: 8_000
        ))
        let encoder = JSONEncoder()
        var object = try #require(JSONSerialization.jsonObject(
            with: encoder.encode(source)
        ) as? [String: Any])
        object["analyzedFrameCount"] = -1
        object["accentedOnsetCount"] = -2
        object["slideWindowCount"] = -3
        let malformed = try JSONDecoder().decode(
            UpperTimbreEvidence.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(malformed.fingerprint == malformed.fingerprint)
        #expect(malformed.fingerprint.count == 16)
    }

    @Test("Plan, graph, route, and every continuation owner move exact fingerprints")
    func exactStateFingerprints() {
        let director = AutonomousSessionDirector(rootSeed: 42)
        let state = director.initialState()
        let candidates = director.candidates(from: state)
        let replay = director.candidates(from: state)
        #expect(AutonomousCandidateFingerprint.plan(candidates.primary) ==
                AutonomousCandidateFingerprint.plan(replay.primary))
        #expect(AutonomousCandidateFingerprint.plan(candidates.primary) !=
                AutonomousCandidateFingerprint.plan(candidates.alternate))
        #expect(AutonomousCandidatePlanFingerprints.make(candidates: candidates).isComplete)

        let graph42 = DSPGraphGenerator.safePlan(sessionSeed: 42)
        let graph43 = DSPGraphGenerator.safePlan(sessionSeed: 43)
        #expect(AutonomousCandidateFingerprint.graph(graph42) !=
                AutonomousCandidateFingerprint.graph(graph43))
        #expect(AutonomousCandidateFingerprint.route(sampleRate: 44_100, generation: 0) !=
                AutonomousCandidateFingerprint.route(sampleRate: 48_000, generation: 0))
        #expect(AutonomousCandidateFingerprint.route(sampleRate: 48_000, generation: 0) !=
                AutonomousCandidateFingerprint.route(sampleRate: 48_000, generation: 1))

        let emptyRenderState = RenderState()
        var positiveZeroRenderState = RenderState()
        positiveZeroRenderState.delayBuffer = [0]
        var negativeZeroRenderState = RenderState()
        negativeZeroRenderState.delayBuffer = [-0.0]
        #expect(AutonomousCandidateFingerprint.renderState(emptyRenderState) !=
                AutonomousCandidateFingerprint.renderState(positiveZeroRenderState))
        #expect(AutonomousCandidateFingerprint.renderState(positiveZeroRenderState) !=
                AutonomousCandidateFingerprint.renderState(negativeZeroRenderState))

        var orderedGraphState = GeneratedDSPContinuationState()
        orderedGraphState.nodeStates[2] = DSPGraphNodeState()
        orderedGraphState.nodeStates[1] = DSPGraphNodeState()
        var reverseGraphState = GeneratedDSPContinuationState()
        reverseGraphState.nodeStates[1] = DSPGraphNodeState()
        reverseGraphState.nodeStates[2] = DSPGraphNodeState()
        #expect(AutonomousCandidateFingerprint.generatedDSPState(orderedGraphState) ==
                AutonomousCandidateFingerprint.generatedDSPState(reverseGraphState))
        reverseGraphState.splitLowLeft = 0.25
        #expect(AutonomousCandidateFingerprint.generatedDSPState(orderedGraphState) !=
                AutonomousCandidateFingerprint.generatedDSPState(reverseGraphState))

        let initialQuality = QualityContinuationState()
        let advancedQuality = QualityContinuationState(revision: 1)
        #expect(AutonomousCandidateFingerprint.qualityState(initialQuality) !=
                AutonomousCandidateFingerprint.qualityState(advancedQuality))
        let incoming = AutonomousCandidateContinuationFingerprint.make(
            renderState: emptyRenderState,
            generatedDSPState: orderedGraphState,
            qualityState: initialQuality,
            topologyRevision: 0,
            previousGraphFingerprint: "none",
            routeRecovery: false
        )
        let outgoing = AutonomousCandidateContinuationFingerprint.make(
            renderState: positiveZeroRenderState,
            generatedDSPState: orderedGraphState,
            qualityState: initialQuality,
            topologyRevision: 0,
            previousGraphFingerprint: "none",
            routeRecovery: false
        )
        #expect(incoming.renderState != outgoing.renderState)
        #expect(incoming.combined != outgoing.combined)

        let outgoingRenderDSP = AutonomousCandidateFingerprint.renderDSPContinuation(
            renderState: positiveZeroRenderState,
            generatedDSPState: orderedGraphState
        )
        let sameOutgoingWithAdvancedQuality =
            AutonomousCandidateFingerprint.renderDSPContinuation(
                renderState: positiveZeroRenderState,
                generatedDSPState: orderedGraphState
            )
        #expect(outgoingRenderDSP == sameOutgoingWithAdvancedQuality)
        let initialCommit = AutonomousPreparedCommitProvenance(
            candidateEvaluationFingerprint: "transaction",
            selectedSampleHash: "sample",
            outgoingRenderDSPFingerprint: outgoingRenderDSP,
            qualityState: initialQuality
        )
        let advancedCommit = AutonomousPreparedCommitProvenance(
            candidateEvaluationFingerprint: "transaction",
            selectedSampleHash: "sample",
            outgoingRenderDSPFingerprint: outgoingRenderDSP,
            qualityState: advancedQuality
        )
        #expect(initialCommit.isInternallyConsistent)
        #expect(advancedCommit.isInternallyConsistent)
        #expect(initialCommit.outgoingQualityStateFingerprint !=
                advancedCommit.outgoingQualityStateFingerprint)
        #expect(initialCommit.fingerprint != advancedCommit.fingerprint)

        #expect(AutonomousCandidateFingerprint.plan(candidates.primary) ==
                "652053b3212f9dad")
        #expect(AutonomousCandidateFingerprint.graph(graph42) ==
                "011f35a0373a1e23")
        #expect(AutonomousCandidateFingerprint.renderState(emptyRenderState) ==
                "3fc1f96e4d6614b0")
        #expect(AutonomousCandidateFingerprint.generatedDSPState(orderedGraphState) ==
                "ab9b24221ea4baa5")
        #expect(AutonomousCandidateFingerprint.qualityState(initialQuality) ==
                "e176e5a043fe0a6f")
        #expect(AutonomousCandidateFingerprint.route(
            sampleRate: 48_000,
            generation: 7
        ) == "dbc523a48a82ad69")
        #expect(AutonomousCandidateFingerprint.renderDSPContinuation(
            renderState: positiveZeroRenderState,
            generatedDSPState: orderedGraphState
        ) == "9ec3acd2fbc147d5")
    }

    private var fixturePlanFingerprints: AutonomousCandidatePlanFingerprints {
        AutonomousCandidatePlanFingerprints(
            primary: "plan-primary",
            alternate: "plan-alternate",
            fallback: "plan-fallback"
        )
    }

    private func fixtureVector(
        slot: AutonomousCandidateSlot,
        maskingSourceCount: Int = 12,
        maskingObservationCount: Int = 12,
        stemSourceRoleCount: Int = 5,
        stemRoleCount: Int = 5,
        planFingerprintOverride: String? = nil,
        groovePulseBar: AutonomousGroovePulseBarEvidence? = nil,
        nonFinite: Bool = false
    ) -> AutonomousCandidateEvaluationVector {
        let planFingerprint = planFingerprintOverride ?? fixturePlanFingerprints[slot]
        let graphFingerprint = "graph-\(slot.rawValue)"
        let movementScore = nonFinite ? Double.nan : 0
        let interest = PhraseInterestReport(
            pulseClarity: 0.8,
            intentionalSpace: 0.7,
            responseClosure: 0.6,
            structuralTimeliness: 0.9,
            identityContinuity: 1,
            weakPositionCoverage: 0.5,
            trailingSideRelationship: 0.4,
            overactivityPenalty: 0.1,
            overdueDebtCount: 0
        )
        let upper = UpperTimbreEvidenceAnalyzer.analyze(UpperTimbreAnalysisInput(
            left: [Float](repeating: 0, count: 64),
            right: [Float](repeating: 0, count: 64),
            sampleRate: 8_000
        ))
        let symbolic = AutonomousSymbolicEvidence(
            planFingerprint: planFingerprint,
            phraseIndex: 0,
            startBar: 0,
            declaredBarCount: 1,
            resolvedBarCount: 1,
            phraseKind: slot == .fallback
                ? AutonomousPhraseKind.identityReturn.rawValue
                : AutonomousPhraseKind.lock.rawValue,
            pulseClarity: 0.8,
            intentionalSpace: 0.7,
            responseClosure: 0.6,
            structuralTimeliness: 0.9,
            identityContinuity: 1,
            weakPositionCoverage: 0.5,
            trailingSideRelationship: 0.4,
            overactivityPenalty: 0.1,
            overdueDebtCount: 0,
            interestScore: interest.score,
            interestValid: interest.valid,
            chapterChanged: false,
            alternate: slot == .alternate,
            conservative: slot == .fallback,
            boundsValid: true
        )
        let hardGates = AutonomousHardGateEvidence(
            symbolicValid: true,
            graphValid: true,
            audioSafetyValid: !nonFinite,
            fullMixFinite: !nonFinite,
            upperTimbreFinite: true,
            blocksPresent: true,
            blockChannelsAligned: true,
            allSamplesFinite: !nonFinite,
            completeInputs: true
        )
        let fullMix = AutonomousFullMixEvidence(
            sourceBarCount: 1,
            analyzedFrameCount: upper.analyzedFrameCount,
            sampleHash: "sample-\(slot.rawValue)",
            peak: 0.5,
            truePeakEstimate: 0.55,
            rms: 0.2,
            loudnessEstimate: -0.691 + 20 * log10(0.2),
            maximumMomentaryLoudness: -0.691 + 20 * log10(0.2),
            maximumShortTermLoudness: -0.691 + 20 * log10(0.2),
            loudnessRange: 0,
            momentaryBlockCount: 1,
            absoluteGatedBlockCount: 1,
            relativeGatedBlockCount: 1,
            shortTermBlockCount: 0,
            dcOffset: 0,
            stereoCorrelation: 1,
            lowStereoCorrelation: 1,
            maximumBoundaryDelta: 0.01,
            movementScore: movementScore,
            bars: [AutonomousBarFullMixEvidence(
                bar: 0,
                loudness: -14,
                spectralCentroid: 800,
                transientDensity: 1.5,
                crestFactor: 5,
                finite: true
            )]
        )
        var maskingObservations = validMaskingObservations
        while maskingObservations.count < maskingObservationCount {
            maskingObservations.append(maskingObservations[0])
        }
        maskingObservations = Array(maskingObservations.prefix(maskingObservationCount))

        var roles = validStemRoles
        while roles.count < stemRoleCount { roles.append(roles[0]) }
        roles = Array(roles.prefix(stemRoleCount))
        let gains = MixRole.allCases.map {
            AutonomousRoleGainEvidence(role: $0.rawValue, gainDB: $0 == .kick ? -1 : 0)
        }
        let graph = AutonomousGraphEvidence(
            graphFingerprint: graphFingerprint,
            revision: 0,
            nodeCount: 4,
            branchCount: 2,
            maximumDepth: 2,
            lowEndProtected: true,
            protectedRoutingValid: true,
            validationValid: true,
            sourceViolationCount: 0,
            violations: [],
            mutationKind: nil,
            mutatedNodeCount: 0
        )
        let route = AutonomousRouteContinuationEvidence(
            sampleRate: 8_000,
            routeGeneration: 0,
            routeFingerprint: AutonomousCandidateFingerprint.route(
                sampleRate: 8_000,
                generation: 0
            ),
            incomingContinuationFingerprint: "incoming",
            incomingQualityStateFingerprint:
                AutonomousCandidateFingerprint.qualityState(
                    QualityContinuationState()
                ),
            incomingKickCorrectionDB: -1,
            incomingTopologyRevision: 0,
            previousGraphFingerprint: "none",
            routeRecovery: false,
            outgoingRenderDSPFingerprint: "outgoing-render-dsp",
            controllerStateFingerprint:
                AutonomousCandidateFingerprint.automaticMixController(
                    kickCorrectionDB: -1
                )
        )
        return AutonomousCandidateEvaluationVector(
            slot: slot,
            planFingerprint: planFingerprint,
            graphFingerprint: graphFingerprint,
            symbolic: symbolic,
            hardGates: hardGates,
            fullMix: fullMix,
            masking: [AutonomousMaskingBarEvidence(
                bar: 0,
                sourceObservationCount: maskingSourceCount,
                observations: maskingObservations
            )],
            stems: [AutonomousStemBarEvidence(
                bar: 0,
                sourceRoleCount: stemSourceRoleCount,
                roles: roles
            )],
            automaticMix: [AutonomousAutomaticMixEvidence(
                bar: 0,
                section: SectionKind.breakdown.rawValue,
                foundationCompanion: FoundationCompanion.bass.rawValue,
                gains: gains,
                measuredKickOverFoundationDB: nil,
                targetKickOverFoundationDB: nil
            )],
            groovePulse: [groovePulseBar ?? AutonomousGroovePulseBarEvidence(
                bar: 0,
                sourceScoreEventCount: 0,
                sourceRenderEventCount: 0,
                events: []
            )],
            graph: graph,
            routeContinuation: route,
            preGraphUpperTimbreEvidence: upper,
            postGraphUpperTimbreEvidence: upper
        )
    }

    private func fixtureGroovePulseEvent(
        step: Int = 3,
        intensity: Double = 0.52,
        strikeZone: GroovePulseStrikeZone = .middle,
        damping: Double = 0.5,
        timbreMicrovariation: Double = 0.02,
        renderedFrameCount: Int = 360,
        sampleHash: String = "0123456789abcdef",
        sourceRMS: Double = 0.012,
        spectralCentroidHz: Double = 2_400,
        tailToAttackDB: Double = -18,
        finite: Bool = true
    ) -> AutonomousGroovePulseEventEvidence {
        AutonomousGroovePulseEventEvidence(
            step: step,
            intensity: intensity,
            strikeZone: strikeZone.rawValue,
            damping: damping,
            timbreMicrovariation: timbreMicrovariation,
            renderedFrameCount: renderedFrameCount,
            sampleHash: sampleHash,
            sourceRMS: sourceRMS,
            spectralCentroidHz: spectralCentroidHz,
            tailToAttackDB: tailToAttackDB,
            finite: finite
        )
    }

    private var validMaskingObservations: [AutonomousMaskingObservationEvidence] {
        let bands: [(String, Double, Double)] = [
            ("sub", 35, 120),
            ("low-mid", 120, 420),
            ("mid", 420, 2_400),
            ("high", 2_400, 10_000),
        ]
        let pairs: [(MaskingRole, MaskingRole)] = [
            (.foundation, .percussion),
            (.foundation, .upper),
            (.percussion, .upper),
        ]
        return pairs.flatMap { first, second in
            bands.map { name, lower, upper in
                AutonomousMaskingObservationEvidence(
                    bandName: name,
                    lowerHz: lower,
                    upperHz: upper,
                    firstRole: first.rawValue,
                    secondRole: second.rawValue,
                    analyzedWindowCount: SpectrumMaskingAnalyzer.analyzedWindowCount,
                    activePairWindowCount: 0,
                    overlapWindowCount: 0,
                    longestOverlapRun: 0,
                    maximumOverlap: 0
                )
            }
        }
    }

    private var validStemRoles: [AutonomousRoleStemEvidence] {
        MixRole.allCases.map { role in
            AutonomousRoleStemEvidence(
                role: role.rawValue,
                rms: 0.1,
                activeRMS: 0.2,
                onsetRMS: 0.3,
                peak: 0.5,
                crestFactor: 5,
                occupancy: 0.25,
                bands: MixBand.allCases.map {
                    AutonomousStemBandEvidence(band: $0.rawValue, energy: 0.1)
                }
            )
        }
    }
}
