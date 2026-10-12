import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Source-terminal de-clicking")
struct SourceTerminalDeclickTests {
    @MainActor
    @Test("Canonical full-phrase rumble support reaches candidate admission")
    func algorithmicRumbleFullPhraseSupport() throws {
        struct Support: Encodable {
            let bar: Int
            let scoreEventIndex: Int
            let step: Int
            let barFrames: Int
            let expectedFrames: Int
            let renderedFrames: Int
            let terminalComplete: Bool
            let admissionComplete: Bool
        }
        struct Row: Encodable {
            let rootSeed: UInt64
            let sampleRate: Int
            let planFingerprint: String
            let graphFingerprint: String
            let sampleHash: String
            let frameCount: Int
            let scoreRumbleEvents: Int
            let support: [Support]
            let exactReplay: Bool
            let preparedProductPresent: Bool
            let preparedMatchesDirectRender: Bool?
            let vectorComplete: Bool
            let transactionComplete: Bool
            let audioSafetyValid: Bool?
            let evaluationHardGatesPassed: Bool
            let commitEligible: Bool
            let commitFailureDiagnostics: [String]
            let preparationFailure: String?
        }
        var rows: [Row] = []
        // Frozen mutation protocol: known roots, first score-only phrase with a
        // positive step-zero rumble, no output-based selection. The independent
        // integer oracle never calls the source-duration admission predicate.
        // The normal test expects valid production. An isolated mutation build
        // changes source duration before the same nonlinear render; its expected
        // test failures and emitted report are checked outside the shipping code.
        for seed: UInt64 in [1, 6011] {
            let director = AutonomousSessionDirector(rootSeed: seed)
            var session = director.initialState()
            var selected: AutonomousPhrasePlan?
            for _ in 0..<128 {
                let plan = director.plan(from: session)
                if plan.resolvedBars.contains(where: { bar in
                    bar.ensemble.events.contains { $0.voice == .rumble && $0.step == 0 && $0.intensity > 0 }
                }) { selected = plan; break }
                session.advancePlanning(using: plan)
            }
            let plan = try #require(selected)
            let scoreCount = plan.resolvedBars.flatMap(\.ensemble.events).filter { $0.voice == .rumble }.count
            for rate in [44_100.0, 48_000.0] {
                let graph = DSPGraphGenerator.plan(sessionSeed: seed, phrase: plan,
                    memory: session.memory, previous: nil)
                var incoming = RenderState(); incoming.barIndex = plan.startBar
                let incomingGraph = GeneratedDSPContinuationState()
                var outgoing = incoming; var outgoingGraph = incomingGraph
                let blocksResult = AutonomousPhraseRenderer.renderIfNotCancelled(
                    plan: plan, graph: graph, sampleRate: rate, state: &outgoing,
                    graphState: &outgoingGraph, cancellationRequested: { false })
                let blocks = try #require(blocksResult)
                let preflightResult = PhraseAudioPreflight(blocks: blocks, sampleRate: rate,
                    cancellationRequested: { false })
                let preflight = try #require(preflightResult)
                var support: [Support] = []
                for block in blocks {
                    for event in block.sourceTerminalDeclickRenderEvidence where event.voice == .rumble {
                        let start = (event.step * block.left.count + 8) / 16
                        let expected = min(Int(rate) * 17 / 25, block.left.count - start)
                        support.append(Support(bar: block.bar, scoreEventIndex: event.scoreEventIndex,
                            step: event.step, barFrames: block.left.count, expectedFrames: expected,
                            renderedFrames: event.renderedFrameCount,
                            terminalComplete: event.isComplete(sampleRate: rate),
                            admissionComplete: event.isComplete(sampleRate: rate,
                                destinationFrameCount: block.left.count)))
                    }
                }
                try #require(support.count == scoreCount && !support.isEmpty)
                #expect(support.allSatisfy { $0.expectedFrames == $0.renderedFrames })
                #expect(support.allSatisfy { $0.terminalComplete && $0.admissionComplete })
                var replayState = incoming; var replayGraph = incomingGraph
                let replay = try #require(AutonomousPhraseRenderer.renderIfNotCancelled(
                    plan: plan, graph: graph, sampleRate: rate, state: &replayState,
                    graphState: &replayGraph, cancellationRequested: { false }))
                let exactReplay = replay == blocks &&
                    AutonomousCandidateFingerprint.renderDSPContinuation(renderState: replayState,
                        generatedDSPState: replayGraph) ==
                    AutonomousCandidateFingerprint.renderDSPContinuation(renderState: outgoing,
                        generatedDSPState: outgoingGraph)
                #expect(exactReplay)
                let outcome = AutonomousPhrasePreparer.prepareDiagnosingIfNotCancelled(
                    plan: plan, sessionSeed: seed, memory: session.memory, sampleRate: rate,
                    incomingRenderState: incoming, incomingGraphState: incomingGraph, previousGraph: nil,
                    incomingQualityState: session.quality, evaluator: AcceptingPrimaryTestEvaluator(),
                    cancellationRequested: { false })
                let prepared = outcome.preparedPhrase
                let matches = prepared.map { $0.blocks == blocks }
                let vectorComplete = prepared?.selectedCandidateEvidence.isComplete ?? false
                let transactionComplete = prepared?.candidateEvaluation.isComplete ?? false
                #expect(prepared != nil && vectorComplete && transactionComplete)
                #expect(prepared?.selectedCandidateEvidence.hardGates.audioSafetyValid == true)
                if let matches { #expect(matches) }
                rows.append(Row(rootSeed: seed, sampleRate: Int(rate),
                    planFingerprint: AutonomousCandidateFingerprint.plan(plan),
                    graphFingerprint: AutonomousCandidateFingerprint.graph(graph),
                    sampleHash: preflight.quality.sampleHash,
                    frameCount: blocks.reduce(0) { $0 + $1.left.count }, scoreRumbleEvents: scoreCount,
                    support: support, exactReplay: exactReplay, preparedProductPresent: prepared != nil,
                    preparedMatchesDirectRender: matches, vectorComplete: vectorComplete,
                    transactionComplete: transactionComplete,
                    audioSafetyValid: prepared?.selectedCandidateEvidence.hardGates.audioSafetyValid,
                    evaluationHardGatesPassed: prepared?.selectedCandidateEvidence.hardGatesPassed ?? false,
                    commitEligible: prepared?.commitEligible ?? false,
                    commitFailureDiagnostics: prepared?.commitFailureDiagnostics ?? [],
                    preparationFailure: outcome.failure.map { $0.stage.rawValue + ":" + $0.code.rawValue }))
            }
        }
        #expect(rows.count == 4)
        struct Report: Encodable {
            let schema = "autotechno-rumble-full-phrase-source-support.v1"
            let scope = "canonical-nonlinear-render-and-preparer-duration-binding"
            let rows: [Row]
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(Report(rows: rows)))
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    @Test("Raised-cosine release preserves the first 8 ms and reaches exact zero")
    func physicalTimeGeometry() {
        for sampleRate in [44_100.0, 48_000.0] {
            for (voice, duration, fadeSeconds) in [
                (EnsembleVoice.kick, 0.32, 0.004),
                (.rumble, 0.68, 0.004),
                (.clap, 0.16, 0.002),
                (.openHat, 0.19, 0.002),
                (.metallic, 0.065, 0.002),
            ] {
                let frameCount = Int(sampleRate * duration)
                let attackFrames = SourceTerminalDeclickContract
                    .attackFrameCount(
                        sampleRate: sampleRate,
                        renderedFrameCount: frameCount
                    )
                let fadeFrames = SourceTerminalDeclickContract.fadeFrameCount(
                    voice: voice,
                    sampleRate: sampleRate,
                    renderedFrameCount: frameCount
                )
                let multipliers = (0..<frameCount).map { frame in
                    SourceTerminalDeclickContract.multiplier(
                        voice: voice,
                        frame: frame,
                        renderedFrameCount: frameCount,
                        sampleRate: sampleRate
                    )
                }

                #expect(attackFrames == Int((sampleRate * 0.008).rounded()))
                #expect(fadeFrames == Int((sampleRate * fadeSeconds).rounded()))
                #expect(multipliers.prefix(attackFrames).allSatisfy { $0 == 1 })
                #expect(multipliers[frameCount - fadeFrames - 1] == 1)
                #expect(multipliers[frameCount - fadeFrames] == 1)
                #expect(multipliers.last?.bitPattern == 0)
                #expect(zip(multipliers, multipliers.dropFirst()).allSatisfy {
                    $0 >= $1
                })
                #expect(multipliers.allSatisfy {
                    $0.isFinite && $0 >= 0 && $0 <= 1
                })
            }
        }
    }

    @Test("Event-local evidence proves exact attack identity and zero terminal delta")
    func eventEvidence() {
        for sampleRate in [44_100.0, 48_000.0] {
            for (index, voice) in [
                EnsembleVoice.kick,
                .rumble,
                .clap,
                .openHat,
                .metallic,
            ].enumerated() {
                let frameCount = Int(sampleRate * 0.08)
                var evidence = SourceTerminalDeclickEvidenceAccumulator(
                    scoreEventIndex: index,
                    voice: voice,
                    step: index * 2,
                    sampleRate: sampleRate,
                    renderedFrameCount: frameCount
                )
                for frame in 0..<frameCount {
                    let source = Float(0.2 + 0.1 *
                        sin(Double(frame) * 0.017))
                    let rendered = SourceTerminalDeclickContract.process(
                        sample: source,
                        voice: voice,
                        frame: frame,
                        renderedFrameCount: frameCount,
                        sampleRate: sampleRate
                    )
                    evidence.append(
                        frame: frame,
                        preFade: source,
                        rendered: rendered
                    )
                }

                let result = evidence.evidence
                #expect(result.isComplete(sampleRate: sampleRate))
                #expect(!result.isComplete(sampleRate: sampleRate * 0.5))
                #expect(result.preFadeAttackSampleHash ==
                        result.renderedAttackSampleHash)
                #expect(result.preFadeLastSampleBitPattern != 0)
                #expect(result.renderedLastSampleBitPattern == 0)
                #expect(result.preFadeTerminalDelta > 0)
                #expect(result.renderedTerminalDelta.bitPattern == 0)
                #expect(result.changedSampleCount == result.fadeFrameCount - 1)
            }
        }
    }

    @Test("AT-0039 rumble support distinguishes bar clipping from unauthorized shortening")
    func algorithmicRumbleDurationFaults() throws {
        // Freeze support before PCM: the existing source lasts 17/25 second,
        // clipped only by the original destination boundary. Roots/rates share
        // one constructor and cannot supply population uncertainty.
        var rows: [[String: Any]] = []
        for (seed, split) in [(UInt64(1), "development"), (UInt64(6011), "held-out-root")] {
            for rate in [44_100.0, 48_000.0] {
                let barFrames = Int((240.0 / 130.0 * rate).rounded())
                let naturalFrames = Int(rate) * 17 / 25
                for step in [0, 15] {
                    let start = Int((Double(step) * Double(barFrames) / 16).rounded())
                    let expectedFrames = min(naturalFrames, barFrames - start)
                    var reference = [Float](repeating: 0, count: barFrames)
                    var referenceMeasurement = reference
                    let referenceEvidence = try #require(VoiceRenderer.rumble(&reference,
                        measurement: &referenceMeasurement, scoreEventIndex: 0, start: start,
                        sampleRate: rate, level: 0.072, seed: seed, step: step))
                    #expect(reference == referenceMeasurement)
                    #expect(referenceEvidence.renderedFrameCount == expectedFrames)
                    for shortened in [false, true] {
                        let suppliedFrames = shortened ? start + expectedFrames / 2 : barFrames
                        var actual = [Float](repeating: 0, count: suppliedFrames)
                        var measurement = actual
                        let evidence = try #require(VoiceRenderer.rumble(&actual,
                            measurement: &measurement, scoreEventIndex: 0, start: start,
                            sampleRate: rate, level: 0.072, seed: seed, step: step))
                        #expect(actual == measurement)
                        let declickComplete = evidence.isComplete(sampleRate: rate)
                        let supportBinding = evidence.renderedFrameCount == expectedFrames
                        #expect(declickComplete) // Valid de-clicking does not prove duration.
                        #expect(supportBinding == !shortened)
                        // Exercise the same source-support predicate used by
                        // candidate audio-safety admission, not only the oracle.
                        #expect(evidence.isComplete(sampleRate: rate,
                            destinationFrameCount: barFrames) == supportBinding)
                        let suppliedSupport = min(naturalFrames, suppliedFrames - start)
                        #expect(evidence.renderedFrameCount == suppliedSupport)
                        // The fault is applied before canonical rendering. Zero
                        // extension only aligns source outputs for comparison;
                        // it is never used as a nonlinear-mix counterfactual.
                        let aligned = actual + [Float](repeating: 0, count: barFrames - actual.count)
                        let protectedEnd = start + evidence.renderedFrameCount - evidence.fadeFrameCount
                        #expect(Array(aligned.prefix(protectedEnd)) == Array(reference.prefix(protectedEnd)))
                        let energy = zip(aligned, reference).reduce(0.0) {
                            let delta = Double($1.0) - Double($1.1)
                            return $0 + delta * delta
                        }
                        let errorRMS = sqrt(energy / Double(barFrames))
                        if shortened {
                            #expect(aligned != reference && errorRMS > 0)
                            #expect(reference.dropFirst(suppliedFrames).contains { $0 != 0 })
                        } else {
                            #expect(aligned == reference && errorRMS == 0)
                            #expect(evidence == referenceEvidence)
                        }
                        var replay = [Float](repeating: 0, count: suppliedFrames)
                        var replayMeasurement = replay
                        let replayEvidence = VoiceRenderer.rumble(&replay,
                            measurement: &replayMeasurement, scoreEventIndex: 0, start: start,
                            sampleRate: rate, level: 0.072, seed: seed, step: step)
                        #expect(replay == actual && replayMeasurement == measurement && replayEvidence == evidence)
                        rows.append(["rootSeed": seed, "split": split, "sampleRate": Int(rate),
                            "step": step, "scenario": shortened ? "unauthorized-shortening" : "original-support",
                            "originalBarFrames": barFrames, "eventStartFrame": start,
                            "naturalFrames": naturalFrames, "expectedFrames": expectedFrames,
                            "suppliedBufferFrames": suppliedFrames, "renderedFrames": evidence.renderedFrameCount,
                            "declickComplete": declickComplete, "expectedSupportBinding": !shortened,
                            "observedSupportBinding": supportBinding, "sampleErrorRMS": errorRMS,
                            "actualAlignedSampleHash": ExactPCMFingerprint.mono(aligned),
                            "referenceSampleHash": ExactPCMFingerprint.mono(reference), "replayExact": replay == actual])
                    }
                }
            }
        }
        #expect(rows.count == 16)
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: [
            "schema": "autotechno-rumble-duration-fault-component.v1",
            "scope": "canonical-rumble-source-support-with-original-destination-binding",
            "qualification": "unavailable",
            "unavailable": ["full-prepared-transaction", "nonlinear-full-mix",
                "perceptual-quality", "independent-constructor-holdout", "population-error-intervals"],
            "rows": rows
        ], options: [.sortedKeys]))
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    @Test("Rumble support admission refuses unavailable destination geometry")
    func rumbleSupportAdmissionBounds() throws {
        var samples = [Float](repeating: 0, count: 96_000)
        var measurement = samples
        let evidence = try #require(VoiceRenderer.rumble(&samples,
            measurement: &measurement, scoreEventIndex: 0, start: 0,
            sampleRate: 48_000, level: 0.072, seed: 1, step: 0))
        #expect(evidence.isComplete(sampleRate: 48_000, destinationFrameCount: samples.count))
        for frames in [0, -1, Int.min] {
            #expect(!evidence.isComplete(sampleRate: 48_000, destinationFrameCount: frames))
        }
        for rate in [Double.nan, .infinity, -.infinity, .greatestFiniteMagnitude, 0, -1, 7_999, 192_001] {
            #expect(!evidence.isComplete(sampleRate: rate, destinationFrameCount: samples.count))
        }
        #expect(!evidence.isComplete(sampleRate: 48_000, destinationFrameCount: evidence.renderedFrameCount / 2))
    }

    @Test("Unsupported voices remain bit-exact")
    func unsupportedVoiceIdentity() {
        let samples: [Float] = [
            0,
            Float(bitPattern: 0x8000_0000),
            0.25,
            -0.75,
        ]
        for (frame, sample) in samples.enumerated() {
            let output = SourceTerminalDeclickContract.process(
                sample: sample,
                voice: .bass,
                frame: frame,
                renderedFrameCount: samples.count,
                sampleRate: 48_000
            )
            #expect(output.bitPattern == sample.bitPattern)
        }
    }
}
