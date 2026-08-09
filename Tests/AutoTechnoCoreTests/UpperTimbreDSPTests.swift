@testable import AutoTechnoDSP
import AutoTechnoCore
import Foundation
import Testing

@Suite("Upper timbre DSP articulation")
struct UpperTimbreDSPTests {
    @Test("Anchor velocity response is bounded, monotonic, and role local")
    func velocityResponseBoundsAndRoles() {
        let quiet = AlienVelocityResponse.resolve(velocity: -1, role: .anchor)
        let neutral = AlienVelocityResponse.resolve(velocity: 0.5, role: .anchor)
        let accented = AlienVelocityResponse.resolve(velocity: 2, role: .anchor)

        #expect(quiet.spectralEnvelopeScale == 0.40)
        #expect(quiet.decayScale == 0.80)
        #expect(neutral == .neutral)
        #expect(accented.spectralEnvelopeScale == 1.60)
        #expect(abs(accented.decayScale - 1.20) < 0.000_000_001)
        #expect(accented.spectralEnvelopeScale > quiet.spectralEnvelopeScale)
        #expect(accented.decayScale > quiet.decayScale)
        for role in SynthRole.allCases where role != .anchor {
            #expect(AlienVelocityResponse.resolve(velocity: 0, role: role) == .neutral)
            #expect(AlienVelocityResponse.resolve(velocity: 1, role: role) == .neutral)
        }
    }

