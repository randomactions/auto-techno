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

    @Test("Kick syntax evidence binds score, render, silence, and remains selection-neutral")
    func kickSyntaxEvidenceContract() throws {
        let baseline = fixtureVector(slot: .primary)
        let grounded = try #require(baseline.kickSyntax.first)
        let zeroHash = AutonomousKickSyntaxBarEvidence.zeroSampleHash(
            renderedFrameCount: 14_769
        )
        #expect(zeroHash == ExactPCMFingerprint.mono(
            [Float](repeating: 0, count: 14_769)
        ))
        let withheld = fixtureKickSyntax(
            role: .withheld,
            scoreKickEventCount: 0,
            scoreKickStepMask: 0,
            renderedKickEventCount: 0,
            renderedKickStepMask: 0,
            detectorPeak: 0,
            detectorRMS: 0,
            audiblePeak: 0,
            audibleRMS: 0,
            duckingEnvelopePeak: 0,
            detectorSampleHash: zeroHash,
            audibleSampleHash: zeroHash,
            detectorNonzeroSampleCount: 0,
            audibleNonzeroSampleCount: 0
        )

        #expect(grounded.isComplete(sampleRate: 8_000))
        #expect(withheld.isComplete(sampleRate: 8_000))
        #expect(!fixtureKickSyntax(
            scoreKickEventCount: 2,
            scoreKickStepMask: 1,
            renderedKickEventCount: 2,
            renderedKickStepMask: 1
        ).isComplete(sampleRate: 8_000))
        #expect(!fixtureKickSyntax(
            role: .withheld,
            scoreKickEventCount: 0,
            scoreKickStepMask: 0,
            renderedKickEventCount: 0,
            renderedKickStepMask: 0,
            detectorPeak: 0,
            detectorRMS: 0,
            audiblePeak: 0,
            audibleRMS: 0,
            duckingEnvelopePeak: 0,
            detectorSampleHash: "aaaaaaaaaaaaaaaa",
            audibleSampleHash: "aaaaaaaaaaaaaaaa",
            detectorNonzeroSampleCount: 0,
            audibleNonzeroSampleCount: 0
        ).isComplete(sampleRate: 8_000))

        let data = try baseline.deterministicJSON()
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var gainForgedObject = object
        var gainForgedBars = try #require(
            gainForgedObject["kickSyntax"] as? [[String: Any]]
        )
        gainForgedBars[0]["audibleGain"] = 0.8
        gainForgedObject["kickSyntax"] = gainForgedBars
        let gainForged = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: gainForgedObject)
        )
        #expect(!gainForged.isComplete)
        #expect(gainForged.isFinite)
        #expect(gainForged.recordIsStructurallyValid)
        #expect(gainForged.selectionEvidence == baseline.selectionEvidence)

        var roleForgedObject = object
        var roleForgedBars = try #require(
            roleForgedObject["kickSyntax"] as? [[String: Any]]
        )
        roleForgedBars[0]["role"] = KickSyntaxRole.withheld.rawValue
        roleForgedObject["kickSyntax"] = roleForgedBars
        let roleForged = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: roleForgedObject)
        )
        #expect(!roleForged.isComplete)
        #expect(roleForged.recordIsStructurallyValid)
        #expect(roleForged.selectionEvidence == baseline.selectionEvidence)

        var missingObject = object
        missingObject["sourceKickSyntaxBarCount"] = 0
        missingObject["kickSyntax"] = []
        let missing = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: missingObject)
        )
        #expect(!missing.isComplete)
        #expect(missing.isFinite)
        #expect(missing.recordIsStructurallyValid)

        let nonFinite = fixtureVector(
            slot: .primary,
            kickSyntaxBar: fixtureKickSyntax(detectorPeak: .nan)
        )
        #expect(!nonFinite.isComplete)
        #expect(!nonFinite.isFinite)
        #expect(nonFinite.recordIsStructurallyValid)
        #expect(AutonomousCandidateAttempt(
            kind: .initialRender,
            reasonCodes: [
                .evidenceMissingV1, .evidenceNonFiniteV1, .hardGateFailedV1,
            ],
            vector: nonFinite
        ).isStructurallyComplete)

        var oversizedSourceObject = object
        oversizedSourceObject["sourceKickSyntaxBarCount"] = 17
        let oversizedSource = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: oversizedSourceObject)
        )
        #expect(!oversizedSource.isComplete)
        #expect(!oversizedSource.recordIsStructurallyValid)
    }

    @Test("Climax-arc evidence binds dramatic debt to committed kick recovery")
    func climaxArcEvidenceContract() throws {
        let debts = [
            SessionDramaticDebt(
                id: 7, openedAtBar: 64, dueByBar: 192, source: .contrast
            ),
            SessionDramaticDebt(
                id: 8, openedAtBar: 96, dueByBar: 224, source: .majorBreak
            ),
        ]
        let syntax = [
            fixtureKickSyntax(bar: 140, role: .grounded),
            fixtureKickSyntax(bar: 141, role: .withheld),
            fixtureKickSyntax(bar: 142, role: .withheld),
            fixtureKickSyntax(bar: 143, role: .recovery),
        ]
        let evidence = AutonomousClimaxArcEvidence(
            relation: .dramaticDebtRecovery,
            paidDebtCount: 2,
            contrastDebtCount: 1,
            majorBreakDebtCount: 1,
            sourceDebtFingerprint:
                AutonomousClimaxArcEvidence.debtFingerprint(debts),
            earliestOpenedAtBar: 64,
            latestOpenedAtBar: 96,
            latestDueByBar: 224,
            releaseStartBar: 128,
            setupBar: 140,
            firstWithheldBar: 141,
            secondWithheldBar: 142,
            recoveryBar: 143,
            bindingValid: true
        )
        #expect(evidence.recordIsStructurallyValid)
        #expect(evidence.isComplete(
            phraseKind: AutonomousPhraseKind.energyRelease.rawValue,
            conservative: false,
            startBar: 128,
            declaredBarCount: 16,
            kickSyntax: syntax
        ))
        let releaseOnly = AutonomousClimaxArcEvidence(
            relation: .dramaticDebtRelease,
            paidDebtCount: 2,
            contrastDebtCount: 1,
            majorBreakDebtCount: 1,
            sourceDebtFingerprint: evidence.sourceDebtFingerprint,
            earliestOpenedAtBar: 64,
            latestOpenedAtBar: 96,
            latestDueByBar: 224,
            releaseStartBar: 128,
            setupBar: nil,
            firstWithheldBar: nil,
            secondWithheldBar: nil,
            recoveryBar: nil,
            bindingValid: true
        )
        #expect(releaseOnly.isComplete(
            phraseKind: AutonomousPhraseKind.energyRelease.rawValue,
            conservative: false,
            startBar: 128,
            declaredBarCount: 16,
            kickSyntax: (128..<144).map {
                fixtureKickSyntax(bar: $0, role: .grounded)
            }
        ))

        let wrongGeometry = AutonomousClimaxArcEvidence(
            relation: .dramaticDebtRecovery,
            paidDebtCount: 2,
            contrastDebtCount: 1,
            majorBreakDebtCount: 1,
            sourceDebtFingerprint: evidence.sourceDebtFingerprint,
            earliestOpenedAtBar: 64,
            latestOpenedAtBar: 96,
            latestDueByBar: 224,
            releaseStartBar: 128,
            setupBar: 140,
            firstWithheldBar: 141,
            secondWithheldBar: 143,
            recoveryBar: 143,
            bindingValid: true
        )
        #expect(!wrongGeometry.isComplete(
            phraseKind: AutonomousPhraseKind.energyRelease.rawValue,
            conservative: false,
            startBar: 128,
            declaredBarCount: 16,
            kickSyntax: syntax
        ))

        let baseline = fixtureVector(slot: .primary)
        let data = try baseline.deterministicJSON()
        var object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var climax = try #require(object["climaxArc"] as? [String: Any])
        climax["sourceDebtFingerprint"] = "aaaaaaaaaaaaaaaa"
        object["climaxArc"] = climax
        let forged = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(!forged.isComplete)
        #expect(forged.recordIsStructurallyValid)
        #expect(forged.fingerprint != baseline.fingerprint)
        #expect(forged.selectionEvidence == baseline.selectionEvidence)
    }

    @Test("Gated percussion texture evidence is compact, causal, and selection-neutral")
    func percussionEchoTextureEvidenceContract() throws {
        let neutral = fixtureVector(
            slot: .primary,
            phraseKind: .contrast
        )
        let activeRecord = fixturePercussionEchoTexture()
        let active = fixtureVector(
            slot: .primary,
            phraseKind: .contrast,
            percussionEchoTextureBar: activeRecord
        )

        #expect(activeRecord.isComplete(
            sampleRate: 8_000,
            phraseKind: .contrast,
            conservative: false
        ))
        #expect(active.isComplete)
        #expect(active.isFinite)
        #expect(active.fingerprint != neutral.fingerprint)
        #expect(active.selectionEvidence == neutral.selectionEvidence)

        let data = try active.deterministicJSON()
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let bars = try #require(
            object["percussionEchoTexture"] as? [[String: Any]]
        )
        let serialized = try #require(bars.first)
        #expect(Set(serialized.keys) == Set([
            "bar", "performanceCharacter", "arrangementGesture", "active",
            "eligibleSourceStepMask", "inputStep", "outputStartStep",
            "outputEndStep", "renderedFrameCount", "inputWindowFrameCount",
            "outputWindowFrameCount", "delayFrameCount",
            "transitionFrameCount", "inputSampleHash", "returnSampleHash",
            "inputPeak", "inputRMS", "returnPeak", "returnRMS",
            "inputNonzeroSampleCount", "returnNonzeroSampleCount",
            "outOfWindowNonzeroSampleCount", "firstOutputSampleBitPattern",
            "lastOutputSampleBitPattern", "renderPassesMatch", "bindingValid",
            "finite",
        ]))

        var forgedObject = object
        var forgedBars = bars
        forgedBars[0]["outOfWindowNonzeroSampleCount"] = 1
        forgedObject["percussionEchoTexture"] = forgedBars
        let forged = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedObject)
        )
        #expect(!forged.isComplete)
        #expect(forged.isFinite)
        #expect(forged.recordIsStructurallyValid)
        #expect(forged.selectionEvidence == active.selectionEvidence)

        var unboundObject = object
        var unboundBars = bars
        unboundBars[0]["bindingValid"] = false
        unboundObject["percussionEchoTexture"] = unboundBars
        let unbound = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: unboundObject)
        )
        #expect(!unbound.isComplete)
        #expect(unbound.recordIsStructurallyValid)

        var impossibleStepObject = object
        var impossibleStepBars = bars
        impossibleStepBars[0]["inputStep"] = Int.max
        impossibleStepObject["percussionEchoTexture"] = impossibleStepBars
        let impossibleStep = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: impossibleStepObject)
        )
        #expect(!impossibleStep.isComplete)
        #expect(impossibleStep.recordIsStructurallyValid)

        var outOfDomainMaskObject = object
        var outOfDomainMaskBars = bars
        outOfDomainMaskBars[0]["eligibleSourceStepMask"] =
            Int(UInt16(1 << 15) | UInt16(1 << activeRecord.inputStep))
        outOfDomainMaskObject["percussionEchoTexture"] = outOfDomainMaskBars
        let outOfDomainMask = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: outOfDomainMaskObject)
        )
        #expect(!outOfDomainMask.isComplete)
        #expect(outOfDomainMask.recordIsStructurallyValid)

        var oversizedObject = object
        oversizedObject["sourcePercussionEchoTextureBarCount"] = 17
        let oversized = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: oversizedObject)
        )
        #expect(!oversized.isComplete)
        #expect(!oversized.recordIsStructurallyValid)
    }

    @Test("Upper timing evidence is compact, score-bound, and selection-neutral")
    func upperTimingEvidenceContract() throws {
        let neutral = fixtureUpperTiming()
        let active = fixtureUpperTiming(
            bar: 7,
            chapter: .breath,
            sourceScoreNoteCount: 3,
            sourceRenderEventCount: 3,
            anchorEventCount: 1,
            activeOffsetCount: 2,
            minimumOffsetInSteps: 0,
            maximumOffsetInSteps: ResolvedUpperNote.maximumTimingOffsetInSteps,
            maximumRoleSpreadInSteps:
                ResolvedUpperNote.maximumTimingOffsetInSteps,
            scoreFingerprint: "abcdef0123456789",
            renderFingerprint: "abcdef0123456789",
            shadowEventCount: 1,
            shadowHash: "3333333333333333",
            shadowPeak: 0.08,
            shadowRMS: 0.02,
            responseEventCount: 1,
            responseHash: "4444444444444444",
            responsePeak: 0.06,
            responseRMS: 0.015
        )
        let baseline = fixtureVector(
            slot: .primary,
            evidenceBar: 7,
            upperTimingBars: [fixtureUpperTiming(bar: 7)]
        )
        let vector = fixtureVector(
            slot: .primary,
            evidenceBar: 7,
            upperTimingBars: [active]
        )

        #expect(neutral.isFinite)
        #expect(neutral.isComplete(
            routeSampleRate: 8_000,
            phraseKind: .lock,
            conservative: false
        ))
        #expect(active.isFinite)
        #expect(active.isComplete(
            routeSampleRate: 8_000,
            phraseKind: .lock,
            conservative: false
        ))
        let performed = fixtureUpperTiming(
            bar: 7,
            chapter: .home,
            relation: .leadPerformance,
            performanceCharacter: .melodicGlow,
            sourceScoreNoteCount: 3,
            sourceRenderEventCount: 3,
            anchorEventCount: 3,
            activeOffsetCount: 2,
            anchorActiveOffsetCount: 2,
            maximumOffsetInSteps:
                SynthPerformancePlan.maximumLeadPerformanceOffsetInSteps,
            maximumRoleSpreadInSteps:
                SynthPerformancePlan.maximumLeadPerformanceOffsetInSteps,
            anchorMaximumOffsetInSteps:
                SynthPerformancePlan.maximumLeadPerformanceOffsetInSteps
        )
        #expect(performed.isComplete(
            routeSampleRate: 8_000,
            phraseKind: .lock,
            conservative: false
        ))
        #expect(performed.normalTimingEligibility(
            phraseKind: .lock,
            conservative: false
        ))
        #expect(!fixtureUpperTiming(
            bar: 7,
            chapter: .home,
            relation: .leadPerformance,
            performanceCharacter: .hypnoticLock,
            sourceScoreNoteCount: 3,
            sourceRenderEventCount: 3,
            anchorEventCount: 3,
            activeOffsetCount: 2,
            anchorActiveOffsetCount: 2,
            maximumOffsetInSteps:
                SynthPerformancePlan.maximumLeadPerformanceOffsetInSteps,
            maximumRoleSpreadInSteps:
                SynthPerformancePlan.maximumLeadPerformanceOffsetInSteps,
            anchorMaximumOffsetInSteps:
                SynthPerformancePlan.maximumLeadPerformanceOffsetInSteps
        ).isComplete(
            routeSampleRate: 8_000,
            phraseKind: .lock,
            conservative: false
        ))
        #expect(!fixtureUpperTiming(
            bar: 7,
            chapter: .breath,
            sourceScoreNoteCount: 3,
            sourceRenderEventCount: 3,
            anchorEventCount: 1,
            activeOffsetCount: 2,
            protectedRoleActiveOffsetCount: 1,
            maximumOffsetInSteps: ResolvedUpperNote.maximumTimingOffsetInSteps,
            maximumRoleSpreadInSteps:
                ResolvedUpperNote.maximumTimingOffsetInSteps,
            shadowEventCount: 1,
            shadowPeak: 0.04,
            shadowRMS: 0.01,
            responseEventCount: 1,
            responsePeak: 0.05,
            responseRMS: 0.012
        ).isComplete(
            routeSampleRate: 8_000,
            phraseKind: .lock,
            conservative: false
        ))
        for bar in [1, 7, 8, 14] {
            let expectedDepth = ResolvedUpperNote.maximumTimingOffsetInSteps *
                SynthPerformancePlan.upperTimingAperture(absoluteBar: bar)
            let replay = fixtureUpperTiming(
                bar: bar,
                chapter: .breath,
                sourceScoreNoteCount: 3,
                sourceRenderEventCount: 3,
                anchorEventCount: 1,
                activeOffsetCount: 2,
                maximumOffsetInSteps: expectedDepth,
                maximumRoleSpreadInSteps: expectedDepth,
                shadowEventCount: 1,
                shadowPeak: 0.04,
                shadowRMS: 0.01,
                responseEventCount: 1,
                responsePeak: 0.05,
                responseRMS: 0.012
            )
            #expect(replay.isComplete(
                routeSampleRate: 8_000,
                phraseKind: .lock,
                conservative: false
            ))
        }
        for bar in [0, 15] {
            let endpoint = fixtureUpperTiming(
                bar: bar,
                chapter: .breath,
                sourceScoreNoteCount: 3,
                sourceRenderEventCount: 3,
                anchorEventCount: 1,
                shadowEventCount: 1,
                shadowPeak: 0.04,
                shadowRMS: 0.01,
                responseEventCount: 1,
                responsePeak: 0.05,
                responseRMS: 0.012
            )
            #expect(endpoint.isComplete(
                routeSampleRate: 8_000,
                phraseKind: .lock,
                conservative: false
            ))
        }
        #expect(!fixtureUpperTiming(
            bar: 7,
            chapter: .breath,
            sourceScoreNoteCount: 2,
            sourceRenderEventCount: 2,
            anchorEventCount: 0,
            activeOffsetCount: 2,
            maximumOffsetInSteps: ResolvedUpperNote.maximumTimingOffsetInSteps,
            maximumRoleSpreadInSteps:
                ResolvedUpperNote.maximumTimingOffsetInSteps,
            shadowEventCount: 1,
            shadowPeak: 0.04,
            shadowRMS: 0.01,
            responseEventCount: 1,
            responsePeak: 0.05,
            responseRMS: 0.012
        ).isComplete(
            routeSampleRate: 8_000,
            phraseKind: .lock,
            conservative: false
        ))
        #expect(!fixtureUpperTiming(
            sourceScoreNoteCount:
                AutonomousCandidateEvaluationVector.maximumUpperTimingEventsPerBar + 1,
            sourceRenderEventCount:
                AutonomousCandidateEvaluationVector.maximumUpperTimingEventsPerBar + 1
        ).isComplete(
            routeSampleRate: 8_000,
            phraseKind: .lock,
            conservative: false
        ))
        #expect(vector.isComplete)
        #expect(vector.isFinite)
        #expect(vector.fingerprint != baseline.fingerprint)
        #expect(vector.selectionEvidence == baseline.selectionEvidence)
        #expect(AutonomousCandidateAttempt(
            kind: .initialRender,
            vector: vector
        ).isStructurallyComplete)
        let chapterMismatch = fixtureVector(
            slot: .primary,
            evidenceBar: 7,
            pulseEchoDriveBars: [fixturePulseEchoDrive(
                bar: 7,
                interlockChapter: .home
            )],
            upperTimingBars: [fixtureUpperTiming(bar: 7, chapter: .tone)]
        )
        #expect(!chapterMismatch.isComplete)

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
        let timingBars = try #require(object["upperTiming"] as? [[String: Any]])
        let serialized = try #require(timingBars.first)
        #expect(Set(serialized.keys) == Set([
            "bar", "chapter", "relation", "performanceCharacter", "bpm",
            "sampleRate", "renderedFrameCount",
            "sourceScoreNoteCount", "sourceRenderEventCount", "anchorEventCount",
            "activeOffsetCount", "protectedRoleActiveOffsetCount",
            "anchorActiveOffsetCount",
            "minimumOffsetInSteps", "maximumOffsetInSteps",
            "maximumRoleSpreadInSteps", "anchorMinimumOffsetInSteps",
            "anchorMaximumOffsetInSteps", "anchorOffsetPatternFingerprint",
            "shadowMinimumOffsetInSteps",
            "shadowMaximumOffsetInSteps", "responseMinimumOffsetInSteps",
            "responseMaximumOffsetInSteps", "scoreFingerprint", "renderFingerprint",
            "appliedGateFingerprint", "anchorSignal", "shadowSignal", "responseSignal",
            "bindingValid", "finite",
        ]))
        #expect(serialized["events"] == nil)

        var forgedObject = object
        var forgedBars = timingBars
        var forgedBar = serialized
        forgedBar["renderFingerprint"] = "9999999999999999"
        forgedBars[0] = forgedBar
        forgedObject["upperTiming"] = forgedBars
        let forgedVector = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedObject)
        )
        #expect(!forgedVector.isComplete)
        #expect(forgedVector.isFinite)
        #expect(forgedVector.recordIsStructurallyValid)
        #expect(forgedVector.fingerprint != vector.fingerprint)
        let rejectedAttempt = AutonomousCandidateAttempt(
            kind: .initialRender,
            reasonCodes: [.evidenceMissingV1, .hardGateFailedV1],
            vector: forgedVector
        )
        #expect(rejectedAttempt.isStructurallyComplete)

        var malformedGateObject = object
        var malformedGateBars = timingBars
        var malformedGateBar = serialized
        malformedGateBar["appliedGateFingerprint"] = "malformed"
        malformedGateBars[0] = malformedGateBar
        malformedGateObject["upperTiming"] = malformedGateBars
        let malformedGateVector = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: malformedGateObject)
        )
        #expect(!malformedGateVector.isComplete)
        #expect(malformedGateVector.fingerprint != vector.fingerprint)

        var changedGateObject = object
        var changedGateBars = timingBars
        var changedGateBar = serialized
        changedGateBar["appliedGateFingerprint"] = "fedcba9876543210"
        changedGateBars[0] = changedGateBar
        changedGateObject["upperTiming"] = changedGateBars
        let changedGateVector = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: changedGateObject)
        )
        #expect(changedGateVector.isComplete)
        #expect(changedGateVector.fingerprint != vector.fingerprint)

        var changedAnchorPatternObject = object
        var changedAnchorPatternBars = timingBars
        var changedAnchorPatternBar = serialized
        changedAnchorPatternBar["anchorOffsetPatternFingerprint"] =
            AutonomousUpperTimingBarEvidence.offsetPatternFingerprint([0.018])
        changedAnchorPatternBars[0] = changedAnchorPatternBar
        changedAnchorPatternObject["upperTiming"] = changedAnchorPatternBars
        let changedAnchorPatternVector = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: changedAnchorPatternObject)
        )
        #expect(!changedAnchorPatternVector.isComplete)
        #expect(changedAnchorPatternVector.fingerprint != vector.fingerprint)

        var oversizedCountObject = object
        var oversizedCountBars = timingBars
        var oversizedCountBar = serialized
        var oversizedShadow = try #require(
            oversizedCountBar["shadowSignal"] as? [String: Any]
        )
        oversizedShadow["eventCount"] = Int.max
        oversizedCountBar["shadowSignal"] = oversizedShadow
        oversizedCountBars[0] = oversizedCountBar
        oversizedCountObject["upperTiming"] = oversizedCountBars
        let oversizedCountVector = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: oversizedCountObject)
        )
        #expect(!oversizedCountVector.isComplete)
        #expect(!AutonomousCandidateAttempt(
            kind: .initialRender,
            reasonCodes: [.evidenceMissingV1, .hardGateFailedV1],
            vector: oversizedCountVector
        ).isStructurallyComplete)

        var anchorForgedObject = object
        var anchorForgedBars = timingBars
        var anchorForgedBar = serialized
        anchorForgedBar["anchorEventCount"] = 0
        anchorForgedBars[0] = anchorForgedBar
        anchorForgedObject["upperTiming"] = anchorForgedBars
        let anchorForgedVector = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: anchorForgedObject)
        )
        #expect(!anchorForgedVector.isComplete)
        #expect(anchorForgedVector.fingerprint != vector.fingerprint)

        var roleOffsetForgedObject = object
        var roleOffsetForgedBars = timingBars
        var roleOffsetForgedBar = serialized
        roleOffsetForgedBar["shadowMaximumOffsetInSteps"] =
            ResolvedUpperNote.maximumTimingOffsetInSteps
        roleOffsetForgedBars[0] = roleOffsetForgedBar
        roleOffsetForgedObject["upperTiming"] = roleOffsetForgedBars
        let roleOffsetForgedVector = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: roleOffsetForgedObject)
        )
        #expect(!roleOffsetForgedVector.isComplete)
        #expect(roleOffsetForgedVector.fingerprint != vector.fingerprint)

        var responseOffsetForgedObject = object
        var responseOffsetForgedBars = timingBars
        var responseOffsetForgedBar = serialized
        responseOffsetForgedBar["responseMinimumOffsetInSteps"] =
            ResolvedUpperNote.maximumTimingOffsetInSteps * 0.5
        responseOffsetForgedBars[0] = responseOffsetForgedBar
        responseOffsetForgedObject["upperTiming"] = responseOffsetForgedBars
        let responseOffsetForgedVector = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: responseOffsetForgedObject)
        )
        #expect(!responseOffsetForgedVector.isComplete)
        #expect(responseOffsetForgedVector.fingerprint != vector.fingerprint)

        var protectedRoleForgedObject = object
        var protectedRoleForgedBars = timingBars
        var protectedRoleForgedBar = serialized
        protectedRoleForgedBar["protectedRoleActiveOffsetCount"] = 1
        protectedRoleForgedBars[0] = protectedRoleForgedBar
        protectedRoleForgedObject["upperTiming"] = protectedRoleForgedBars
        let protectedRoleForgedVector = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: protectedRoleForgedObject)
        )
        #expect(!protectedRoleForgedVector.isComplete)
        #expect(protectedRoleForgedVector.fingerprint != vector.fingerprint)

        let excessiveBars = (0..<17).map { fixtureUpperTiming(bar: $0) }
        let constructorBounded = fixtureVector(
            slot: .primary,
            upperTimingBars: excessiveBars
        )
        #expect(constructorBounded.sourceUpperTimingBarCount == 17)
        #expect(constructorBounded.upperTiming.count ==
                AutonomousCandidateEvaluationVector.maximumBarCount)
        #expect(!constructorBounded.recordIsStructurallyValid)

        var oversizedObject = object
        oversizedObject["sourceUpperTimingBarCount"] = 17
        oversizedObject["upperTiming"] = (0..<17).map { bar -> [String: Any] in
            var copy = serialized
            copy["bar"] = bar
            return copy
        }
        let oversizedVector = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: oversizedObject)
        )
        #expect(oversizedVector.upperTiming.count == 17)
        #expect(!oversizedVector.recordIsStructurallyValid)

        #expect(!fixtureUpperTiming(
            bar: 7,
            chapter: .breath,
            sourceScoreNoteCount: 2,
            sourceRenderEventCount: 2,
            anchorEventCount: 1,
            activeOffsetCount: 1,
            minimumOffsetInSteps: -0.01,
            maximumOffsetInSteps: 0.06,
            maximumRoleSpreadInSteps: 0.07,
            shadowEventCount: 1,
            shadowPeak: 0.04,
            shadowRMS: 0.01
        ).isComplete(
            routeSampleRate: 8_000,
            phraseKind: .lock,
            conservative: false
        ))
        #expect(!fixtureUpperTiming(
            bar: 7,
            chapter: .tone,
            sourceScoreNoteCount: 2,
            sourceRenderEventCount: 2,
            anchorEventCount: 1,
            activeOffsetCount: 1,
            maximumOffsetInSteps: 0.06,
            maximumRoleSpreadInSteps: 0.06,
            shadowEventCount: 1,
            shadowPeak: 0.04,
            shadowRMS: 0.01
        ).isComplete(
            routeSampleRate: 8_000,
            phraseKind: .lock,
            conservative: false
        ))
        #expect(!fixtureUpperTiming(
            chapter: .breath,
            sourceScoreNoteCount: 2,
            sourceRenderEventCount: 2,
            anchorEventCount: 1,
            activeOffsetCount: 1,
            maximumOffsetInSteps: 0.06,
            maximumRoleSpreadInSteps: 0.06,
            shadowEventCount: 1,
            shadowPeak: 0.04,
            shadowRMS: 0.01
        ).isComplete(
            routeSampleRate: 8_000,
            phraseKind: .lock,
            conservative: false
        ))
        #expect(!fixtureUpperTiming(
            bar: 7,
            chapter: .breath,
            sourceScoreNoteCount: 2,
            sourceRenderEventCount: 2,
            anchorEventCount: 1,
            activeOffsetCount: 1,
            maximumOffsetInSteps: 0.06,
            maximumRoleSpreadInSteps: 0.06,
            shadowEventCount: 1
        ).isComplete(
            routeSampleRate: 8_000,
            phraseKind: .lock,
            conservative: false
        ))

        let forcedHomeActive = AutonomousCandidateAttempt(
            kind: .initialRender,
            forceHomeUpperTimbre: true,
            vector: vector
        )
        #expect(!forcedHomeActive.isStructurallyComplete)

        let silentNeutral = fixtureUpperTiming(
            bar: 7,
            chapter: .breath,
            sourceScoreNoteCount: 2,
            sourceRenderEventCount: 2,
            anchorEventCount: 1,
            shadowEventCount: 1
        )
        #expect(!silentNeutral.isComplete(
            routeSampleRate: 8_000,
            phraseKind: .lock,
            conservative: false
        ))
        let silentNeutralVector = fixtureVector(
            slot: .primary,
            evidenceBar: 7,
            upperTimingBars: [silentNeutral]
        )
        #expect(!silentNeutralVector.isComplete)
        #expect(!AutonomousCandidateAttempt(
            kind: .initialRender,
            forceHomeUpperTimbre: true,
            vector: silentNeutralVector
        ).isStructurallyComplete)

        let eligibleNeutral = fixtureUpperTiming(
            bar: 7,
            chapter: .breath,
            sourceScoreNoteCount: 3,
            sourceRenderEventCount: 3,
            anchorEventCount: 1,
            shadowEventCount: 1,
            shadowPeak: 0.04,
            shadowRMS: 0.01,
            responseEventCount: 1,
            responsePeak: 0.05,
            responseRMS: 0.012
        )
        let eligibleNeutralVector = fixtureVector(
            slot: .primary,
            evidenceBar: 7,
            upperTimingBars: [eligibleNeutral]
        )
        #expect(eligibleNeutralVector.isComplete)
        #expect(!AutonomousCandidateAttempt(
            kind: .initialRender,
            vector: eligibleNeutralVector
        ).isStructurallyComplete)
        #expect(AutonomousCandidateAttempt(
            kind: .initialRender,
            forceHomeUpperTimbre: true,
            vector: eligibleNeutralVector
        ).isStructurallyComplete)
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
        #expect(vector.schemaVersion == 18)
        #expect(QualityQualificationContract.schemaVersion == 19)
        #expect(QualityQualificationContract.engineVersion ==
                "autotechno-canonical-engine.v19")
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

    @Test("Closed-hat evidence is bounded, deterministic, and required per bar")
    func closedHatEvidenceContract() throws {
        let emptyBar = AutonomousClosedHatBarEvidence(
            bar: 0,
            sourceScoreEventCount: 0,
            sourceRenderEventCount: 0,
            events: []
        )
        let neutral = fixtureClosedHatEvent()
        let companion = fixtureClosedHatEvent(
            scoreEventIndex: 2,
            step: 7,
            role: .openHatCompanion,
            intensity: 0.64,
            timingOffsetInSteps: 0.08,
            relocated: true,
            decayRateScale: ClosedHatVoiceContract.openHatCompanionDecayRateScale,
            sampleHash: "fedcba9876543210",
            sourceRMS: 0.015,
            spectralCentroidHz: 2_700,
            tailToAttackDB: -12
        )
        let authoredBar = AutonomousClosedHatBarEvidence(
            bar: 0,
            sourceScoreEventCount: 2,
            sourceRenderEventCount: 2,
            events: [neutral, companion]
        )
        let baseline = fixtureVector(slot: .primary)
        let vector = fixtureVector(slot: .primary, closedHatBar: authoredBar)

        #expect(emptyBar.isComplete(sampleRate: 8_000))
        #expect(emptyBar.isFinite)
        #expect(neutral.isComplete(sampleRate: 8_000))
        #expect(neutral.isFinite)
        #expect(companion.isComplete(sampleRate: 8_000))
        #expect(companion.isFinite)
        #expect(authoredBar.isComplete(sampleRate: 8_000))
        #expect(vector.isComplete)
        #expect(vector.isFinite)
        #expect(vector.fingerprint != baseline.fingerprint)
        #expect(vector.selectionEvidence == baseline.selectionEvidence)

        let data = try vector.deterministicJSON()
        let repeatedData = try vector.deterministicJSON()
        #expect(data == repeatedData)
        let decoded = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: data
        )
        #expect(decoded == vector)
        #expect(decoded.fingerprint == vector.fingerprint)

        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let bars = try #require(object["closedHat"] as? [[String: Any]])
        let events = try #require(bars.first?["events"] as? [[String: Any]])
        let serializedEvent = try #require(events.first)
        #expect(Set(serializedEvent.keys) == Set([
            "scoreEventIndex", "step", "role", "intensity",
            "timingOffsetInSteps", "relocated", "decayRateScale",
            "renderedFrameCount", "sampleHash", "sourceRMS",
            "spectralCentroidHz", "tailToAttackDB", "finite",
        ]))

        let excessiveEvents = (0..<5).map { index in
            fixtureClosedHatEvent(
                scoreEventIndex: index,
                step: index * 2 + 1,
                sampleHash: String(format: "%016x", index + 1)
            )
        }
        let truncated = AutonomousClosedHatBarEvidence(
            bar: 0,
            sourceScoreEventCount: excessiveEvents.count,
            sourceRenderEventCount: excessiveEvents.count,
            events: excessiveEvents
        )
        #expect(truncated.events.count ==
                AutonomousCandidateEvaluationVector.maximumClosedHatEventsPerBar)
        #expect(!truncated.isComplete(sampleRate: 8_000))

        var oversizedEventObject = object
        var oversizedEventBars = bars
        var oversizedEventBar = oversizedEventBars[0]
        let decodedOversizedEvents: [[String: Any]] = (0..<5).map { index in
            var copy = serializedEvent
            copy["scoreEventIndex"] = index
            copy["step"] = index * 2 + 1
            copy["sampleHash"] = String(format: "%016x", index + 1)
            return copy
        }
        oversizedEventBar["sourceScoreEventCount"] = 5
        oversizedEventBar["sourceRenderEventCount"] = 5
        oversizedEventBar["events"] = decodedOversizedEvents
        oversizedEventBars[0] = oversizedEventBar
        oversizedEventObject["closedHat"] = oversizedEventBars
        let decodedOversizedEventVector = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: oversizedEventObject)
        )
        #expect(decodedOversizedEventVector.closedHat[0].events.count == 5)
        #expect(!decodedOversizedEventVector.recordIsStructurallyValid)

        var oversizedBarObject = object
        let decodedOversizedBars: [[String: Any]] = (0..<17).map { bar in
            var copy = bars[0]
            copy["bar"] = bar
            return copy
        }
        oversizedBarObject["sourceClosedHatBarCount"] = 17
        oversizedBarObject["closedHat"] = decodedOversizedBars
        let decodedOversizedBarVector = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: oversizedBarObject)
        )
        #expect(decodedOversizedBarVector.closedHat.count == 17)
        #expect(!decodedOversizedBarVector.recordIsStructurallyValid)

        let duplicateEventIndex = AutonomousClosedHatBarEvidence(
            bar: 0,
            sourceScoreEventCount: 2,
            sourceRenderEventCount: 2,
            events: [
                neutral,
                fixtureClosedHatEvent(
                    step: 7,
                    sampleHash: "0000000000000002"
                ),
            ]
        )
        #expect(!duplicateEventIndex.isComplete(sampleRate: 8_000))

        #expect(!fixtureClosedHatEvent(roleRawValue: "ride")
            .isComplete(sampleRate: 8_000))
        #expect(!fixtureClosedHatEvent(decayRateScale: 1.35)
            .isComplete(sampleRate: 8_000))
        #expect(!fixtureClosedHatEvent(renderedFrameCount: 399)
            .isComplete(sampleRate: 8_000))
        #expect(!fixtureClosedHatEvent(sampleHash: "NOT-A-PCM-HASH!!")
            .isComplete(sampleRate: 8_000))
        #expect(!fixtureClosedHatEvent(sourceRMS: 0.251)
            .isComplete(sampleRate: 8_000))
        #expect(!fixtureClosedHatEvent(spectralCentroidHz: 4_001)
            .isComplete(sampleRate: 8_000))
        #expect(!fixtureClosedHatEvent(tailToAttackDB: 121)
            .isComplete(sampleRate: 8_000))
        let nonFinite = fixtureClosedHatEvent(sourceRMS: .nan)
        #expect(!nonFinite.isFinite)
        #expect(!nonFinite.isComplete(sampleRate: 8_000))
        #expect(!fixtureClosedHatEvent(finite: false).isFinite)
    }

    @Test("Instrument assignments and exact architecture PCM are bounded provenance")
    func instrumentEvidenceContract() throws {
        let assignment = InstrumentAssignment(
            use: .motif,
            patch: .acidSequence,
            automation: InstrumentAutomation(
                color: 0.62,
                shape: 0.48,
                motion: 0.78,
                space: 0.22
            ),
            effects: (InstrumentPalette.capability(for: .acidSequence)?.compatibleEffects ?? [])
                .filter { $0 != .pulseEcho }
        )
        let instrumentBar = AutonomousInstrumentBarEvidence(
            bar: 0,
            evidence: [InstrumentArchitectureRenderEvidence(
                architecture: .resonantMono,
                assignments: [assignment],
                patches: [.acidSequence],
                uses: [.motif],
                effects: assignment.effects,
                eventCount: 1,
                sampleHash: "0123456789abcdef",
                peak: 0.20,
                rms: 0.08,
                finite: true,
                nonlinearCore:
                    fixtureTPTAntialiasedNonlinearCoreRenderEvidence(),
                resonantMonoModulation:
                    fixtureResonantMonoModulationRenderEvidence()
            )]
        )
        let vector = fixtureVector(
            slot: .primary,
            instrumentBar: instrumentBar
        )
        let empty = fixtureVector(slot: .primary)

        #expect(instrumentBar.isComplete(sampleRate: 8_000))
        #expect(instrumentBar.isFinite)
        #expect(vector.isComplete)
        #expect(vector.isFinite)
        #expect(vector.fingerprint != empty.fingerprint)
        #expect(vector.selectionEvidence == empty.selectionEvidence)

        let data = try vector.deterministicJSON()
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let bars = try #require(object["instruments"] as? [[String: Any]])
        let architectures = try #require(
            bars.first?["architectures"] as? [[String: Any]]
        )
        let serialized = try #require(architectures.first)
        #expect(Set(serialized.keys) == Set([
            "architecture", "sourceAssignmentCount", "assignments", "eventCount",
            "sampleHash", "peak", "rms", "finite", "nonlinearCore",
            "resonantMonoModulation",
        ]))
        let serializedAssignments = try #require(
            serialized["assignments"] as? [[String: Any]]
        )
        let serializedAssignment = try #require(serializedAssignments.first)
        #expect(Set(serializedAssignment.keys) == Set([
            "use", "architecture", "patch", "color", "shape", "motion", "space",
            "effects",
        ]))
        let serializedModulation = try #require(
            serialized["resonantMonoModulation"] as? [String: Any]
        )
        let serializedCore = try #require(
            serialized["nonlinearCore"] as? [String: Any]
        )
        #expect(Set(serializedCore.keys) == Set([
            "version", "antialiasOrder", "sourceAssignmentCount",
            "sourceEventCount", "processedSampleCount", "minimumCutoffHz",
            "maximumCutoffHz", "minimumQ", "maximumQ",
            "minimumInputDrive", "maximumInputDrive", "minimumOutputDrive",
            "maximumOutputDrive", "minimumBandMix", "maximumBandMix",
            "inputSampleHash", "outputSampleHash", "inputPeak", "inputRMS",
            "outputPeak", "outputRMS", "bindingValid", "finite",
        ]))
        #expect(Set(serializedModulation.keys) == Set([
            "sourceAssignmentCount", "eventCount", "orderedEventCount",
            "metallicEventCount", "orderedModulatorRatio",
            "metallicModulatorRatio", "maximumRequestedPeakIndex",
            "minimumAppliedPeakIndex", "maximumAppliedPeakIndex",
            "eventFingerprint", "operatorSampleHash", "operatorPeak",
            "operatorRMS", "operatorCrestFactor", "lowBandEnergyRatio",
            "bindingValid", "finite",
        ]))

        var forgedObject = object
        var forgedBars = bars
        var forgedBar = forgedBars[0]
        var forgedArchitectures = architectures
        var forgedArchitecture = forgedArchitectures[0]
        var forgedAssignments = serializedAssignments
        var forgedAssignment = forgedAssignments[0]
        forgedAssignment["patch"] = InstrumentPatch.alienNoise.rawValue
        forgedAssignments[0] = forgedAssignment
        forgedArchitecture["assignments"] = forgedAssignments
        forgedArchitectures[0] = forgedArchitecture
        forgedBar["architectures"] = forgedArchitectures
        forgedBars[0] = forgedBar
        forgedObject["instruments"] = forgedBars
        let forged = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedObject)
        )
        #expect(!forged.isComplete)
        #expect(forged.fingerprint != vector.fingerprint)

        var excessiveObject = object
        var excessiveBars = bars
        var excessiveBar = excessiveBars[0]
        var excessiveArchitectures = architectures
        var excessiveArchitecture = excessiveArchitectures[0]
        excessiveArchitecture["eventCount"] =
            AutonomousCandidateEvaluationVector.maximumInstrumentEventsPerBar + 1
        excessiveArchitectures[0] = excessiveArchitecture
        excessiveBar["architectures"] = excessiveArchitectures
        excessiveBars[0] = excessiveBar
        excessiveObject["instruments"] = excessiveBars
        let excessive = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: excessiveObject)
        )
        #expect(!excessive.isComplete)

        var lowLeakageObject = object
        var lowLeakageBars = bars
        var lowLeakageBar = lowLeakageBars[0]
        var lowLeakageArchitectures = architectures
        var lowLeakageArchitecture = lowLeakageArchitectures[0]
        var lowLeakageModulation = serializedModulation
        lowLeakageModulation["lowBandEnergyRatio"] = 0.9
        lowLeakageArchitecture["resonantMonoModulation"] =
            lowLeakageModulation
        lowLeakageArchitectures[0] = lowLeakageArchitecture
        lowLeakageBar["architectures"] = lowLeakageArchitectures
        lowLeakageBars[0] = lowLeakageBar
        lowLeakageObject["instruments"] = lowLeakageBars
        let excessiveLowLeakage = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: lowLeakageObject)
        )
        #expect(!excessiveLowLeakage.isComplete)

        var disconnectedObject = object
        var disconnectedBars = bars
        var disconnectedBar = disconnectedBars[0]
        var disconnectedArchitectures = architectures
        var disconnectedArchitecture = disconnectedArchitectures[0]
        var disconnectedModulation = serializedModulation
        disconnectedModulation["bindingValid"] = false
        disconnectedArchitecture["resonantMonoModulation"] =
            disconnectedModulation
        disconnectedArchitectures[0] = disconnectedArchitecture
        disconnectedBar["architectures"] = disconnectedArchitectures
        disconnectedBars[0] = disconnectedBar
        disconnectedObject["instruments"] = disconnectedBars
        let disconnected = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: disconnectedObject)
        )
        #expect(!disconnected.isComplete)

        var forgedCoreObject = object
        var forgedCoreBars = bars
        var forgedCoreBar = forgedCoreBars[0]
        var forgedCoreArchitectures = architectures
        var forgedCoreArchitecture = forgedCoreArchitectures[0]
        var forgedCore = serializedCore
        forgedCore["version"] = "unqualified-core.v999"
        forgedCoreArchitecture["nonlinearCore"] = forgedCore
        forgedCoreArchitectures[0] = forgedCoreArchitecture
        forgedCoreBar["architectures"] = forgedCoreArchitectures
        forgedCoreBars[0] = forgedCoreBar
        forgedCoreObject["instruments"] = forgedCoreBars
        let forgedCoreVector = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedCoreObject)
        )
        #expect(!forgedCoreVector.isComplete)
        #expect(forgedCoreVector.fingerprint != vector.fingerprint)

        var misplacedObject = object
        var misplacedBars = bars
        misplacedBars[0]["bar"] = 1
        misplacedObject["instruments"] = misplacedBars
        let misplaced = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: misplacedObject)
        )
        #expect(!misplaced.isComplete)
    }

    @Test("Rising spectral cluster evidence is bounded and selection-neutral")
    func spectralTextureClusterEvidenceContract() throws {
        let assignment = InstrumentAssignment(
            use: .transition,
            patch: .metalVeil,
            automation: InstrumentAutomation(
                color: 0.78, shape: 0.32, motion: 0.68, space: 0.52
            ),
            effects: InstrumentPalette.capability(for: .metalVeil)?
                .compatibleEffects ?? []
        )
        let cluster = SpectralTextureClusterRenderEvidence(
            sourceAssignmentCount: 1,
            eventCount: 1,
            relation: .risingAdjacentCluster,
            adjacentRatio: SpectralTextureClusterContract.adjacentSemitoneRatio,
            maximumComponentRatio:
                SpectralTextureClusterContract.maximumComponentRatio,
            minimumStartFrequency: 174.61,
            maximumAppliedEndFrequency: 438,
            eventFingerprint: "fedcba9876543210",
            clusterSampleHash: "0123456789abcdef",
            clusterPeak: 0.20,
            clusterRMS: 0.08,
            clusterCrestFactor: 2.5,
            bindingValid: true,
            finite: true
        )
        let bar = AutonomousInstrumentBarEvidence(
            bar: 0,
            evidence: [InstrumentArchitectureRenderEvidence(
                architecture: .spectralTexture,
                assignments: [assignment],
                patches: [.metalVeil],
                uses: [.transition],
                effects: assignment.effects,
                eventCount: 1,
                sampleHash: "89abcdef01234567",
                peak: 0.20,
                rms: 0.08,
                finite: true,
                spectralTextureCluster: cluster
            )]
        )
        let vector = fixtureVector(slot: .primary, instrumentBar: bar)
        let baseline = fixtureVector(slot: .primary)
        #expect(bar.isComplete(sampleRate: 8_000))
        #expect(vector.isComplete)
        #expect(vector.fingerprint != baseline.fingerprint)
        #expect(vector.selectionEvidence == baseline.selectionEvidence)

        let data = try vector.deterministicJSON()
        var object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var bars = try #require(object["instruments"] as? [[String: Any]])
        var architecture = try #require(
            (bars[0]["architectures"] as? [[String: Any]])?.first
        )
        let serialized = try #require(
            architecture["spectralTextureCluster"] as? [String: Any]
        )
        #expect(Set(serialized.keys) == Set([
            "sourceAssignmentCount", "eventCount", "relation",
            "adjacentRatio", "maximumComponentRatio", "minimumStartFrequency",
            "maximumAppliedEndFrequency", "eventFingerprint", "clusterSampleHash",
            "clusterPeak", "clusterRMS", "clusterCrestFactor", "bindingValid",
            "finite",
        ]))

        architecture["spectralTextureCluster"] = nil
        var architectures = try #require(
            bars[0]["architectures"] as? [[String: Any]]
        )
        architectures[0] = architecture
        bars[0]["architectures"] = architectures
        object["instruments"] = bars
        let disconnected = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(!disconnected.isComplete)

        var forgedObject = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var forgedBars = try #require(
            forgedObject["instruments"] as? [[String: Any]]
        )
        var forgedArchitectures = try #require(
            forgedBars[0]["architectures"] as? [[String: Any]]
        )
        var forgedArchitecture = forgedArchitectures[0]
        var forgedCluster = try #require(
            forgedArchitecture["spectralTextureCluster"] as? [String: Any]
        )
        forgedCluster["adjacentRatio"] = 1.25
        forgedArchitecture["spectralTextureCluster"] = forgedCluster
        forgedArchitectures[0] = forgedArchitecture
        forgedBars[0]["architectures"] = forgedArchitectures
        forgedObject["instruments"] = forgedBars
        let wrongRatio = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedObject)
        )
        #expect(!wrongRatio.isComplete)

        forgedCluster["adjacentRatio"] =
            SpectralTextureClusterContract.adjacentSemitoneRatio
        forgedCluster["maximumAppliedEndFrequency"] = 1_000
        forgedArchitecture["spectralTextureCluster"] = forgedCluster
        forgedArchitectures[0] = forgedArchitecture
        forgedBars[0]["architectures"] = forgedArchitectures
        forgedObject["instruments"] = forgedBars
        let outOfRoute = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedObject)
        )
        #expect(!outOfRoute.isComplete)
    }

    @Test("Tonal envelope expansion evidence binds the applied wash and stays selection-neutral")
    func tonalEnvelopeExpansionEvidenceContract() throws {
        let baseSustain = 0.31
        let baseRelease = 0.22
        let applied = TonalEnvelopeExpansionContract.resolve(
            baseSustain: baseSustain,
            baseReleaseSeconds: baseRelease,
            relation: .sustainedWash
        )
        let relation = TonalEnvelopeExpansionRenderEvidence(
            eligible: true,
            active: true,
            eventCount: 1,
            relation: .sustainedWash,
            baseSustain: baseSustain,
            baseReleaseSeconds: baseRelease,
            appliedSustain: applied.sustain,
            appliedReleaseSeconds: applied.releaseSeconds,
            eventFingerprint: "0123456789abcdef",
            sampleHash: "fedcba9876543210",
            peak: 0.18,
            rms: 0.06,
            attackRMS: 0.08,
            tailRMS: 0.03,
            tailToAttackDB: -8.519_374_645_445_623,
            nonzeroSampleCount: 2_000,
            bindingValid: true,
            finite: true
        )
        let assignment = InstrumentPalette.safeUpper(role: .anchor)
        let bar = AutonomousInstrumentBarEvidence(
            bar: 15,
            evidence: [InstrumentArchitectureRenderEvidence(
                architecture: .tonalMotion,
                assignments: [assignment],
                patches: [assignment.patch],
                uses: [assignment.use],
                effects: assignment.effects,
                eventCount: 1,
                sampleHash: "1111111111111111",
                peak: 0.20,
                rms: 0.07,
                finite: true,
                tonalEnvelopeExpansion: relation
            )]
        )
        let vector = fixtureVector(
            slot: .primary,
            evidenceBar: 15,
            phraseKind: .energyRelease,
            instrumentBar: bar
        )
        let baseline = fixtureVector(
            slot: .primary,
            evidenceBar: 15,
            phraseKind: .energyRelease
        )
        #expect(bar.isComplete(sampleRate: 8_000))
        #expect(vector.isComplete)
        #expect(AutonomousCandidateAttempt(
            kind: .initialRender,
            vector: vector
        ).isStructurallyComplete)
        #expect(vector.fingerprint != baseline.fingerprint)
        #expect(vector.selectionEvidence == baseline.selectionEvidence)

        let data = try vector.deterministicJSON()
        var object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var bars = try #require(object["instruments"] as? [[String: Any]])
        var architectures = try #require(
            bars[0]["architectures"] as? [[String: Any]]
        )
        var architecture = architectures[0]
        var serialized = try #require(
            architecture["tonalEnvelopeExpansion"] as? [String: Any]
        )
        #expect(Set(serialized.keys) == Set([
            "eligible", "active", "eventCount", "relation", "baseSustain",
            "baseReleaseSeconds", "appliedSustain", "appliedReleaseSeconds",
            "eventFingerprint", "sampleHash", "peak", "rms", "attackRMS",
            "tailRMS", "tailToAttackDB", "nonzeroSampleCount",
            "bindingValid", "finite",
        ]))

        serialized["appliedReleaseSeconds"] = applied.releaseSeconds + 0.01
        architecture["tonalEnvelopeExpansion"] = serialized
        architectures[0] = architecture
        bars[0]["architectures"] = architectures
        object["instruments"] = bars
        let forged = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(!forged.isComplete)
        #expect(forged.fingerprint != vector.fingerprint)
    }

    @Test("Pulse-echo return drive evidence is bounded, attributable, and selection-neutral")
    func pulseEchoDriveEvidenceContract() throws {
        let pulseInstrument = fixturePulseEchoInstrumentBar()
        let preDrivePeak = Double(Float(0.20))
        let activePostDrivePeak = abs(Double(
            PulseEchoReturnDriveContract.process(
                preDriveSample: Float(preDrivePeak),
                amount: 0.4
            )
        ))
        let cappedPostDrivePeak = abs(Double(
            PulseEchoReturnDriveContract.process(
                preDriveSample: Float(preDrivePeak),
                amount: 0.55
            )
        ))
        let active = fixturePulseEchoDrive(
            scoreEnabled: true,
            earliestPulseEchoOnsetStep: 0,
            driveEligible: true,
            appliedAmount: 0.4,
            currentSendRMS: 0.02,
            postDriveSampleHash: "fedcba9876543210",
            preDrivePeak: preDrivePeak,
            postDrivePeak: activePostDrivePeak,
            preDriveRMS: 0.08,
            postDriveRMS: 0.075,
            preDriveLowBandRMS: 0.01,
            postDriveLowBandRMS: 0.008,
            differenceRMS: 0.012,
            interlockChapter: .memory
        )
        let baseline = fixtureVector(
            slot: .primary,
            instrumentBar: pulseInstrument,
            pulseEchoDriveBars: [fixturePulseEchoDrive(
                scoreEnabled: true,
                earliestPulseEchoOnsetStep: 0
            )]
        )
        let vector = fixtureVector(
            slot: .primary,
            instrumentBar: pulseInstrument,
            pulseEchoDriveBars: [active]
        )

        #expect(pulseInstrument.isComplete(sampleRate: 8_000))
        #expect(active.isFinite)
        #expect(active.isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: pulseInstrument
        ))
        #expect(vector.isComplete)
        #expect(vector.isFinite)
        #expect(vector.fingerprint != baseline.fingerprint)
        #expect(vector.selectionEvidence == baseline.selectionEvidence)
        #expect(AutonomousCandidateAttempt(
            kind: .initialRender,
            reasonCodes: [],
            vector: vector
        ).isStructurallyComplete)
        #expect(!AutonomousCandidateAttempt(
            kind: .correctionRender,
            forceHomeUpperTimbre: true,
            reasonCodes: [],
            vector: vector
        ).isStructurallyComplete)

        let data = try vector.deterministicJSON()
        #expect(try vector.deterministicJSON() == data)
        let decoded = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: data
        )
        #expect(decoded == vector)
        #expect(decoded.fingerprint == vector.fingerprint)

        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let bars = try #require(object["pulseEchoDrive"] as? [[String: Any]])
        let serialized = try #require(bars.first)
        #expect(Set(serialized.keys) == Set([
            "bar", "bpm", "delayFrameCount", "scoreEnabled", "driveEligible",
            "earliestPulseEchoOnsetStep", "machineTexture",
            "appliedAmount", "transitionFrameCount", "renderedFrameCount",
            "currentSendRMS",
            "preDriveSampleHash", "postDriveSampleHash", "preDrivePeak",
            "firstPreDriveSampleBitPattern", "firstPostDriveSampleBitPattern",
            "lastPreDriveSampleBitPattern", "lastPostDriveSampleBitPattern",
            "changedFrameIndex", "changedPreDriveSampleBitPattern",
            "preDrivePeakFrameIndex", "postDrivePeak", "postDrivePeakFrameIndex",
            "postDrivePeakPreDriveSample", "postDrivePeakEffectiveAmount",
            "preDriveRMS", "postDriveRMS",
            "preDriveLowBandRMS", "postDriveLowBandRMS", "differenceRMS",
            "interlockChapter", "bindingValid", "finite",
        ]))

        var forgedAmountObject = object
        var forgedAmountBars = bars
        forgedAmountBars[0]["appliedAmount"] = 0.39
        forgedAmountObject["pulseEchoDrive"] = forgedAmountBars
        let forgedAmount = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedAmountObject)
        )
        #expect(!forgedAmount.isComplete)
        #expect(forgedAmount.fingerprint != vector.fingerprint)

        var forgedBindingObject = object
        var forgedBindingBars = bars
        forgedBindingBars[0]["bindingValid"] = false
        forgedBindingObject["pulseEchoDrive"] = forgedBindingBars
        let forgedBinding = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedBindingObject)
        )
        #expect(!forgedBinding.isComplete)
        #expect(forgedBinding.recordIsStructurallyValid)
        #expect(AutonomousCandidateAttempt(
            kind: .initialRender,
            reasonCodes: [.evidenceMissingV1, .hardGateFailedV1],
            vector: forgedBinding
        ).isStructurallyComplete)

        var forgedHashObject = object
        var forgedHashBars = bars
        forgedHashBars[0]["postDriveSampleHash"] = "FEDCBA9876543210"
        forgedHashObject["pulseEchoDrive"] = forgedHashBars
        let forgedHash = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedHashObject)
        )
        #expect(!forgedHash.isComplete)

        var forgedPeakObject = object
        var forgedPeakBars = bars
        forgedPeakBars[0]["postDrivePeak"] = 0.21
        forgedPeakObject["pulseEchoDrive"] = forgedPeakBars
        let forgedPeak = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedPeakObject)
        )
        #expect(!forgedPeak.isComplete)

        var forgedTransitionObject = object
        var forgedTransitionBars = bars
        forgedTransitionBars[0]["transitionFrameCount"] = 63
        forgedTransitionObject["pulseEchoDrive"] = forgedTransitionBars
        let forgedTransition = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedTransitionObject)
        )
        #expect(!forgedTransition.isComplete)

        var forgedPrePeakFrameObject = object
        var forgedPrePeakFrameBars = bars
        forgedPrePeakFrameBars[0]["preDrivePeakFrameIndex"] = 0
        forgedPrePeakFrameObject["pulseEchoDrive"] = forgedPrePeakFrameBars
        let forgedPrePeakFrame = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedPrePeakFrameObject)
        )
        #expect(!forgedPrePeakFrame.isComplete)

        var forgedChangedFrameObject = object
        var forgedChangedFrameBars = bars
        forgedChangedFrameBars[0]["changedFrameIndex"] = 0
        forgedChangedFrameObject["pulseEchoDrive"] = forgedChangedFrameBars
        let forgedChangedFrame = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedChangedFrameObject)
        )
        #expect(!forgedChangedFrame.isComplete)

        var forgedChangedSampleObject = object
        var forgedChangedSampleBars = bars
        forgedChangedSampleBars[0]["changedPreDriveSampleBitPattern"] = 0
        forgedChangedSampleObject["pulseEchoDrive"] = forgedChangedSampleBars
        let forgedChangedSample = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedChangedSampleObject)
        )
        #expect(!forgedChangedSample.isComplete)

        var forgedChangedMagnitudeObject = object
        var forgedChangedMagnitudeBars = bars
        forgedChangedMagnitudeBars[0]["changedPreDriveSampleBitPattern"] =
            Float(1).bitPattern
        forgedChangedMagnitudeObject["pulseEchoDrive"] =
            forgedChangedMagnitudeBars
        let forgedChangedMagnitude = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedChangedMagnitudeObject)
        )
        #expect(!forgedChangedMagnitude.isComplete)

        var forgedWitnessObject = object
        var forgedWitnessBars = bars
        forgedWitnessBars[0]["postDrivePeakFrameIndex"] = 0
        forgedWitnessObject["pulseEchoDrive"] = forgedWitnessBars
        let forgedWitness = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedWitnessObject)
        )
        #expect(!forgedWitness.isComplete)

        var forgedWitnessAmountObject = object
        var forgedWitnessAmountBars = bars
        forgedWitnessAmountBars[0]["postDrivePeakEffectiveAmount"] = 0.39
        forgedWitnessAmountObject["pulseEchoDrive"] = forgedWitnessAmountBars
        let forgedWitnessAmount = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedWitnessAmountObject)
        )
        #expect(!forgedWitnessAmount.isComplete)

        var forgedWitnessSampleObject = object
        var forgedWitnessSampleBars = bars
        forgedWitnessSampleBars[0]["postDrivePeakPreDriveSample"] =
            preDrivePeak + 0.000_000_000_001
        forgedWitnessSampleObject["pulseEchoDrive"] = forgedWitnessSampleBars
        let forgedWitnessSample = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedWitnessSampleObject)
        )
        #expect(!forgedWitnessSample.isComplete)

        var forgedPrePeakObject = object
        var forgedPrePeakBars = bars
        forgedPrePeakBars[0]["preDrivePeak"] =
            preDrivePeak + 0.000_000_000_001
        forgedPrePeakObject["pulseEchoDrive"] = forgedPrePeakBars
        let forgedPrePeak = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedPrePeakObject)
        )
        #expect(!forgedPrePeak.isComplete)

        var forgedBoundaryObject = object
        var forgedBoundaryBars = bars
        forgedBoundaryBars[0]["lastPostDriveSampleBitPattern"] = 1
        forgedBoundaryObject["pulseEchoDrive"] = forgedBoundaryBars
        let forgedBoundary = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedBoundaryObject)
        )
        #expect(!forgedBoundary.isComplete)

        var forgedLateOnsetObject = object
        var forgedLateOnsetBars = bars
        forgedLateOnsetBars[0]["earliestPulseEchoOnsetStep"] = 13
        forgedLateOnsetObject["pulseEchoDrive"] = forgedLateOnsetBars
        let forgedLateOnset = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedLateOnsetObject)
        )
        #expect(!forgedLateOnset.isComplete)

        var forgedMuteObject = object
        var forgedMuteBars = bars
        forgedMuteBars[0]["postDrivePeak"] = 0
        forgedMuteBars[0]["postDriveRMS"] = 0
        forgedMuteBars[0]["postDriveLowBandRMS"] = 0
        forgedMuteObject["pulseEchoDrive"] = forgedMuteBars
        let forgedMute = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedMuteObject)
        )
        #expect(!forgedMute.isComplete)
        #expect(!fixturePulseEchoDrive(
            scoreEnabled: true,
            earliestPulseEchoOnsetStep: 0,
            driveEligible: true,
            appliedAmount: 0.4,
            currentSendRMS: 0.02,
            postDriveSampleHash: "fedcba9876543210",
            preDrivePeak: 0.000_000_5,
            postDrivePeak: 0,
            postDrivePeakFrameIndex: 0,
            postDrivePeakPreDriveSample: 0,
            postDrivePeakEffectiveAmount: 0,
            preDriveRMS: 0.000_000_5,
            postDriveRMS: 0,
            differenceRMS: 0.000_000_5,
            interlockChapter: .memory
        ).isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: pulseInstrument
        ))

        var forgedRMSObject = object
        var forgedRMSBars = bars
        forgedRMSBars[0]["postDriveRMS"] = 0.095
        forgedRMSObject["pulseEchoDrive"] = forgedRMSBars
        let forgedRMS = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedRMSObject)
        )
        #expect(!forgedRMS.isComplete)

        var forgedLowDifferenceObject = object
        var forgedLowDifferenceBars = bars
        forgedLowDifferenceBars[0]["differenceRMS"] = 0.001
        forgedLowDifferenceObject["pulseEchoDrive"] = forgedLowDifferenceBars
        let forgedLowDifference = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedLowDifferenceObject)
        )
        #expect(!forgedLowDifference.isComplete)

        var forgedHighDifferenceObject = object
        var forgedHighDifferenceBars = bars
        forgedHighDifferenceBars[0]["differenceRMS"] = 0.156
        forgedHighDifferenceObject["pulseEchoDrive"] = forgedHighDifferenceBars
        let forgedHighDifference = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedHighDifferenceObject)
        )
        #expect(!forgedHighDifference.isComplete)

        var forgedLowBandObject = object
        var forgedLowBandBars = bars
        forgedLowBandBars[0]["postDriveLowBandRMS"] = 0.076
        forgedLowBandObject["pulseEchoDrive"] = forgedLowBandBars
        let forgedLowBand = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedLowBandObject)
        )
        #expect(!forgedLowBand.isComplete)

        let noPulseAccess = fixturePulseEchoInstrumentBar(effects: [])
        #expect(noPulseAccess.isComplete(sampleRate: 8_000))
        #expect(!active.isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: noPulseAccess
        ))
        #expect(fixturePulseEchoDrive(
            scoreEnabled: true,
            interlockChapter: .memory
        ).isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: noPulseAccess
        ))
        #expect(!fixturePulseEchoDrive(
            interlockChapter: .memory
        ).isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: pulseInstrument
        ))
        #expect(!fixturePulseEchoDrive(
            scoreEnabled: true,
            earliestPulseEchoOnsetStep: 0,
            driveEligible: true,
            appliedAmount: 0.4,
            preDrivePeak: preDrivePeak,
            postDrivePeak: preDrivePeak,
            preDriveRMS: 0.08,
            postDriveRMS: 0.08,
            preDriveLowBandRMS: 0.01,
            postDriveLowBandRMS: 0.01,
            interlockChapter: .memory
        ).isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: pulseInstrument
        ))
        let tinyAmount = 0.000_000_000_001
        let tinyPostDrivePeak = abs(Double(
            PulseEchoReturnDriveContract.process(
                preDriveSample: Float(preDrivePeak),
                amount: tinyAmount
            )
        ))
        #expect(Float(tinyPostDrivePeak).bitPattern != Float(preDrivePeak).bitPattern)
        #expect(fixturePulseEchoDrive(
            scoreEnabled: true,
            earliestPulseEchoOnsetStep: 0,
            driveEligible: true,
            machineTexture: tinyAmount,
            appliedAmount: tinyAmount,
            currentSendRMS: 0.02,
            postDriveSampleHash: "fedcba9876543210",
            preDrivePeak: preDrivePeak,
            postDrivePeak: tinyPostDrivePeak,
            preDriveRMS: 0.08,
            postDriveRMS: 0.08,
            preDriveLowBandRMS: 0.01,
            postDriveLowBandRMS: 0.01,
            differenceRMS: Double(Float.leastNonzeroMagnitude),
            interlockChapter: .memory
        ).isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: pulseInstrument
        ))
        #expect(!fixturePulseEchoDrive(
            scoreEnabled: true,
            earliestPulseEchoOnsetStep: 0,
            driveEligible: true,
            machineTexture: tinyAmount,
            appliedAmount: tinyAmount,
            currentSendRMS: 0.02,
            preDrivePeak: preDrivePeak,
            postDrivePeak: tinyPostDrivePeak,
            preDriveRMS: 0.08,
            postDriveRMS: 0.08,
            preDriveLowBandRMS: 0.01,
            postDriveLowBandRMS: 0.01,
            differenceRMS: 0,
            interlockChapter: .memory
        ).isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: pulseInstrument
        ))
        let boundaryPeak = fixturePulseEchoDrive(
            scoreEnabled: true,
            earliestPulseEchoOnsetStep: 0,
            driveEligible: true,
            appliedAmount: 0.4,
            currentSendRMS: 0.02,
            postDriveSampleHash: "fedcba9876543210",
            changedFrameIndex: 64,
            changedPreDriveSampleBitPattern: Float(0.02).bitPattern,
            preDrivePeak: preDrivePeak,
            preDrivePeakFrameIndex: 0,
            postDrivePeak: preDrivePeak,
            postDrivePeakFrameIndex: 0,
            postDrivePeakPreDriveSample: preDrivePeak,
            postDrivePeakEffectiveAmount: 0,
            preDriveRMS: 0.08,
            postDriveRMS: 0.09,
            preDriveLowBandRMS: 0.01,
            postDriveLowBandRMS: 0.012,
            differenceRMS: 0.02,
            interlockChapter: .memory
        )
        #expect(boundaryPeak.isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: pulseInstrument
        ))
        #expect(!fixturePulseEchoDrive(
            scoreEnabled: true,
            earliestPulseEchoOnsetStep: 0,
            driveEligible: true,
            appliedAmount: 0.4,
            currentSendRMS: 0.02,
            changedFrameIndex: -1,
            changedPreDriveSampleBitPattern: 0,
            preDrivePeak: preDrivePeak,
            preDrivePeakFrameIndex: 0,
            postDrivePeak: preDrivePeak,
            postDrivePeakFrameIndex: 0,
            postDrivePeakPreDriveSample: preDrivePeak,
            postDrivePeakEffectiveAmount: 0,
            preDriveRMS: 0.08,
            postDriveRMS: 0.08,
            preDriveLowBandRMS: 0.01,
            postDriveLowBandRMS: 0.01,
            differenceRMS: 0,
            interlockChapter: .memory
        ).isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: pulseInstrument
        ))
        #expect(!fixturePulseEchoDrive(
            scoreEnabled: true,
            earliestPulseEchoOnsetStep: 0,
            driveEligible: true,
            appliedAmount: 0.4,
            interlockChapter: .memory
        ).isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: pulseInstrument
        ))
        #expect(!fixturePulseEchoDrive(
            scoreEnabled: true,
            currentSendRMS: 0.02,
            preDrivePeak: preDrivePeak,
            postDrivePeak: preDrivePeak,
            preDriveRMS: 0.08,
            postDriveRMS: 0.08,
            preDriveLowBandRMS: 0.01,
            postDriveLowBandRMS: 0.01
        ).isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: noPulseAccess
        ))

        let nonMemoryBypass = fixturePulseEchoDrive(
            scoreEnabled: true,
            earliestPulseEchoOnsetStep: 0,
            preDrivePeak: preDrivePeak,
            postDrivePeak: preDrivePeak,
            preDriveRMS: 0.08,
            postDriveRMS: 0.08,
            preDriveLowBandRMS: 0.01,
            postDriveLowBandRMS: 0.01,
            interlockChapter: .motion
        )
        #expect(nonMemoryBypass.isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: pulseInstrument
        ))
        let forceHomeBypass = fixturePulseEchoDrive(
            scoreEnabled: true,
            earliestPulseEchoOnsetStep: 0,
            preDrivePeak: preDrivePeak,
            postDrivePeak: preDrivePeak,
            preDriveRMS: 0.08,
            postDriveRMS: 0.08,
            preDriveLowBandRMS: 0.01,
            postDriveLowBandRMS: 0.01,
            interlockChapter: .memory
        )
        let forceHomeVector = fixtureVector(
            slot: .primary,
            instrumentBar: pulseInstrument,
            pulseEchoDriveBars: [forceHomeBypass]
        )
        #expect(forceHomeVector.isComplete)
        #expect(AutonomousCandidateAttempt(
            kind: .correctionRender,
            forceHomeUpperTimbre: true,
            reasonCodes: [],
            vector: forceHomeVector
        ).isStructurallyComplete)
        #expect(!AutonomousCandidateAttempt(
            kind: .initialRender,
            reasonCodes: [],
            vector: forceHomeVector
        ).isStructurallyComplete)
        let lateOnly = fixturePulseEchoDrive(
            scoreEnabled: true,
            earliestPulseEchoOnsetStep: 13,
            currentSendRMS: 0.02,
            preDrivePeak: preDrivePeak,
            postDrivePeak: preDrivePeak,
            preDriveRMS: 0.08,
            postDriveRMS: 0.08,
            preDriveLowBandRMS: 0.01,
            postDriveLowBandRMS: 0.01,
            interlockChapter: .memory
        )
        #expect(lateOnly.isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: pulseInstrument
        ))
        #expect(!lateOnly.normalDriveEligibility(
            phraseKind: .lock,
            conservative: false,
            instruments: pulseInstrument
        ))
        let lateOnlyVector = fixtureVector(
            slot: .primary,
            instrumentBar: pulseInstrument,
            pulseEchoDriveBars: [lateOnly]
        )
        #expect(AutonomousCandidateAttempt(
            kind: .initialRender,
            reasonCodes: [],
            vector: lateOnlyVector
        ).isStructurallyComplete)
        #expect(!fixturePulseEchoDrive(
            scoreEnabled: true,
            earliestPulseEchoOnsetStep: 0,
            driveEligible: true,
            appliedAmount: 0.4,
            postDriveSampleHash: "fedcba9876543210",
            preDrivePeak: preDrivePeak,
            postDrivePeak: activePostDrivePeak,
            preDriveRMS: 0.08,
            postDriveRMS: 0.075,
            preDriveLowBandRMS: 0.01,
            postDriveLowBandRMS: 0.008,
            differenceRMS: 0.012,
            interlockChapter: .motion
        ).isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: pulseInstrument
        ))

        for forcedPhrase in [AutonomousPhraseKind.identityReturn, .majorBreak] {
            #expect(!active.isComplete(
                sampleRate: 8_000,
                phraseKind: forcedPhrase,
                conservative: false,
                instruments: pulseInstrument
            ))
        }
        #expect(!active.isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: true,
            instruments: pulseInstrument
        ))
        let lowLevelPreDrivePeak = Double(Float(0.02))
        let lowLevelPostDrivePeak = abs(Double(
            PulseEchoReturnDriveContract.process(
                preDriveSample: Float(lowLevelPreDrivePeak),
                amount: 0.4
            )
        ))
        #expect(lowLevelPostDrivePeak > lowLevelPreDrivePeak)
        #expect(fixturePulseEchoDrive(
            scoreEnabled: true,
            earliestPulseEchoOnsetStep: 0,
            driveEligible: true,
            appliedAmount: 0.4,
            currentSendRMS: 0.02,
            postDriveSampleHash: "fedcba9876543210",
            preDrivePeak: lowLevelPreDrivePeak,
            postDrivePeak: lowLevelPostDrivePeak,
            preDriveRMS: 0.008,
            postDriveRMS: 0.015,
            preDriveLowBandRMS: 0.001,
            postDriveLowBandRMS: 0.002,
            differenceRMS: 0.008,
            interlockChapter: .memory
        ).isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: pulseInstrument
        ))
        #expect(!fixturePulseEchoDrive(
            scoreEnabled: true,
            earliestPulseEchoOnsetStep: 0,
            driveEligible: true,
            appliedAmount: 0.4,
            currentSendRMS: 0.02,
            postDriveSampleHash: "fedcba9876543210",
            preDrivePeak: preDrivePeak,
            postDrivePeak: activePostDrivePeak,
            preDriveRMS: 0.02,
            postDriveRMS: 0.065,
            preDriveLowBandRMS: 0.005,
            postDriveLowBandRMS: 0.01,
            differenceRMS: 0.05,
            interlockChapter: .memory
        ).isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: pulseInstrument
        ))
        #expect(fixturePulseEchoDrive(
            scoreEnabled: true,
            earliestPulseEchoOnsetStep: 0,
            driveEligible: true,
            machineTexture: 0.8,
            appliedAmount: 0.55,
            currentSendRMS: 0.02,
            postDriveSampleHash: "fedcba9876543210",
            preDrivePeak: preDrivePeak,
            postDrivePeak: cappedPostDrivePeak,
            preDriveRMS: 0.08,
            postDriveRMS: 0.05,
            preDriveLowBandRMS: 0.01,
            postDriveLowBandRMS: 0.008,
            differenceRMS: 0.035,
            interlockChapter: .memory
        ).isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: pulseInstrument
        ))

        #expect(!fixturePulseEchoDrive(delayFrameCount: 2_768).isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: AutonomousInstrumentBarEvidence(bar: 0, evidence: [])
        ))
        #expect(!fixturePulseEchoDrive(renderedFrameCount: 14_768).isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: AutonomousInstrumentBarEvidence(bar: 0, evidence: [])
        ))
        #expect(!fixturePulseEchoDrive(bpm: 129).isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: AutonomousInstrumentBarEvidence(bar: 0, evidence: [])
        ))
        #expect(!fixturePulseEchoDrive(bar: 1).isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: pulseInstrument
        ))
        #expect(!fixturePulseEchoDrive(
            preDrivePeak: 0.08,
            postDrivePeak: 0.08,
            preDriveRMS: 0.08,
            postDriveRMS: 0.08,
            preDriveLowBandRMS: 0.081,
            postDriveLowBandRMS: 0.081
        ).isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: AutonomousInstrumentBarEvidence(bar: 0, evidence: [])
        ))
        #expect(!fixturePulseEchoDrive(
            preDriveLowBandRMS: 0.000_000_1,
            postDriveLowBandRMS: 0.000_000_1
        ).isComplete(
            sampleRate: 8_000,
            phraseKind: .lock,
            conservative: false,
            instruments: AutonomousInstrumentBarEvidence(bar: 0, evidence: [])
        ))
        #expect(!fixturePulseEchoDrive(finite: false).isFinite)

        let oversizedSource = (0..<17).map { bar in
            fixturePulseEchoDrive(bar: bar)
        }
        let constructorBounded = fixtureVector(
            slot: .primary,
            pulseEchoDriveBars: oversizedSource
        )
        #expect(constructorBounded.sourcePulseEchoDriveBarCount == 17)
        #expect(constructorBounded.pulseEchoDrive.count ==
                AutonomousCandidateEvaluationVector.maximumBarCount)
        #expect(!constructorBounded.recordIsStructurallyValid)

        var oversizedObject = object
        let decodedOversizedBars: [[String: Any]] = (0..<17).map { bar in
            var copy = bars[0]
            copy["bar"] = bar
            return copy
        }
        oversizedObject["sourcePulseEchoDriveBarCount"] = 17
        oversizedObject["pulseEchoDrive"] = decodedOversizedBars
        let decodedOversized = try JSONDecoder().decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: oversizedObject)
        )
        #expect(decodedOversized.pulseEchoDrive.count == 17)
        #expect(!decodedOversized.recordIsStructurallyValid)
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
        let oversizedPerceptual = fixturePerceptualEvidence(
            frameCount: 1,
            sampleRate: 8_000
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
            analysisPeakWorkingByteCount:
                oversizedPerceptual.peakWorkingByteCount + 1,
            perceptual: oversizedPerceptual,
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

        var forgedPerceptualObject = try #require(JSONSerialization.jsonObject(
            with: sourceVector.deterministicJSON()
        ) as? [String: Any])
        var forgedPerceptualFullMix = try #require(
            forgedPerceptualObject["fullMix"] as? [String: Any]
        )
        var forgedPerceptual = try #require(
            forgedPerceptualFullMix["perceptual"] as? [String: Any]
        )
        forgedPerceptual["analyzerVersion"] = "forged-analyzer"
        forgedPerceptualFullMix["perceptual"] = forgedPerceptual
        forgedPerceptualObject["fullMix"] = forgedPerceptualFullMix
        let forgedPerceptualVector = try decoder.decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedPerceptualObject)
        )
        #expect(!forgedPerceptualVector.isComplete)
        #expect(forgedPerceptualVector.recordIsStructurallyValid)

        var forgedMemoryObject = try #require(JSONSerialization.jsonObject(
            with: sourceVector.deterministicJSON()
        ) as? [String: Any])
        var forgedMemoryFullMix = try #require(
            forgedMemoryObject["fullMix"] as? [String: Any]
        )
        forgedMemoryFullMix["analysisPeakWorkingByteCount"] =
            AutonomousFullMixEvidence.maximumAnalysisPeakWorkingByteCount + 1
        forgedMemoryObject["fullMix"] = forgedMemoryFullMix
        let forgedMemoryVector = try decoder.decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: forgedMemoryObject)
        )
        #expect(!forgedMemoryVector.isComplete)
        #expect(forgedMemoryVector.recordIsStructurallyValid)

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
        #expect(impossibleStem.completenessFailures == [.levelBounds])
        #expect(sourceVector.completenessFailures.isEmpty)

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

    @Test("Spatial FDN evidence is bounded, deterministic, required, and selection-neutral")
    func spatialFDNEvidenceContract() throws {
        let source = fixtureVector(slot: .primary)
        let evidence = try #require(source.spatialFDN.first)

        #expect(evidence.lineCount == FeedbackDelayNetworkConfiguration.lineCount)
        #expect(evidence.delayFrameCounts.count == evidence.lineCount)
        #expect(evidence.isComplete(routeSampleRate: 8_000))
        #expect(source.sourceSpatialFDNBarCount == 1)
        #expect(source.isComplete)
        #expect(!source.completenessFailures.contains(.spatialFDNEvidence))

        let decoder = JSONDecoder()
        var object = try #require(JSONSerialization.jsonObject(
            with: source.deterministicJSON()
        ) as? [String: Any])
        var bars = try #require(object["spatialFDN"] as? [[String: Any]])

        var changedHashBar = bars[0]
        changedHashBar["wetLeftSampleHash"] = "fedcba9876543210"
        object["spatialFDN"] = [changedHashBar]
        let changedHash = try decoder.decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(changedHash.isComplete)
        #expect(changedHash.fingerprint != source.fingerprint)
        #expect(changedHash.selectionEvidence == source.selectionEvidence)

        let invalidMutations: [(String, Any)] = [
            ("lineCount", 7),
            ("delayFrameCounts", [345, 425, 425, 633, 777, 905, 1097, 1305]),
            ("roomScale", 1.1),
            ("maximumFeedbackGain", 1.0),
            ("bindingValid", false),
            ("wetLeftSampleHash", "not-a-pcm-hash"),
        ]
        for (field, value) in invalidMutations {
            var forgedObject = try #require(JSONSerialization.jsonObject(
                with: source.deterministicJSON()
            ) as? [String: Any])
            var forgedBars = try #require(
                forgedObject["spatialFDN"] as? [[String: Any]]
            )
            forgedBars[0][field] = value
            forgedObject["spatialFDN"] = forgedBars
            let forged = try decoder.decode(
                AutonomousCandidateEvaluationVector.self,
                from: JSONSerialization.data(withJSONObject: forgedObject)
            )
            #expect(!forged.isComplete)
            #expect(forged.completenessFailures.contains(.spatialFDNEvidence))
        }

        var missingObject = try #require(JSONSerialization.jsonObject(
            with: source.deterministicJSON()
        ) as? [String: Any])
        missingObject["spatialFDN"] = []
        missingObject["sourceSpatialFDNBarCount"] = 0
        let missing = try decoder.decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: missingObject)
        )
        #expect(!missing.isComplete)
        #expect(missing.completenessFailures.contains(.spatialFDNEvidence))

        bars.append(bars[0])
        var oversizedObject = try #require(JSONSerialization.jsonObject(
            with: source.deterministicJSON()
        ) as? [String: Any])
        oversizedObject["sourceSpatialFDNBarCount"] = 17
        oversizedObject["spatialFDN"] = Array(repeating: bars[0], count: 17)
        let oversized = try decoder.decode(
            AutonomousCandidateEvaluationVector.self,
            from: JSONSerialization.data(withJSONObject: oversizedObject)
        )
        #expect(oversized.spatialFDN.count == 17)
        #expect(!oversized.recordIsStructurallyValid)
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
        let kickChangedCorrection = AutonomousCandidateAttempt(
            kind: .correctionRender,
            forceHomeUpperTimbre: true,
            reasonCodes: [.evidenceNonFiniteV1, .hardGateFailedV1],
            vector: fixtureVector(
                slot: .primary,
                kickSyntaxBar: fixtureKickSyntax(
                    detectorSampleHash: "aaaaaaaaaaaaaaaa"
                ),
                nonFinite: true
            )
        )
        let kickChangedTransaction = AutonomousCandidateEvaluationTransaction(
            engineVersion: "engine.test.v1",
            policyVersion: "policy.test.v1",
            evaluatorVersion: "evaluator.test.v1",
            planFingerprints: plans,
            attempts: [failedPrimary, alternate, kickChangedCorrection, fallback],
            selectedAttemptIndex: 3,
            selectedSlot: .fallback,
            comparison: .primary,
            correctionCount: 1
        )
        #expect(!kickChangedTransaction.isComplete)
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
                "62565aad578c7ab7")
        #expect(AutonomousCandidateFingerprint.graph(graph42) ==
                "011f35a0373a1e23")
        #expect(AutonomousCandidateFingerprint.renderState(emptyRenderState) ==
                "d6d404790bd651aa")
        #expect(AutonomousCandidateFingerprint.generatedDSPState(orderedGraphState) ==
                "ab9b24221ea4baa5")
        #expect(AutonomousCandidateFingerprint.qualityState(initialQuality) ==
                "1d26ee6f170727a7")
        #expect(AutonomousCandidateFingerprint.route(
            sampleRate: 48_000,
            generation: 7
        ) == "dbc523a48a82ad69")
        #expect(AutonomousCandidateFingerprint.renderDSPContinuation(
            renderState: positiveZeroRenderState,
            generatedDSPState: orderedGraphState
        ) == "1cd07aec247972a1")
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
        evidenceBar: Int = 0,
        phraseKind: AutonomousPhraseKind? = nil,
        planFingerprintOverride: String? = nil,
        kickSyntaxBar: AutonomousKickSyntaxBarEvidence? = nil,
        climaxArc: AutonomousClimaxArcEvidence? = nil,
        groovePulseBar: AutonomousGroovePulseBarEvidence? = nil,
        closedHatBar: AutonomousClosedHatBarEvidence? = nil,
        instrumentBar: AutonomousInstrumentBarEvidence? = nil,
        percussionEchoTextureBar:
            AutonomousPercussionEchoTextureBarEvidence? = nil,
        pulseEchoDriveBars: [AutonomousPulseEchoDriveBarEvidence]? = nil,
        spatialFDNBar: AutonomousSpatialFDNBarEvidence? = nil,
        upperTimingBars: [AutonomousUpperTimingBarEvidence]? = nil,
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
            startBar: evidenceBar,
            declaredBarCount: 1,
            resolvedBarCount: 1,
            phraseKind: (phraseKind ?? (slot == .fallback
                ? AutonomousPhraseKind.identityReturn
                : AutonomousPhraseKind.lock)).rawValue,
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
        let perceptual = fixturePerceptualEvidence(
            frameCount: upper.analyzedFrameCount,
            sampleRate: upper.sampleRate,
            finite: !nonFinite
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
            analysisPeakWorkingByteCount:
                perceptual.peakWorkingByteCount + 1,
            perceptual: perceptual,
            bars: [AutonomousBarFullMixEvidence(
                bar: evidenceBar,
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
        let explicitPulseEchoChapter = pulseEchoDriveBars?.first.flatMap {
            InterlockChapter(rawValue: $0.interlockChapter)
        }
        let resolvedUpperTimingBars = upperTimingBars ?? [
            fixtureUpperTiming(
                bar: evidenceBar,
                chapter: explicitPulseEchoChapter ?? .home
            ),
        ]
        let defaultTiming = resolvedUpperTimingBars.first
        let defaultTimingChapter = defaultTiming.flatMap {
            InterlockChapter(rawValue: $0.chapter)
        } ?? .home
        return AutonomousCandidateEvaluationVector(
            slot: slot,
            planFingerprint: planFingerprint,
            graphFingerprint: graphFingerprint,
            symbolic: symbolic,
            hardGates: hardGates,
            fullMix: fullMix,
            masking: [AutonomousMaskingBarEvidence(
                bar: evidenceBar,
                sourceObservationCount: maskingSourceCount,
                observations: maskingObservations
            )],
            stems: [AutonomousStemBarEvidence(
                bar: evidenceBar,
                sourceRoleCount: stemSourceRoleCount,
                roles: roles
            )],
            automaticMix: [AutonomousAutomaticMixEvidence(
                bar: evidenceBar,
                section: SectionKind.breakdown.rawValue,
                foundationCompanion: FoundationCompanion.bass.rawValue,
                gains: gains,
                measuredKickOverFoundationDB: nil,
                targetKickOverFoundationDB: nil
            )],
            kickSyntax: [kickSyntaxBar ?? fixtureKickSyntax(bar: evidenceBar)],
            climaxArc: climaxArc ?? .inactive(releaseStartBar: evidenceBar),
            groovePulse: [groovePulseBar ?? AutonomousGroovePulseBarEvidence(
                bar: evidenceBar,
                sourceScoreEventCount: 0,
                sourceRenderEventCount: 0,
                events: []
            )],
            closedHat: [closedHatBar ?? AutonomousClosedHatBarEvidence(
                bar: evidenceBar,
                sourceScoreEventCount: 0,
                sourceRenderEventCount: 0,
                events: []
            )],
            instruments: [instrumentBar ?? AutonomousInstrumentBarEvidence(
                bar: evidenceBar,
                evidence: []
            )],
            percussionEchoTexture: [
                percussionEchoTextureBar ?? .neutral(
                    bar: evidenceBar,
                    sampleRate: 8_000
                ),
            ],
            phraseComposition: [.neutral(bar: evidenceBar)],
            pulseEchoDrive: pulseEchoDriveBars ?? [fixturePulseEchoDrive(
                bar: evidenceBar,
                renderedFrameCount: defaultTiming?.renderedFrameCount ?? 14_769,
                interlockChapter: defaultTimingChapter
            )],
            spatialFDN: [spatialFDNBar ?? .neutral(
                bar: evidenceBar,
                sampleRate: 8_000
            )],
            upperTiming: resolvedUpperTimingBars,
            graph: graph,
            routeContinuation: route,
            preGraphUpperTimbreEvidence: upper,
            postGraphUpperTimbreEvidence: upper
        )
    }

    private func fixtureKickSyntax(
        bar: Int = 0,
        role: KickSyntaxRole = .grounded,
        scoreKickEventCount: Int = 1,
        scoreKickStepMask: UInt16 = 1,
        renderedKickEventCount: Int = 1,
        renderedKickStepMask: UInt16 = 1,
        renderedFrameCount: Int = 14_769,
        audibleGain: Double = KickMixBalance.audibleGain * Double(
            Float(pow(10, AutomaticMixBalancer.homeKickCorrectionDB / 20))
        ),
        detectorPeak: Double = 0.6,
        detectorRMS: Double = 0.12,
        audiblePeak: Double = 0.5,
        audibleRMS: Double = 0.1,
        duckingEnvelopePeak: Double = 0.4,
        detectorSampleHash: String = "0123456789abcdef",
        audibleSampleHash: String = "fedcba9876543210",
        detectorNonzeroSampleCount: Int = 1_024,
        audibleNonzeroSampleCount: Int = 1_024,
        detectorToAudibleScaleMatches: Bool = true,
        renderPassesMatch: Bool = true,
        bindingValid: Bool = true
    ) -> AutonomousKickSyntaxBarEvidence {
        AutonomousKickSyntaxBarEvidence(
            bar: bar,
            role: role,
            scoreKickEventCount: scoreKickEventCount,
            scoreKickStepMask: scoreKickStepMask,
            renderedKickEventCount: renderedKickEventCount,
            renderedKickStepMask: renderedKickStepMask,
            renderedFrameCount: renderedFrameCount,
            audibleGain: audibleGain,
            detectorPeak: detectorPeak,
            detectorRMS: detectorRMS,
            audiblePeak: audiblePeak,
            audibleRMS: audibleRMS,
            duckingEnvelopePeak: duckingEnvelopePeak,
            detectorSampleHash: detectorSampleHash,
            audibleSampleHash: audibleSampleHash,
            detectorNonzeroSampleCount: detectorNonzeroSampleCount,
            audibleNonzeroSampleCount: audibleNonzeroSampleCount,
            detectorToAudibleScaleMatches: detectorToAudibleScaleMatches,
            renderPassesMatch: renderPassesMatch,
            bindingValid: bindingValid
        )
    }

    private func fixturePercussionEchoTexture(
        bar: Int = 0
    ) -> AutonomousPercussionEchoTextureBarEvidence {
        let sampleRate = 8_000.0
        let renderedFrameCount = Int((
            240.0 / AutonomousSessionDirector.bpm * sampleRate
        ).rounded())
        let inputStep = 3
        let outputStartStep = inputStep +
            PercussionEchoTextureResolver.outputDelayInSteps
        let outputEndStep = outputStartStep +
            PercussionEchoTextureResolver.outputWindowLengthInSteps
        func frame(_ step: Int) -> Int {
            Int((Double(step) * Double(renderedFrameCount) / 16.0).rounded())
        }
        let inputWindowFrameCount = frame(inputStep + 1) - frame(inputStep)
        let outputWindowFrameCount = frame(outputEndStep) -
            frame(outputStartStep)
        let evidence = PercussionEchoTextureRenderEvidence(
            active: true,
            bpm: AutonomousSessionDirector.bpm,
            sampleRate: sampleRate,
            inputStep: inputStep,
            outputStartStep: outputStartStep,
            outputEndStep: outputEndStep,
            renderedFrameCount: renderedFrameCount,
            inputWindowFrameCount: inputWindowFrameCount,
            outputWindowFrameCount: outputWindowFrameCount,
            delayFrameCount: max(
                1,
                Int((Double(renderedFrameCount) / 16.0).rounded())
            ),
            transitionFrameCount:
                PercussionEchoTextureVoice.transitionFrameCount(
                    sampleRate: sampleRate
                ),
            inputSampleHash: "1111111111111111",
            returnSampleHash: "2222222222222222",
            inputPeak: 0.08,
            inputRMS: 0.02,
            returnPeak: 0.04,
            returnRMS: 0.01,
            inputNonzeroSampleCount: 100,
            returnNonzeroSampleCount: 300,
            outOfWindowNonzeroSampleCount: 0,
            firstOutputSampleBitPattern: 0,
            lastOutputSampleBitPattern: 0,
            finite: true
        )
        return AutonomousPercussionEchoTextureBarEvidence(
            evidence,
            bar: bar,
            performanceCharacter: .brokenSuspension,
            arrangementGesture: .gearShift,
            eligibleSourceStepMask: UInt16(1 << inputStep),
            renderPassesMatch: true,
            bindingValid: true
        )
    }

    private func fixtureUpperTiming(
        bar: Int = 0,
        chapter: InterlockChapter = .home,
        relation: UpperTimingRelation? = nil,
        performanceCharacter: PerformanceCharacter = .hypnoticLock,
        renderedFrameCount: Int = 14_769,
        sourceScoreNoteCount: Int = 0,
        sourceRenderEventCount: Int = 0,
        anchorEventCount: Int = 0,
        activeOffsetCount: Int = 0,
        protectedRoleActiveOffsetCount: Int = 0,
        anchorActiveOffsetCount: Int = 0,
        minimumOffsetInSteps: Double = 0,
        maximumOffsetInSteps: Double = 0,
        maximumRoleSpreadInSteps: Double = 0,
        anchorMinimumOffsetInSteps: Double = 0,
        anchorMaximumOffsetInSteps: Double = 0,
        shadowMinimumOffsetInSteps: Double? = nil,
        shadowMaximumOffsetInSteps: Double? = nil,
        responseMinimumOffsetInSteps: Double? = nil,
        responseMaximumOffsetInSteps: Double? = nil,
        scoreFingerprint: String = "0123456789abcdef",
        renderFingerprint: String = "0123456789abcdef",
        appliedGateFingerprint: String = "89abcdef01234567",
        shadowEventCount: Int = 0,
        shadowHash: String = "1111111111111111",
        shadowPeak: Double = 0,
        shadowRMS: Double = 0,
        responseEventCount: Int = 0,
        responseHash: String = "2222222222222222",
        responsePeak: Double = 0,
        responseRMS: Double = 0,
        anchorHash: String = "3333333333333333",
        anchorPeak: Double? = nil,
        anchorRMS: Double? = nil,
        bindingValid: Bool = true,
        finite: Bool = true
    ) -> AutonomousUpperTimingBarEvidence {
        let fullDepth = ResolvedUpperNote.maximumTimingOffsetInSteps *
            SynthPerformancePlan.upperTimingAperture(absoluteBar: bar)
        let defaultShadowOffset = activeOffsetCount > 0 && shadowEventCount > 0
            ? fullDepth * 0.5 : 0
        let defaultResponseOffset = activeOffsetCount > 0 && responseEventCount > 0
            ? fullDepth : 0
        return AutonomousUpperTimingBarEvidence(
            bar: bar,
            chapter: chapter,
            relation: relation ?? (activeOffsetCount > 0
                ? .harmonicCascade : .aligned),
            performanceCharacter: performanceCharacter,
            bpm: AutonomousSessionDirector.bpm,
            sampleRate: 8_000,
            renderedFrameCount: renderedFrameCount,
            sourceScoreNoteCount: sourceScoreNoteCount,
            sourceRenderEventCount: sourceRenderEventCount,
            anchorEventCount: anchorEventCount,
            activeOffsetCount: activeOffsetCount,
            protectedRoleActiveOffsetCount: protectedRoleActiveOffsetCount,
            anchorActiveOffsetCount: anchorActiveOffsetCount,
            minimumOffsetInSteps: minimumOffsetInSteps,
            maximumOffsetInSteps: maximumOffsetInSteps,
            maximumRoleSpreadInSteps: maximumRoleSpreadInSteps,
            anchorMinimumOffsetInSteps: anchorMinimumOffsetInSteps,
            anchorMaximumOffsetInSteps: anchorMaximumOffsetInSteps,
            anchorOffsetPatternFingerprint:
                AutonomousUpperTimingBarEvidence.offsetPatternFingerprint(
                    (0..<anchorEventCount).map { index in
                        relation == .leadPerformance
                            ? SynthPerformancePlan.leadPerformanceOffsetInSteps(
                                performanceIndex: index
                            )
                            : 0
                    }
                ),
            shadowMinimumOffsetInSteps:
                shadowMinimumOffsetInSteps ?? defaultShadowOffset,
            shadowMaximumOffsetInSteps:
                shadowMaximumOffsetInSteps ?? defaultShadowOffset,
            responseMinimumOffsetInSteps:
                responseMinimumOffsetInSteps ?? defaultResponseOffset,
            responseMaximumOffsetInSteps:
                responseMaximumOffsetInSteps ?? defaultResponseOffset,
            scoreFingerprint: scoreFingerprint,
            renderFingerprint: renderFingerprint,
            appliedGateFingerprint: appliedGateFingerprint,
            anchorSignal: AutonomousUpperTimingRoleSignalEvidence(
                role: .anchor,
                eventCount: anchorEventCount,
                sampleHash: anchorHash,
                peak: anchorPeak ?? (anchorEventCount > 0 ? 0.05 : 0),
                rms: anchorRMS ?? (anchorEventCount > 0 ? 0.012 : 0),
                finite: finite
            ),
            shadowSignal: AutonomousUpperTimingRoleSignalEvidence(
                role: .shadow,
                eventCount: shadowEventCount,
                sampleHash: shadowHash,
                peak: shadowPeak,
                rms: shadowRMS,
                finite: finite
            ),
            responseSignal: AutonomousUpperTimingRoleSignalEvidence(
                role: .response,
                eventCount: responseEventCount,
                sampleHash: responseHash,
                peak: responsePeak,
                rms: responseRMS,
                finite: finite
            ),
            bindingValid: bindingValid,
            finite: finite
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

    private func fixtureClosedHatEvent(
        scoreEventIndex: Int = 1,
        step: Int = 3,
        role: ClosedHatDecayRole = .neutral,
        roleRawValue: String? = nil,
        intensity: Double = 0.52,
        timingOffsetInSteps: Double = 0.06,
        relocated: Bool = false,
        decayRateScale: Double = 1,
        renderedFrameCount: Int = 400,
        sampleHash: String = "0123456789abcdef",
        sourceRMS: Double = 0.012,
        spectralCentroidHz: Double = 2_400,
        tailToAttackDB: Double = -18,
        finite: Bool = true
    ) -> AutonomousClosedHatEventEvidence {
        AutonomousClosedHatEventEvidence(
            scoreEventIndex: scoreEventIndex,
            step: step,
            role: roleRawValue ?? role.rawValue,
            intensity: intensity,
            timingOffsetInSteps: timingOffsetInSteps,
            relocated: relocated,
            decayRateScale: decayRateScale,
            renderedFrameCount: renderedFrameCount,
            sampleHash: sampleHash,
            sourceRMS: sourceRMS,
            spectralCentroidHz: spectralCentroidHz,
            tailToAttackDB: tailToAttackDB,
            finite: finite
        )
    }

    private func fixturePulseEchoDrive(
        bar: Int = 0,
        bpm: Double = 130,
        delayFrameCount: Int = 2_769,
        scoreEnabled: Bool = false,
        earliestPulseEchoOnsetStep: Int? = nil,
        driveEligible: Bool = false,
        machineTexture: Double = 0.4,
        appliedAmount: Double = 0,
        transitionFrameCount: Int = 64,
        renderedFrameCount: Int = 14_769,
        currentSendRMS: Double = 0,
        preDriveSampleHash: String = "0123456789abcdef",
        postDriveSampleHash: String = "0123456789abcdef",
        firstPreDriveSampleBitPattern: UInt32 = 0,
        firstPostDriveSampleBitPattern: UInt32 = 0,
        lastPreDriveSampleBitPattern: UInt32 = 0,
        lastPostDriveSampleBitPattern: UInt32 = 0,
        changedFrameIndex: Int? = nil,
        changedPreDriveSampleBitPattern: UInt32? = nil,
        preDrivePeak: Double = 0,
        preDrivePeakFrameIndex: Int? = nil,
        postDrivePeak: Double = 0,
        postDrivePeakFrameIndex: Int? = nil,
        postDrivePeakPreDriveSample: Double? = nil,
        postDrivePeakEffectiveAmount: Double? = nil,
        preDriveRMS: Double = 0,
        postDriveRMS: Double = 0,
        preDriveLowBandRMS: Double = 0,
        postDriveLowBandRMS: Double = 0,
        differenceRMS: Double = 0,
        interlockChapter: InterlockChapter = .home,
        finite: Bool = true
    ) -> AutonomousPulseEchoDriveBarEvidence {
        let inputPeakFrameIndex = preDrivePeakFrameIndex ??
            (appliedAmount > 0 ? transitionFrameCount : 0)
        let firstChangedFrameIndex = changedFrameIndex ??
            (appliedAmount > 0 ? transitionFrameCount : -1)
        let firstChangedPreDriveSampleBitPattern =
            changedPreDriveSampleBitPattern ??
            (appliedAmount > 0 ? Float(preDrivePeak).bitPattern : 0)
        let peakFrameIndex = postDrivePeakFrameIndex ??
            (appliedAmount > 0 ? transitionFrameCount : 0)
        let peakPreDriveSample = postDrivePeakPreDriveSample ?? preDrivePeak
        let peakEffectiveAmount = postDrivePeakEffectiveAmount ??
            PulseEchoReturnDriveContract.effectiveAmount(
                targetAmount: appliedAmount,
                frame: peakFrameIndex,
                totalFrameCount: renderedFrameCount,
                transitionFrameCount: transitionFrameCount
            )
        return AutonomousPulseEchoDriveBarEvidence(
            bar: bar,
            bpm: bpm,
            delayFrameCount: delayFrameCount,
            scoreEnabled: scoreEnabled,
            earliestPulseEchoOnsetStep: earliestPulseEchoOnsetStep,
            driveEligible: driveEligible,
            machineTexture: machineTexture,
            appliedAmount: appliedAmount,
            transitionFrameCount: transitionFrameCount,
            renderedFrameCount: renderedFrameCount,
            currentSendRMS: currentSendRMS,
            preDriveSampleHash: preDriveSampleHash,
            postDriveSampleHash: postDriveSampleHash,
            firstPreDriveSampleBitPattern: firstPreDriveSampleBitPattern,
            firstPostDriveSampleBitPattern: firstPostDriveSampleBitPattern,
            lastPreDriveSampleBitPattern: lastPreDriveSampleBitPattern,
            lastPostDriveSampleBitPattern: lastPostDriveSampleBitPattern,
            changedFrameIndex: firstChangedFrameIndex,
            changedPreDriveSampleBitPattern:
                firstChangedPreDriveSampleBitPattern,
            preDrivePeak: preDrivePeak,
            preDrivePeakFrameIndex: inputPeakFrameIndex,
            postDrivePeak: postDrivePeak,
            postDrivePeakFrameIndex: peakFrameIndex,
            postDrivePeakPreDriveSample: peakPreDriveSample,
            postDrivePeakEffectiveAmount: peakEffectiveAmount,
            preDriveRMS: preDriveRMS,
            postDriveRMS: postDriveRMS,
            preDriveLowBandRMS: preDriveLowBandRMS,
            postDriveLowBandRMS: postDriveLowBandRMS,
            differenceRMS: differenceRMS,
            interlockChapter: interlockChapter,
            finite: finite
        )
    }

    private func fixturePulseEchoInstrumentBar(
        effects: [InstrumentEffect]? = nil
    ) -> AutonomousInstrumentBarEvidence {
        let assignment = InstrumentAssignment(
            use: .motif,
            patch: .acidSequence,
            automation: InstrumentAutomation(
                color: 0.62,
                shape: 0.48,
                motion: 0.78,
                space: 0.22
            ),
            effects: effects ??
                (InstrumentPalette.capability(for: .acidSequence)?.compatibleEffects ?? [])
        )
        return AutonomousInstrumentBarEvidence(
            bar: 0,
            evidence: [InstrumentArchitectureRenderEvidence(
                architecture: .resonantMono,
                assignments: [assignment],
                patches: [.acidSequence],
                uses: [.motif],
                effects: assignment.effects,
                eventCount: 1,
                sampleHash: "0123456789abcdef",
                peak: 0.20,
                rms: 0.08,
                finite: true,
                nonlinearCore:
                    fixtureTPTAntialiasedNonlinearCoreRenderEvidence(),
                resonantMonoModulation:
                    fixtureResonantMonoModulationRenderEvidence()
            )]
        )
    }

    private func fixtureResonantMonoModulationRenderEvidence(
        bindingValid: Bool = true,
        lowBandEnergyRatio: Double = 0.12
    ) -> ResonantMonoModulationRenderEvidence {
        ResonantMonoModulationRenderEvidence(
            sourceAssignmentCount: 1,
            eventCount: 1,
            orderedEventCount: 0,
            metallicEventCount: 1,
            orderedModulatorRatio: 0,
            metallicModulatorRatio: 1.414_213_562_373_095_1,
            maximumRequestedPeakIndex: 1.62,
            minimumAppliedPeakIndex: 1.20,
            maximumAppliedPeakIndex: 1.20,
            eventFingerprint: "fedcba9876543210",
            operatorSampleHash: "0123456789abcdef",
            operatorPeak: 0.20,
            operatorRMS: 0.08,
            operatorCrestFactor: 2.5,
            lowBandEnergyRatio: lowBandEnergyRatio,
            bindingValid: bindingValid,
            finite: true
        )
    }

    private func fixtureTPTAntialiasedNonlinearCoreRenderEvidence(
        bindingValid: Bool = true
    ) -> TPTAntialiasedNonlinearCoreRenderEvidence {
        TPTAntialiasedNonlinearCoreRenderEvidence(
            version: TPTAntialiasedNonlinearCoreContract.version,
            antialiasOrder: TPTAntialiasedNonlinearCoreContract.antialiasOrder,
            sourceAssignmentCount: 1,
            sourceEventCount: 1,
            processedSampleCount: 800,
            minimumCutoffHz: 80,
            maximumCutoffHz: 1_200,
            minimumQ: 0.8,
            maximumQ: 3.0,
            minimumInputDrive: 1.0,
            maximumInputDrive: 2.0,
            minimumOutputDrive: 1.1,
            maximumOutputDrive: 1.5,
            minimumBandMix: 0.05,
            maximumBandMix: 0.20,
            inputSampleHash: "0123456789abcdef",
            outputSampleHash: "fedcba9876543210",
            inputPeak: 1,
            inputRMS: 0.5,
            outputPeak: 0.20,
            outputRMS: 0.08,
            bindingValid: bindingValid,
            finite: true
        )
    }

    private func fixturePerceptualEvidence(
        frameCount: Int,
        sampleRate: Double,
        finite: Bool = true
    ) -> StreamingPerceptualEvidence {
        var samples = [Float](repeating: 0, count: frameCount)
        if !finite, !samples.isEmpty { samples[samples.count - 1] = .nan }
        guard let evidence = StreamingPerceptualEvidenceAnalyzer.analyze(
            left: samples,
            right: samples,
            sampleRate: sampleRate
        ) else {
            preconditionFailure("Non-cancellable perceptual fixture stopped")
        }
        return evidence
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