    @Test("Timbre projection is bounded and role specific")
    func treatmentBoundsAndRoles() {
        let quiet = AlienTimbreTreatment.resolve(
            intent: .resonantSequence(amount: 1), velocity: 0, role: .anchor
        )
        let accented = AlienTimbreTreatment.resolve(
            intent: .resonantSequence(amount: 1), velocity: 1, role: .anchor
        )
        #expect(quiet.amplitudeScale >= 1 && accented.amplitudeScale <= 1.14)
        #expect(accented.amplitudeScale > quiet.amplitudeScale)
        #expect(accented.filterEnvelopeDepth > quiet.filterEnvelopeDepth)
        #expect(accented.driveScale > quiet.driveScale)
        #expect(accented.resonanceLift > quiet.resonanceLift)
        #expect(accented.detuneRatioLift == 0)

        let movingShadow = AlienTimbreTreatment.resolve(
            intent: .detunedMotion(amount: 1), velocity: 1, role: .shadow
        )
        let movingResponse = AlienTimbreTreatment.resolve(
            intent: .detunedMotion(amount: 1), velocity: 1, role: .response
        )
        let protectedAnchor = AlienTimbreTreatment.resolve(
            intent: .detunedMotion(amount: 1), velocity: 1, role: .anchor
        )
        #expect(movingShadow.detuneRatioLift > 0 && movingShadow.detuneRatioLift <= 0.006)
        #expect(movingResponse.detuneRatioLift == movingShadow.detuneRatioLift)
        #expect(protectedAnchor.detuneRatioLift == 0)
        #expect(protectedAnchor == AlienTimbreTreatment.resolve(
            intent: .home, velocity: 1, role: .anchor
        ))
    }

    @Test("Resonant and detuned intents change only eligible prepared PCM deterministically")
    func deterministicIntentPCM() {
        let resonant = render(
            role: .anchor,
            notes: [note(
                startFrame: 128,
                durationFrames: 1_280,
                frequency: 196,
                velocity: 0.92,
                timbre: .resonantSequence(amount: 0.88)
            )]
        )
        let resonantReplay = render(
            role: .anchor,
            notes: [note(
                startFrame: 128,
                durationFrames: 1_280,
                frequency: 196,
                velocity: 0.92,
                timbre: .resonantSequence(amount: 0.88)
            )]
        )
        let homeAnchor = render(
            role: .anchor,
            notes: [note(
                startFrame: 128,
                durationFrames: 1_280,
                frequency: 196,
                velocity: 0.92,
                timbre: .home
            )]
        )
        #expect(resonant.samples == resonantReplay.samples)
        #expect(resonant.state == resonantReplay.state)
        #expect(resonant.samples[..<128] == homeAnchor.samples[..<128])
        #expect(resonant.samples[128...] != homeAnchor.samples[128...])

        let movingShadow = render(
            role: .shadow,
            notes: [note(
                startFrame: 128,
                durationFrames: 1_280,
                frequency: 196,
                velocity: 0.76,
                timbre: .detunedMotion(amount: 0.80),
                role: .shadow
            )]
        )
        let homeShadow = render(
            role: .shadow,
            notes: [note(
                startFrame: 128,
                durationFrames: 1_280,
                frequency: 196,
                velocity: 0.76,
                timbre: .home,
                role: .shadow
            )]
        )
        let ignoredAnchor = render(
            role: .anchor,
            notes: [note(
                startFrame: 128,
                durationFrames: 1_280,
                frequency: 196,
                velocity: 0.76,
                timbre: .detunedMotion(amount: 0.80)
            )]
        )
        let matchingHomeAnchor = render(
            role: .anchor,
            notes: [note(
                startFrame: 128,
                durationFrames: 1_280,
                frequency: 196,
                velocity: 0.76,
                timbre: .home
            )]
        )
        #expect(movingShadow.samples != homeShadow.samples)
        #expect(ignoredAnchor.samples == matchingHomeAnchor.samples)
        #expect(resonant.samples.allSatisfy { $0.isFinite })
        #expect(movingShadow.samples.allSatisfy { $0.isFinite })
        #expect(homeAnchor.evidence.count == 1)
        #expect(abs(homeAnchor.evidence[0].requestedStartFrequency - 196) < 0.000_001)
        #expect(abs(homeAnchor.evidence[0].appliedStartFrequency - 65.41) < 0.01)
        #expect(abs(movingShadow.evidence[0].appliedStartFrequency -
                    homeShadow.evidence[0].appliedStartFrequency) < 0.000_001)
        #expect(abs(movingShadow.evidence[0].frequencyAtAppliedGateEnd -
                    homeShadow.evidence[0].frequencyAtAppliedGateEnd) < 0.000_001)
        #expect(homeAnchor.evidence[0].requestedGate == .retrigger)
        #expect(homeAnchor.evidence[0].appliedGate == .retrigger)
    }

    @Test("Anchor velocity changes normalized attack spectrum and in-gate decay")
    func velocityExpressionPCM() throws {
        for sampleRate in [44_100.0, 48_000.0] {
            let onset = Int((sampleRate * 0.01).rounded())
            let duration = Int((sampleRate * 0.16).rounded())
            let frameCount = Int((sampleRate * 0.22).rounded())
            let low = render(
                role: .anchor,
                notes: [note(
                    startFrame: onset,
                    durationFrames: duration,
                    frequency: 196,
                    velocity: 0.20,
                    timbre: .home
                )],
                sampleRate: sampleRate,
                frameCount: frameCount
            )
            let high = render(
                role: .anchor,
                notes: [note(
                    startFrame: onset,
                    durationFrames: duration,
                    frequency: 196,
                    velocity: 0.95,
                    timbre: .home
                )],
                sampleRate: sampleRate,
                frameCount: frameCount
            )
            let lowReplay = render(
                role: .anchor,
                notes: [note(
                    startFrame: onset,
                    durationFrames: duration,
                    frequency: 196,
                    velocity: 0.20,
                    timbre: .home
                )],
                sampleRate: sampleRate,
                frameCount: frameCount
            )
            let lowExpression = try #require(
                velocityEvidence(low, sampleRate: sampleRate).velocityExpression.first
            )
            let highExpression = try #require(
                velocityEvidence(high, sampleRate: sampleRate).velocityExpression.first
            )

            #expect(low.samples == lowReplay.samples)
            #expect(low.state == lowReplay.state)
            #expect(low.evidence == lowReplay.evidence)
            #expect(low.samples[..<onset] == high.samples[..<onset])
            #expect(low.samples[onset...] != high.samples[onset...])
            #expect(lowExpression.complete && highExpression.complete)
            #expect(highExpression.spectralEnvelopeScale >
                    lowExpression.spectralEnvelopeScale)
            #expect(highExpression.decayScale > lowExpression.decayScale)
            #expect(highExpression.attackHighBandRatio >
                    lowExpression.attackHighBandRatio)
            #expect(highExpression.tailToAttackDB > lowExpression.tailToAttackDB)
            #expect(lowExpression.appliedStartFrequency ==
                    highExpression.appliedStartFrequency)
            #expect(lowExpression.analyzedFrameCount ==
                    highExpression.analyzedFrameCount)
            #expect(low.evidence[0].requestedVelocity == 0.20)
            #expect(low.evidence[0].appliedVelocity == 0.20)
            #expect(high.evidence[0].requestedVelocity == 0.95)
            #expect(high.evidence[0].appliedVelocity == 0.95)
            #expect(low.samples.allSatisfy { $0.isFinite })
            #expect(high.samples.allSatisfy { $0.isFinite })
        }
    }

    @Test("Slides inherit the latched retrigger response and velocity clamps replay")
    func velocityResponseContinuationAndClamps() {
        let onset = 96
        let slideFrame = 720
        let first = note(
            startFrame: onset,
            durationFrames: 1_600,
            frequency: 174.61,
            velocity: 0.20,
            timbre: .home
        )
        let slide = note(
            startFrame: slideFrame,
            durationFrames: 960,
            frequency: 174.61,
            endFrequency: 220,
            velocity: 1,
            gate: .slide,
            timbre: .home
        )
        let rendered = render(role: .anchor, notes: [first, slide])
        #expect(rendered.evidence.count == 2)
        #expect(rendered.evidence[1].appliedGate == .slide)
        #expect(rendered.evidence[1].appliedVelocity == 1)
        #expect(rendered.evidence[1].velocitySpectralEnvelopeScale ==
                rendered.evidence[0].velocitySpectralEnvelopeScale)
        #expect(rendered.evidence[1].velocityDecayScale ==
                rendered.evidence[0].velocityDecayScale)
        #expect(rendered.state.velocityResponse == AlienVelocityResponse.resolve(
            velocity: 0.20,
            role: .anchor
        ))

        let below = render(role: .anchor, notes: [note(
            startFrame: onset,
            durationFrames: 1_200,
            frequency: 196,
            velocity: -1,
            timbre: .home
        )])
        let zero = render(role: .anchor, notes: [note(
            startFrame: onset,
            durationFrames: 1_200,
            frequency: 196,
            velocity: 0,
            timbre: .home
        )])
        let above = render(role: .anchor, notes: [note(
            startFrame: onset,
            durationFrames: 1_200,
            frequency: 196,
            velocity: 2,
            timbre: .home
        )])
        let one = render(role: .anchor, notes: [note(
            startFrame: onset,
            durationFrames: 1_200,
            frequency: 196,
            velocity: 1,
            timbre: .home
        )])
        #expect(below.samples == zero.samples)
        #expect(below.state == zero.state)
        #expect(above.samples == one.samples)
        #expect(above.state == one.state)
        #expect(below.evidence[0].requestedVelocity == -1)
        #expect(below.evidence[0].appliedVelocity == 0)
        #expect(above.evidence[0].requestedVelocity == 2)
        #expect(above.evidence[0].appliedVelocity == 1)
    }

    @Test("Velocity evidence is gain normalized, bounded, and explicit when unavailable")
    func velocityEvidenceAdversaries() throws {
        let sampleRate = 48_000.0
        let frameCount = Int((sampleRate * 0.16).rounded())
        let source = (0..<frameCount).map { frame -> Float in
            let time = Double(frame) / sampleRate
            let envelope = exp(-time * 4.2)
            return Float((sin(2 * .pi * 440 * time) +
                          sin(2 * .pi * 5_200 * time) * 0.18) * envelope)
        }
        let quiet = source.map { $0 * 0.20 }
        let window = UpperVelocityExpressionWindow(
            onsetFrame: 0,
            endFrame: frameCount,
            velocity: 0.70,
            appliedStartFrequency: 440,
            spectralEnvelopeScale: 1.24,
            decayScale: 1.08
        )
        func analyze(_ samples: [Float], window: UpperVelocityExpressionWindow)
            -> UpperTimbreEvidence {
            UpperTimbreEvidenceAnalyzer.analyze(UpperTimbreAnalysisInput(
                left: samples,
                right: samples,
                sampleRate: sampleRate,
                velocityExpressionWindows: [window]
            ))
        }

        let loudEvidence = analyze(source, window: window)
        let quietEvidence = analyze(quiet, window: window)
        let loudEvent = try #require(loudEvidence.velocityExpression.first)
        let quietEvent = try #require(quietEvidence.velocityExpression.first)
        #expect(loudEvent.complete && quietEvent.complete)
        #expect(loudEvent.sourceRMS > quietEvent.sourceRMS)
        #expect(abs(loudEvent.attackHighBandRatio -
                    quietEvent.attackHighBandRatio) < 0.000_001)
        #expect(abs(loudEvent.tailToAttackDB - quietEvent.tailToAttackDB) < 0.000_001)

        let short = analyze(source, window: UpperVelocityExpressionWindow(
            onsetFrame: 0,
            endFrame: Int((sampleRate * 0.05).rounded()),
            velocity: 0.70,
            appliedStartFrequency: 440,
            spectralEnvelopeScale: 1.24,
            decayScale: 1.08
        ))
        #expect(short.finite)
        #expect(short.velocityExpression.count == 1)
        #expect(short.velocityExpression[0].analyzedFrameCount > 0)
        #expect(!short.velocityExpression[0].complete)

        let malformed = analyze(source, window: UpperVelocityExpressionWindow(
            onsetFrame: -1,
            endFrame: frameCount,
            velocity: 0.70,
            appliedStartFrequency: 440,
            spectralEnvelopeScale: 1.24,
            decayScale: 1.08
        ))
        #expect(!malformed.finite)
        #expect(!malformed.velocityExpression[0].complete)

        let overBound = UpperTimbreEvidenceAnalyzer.analyze(UpperTimbreAnalysisInput(
            left: source,
            right: source,
            sampleRate: sampleRate,
            velocityExpressionWindows: Array(
                repeating: window,
                count: UpperTimbreEvidenceAnalyzer.maximumVelocityExpressionWindows + 1
            )
        ))
        #expect(!overBound.finite)
        #expect(overBound.velocityExpression.count ==
                UpperTimbreEvidenceAnalyzer.maximumVelocityExpressionWindows)

        let aggregate = UpperTimbreEvidence.aggregating([loudEvidence, quietEvidence])
        #expect(aggregate.finite)
        #expect(aggregate.velocityExpression.count == 2)
        #expect(aggregate.velocityExpression[0] == loudEvent)
        #expect(aggregate.velocityExpression[1].onsetFrame ==
                quietEvent.onsetFrame + loudEvidence.analyzedFrameCount)
        #expect(aggregate.velocityExpression[1].analyzedEndFrame ==
                quietEvent.analyzedEndFrame + loudEvidence.analyzedFrameCount)
        #expect(aggregate.velocityExpression[1].analyzedFrameCount ==
                quietEvent.analyzedFrameCount)
        #expect(aggregate.velocityExpression[1].velocity == quietEvent.velocity)
        #expect(aggregate.velocityExpression[1].attackHighBandRatio ==
                quietEvent.attackHighBandRatio)
        #expect(aggregate.velocityExpression[1].tailToAttackDB ==
                quietEvent.tailToAttackDB)
        #expect(aggregate.fingerprint != loudEvidence.fingerprint)
    }

    @Test("One slide changes PCM only at its boundary and does not retrigger the envelope")
    func legatoSlideLocality() {
        let first = note(
            startFrame: 96,
            durationFrames: 1_200,
            frequency: 174.61,
            velocity: 0.90,
            timbre: .resonantSequence(amount: 0.84)
        )
        let slideFrame = 640
        let slide = note(
            startFrame: slideFrame,
            durationFrames: 960,
            frequency: 174.61,
            endFrequency: 220,
            velocity: 0.90,
            gate: .slide,
            timbre: .resonantSequence(amount: 0.84)
        )
        let retrigger = note(
            startFrame: slideFrame,
            durationFrames: 960,
            frequency: 174.61,
            endFrequency: 220,
            velocity: 0.90,
            gate: .retrigger,
            timbre: .resonantSequence(amount: 0.84)
        )
        let unchanged = render(role: .anchor, notes: [first])
        let slid = render(role: .anchor, notes: [first, slide])
        let retriggered = render(role: .anchor, notes: [first, retrigger])
        let orphanedSlide = render(role: .anchor, notes: [slide])

        #expect(slid.samples[..<slideFrame] == unchanged.samples[..<slideFrame])
        #expect(slid.samples[slideFrame...] != unchanged.samples[slideFrame...])
        #expect(windowRMS(slid.samples, start: slideFrame, count: 96) >
                windowRMS(retriggered.samples, start: slideFrame, count: 96))
        #expect(slid.state.phaseA != 0 && slid.state.phaseB != 0)
        #expect(slid.state.filterEnvelope < retriggered.state.filterEnvelope)
        #expect(slid.evidence.count == 2)
        #expect(slid.evidence[1].requestedGate == .slide)
        #expect(slid.evidence[1].appliedGate == .slide)
        #expect(!slid.evidence[1].didRetrigger)
        #expect(slid.evidence[0].appliedGateEndFrame == slideFrame)
        #expect(orphanedSlide.evidence[0].requestedGate == .slide)
        #expect(orphanedSlide.evidence[0].appliedGate == .retrigger)
        #expect(orphanedSlide.evidence[0].didRetrigger)
    }

    @Test("Gate evidence distinguishes requested cross-bar duration from applied truncation")
    func crossBarGateEvidence() {
        let startFrame = 2_100
        let durationFrames = 640
        let frameCount = 2_400
        let rendered = render(
            role: .anchor,
            notes: [note(
                startFrame: startFrame,
                durationFrames: durationFrames,
                frequency: 196,
                velocity: 0.82,
                timbre: .resonantSequence(amount: 0.72)
            )],
            frameCount: frameCount
        )

        #expect(rendered.evidence.count == 1)
        #expect(rendered.evidence[0].requestedGateEndFrame ==
                startFrame + durationFrames)
        #expect(rendered.evidence[0].appliedGateEndFrame == frameCount)
    }

    @Test("A home bar neutralizes prior treatment without resetting voice phase")
    func homeNeutralizesPersistentTreatment() {
        let active = render(
            role: .anchor,
            notes: [note(
                startFrame: 64,
                durationFrames: 1_280,
                frequency: 196,
                velocity: 0.94,
                timbre: .resonantSequence(amount: 0.90)
            )]
        )
        var state = active.state
        let incomingPhaseA = state.phaseA
        let incomingPhaseB = state.phaseB
        let incomingVelocityResponse = state.velocityResponse
        #expect(state.timbreIntent.kind == .resonantSequence)
        #expect(state.filterEnvelope > 0)

        var output = [Float](repeating: 0, count: 512)
        var measurement = [Float](repeating: 0, count: output.count)
        var pulseEcho = [Float](repeating: 0, count: output.count)
        var spatial = [Float](repeating: 0, count: output.count)
        var noteEvidence: [UpperNoteRenderEvidence] = []
        AlienAnalogVoice.render(
            &output,
            measurement: &measurement,
            pulseEchoSend: &pulseEcho,
            spatialReverbSend: &spatial,
            noteRenderEvidence: &noteEvidence,
            notes: [],
            sampleRate: 8_000,
            level: 0.12,
            world: fixtureWorld(),
            bar: fixtureBar(),
            role: .anchor,
            state: &state
        )

        #expect(state.timbreIntent == .home)
        #expect(state.timbreVelocity == 0)
        #expect(state.filterEnvelope < active.state.filterEnvelope)
        #expect(state.timbreTreatment.filterEnvelopeDepth <
                active.state.timbreTreatment.filterEnvelopeDepth)
        #expect(state.velocityResponse == incomingVelocityResponse)
        #expect(abs(Double(output[0] - (active.samples.last ?? 0))) < 0.65)
        #expect(state.phaseA != 0 && state.phaseB != 0)
        #expect(state.phaseA != incomingPhaseA || state.phaseB != incomingPhaseB)
    }

    @Test("Maximum resonant treatment stays finite on production-rate routes")
    func productionRateStability() {
        for sampleRate in [44_100.0, 48_000.0, 96_000.0, 192_000.0] {
            let start = Int((sampleRate * 0.01).rounded())
            let duration = Int((sampleRate * 0.10).rounded())
            let rendered = render(
                role: .anchor,
                notes: [note(
                    startFrame: start,
                    durationFrames: duration,
                    frequency: 196,
                    endFrequency: 246.94,
                    velocity: 1,
                    timbre: .resonantSequence(amount: 1)
                )],
                sampleRate: sampleRate,
                frameCount: Int((sampleRate * 0.14).rounded())
            )
            let evidence = UpperTimbreEvidenceAnalyzer.analyze(
                UpperTimbreAnalysisInput(
                    left: rendered.samples,
                    right: rendered.samples,
                    sampleRate: sampleRate
                )
            )
            #expect(rendered.samples.allSatisfy { $0.isFinite })
            #expect(rendered.samples.map { abs($0) }.max() ?? 0 < 1)
            #expect(evidence.finite)
            #expect(evidence.aliasBandEnergyRatio < 0.20)
        }
    }

    private func render(role: SynthRole, notes: [AlienVoiceNote],
                        sampleRate: Double = 8_000,
                        frameCount: Int = 2_400) ->
        (samples: [Float], state: AlienVoiceState, evidence: [UpperNoteRenderEvidence]) {
        var output = [Float](repeating: 0, count: frameCount)
        var measurement = [Float](repeating: 0, count: output.count)
        var pulseEcho = [Float](repeating: 0, count: output.count)
        var spatial = [Float](repeating: 0, count: output.count)
        var noteEvidence: [UpperNoteRenderEvidence] = []
        var state = AlienVoiceState()
        AlienAnalogVoice.render(
            &output,
            measurement: &measurement,
            pulseEchoSend: &pulseEcho,
            spatialReverbSend: &spatial,
            noteRenderEvidence: &noteEvidence,
            notes: notes,
            sampleRate: sampleRate,
            level: 0.12,
            world: fixtureWorld(),
            bar: fixtureBar(),
            role: role,
            state: &state
        )
        #expect(output == measurement)
        return (output, state, noteEvidence)
    }

    private func note(startFrame: Int, durationFrames: Int, frequency: Double,
                      endFrequency: Double? = nil, velocity: Double,
                      gate: UpperNoteGate = .retrigger,
                      timbre: UpperTimbreIntent,
                      role: SynthRole = .anchor) -> AlienVoiceNote {
        AlienVoiceNote(
            startFrame: startFrame,
            durationFrames: durationFrames,
            frequency: frequency,
            endFrequency: endFrequency ?? frequency,
            velocity: velocity,
            gate: gate,
            timbreIntent: timbre,
            role: role,
            articulation: .neutral,
            dryScale: 1,
            spatialReverbSend: 0,
            narrativeGainScale: 1,
            narrativeSpectralScale: 1
        )
    }

    private func velocityEvidence(
        _ rendered: (
            samples: [Float],
            state: AlienVoiceState,
            evidence: [UpperNoteRenderEvidence]
        ),
        sampleRate: Double
    ) -> UpperTimbreEvidence {
        let windows = rendered.evidence.filter {
            $0.role == .anchor && $0.didRetrigger
        }.map {
            UpperVelocityExpressionWindow(
                onsetFrame: $0.onsetFrame,
                endFrame: $0.appliedGateEndFrame,
                velocity: $0.appliedVelocity,
                appliedStartFrequency: $0.appliedStartFrequency,
                spectralEnvelopeScale: $0.velocitySpectralEnvelopeScale,
                decayScale: $0.velocityDecayScale
            )
        }
        return UpperTimbreEvidenceAnalyzer.analyze(
            UpperTimbreAnalysisInput(
                left: rendered.samples,
                right: rendered.samples,
                sampleRate: sampleRate,
                velocityExpressionWindows: windows
            )
        )
    }

    private func fixtureWorld() -> SynthWorldDNA {
        let scene = TechnoScene(
            intent: MusicalIntent(values: [.darkness: 0.76, .hypnosis: 0.82]),
            seed: 48_291,
            bpm: 130
        )
        return SynthWorldDNA(scene: scene, dna: SceneDNA(scene: scene))
    }

    private func fixtureBar() -> SynthPerformanceBar {
        SynthPerformanceBar(
            bar: 0,
            gesture: .interlock,
            mutationAmount: 0.48,
            relationalSteps: Array(repeating: .neutral, count: 16),
            upperNotes: []
        )
    }

    private func windowRMS(_ samples: [Float], start: Int, count: Int) -> Double {
        let end = min(samples.count, start + count)
        guard start < end else { return 0 }
        let energy = samples[start..<end].reduce(0.0) {
            $0 + Double($1) * Double($1)
        }
        return sqrt(energy / Double(end - start))
    }
}
