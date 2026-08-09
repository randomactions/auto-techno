import AutoTechnoCore
import Foundation

package enum KickMixBalance {
    package static let attenuationDB = -1.5
    package static let audibleGain = 0.841_395
    package static let regularDetectorLevel = 0.72
    package static let breakdownDetectorLevel = 0.54

    package static func detectorLevel(for section: SectionKind) -> Double {
        section == .breakdown ? breakdownDetectorLevel : regularDetectorLevel
    }

    package static func audibleLevel(for section: SectionKind) -> Double {
        detectorLevel(for: section) * audibleGain
    }
}

package enum GroovePulseVoice {
    package static let baseLevel = 0.045
    package static let durationSeconds = 0.045
    package static let highPassFrequency = 550.0
    package static let lowPassFrequency = 3_200.0

    package struct Parameters: Equatable, Sendable {
        package let highPassHz: Double
        package let lowPassHz: Double
        package let clickHz: Double
        package let envelopeDecay: Double
        package let clickDecay: Double
        package let noiseWeight: Double
        package let clickWeight: Double
    }

    package static func parameters(for articulation: GroovePulseArticulation) -> Parameters {
        let zone: (highPass: Double, lowPass: Double, click: Double)
        switch articulation.strikeZone {
        case .center:
            zone = (550, 2_600, 940)
        case .middle:
            zone = (highPassFrequency, lowPassFrequency, 1_180)
        case .edge:
            zone = (700, 3_900, 1_480)
        }
        let damping = min(0.75, max(0.25, articulation.damping))
        let microvariation = min(0.04, max(-0.04, articulation.timbreMicrovariation))
        return Parameters(
            highPassHz: zone.highPass,
            lowPassHz: zone.lowPass * (1 + 0.5 * microvariation),
            clickHz: zone.click * (1 + microvariation),
            envelopeDecay: 72 + (damping - 0.5) * 72,
            clickDecay: 145 + (damping - 0.5) * 100,
            noiseWeight: 0.78 * (1 - 0.5 * microvariation),
            clickWeight: 0.24 * (1 + 0.5 * microvariation)
        )
    }

    @discardableResult
    package static func render(_ output: inout [Float], measurement: inout [Float],
                               start: Int, sampleRate: Double,
                               articulation: GroovePulseArticulation,
                               seed: UInt64) -> GroovePulseRenderEvidence? {
        let frames = min(Int(sampleRate * durationSeconds), output.count - start)
        guard frames > 0 else { return nil }
        let applied = parameters(for: articulation)
        var random = SeededGenerator(seed: seed)
        var highPassState = 0.0
        var lowPassState = 0.0
        let highPassCoefficient = min(
            0.35,
            1 - exp(-2 * .pi * applied.highPassHz / sampleRate)
        )
        let lowPassCoefficient = min(
            0.55,
            1 - exp(-2 * .pi * applied.lowPassHz / sampleRate)
        )
        let lowBandCoefficient = min(1, 1 - exp(-2 * .pi * 500 / sampleRate))
        let midBandCoefficient = min(1, 1 - exp(-2 * .pi * 2_500 / sampleRate))
        let attackFrameCount = min(frames, max(1, Int((sampleRate * 0.008).rounded())))
        let tailStartFrame = min(frames, max(0, Int((sampleRate * 0.024).rounded())))
        var drySamples: [Float] = []
        drySamples.reserveCapacity(frames)
        var peak = 0.0
        var totalEnergy = 0.0
        var attackEnergy = 0.0
        var tailEnergy = 0.0
        var lowBandState = 0.0
        var midBandState = 0.0
        var lowBandEnergy = 0.0
        var middleBandEnergy = 0.0
        var highBandEnergy = 0.0
        var samplesFinite = true
        for index in 0..<frames {
            let time = Double(index) / sampleRate
            let noise = random.unit() * 2 - 1
            highPassState += (noise - highPassState) * highPassCoefficient
            let highPassed = noise - highPassState
            let mutedClick = sin(2 * .pi * applied.clickHz * time) *
                exp(-time * applied.clickDecay) * applied.clickWeight
            lowPassState += (highPassed * applied.noiseWeight + mutedClick - lowPassState) *
                lowPassCoefficient
            let attack = min(1, time / 0.0008)
            let envelope = attack * exp(-time * applied.envelopeDecay)
            let renderedSample = Float(
                tanh(lowPassState * 1.16) * envelope * baseLevel * articulation.intensity
            )
            output[start + index] += renderedSample
            measurement[start + index] += renderedSample
            drySamples.append(renderedSample)

            let value = Double(renderedSample)
            let energy = value * value
            peak = max(peak, abs(value))
            totalEnergy += energy
            if index < attackFrameCount { attackEnergy += energy }
            if index >= tailStartFrame { tailEnergy += energy }
            lowBandState += (value - lowBandState) * lowBandCoefficient
            midBandState += (value - midBandState) * midBandCoefficient
            let middle = midBandState - lowBandState
            let high = value - midBandState
            lowBandEnergy += lowBandState * lowBandState
            middleBandEnergy += middle * middle
            highBandEnergy += high * high
            samplesFinite = samplesFinite && renderedSample.isFinite
        }
        let rms = sqrt(totalEnergy / Double(frames))
        let crest = rms > 0 ? peak / rms : 0
        let attackRMS = sqrt(attackEnergy / Double(attackFrameCount))
        let tailFrameCount = max(1, frames - tailStartFrame)
        let tailRMS = sqrt(tailEnergy / Double(tailFrameCount))
        let tailToAttack = attackRMS > 0 ? tailRMS / attackRMS : 0
        let tailToAttackDB = attackRMS > 0
            ? min(120, max(-120, 20 * log10(max(tailToAttack, 0.000_001))))
            : -120
        let bandEnergy = lowBandEnergy + middleBandEnergy + highBandEnergy
        let lowRatio = bandEnergy > 0 ? lowBandEnergy / bandEnergy : 0
        let middleRatio = bandEnergy > 0 ? middleBandEnergy / bandEnergy : 0
        let highRatio = bandEnergy > 0 ? highBandEnergy / bandEnergy : 0
        let spectralCentroid = lowRatio * min(250, sampleRate * 0.10) +
            middleRatio * min(1_500, sampleRate * 0.30) +
            highRatio * min(5_000, sampleRate * 0.45)
        let scalarValues = [
            applied.highPassHz, applied.lowPassHz, applied.clickHz,
            applied.envelopeDecay, applied.clickDecay, peak, rms, crest,
            attackRMS, tailRMS, tailToAttack, tailToAttackDB,
            lowRatio, middleRatio, highRatio, spectralCentroid,
        ]
        return GroovePulseRenderEvidence(
            step: articulation.step,
            pulseClass: articulation.pulseClass,
            stage: articulation.stage,
            intensity: articulation.intensity,
            timingOffsetInSteps: articulation.timingOffsetInSteps,
            strikeZone: articulation.strikeZone,
            damping: articulation.damping,
            timbreMicrovariation: articulation.timbreMicrovariation,
            appliedHighPassHz: applied.highPassHz,
            appliedLowPassHz: applied.lowPassHz,
            appliedClickHz: applied.clickHz,
            appliedEnvelopeDecay: applied.envelopeDecay,
            appliedClickDecay: applied.clickDecay,
            renderedFrameCount: frames,
            sampleHash: ExactPCMFingerprint.mono(drySamples),
            peak: peak,
            rms: rms,
            crestFactor: crest,
            attackRMS: attackRMS,
            tailRMS: tailRMS,
            tailToAttackRatio: tailToAttack,
            tailToAttackDB: tailToAttackDB,
            lowBandEnergyRatio: lowRatio,
            midBandEnergyRatio: middleRatio,
            highBandEnergyRatio: highRatio,
            spectralCentroidHz: spectralCentroid,
            finite: samplesFinite && scalarValues.allSatisfy(\.isFinite)
        )
    }
}

package enum VoiceRenderer {
    package static func timingOffsetInSteps(for voice: EnsembleVoice, step: Int,
                                            dna: SceneDNA) -> Double {
        let swings = voice == .bass || voice == .percussion || voice == .openHat ||
            voice == .groovePulse
        guard swings, !step.isMultiple(of: 2) else { return 0 }
        return max(0, min(0.24, (dna.rhythm.swingPercent - 0.5) * 2.0))
    }

    static func renderBar(scene: TechnoScene, sampleRate: Double, state: inout RenderState,
                          dna: SceneDNA, resolved: ResolvedPerformanceBar,
                          synthWorld: SynthWorldDNA, synthPerformance: SynthPerformanceBar,
                          workspace: inout RenderWorkspace, layer: RenderLayer) -> RenderedBar {
        let performance = resolved.performance
        let section = performance.section
        let frames = max(1, Int((240.0 / scene.bpm * sampleRate).rounded()))
        let stepFrames = Double(frames) / 16.0
        var checkedOut = workspace.checkout(
            frameCount: frames,
            includeUpperRoleTaps: layer == .full
        )
        var output: [Float] = []
        var kickBus: [Float] = []
        var kickDetectorBus: [Float] = []
        var foundationStem: [Float] = []
        var percussionStem: [Float] = []
        var upperTonalStem: [Float] = []
        var atmosphereStem: [Float] = []
        var resonantAnchorStem: [Float] = []
        var detunedCompanionStem: [Float] = []
        var maskingFoundationBus: [Float] = []
        var synthBus: [Float] = []
        var pulseEchoSendBus: [Float] = []
        var spatialReverbSendBus: [Float] = []
        var groovePulseRenderEvidence: [GroovePulseRenderEvidence] = []
        groovePulseRenderEvidence.reserveCapacity(resolved.groovePulses.count)
        swap(&output, &checkedOut.output)
        swap(&kickBus, &checkedOut.kick)
        swap(&kickDetectorBus, &checkedOut.kickDetector)
        swap(&foundationStem, &checkedOut.foundationStem)
        swap(&percussionStem, &checkedOut.percussionStem)
        swap(&upperTonalStem, &checkedOut.upperTonalStem)
        swap(&atmosphereStem, &checkedOut.atmosphereStem)
        swap(&resonantAnchorStem, &checkedOut.resonantAnchorStem)
        swap(&detunedCompanionStem, &checkedOut.detunedCompanionStem)
        swap(&maskingFoundationBus, &checkedOut.maskingFoundation)
        swap(&synthBus, &checkedOut.synth)
        swap(&pulseEchoSendBus, &checkedOut.pulseEchoSend)
        swap(&spatialReverbSendBus, &checkedOut.spatialReverbSend)
        var random = SeededGenerator(seed: performance.eventSeed)

        for event in resolved.ensemble.events {
            let pulseArticulation = event.voice == .groovePulse
                ? resolved.groovePulse(at: event.step) : nil
            let offset = pulseArticulation?.timingOffsetInSteps ??
                timingOffsetInSteps(for: event.voice, step: event.step, dna: dna)
            let start = Int(((Double(event.step) + offset) * stepFrames).rounded())
            let accent = performance.accent(at: event.step) * event.intensity
            switch event.voice {
            case .kick:
                let detectorLevel = KickMixBalance.detectorLevel(for: section) * accent
                kick(&kickDetectorBus, start: start, sampleRate: sampleRate, level: detectorLevel,
                     seed: scene.seed, step: event.step)
            case .bass where !(performance.signatureEvent == .delayedBassEntry && event.step < 8):
                let frequency = relationalBassFrequency(
                    dna: dna, step: event.step, tension: performance.tension
                )
                bass(&output, measurement: &foundationStem,
                     start: start, sampleRate: sampleRate,
                     level: (0.11 + performance.tension * 0.035) * accent,
                     frequency: frequency, articulation: 0.3 + performance.tension * 0.5,
                     phase: &state.bassPhase, filterState: &state.bassFilter)
            case .rumble:
                rumble(&output, measurement: &foundationStem,
                       start: start, sampleRate: sampleRate,
                       level: 0.072 * accent, seed: scene.seed, step: event.step)
            case .tunedTom:
                let frequency = 49.0 * pow(2, Double(dna.tonalCenter) / 12)
                tom(&output, measurement: &foundationStem,
                    start: start, sampleRate: sampleRate,
                    level: 0.085 * accent, frequency: frequency)
            case .percussion:
                let level = (section == .build ? 0.09 : 0.075) * accent
                hat(&output, measurement: &percussionStem, start: start,
                    sampleRate: sampleRate, level: level,
                    brightness: scene.character.percussionBrightness, random: &random)
            case .clap:
                clap(&output, measurement: &percussionStem,
                     start: start, sampleRate: sampleRate, level: 0.08 * accent,
                     brightness: scene.character.percussionBrightness, random: &random)
            case .openHat:
                openHat(&output, measurement: &percussionStem,
                        start: start, sampleRate: sampleRate,
                        level: 0.052 * accent,
                        brightness: scene.character.percussionBrightness, random: &random)
            case .metallic:
                metallicPercussion(&output, measurement: &percussionStem,
                                   start: start, sampleRate: sampleRate,
                                   level: 0.042 * accent,
                                   brightness: scene.character.percussionBrightness, random: &random)
            case .groovePulse:
                guard let pulseArticulation else { break }
                let pulseSeed = performance.eventSeed ^ UInt64(event.step + 1) ^ 0x6A20_0C15
                if let evidence = GroovePulseVoice.render(
                    &output, measurement: &percussionStem,
                    start: start, sampleRate: sampleRate,
                    articulation: pulseArticulation, seed: pulseSeed
                ) {
                    groovePulseRenderEvidence.append(evidence)
                }
            default: break
            }
        }
        for index in 0..<frames {
            let audibleKick = kickDetectorBus[index] * Float(KickMixBalance.audibleGain)
            kickBus[index] = audibleKick
            output[index] += audibleKick
        }
        let textureCollapsed = performance.signatureEvent == .textureCollapse
        let upperRolesActive = performance.roles.contains {
            $0 == .motif || $0 == .response || $0 == .atmosphere || $0 == .transition
        }
        var upperNoteRenderEvidence: [UpperNoteRenderEvidence] = []
        if layer == .full {
            renderAlienWorld(
                &synthBus,
                pulseEchoSend: &pulseEchoSendBus,
                spatialReverbSend: &spatialReverbSendBus,
                upperTonalStem: &upperTonalStem,
                atmosphereStem: &atmosphereStem,
                resonantAnchorStem: &resonantAnchorStem,
                detunedCompanionStem: &detunedCompanionStem,
                noteRenderEvidence: &upperNoteRenderEvidence,
                renderScheduledNotes: !textureCollapsed && upperRolesActive,
                scene: scene,
                sampleRate: sampleRate,
                stepFrames: stepFrames,
                resolved: resolved,
                world: synthWorld,
                synthBar: synthPerformance,
                state: &state
            )
        }

        func onsetFrames(for roles: Set<EnsembleVoice>) -> [Int] {
            resolved.ensemble.events.filter { roles.contains($0.voice) }.map { event in
                let offset = event.voice == .groovePulse
                    ? (resolved.groovePulse(at: event.step)?.timingOffsetInSteps ?? 0)
                    : 0
                return Int(((Double(event.step) + offset) * stepFrames).rounded())
            }
        }
        let kickOnsets = onsetFrames(for: [.kick])
        var stemObservations: [MixRole: StemObservation] = [
            .kick: StemObservationAnalyzer.analyze(
                kickBus, sampleRate: sampleRate, onsetFrames: kickOnsets
            ),
            .foundation: StemObservationAnalyzer.analyze(
                foundationStem, sampleRate: sampleRate, onsetFrames: kickOnsets
            ),
            .percussion: StemObservationAnalyzer.analyze(
                percussionStem, sampleRate: sampleRate,
                onsetFrames: onsetFrames(for: [
                    .percussion, .clap, .openHat, .metallic, .groovePulse,
                ])
            ),
            .upperTonal: StemObservationAnalyzer.analyze(
                upperTonalStem, sampleRate: sampleRate,
                onsetFrames: onsetFrames(for: [.motif, .response])
            ),
            .atmosphere: StemObservationAnalyzer.analyze(
                atmosphereStem, sampleRate: sampleRate,
                onsetFrames: onsetFrames(for: [.atmosphere, .transition])
            ),
        ]
        let automaticMix = AutomaticMixBalancer.resolve(
            observations: stemObservations,
            companion: resolved.foundationCompanion,
            section: section,
            state: &state.automaticMixState
        )
        let automaticKickGain = Float(automaticMix.gain(for: .kick))
        if automaticKickGain != 1 {
            for index in 0..<frames {
                let originalKick = kickBus[index]
                let balancedKick = originalKick * automaticKickGain
                kickBus[index] = balancedKick
                output[index] += balancedKick - originalKick
            }
            stemObservations[.kick] = StemObservationAnalyzer.analyze(
                kickBus, sampleRate: sampleRate, onsetFrames: kickOnsets
            )
        }
        var dryCenterMaximumError: Float = 0
        var upperMaximumError: Float = 0
        for index in 0..<frames {
            maskingFoundationBus[index] = kickBus[index] + foundationStem[index]
            let reconstructedCenter = maskingFoundationBus[index] + percussionStem[index]
            dryCenterMaximumError = max(
                dryCenterMaximumError, abs(output[index] - reconstructedCenter)
            )
            let reconstructedUpper = upperTonalStem[index] + atmosphereStem[index]
            upperMaximumError = max(
                upperMaximumError, abs(synthBus[index] - reconstructedUpper)
            )
        }
        let stemReconstruction = StemReconstructionEvidence(
            dryCenterMaximumError: dryCenterMaximumError,
            upperMaximumError: upperMaximumError
        )

        let delayFrames = max(1, Int((60.0 / scene.bpm * 0.5 * sampleRate).rounded()))
        if state.delayBuffer.count != delayFrames { state.delayBuffer = [Float](repeating: 0, count: delayFrames); state.delayWriteIndex = 0 }
        // Three sixteenth notes: a pulse echo rather than a broad wash. The
        // return is band-limited and exists only on the upper path.
        let pulseEchoFrames = max(1, Int((60.0 / scene.bpm * 0.75 * sampleRate).rounded()))
        if state.pulseEchoBuffer.count != pulseEchoFrames {
            state.pulseEchoBuffer = [Float](repeating: 0, count: pulseEchoFrames)
            state.pulseEchoWriteIndex = 0
            state.pulseEchoHighPassState = 0
            state.pulseEchoLowPassState = 0
        }
        let earlyReflectionFrames = max(8, Int(sampleRate * 0.013))
        if state.earlyReflectionBuffer.count != earlyReflectionFrames {
            state.earlyReflectionBuffer = [Float](repeating: 0, count: earlyReflectionFrames)
            state.earlyReflectionWriteIndex = 0
        }
        let dramaticDistance = scene.atmosphere
        let wet = Float(0.10 + scene.atmosphere * 0.18)
        let feedback = Float(0.20 + scene.hypnosis * 0.12)
        // Upper voices move over several bars; kick and bass remain centered.
        // The phase lives in RenderState so adjacent bars do not reset the
        // stereo image, and the bounded range stays mono-compatible.
        let panDepth = 0.16 + dramaticDistance * 0.18 + scene.textureChaos * 0.08
        let panRate = 2.0 * Double.pi / (sampleRate * (6.0 + scene.hypnosis * 10.0))
        let chorusFrames = max(8, Int(sampleRate * 0.045))
        if state.chorusDelay.count != chorusFrames {
            state.chorusDelay = [Float](repeating: 0, count: chorusFrames)
            state.chorusWriteIndex = 0
        }
        let chorusRate = 2.0 * Double.pi / (sampleRate * (1.8 + scene.hypnosis * 1.8))
        let chorusDepth = 2.0 + dramaticDistance * 5.0
        // Phrase-scale memory: the tail remains audible across many bars while
        // bounded feedback and ducking keep the groove authoritative.
        let reverbSeconds = 12.0 + scene.atmosphere * 8.0
        let reverbFrames = max(32, Int(sampleRate * reverbSeconds))
        if state.reverbBuffer.count != reverbFrames {
            state.reverbBuffer = [Float](repeating: 0, count: reverbFrames)
            state.reverbWriteIndex = 0
        }
        let reverbFeedback = Float(0.52 + scene.hypnosis * 0.16 + scene.drone * 0.08)
        let reverbWet = Float(dramaticDistance * 0.07 + scene.drone * 0.10)
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)
        var kickEnvelope = 0.0
        var kickEnvelopePeak = 0.0
        var low = 0.0
        var synthLow = 0.0
        var synthMidLow = 0.0
        var synthTone = 0.0
        var highEnvelope = 0.0
        var midEnvelope = 0.0
        var spatialHighPassState = 0.0
        var spatialLowPassState = 0.0
        let spatialHighPassCoefficient = min(
            0.35,
            1 - exp(-2 * .pi * resolved.spatialContrast.highPassHz / sampleRate)
        )
        let spatialLowPassCoefficient = min(
            0.55,
            1 - exp(-2 * .pi * resolved.spatialContrast.lowPassHz / sampleRate)
        )
        let masking: [RoleMaskingObservation] = layer == .full
            ? SpectrumMaskingAnalyzer.analyze(
                signals: [
                    .foundation: maskingFoundationBus,
                    .percussion: percussionStem,
                    .upper: synthBus,
                ],
                sampleRate: sampleRate
            ) : []
        for index in 0..<frames {
            let input = output[index]
            let rawSynthInput = synthBus[index]
            let kickLevel = abs(Double(kickDetectorBus[index]))
            kickEnvelope = max(kickEnvelope * 0.992, kickLevel)
            kickEnvelopePeak = max(kickEnvelopePeak, kickEnvelope)
            // Frequency-dependent sidechain: the centered kick/bass bus owns
            // the low end; the upper texture bus is filtered before spatial
            // effects and receives a stronger musical duck.
            synthLow += (Double(rawSynthInput) - synthLow) * 0.012
            synthMidLow += (Double(rawSynthInput) - synthMidLow) * 0.055
            let lowMid = synthMidLow - synthLow
            let upper = Double(rawSynthInput) - synthMidLow
            // Dynamic low-mid EQ keeps pads, leads, and delay returns from
            // building a constant cloud around the kick. The detector is
            // intentionally slow and bounded: it changes density, never the
            // identity of the note or the mono-compatible low end.
            midEnvelope += (abs(lowMid) - midEnvelope) * 0.014
            let kickMidMask = min(0.16, kickEnvelope * 0.22)
            let dynamicMidCut = min(
                0.42,
                midEnvelope * (0.42 + scene.darkness * 0.24) + kickMidMask
            )
            // Dynamic high-band control: a short envelope on the upper band
            // gently closes the top when metallic texture accumulates energy.
            // This preserves transient definition without making the master
            // limiter responsible for harshness.
            synthTone += (Double(rawSynthInput) - synthTone) * 0.11
            let highBand = upper - synthTone * 0.18
            highEnvelope += (abs(highBand) - highEnvelope) * 0.018
            let dynamicDamping = min(
                0.38,
                highEnvelope * (0.65 + scene.darkness * 0.45)
            )
            let synthInput = Float(synthTone * 0.18 + lowMid * (1.0 - dynamicMidCut) + highBand * (1.0 - dynamicDamping))
            let delayed = state.delayBuffer[state.delayWriteIndex]
            state.delayBuffer[state.delayWriteIndex] = synthInput + delayed * feedback
            let pulseRead = Double(state.pulseEchoBuffer[state.pulseEchoWriteIndex])
            let highPassCoefficient = min(0.25, 1 - exp(-2 * .pi * 180 / sampleRate))
            state.pulseEchoHighPassState +=
                (pulseRead - state.pulseEchoHighPassState) * highPassCoefficient
            let highPassedPulse = pulseRead - state.pulseEchoHighPassState
            let lowPassCoefficient = min(0.45, 1 - exp(-2 * .pi * 3_200 / sampleRate))
            state.pulseEchoLowPassState +=
                (highPassedPulse - state.pulseEchoLowPassState) * lowPassCoefficient
            state.pulseEchoBuffer[state.pulseEchoWriteIndex] = Float(
                Double(pulseEchoSendBus[index]) + pulseRead * 0.28
            )
            state.pulseEchoWriteIndex = (state.pulseEchoWriteIndex + 1) % pulseEchoFrames
            let pulseEcho = Float(state.pulseEchoLowPassState * 0.18)
            // A short independent reflection gives upper voices depth before
            // the longer dark reverb. It is deliberately high-passed by the
            // upper-bus source and never receives kick/bass, preserving mono-
            // compatible low end.
            let earlyRead = state.earlyReflectionBuffer[state.earlyReflectionWriteIndex]
            state.earlyReflectionBuffer[state.earlyReflectionWriteIndex] = synthInput * 0.30
            let earlyMix = Float(0.035 + dramaticDistance * 0.08)
            let reverbRead = state.reverbBuffer[state.reverbWriteIndex]
            let drumSend = percussionStem[index] * Float(scene.atmosphere * 0.08)
            let rawSpatialSend = Double(spatialReverbSendBus[index])
            spatialHighPassState +=
                (rawSpatialSend - spatialHighPassState) * spatialHighPassCoefficient
            let highPassedSpatialSend = rawSpatialSend - spatialHighPassState
            spatialLowPassState +=
                (highPassedSpatialSend - spatialLowPassState) * spatialLowPassCoefficient
            state.reverbBuffer[state.reverbWriteIndex] = synthInput * 0.42 + drumSend +
                Float(spatialLowPassState) + reverbRead * reverbFeedback
            let reverbTail = reverbRead * reverbWet
            state.delayWriteIndex = (state.delayWriteIndex + 1) % delayFrames
            state.earlyReflectionWriteIndex = (state.earlyReflectionWriteIndex + 1) % earlyReflectionFrames
            low += (Double(input) - low) * 0.045
            let duck = Float(1.0 - min(0.20, kickEnvelope * 0.25))
            let upperDuck = Float(1.0 - min(0.38, kickEnvelope * 0.55))
            let dryCenter = input * duck + Float(low) * 0.18
            let center = dryCenter
            let pan = sin(state.stereoPanPhase) * panDepth
            let synthPan = Double(min(1, max(-1, 0.5 + pan)))
            let synthLeft = Float(cos(synthPan * Double.pi * 0.5))
            let synthRight = Float(sin(synthPan * Double.pi * 0.5))
            state.chorusDelay[state.chorusWriteIndex] = synthInput
            let chorusOffset = chorusDepth * sin(state.chorusPhase)
            let baseTap = Int(Double(chorusFrames) * 0.52)
            let leftOffset = max(1, baseTap + Int(chorusOffset))
            let rightOffset = max(1, baseTap - Int(chorusOffset))
            let leftTap = (state.chorusWriteIndex - leftOffset + chorusFrames) % chorusFrames
            let rightTap = (state.chorusWriteIndex - rightOffset + chorusFrames) % chorusFrames
            let chorusLeft = state.chorusDelay[leftTap]
            let chorusRight = state.chorusDelay[rightTap]
            let spatial = delayed * wet
            let delayPan = Float(0.5 + pan * 0.7)
            let chorusMix = Float(0.12 + dramaticDistance * 0.12)
            let synthLeftOut = (synthInput * (1 - chorusMix) * synthLeft + chorusLeft * chorusMix) * upperDuck
            let synthRightOut = (synthInput * (1 - chorusMix) * synthRight + chorusRight * chorusMix) * upperDuck
            let reflectionPan = min(1.0, max(0.0, 0.5 - pan * 0.85))
            let reflectionLeft = earlyRead * earlyMix * Float(cos(reflectionPan * Double.pi * 0.5))
            let reflectionRight = earlyRead * earlyMix * Float(sin(reflectionPan * Double.pi * 0.5))
            let audibleReverbTail = reverbTail
            let leftPreMaster = center + synthLeftOut + reflectionLeft +
                (spatial + pulseEcho) * (1.0 + delayPan * 0.18) * upperDuck +
                audibleReverbTail * (1.0 + delayPan * 0.24)
            let rightPreMaster = center + synthRightOut + reflectionRight +
                (spatial + pulseEcho) * (1.0 + (1.0 - delayPan) * 0.18) * upperDuck +
                audibleReverbTail * (1.0 + (1.0 - delayPan) * 0.24)
            // Linked two-band glue: center and upper energy share detector
            // gains, so compression cannot pull the stereo image sideways.
            // This is deliberately before the master safety stage.
            let linkedLow = abs(Double(center))
            let linkedUpper = max(abs((Double(leftPreMaster - center) + Double(rightPreMaster - center)) * 0.5), 0)
            let lowCoefficient = linkedLow > state.lowBandEnvelope ? 0.12 : 0.006
            let highCoefficient = linkedUpper > state.highBandEnvelope ? 0.10 : 0.008
            state.lowBandEnvelope += (linkedLow - state.lowBandEnvelope) * lowCoefficient
            state.highBandEnvelope += (linkedUpper - state.highBandEnvelope) * highCoefficient
            let lowOver = max(0, state.lowBandEnvelope - 0.34)
            let highOver = max(0, state.highBandEnvelope - 0.26)
            let lowGain = lowOver > 0 ? (0.34 + lowOver / 2.2) / state.lowBandEnvelope : 1.0
            let highGain = highOver > 0 ? (0.26 + highOver / 1.8) / state.highBandEnvelope : 1.0
            let leftCompressed = center * Float(lowGain) + (leftPreMaster - center) * Float(highGain)
            let rightCompressed = center * Float(lowGain) + (rightPreMaster - center) * Float(highGain)
            let envelopeInput = max(abs(Double(leftCompressed)), abs(Double(rightCompressed)))
            let envelopeCoefficient = envelopeInput > state.masterEnvelope ? 0.16 : 0.004
            state.masterEnvelope += (envelopeInput - state.masterEnvelope) * envelopeCoefficient
            let threshold = 0.42
            let over = max(0, state.masterEnvelope - threshold)
            let compressionGain = over > 0 ? (threshold + over / 2.8) / state.masterEnvelope : 1.0
            left[index] = safeMaster(leftCompressed * Float(compressionGain) * 1.015)
            right[index] = safeMaster(rightCompressed * Float(compressionGain) * 1.015)
            state.stereoPanPhase = (state.stereoPanPhase + panRate).truncatingRemainder(dividingBy: 2.0 * Double.pi)
            state.chorusPhase = (state.chorusPhase + chorusRate).truncatingRemainder(dividingBy: 2.0 * Double.pi)
            state.chorusWriteIndex = (state.chorusWriteIndex + 1) % chorusFrames
            state.reverbWriteIndex = (state.reverbWriteIndex + 1) % reverbFrames
        }
        let audibleKickPeak = kickBus.reduce(0) { max($0, abs($1)) }
        let detectorKickPeak = kickDetectorBus.reduce(0) { max($0, abs($1)) }
        let audibleKickRMS = Float(sqrt(
            kickBus.reduce(0.0) { $0 + Double($1 * $1) } / Double(max(1, frames))
        ))
        let detectorKickRMS = Float(sqrt(
            kickDetectorBus.reduce(0.0) { $0 + Double($1 * $1) } / Double(max(1, frames))
        ))
        let kickMix = KickMixEvidence(
            audibleGain: KickMixBalance.audibleGain * Double(automaticKickGain),
            audiblePeak: audibleKickPeak,
            audibleRMS: audibleKickRMS,
            detectorPeak: detectorKickPeak,
            detectorRMS: detectorKickRMS,
            duckingEnvelopePeak: Float(kickEnvelopePeak)
        )
        let rendered = RenderedBar(sampleRate: sampleRate,
                                   samples: zip(left, right).map { ($0 + $1) * 0.5 },
                                   leftSamples: left, rightSamples: right,
                                   masking: masking, kickMix: kickMix,
                                   stemObservations: stemObservations,
                                   automaticMix: automaticMix,
                                   stemReconstruction: stemReconstruction,
                                   dryFoundationSampleHash: ExactPCMFingerprint.mono(
                                    maskingFoundationBus
                                   ),
                                   dryPercussionSampleHash: ExactPCMFingerprint.mono(
                                    percussionStem
                                   ),
                                   groovePulseRenderEvidence: groovePulseRenderEvidence,
                                   upperNoteRenderEvidence: upperNoteRenderEvidence,
                                   resonantAnchorSamples: resonantAnchorStem,
                                   detunedCompanionSamples: detunedCompanionStem)
        swap(&output, &checkedOut.output)
        swap(&kickBus, &checkedOut.kick)
        swap(&kickDetectorBus, &checkedOut.kickDetector)
        swap(&foundationStem, &checkedOut.foundationStem)
        swap(&percussionStem, &checkedOut.percussionStem)
        swap(&upperTonalStem, &checkedOut.upperTonalStem)
        swap(&atmosphereStem, &checkedOut.atmosphereStem)
        swap(&resonantAnchorStem, &checkedOut.resonantAnchorStem)
        swap(&detunedCompanionStem, &checkedOut.detunedCompanionStem)
        swap(&maskingFoundationBus, &checkedOut.maskingFoundation)
        swap(&synthBus, &checkedOut.synth)
        swap(&pulseEchoSendBus, &checkedOut.pulseEchoSend)
        swap(&spatialReverbSendBus, &checkedOut.spatialReverbSend)
        workspace.recycle(&checkedOut)
        return rendered
    }

    private static func renderAlienWorld(
        _ output: inout [Float],
        pulseEchoSend: inout [Float],
        spatialReverbSend: inout [Float],
        upperTonalStem: inout [Float],
        atmosphereStem: inout [Float],
        resonantAnchorStem: inout [Float],
        detunedCompanionStem: inout [Float],
        noteRenderEvidence: inout [UpperNoteRenderEvidence],
        renderScheduledNotes: Bool,
        scene: TechnoScene,
        sampleRate: Double,
        stepFrames: Double,
        resolved: ResolvedPerformanceBar,
        world: SynthWorldDNA,
        synthBar: SynthPerformanceBar,
        state: inout RenderState
    ) {
        func spatialScales(for voice: EnsembleVoice, step: Int) -> (dry: Double, send: Double) {
            let spatial = resolved.spatialContrast
            guard spatial.depthPosition == .distant,
                  spatial.carrierVoice == voice,
                  spatial.carrierStep == step else {
                return (1, 0)
            }
            return (spatial.dryScale, spatial.reverbSend)
        }

        func ensembleVoice(for role: SynthRole) -> EnsembleVoice? {
            switch role {
            case .anchor: .motif
            case .response: .response
            case .atmosphere: .atmosphere
            case .transition: .transition
            case .shadow: nil
            }
        }

        func notes(for role: SynthRole) -> [AlienVoiceNote] {
            guard renderScheduledNotes else { return [] }
            return synthBar.upperNotes(for: role).map { note in
                let spatial: (dry: Double, send: Double)
                if let voice = ensembleVoice(for: role) {
                    spatial = spatialScales(for: voice, step: note.onsetStep)
                } else {
                    spatial = (1, 0)
                }
                let relational: RelationalArticulation = switch role {
                case .anchor, .shadow, .response:
                    synthBar.articulation(at: note.onsetStep)
                case .atmosphere, .transition:
                    .neutral
                }
                let narrativeGain: Double
                let narrativeSpectral: Double
                if role == .anchor {
                    narrativeGain = resolved.narrative.motifGainScale(atStep: note.onsetStep)
                    narrativeSpectral = resolved.narrative.motifSpectralScale(atStep: note.onsetStep)
                } else {
                    narrativeGain = 1
                    narrativeSpectral = 1
                }
                return AlienVoiceNote(
                    startFrame: Int((Double(note.onsetStep) * stepFrames).rounded()),
                    durationFrames: max(1, Int((note.durationInSteps * stepFrames).rounded())),
                    frequency: world.rootFrequency * note.startFrequencyRatio,
                    endFrequency: world.rootFrequency * note.endFrequencyRatio,
                    velocity: note.velocity,
                    gate: note.gate,
                    timbreIntent: note.timbreIntent,
                    role: role,
                    articulation: relational,
                    dryScale: spatial.dry,
                    spatialReverbSend: spatial.send,
                    narrativeGainScale: narrativeGain,
                    narrativeSpectralScale: narrativeSpectral
                )
            }
        }

        let anchorNotes = notes(for: .anchor)
        AlienAnalogVoice.render(
            &output, measurement: &resonantAnchorStem, pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            noteRenderEvidence: &noteRenderEvidence,
            notes: anchorNotes, sampleRate: sampleRate,
            level: 0.090 + scene.synthPresence * 0.060,
            world: world, bar: synthBar, role: .anchor,
            state: &state.alienAnchorState
        )

        let shadowNotes = notes(for: .shadow)
        AlienAnalogVoice.render(
            &output, measurement: &detunedCompanionStem, pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            noteRenderEvidence: &noteRenderEvidence,
            notes: shadowNotes, sampleRate: sampleRate,
            level: 0.032 + scene.synthPresence * 0.034,
            world: world, bar: synthBar, role: .shadow,
            state: &state.alienShadowState
        )

        let atmosphereNotes = notes(for: .atmosphere)
        AlienAnalogVoice.render(
            &output, measurement: &atmosphereStem, pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            noteRenderEvidence: &noteRenderEvidence,
            notes: atmosphereNotes, sampleRate: sampleRate,
            level: 0.017 + scene.atmosphere * 0.025 + scene.drone * 0.018,
            world: world, bar: synthBar, role: .atmosphere,
            state: &state.alienAtmosphereState
        )

        let responseNotes = notes(for: .response)
        AlienAnalogVoice.render(
            &output, measurement: &detunedCompanionStem, pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            noteRenderEvidence: &noteRenderEvidence,
            notes: responseNotes, sampleRate: sampleRate,
            level: 0.026 + scene.melodicity * 0.030,
            world: world, bar: synthBar, role: .response,
            state: &state.alienResponseState
        )

        let transitionNotes = notes(for: .transition)
        AlienAnalogVoice.render(
            &output, measurement: &atmosphereStem, pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            noteRenderEvidence: &noteRenderEvidence,
            notes: transitionNotes, sampleRate: sampleRate,
            level: 0.008 + scene.atmosphere * 0.012,
            world: world, bar: synthBar, role: .transition,
            state: &state.alienTransitionState
        )
        for frame in upperTonalStem.indices {
            upperTonalStem[frame] = resonantAnchorStem[frame] + detunedCompanionStem[frame]
        }
    }

    private static func safeMaster(_ sample: Float) -> Float {
        Float(tanh(Double(sample) * 1.12) * 0.78)
    }

    private static func relationalBassFrequency(dna: SceneDNA, step: Int, tension: Double) -> Double {
        let index = dna.rhythm.bassSteps.firstIndex(of: step) ?? (step / 2)
        if dna.modalIdentity == .phrygian {
            // Phrygian tension belongs to the upper voices. The protected low
            // end remains on root, fifth, and octave relationships.
            let foundationDegrees = [0, 7, 0, 12]
            let degree = foundationDegrees[index % foundationDegrees.count]
            return 43.65 * pow(2, Double(dna.tonalCenter + degree) / 12.0)
        }
        let modalIndex = index % dna.modalDegrees.count
        var degree = dna.modalDegrees[modalIndex]
        if tension > 0.72 && modalIndex == dna.modalDegrees.count - 1 { degree += 1 }
        return 43.65 * pow(2, Double(dna.tonalCenter + degree) / 12.0)
    }

    private static func kick(_ output: inout [Float], start: Int, sampleRate: Double, level: Double, seed: UInt64, step: Int) {
        let frames = min(Int(sampleRate * 0.32), output.count - start); guard frames > 0 else { return }
        var random = SeededGenerator(seed: seed ^ UInt64(step + 1) ^ 0x9E3779B97F4A7C15)
        var bodyPhase = 0.0
        var subPhase = 0.0
        let fundamental = 44.0 + Double(seed % 5) * 0.7
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            let pitch = fundamental + 205 * exp(-t * 48) + 28 * exp(-t * 150)
            bodyPhase += 2 * Double.pi * pitch / sampleRate
            subPhase += 2 * Double.pi * fundamental / sampleRate
            let attack = min(1, t / 0.0012)
            let bodyEnvelope = attack * exp(-t * 17.5)
            let subEnvelope = min(1, t / 0.006) * exp(-t * 12.5)
            let body = tanh((sin(bodyPhase) + sin(bodyPhase * 2) * 0.075) * 1.22) * bodyEnvelope
            let sub = sin(subPhase) * subEnvelope * 0.22
            let transientEnvelope = exp(-t * 1_050)
            let transient = i < Int(sampleRate * 0.0045)
                ? ((random.unit() * 2 - 1) * 0.08 + sin(2 * .pi * 2_800 * t) * 0.055) * transientEnvelope
                : 0
            output[start + i] += Float((body + sub + transient) * level)
        }
    }

    private static func rumble(_ output: inout [Float], measurement: inout [Float],
                               start: Int, sampleRate: Double,
                               level: Double, seed: UInt64, step: Int) {
        let frames = min(Int(sampleRate * 0.68), output.count - start)
        guard frames > 0 else { return }
        var phase = 0.0
        var noiseLow = 0.0
        var random = SeededGenerator(seed: seed ^ UInt64(step + 1) ^ 0x2A4B1E)
        let frequency = 43.0 + Double(seed % 7) * 0.55
        for index in 0..<frames {
            let time = Double(index) / sampleRate
            phase += 2 * .pi * frequency / sampleRate
            let noise = random.unit() * 2 - 1
            noiseLow += (noise - noiseLow) * 0.018
            // The delayed attack is the kick duck: the companion cannot mask
            // the transient that created it.
            let duckedAttack = 1 - exp(-time * 34)
            let envelope = duckedAttack * exp(-time * 5.6)
            let body = sin(phase) * 0.82 + noiseLow * 0.18
            let renderedSample = Float(tanh(body * 1.12) * envelope * level)
            output[start + index] += renderedSample
            measurement[start + index] += renderedSample
        }
    }

    private static func bass(_ output: inout [Float], measurement: inout [Float],
                             start: Int, sampleRate: Double, level: Double,
                             frequency: Double, articulation: Double, phase: inout Double, filterState: inout Double) {
        let frames = min(Int(sampleRate * (0.20 + articulation * 0.12)), output.count - start); guard frames > 0 else { return }
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            phase += 2 * Double.pi * frequency / sampleRate
            let envelope = min(1, t / 0.005) * exp(-t * (7.2 + articulation * 3.2))
            let saw = 2 * ((phase / (2 * .pi)).truncatingRemainder(dividingBy: 1)) - 1
            let source = sin(phase) * 0.72 + saw * 0.28
            let cutoff = 95 + articulation * 280 + envelope * (260 + articulation * 520)
            let coefficient = min(0.28, 1 - exp(-2 * .pi * cutoff / sampleRate))
            filterState += (tanh(source * (1.15 + articulation * 0.5)) - filterState) * coefficient
            let renderedSample = Float(tanh(filterState * 1.35) * envelope * level)
            output[start + i] += renderedSample
            measurement[start + i] += renderedSample
        }
    }

    private static func hat(_ output: inout [Float], measurement: inout [Float],
                            start: Int, sampleRate: Double, level: Double,
                            brightness: Double, random: inout SeededGenerator) {
        let frames = min(Int(sampleRate * 0.05), output.count - start); guard frames > 0 else { return }; var state = 0.0
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            let n = random.unit() * 2 - 1
            state += (n - state) * (0.25 + brightness * 0.25)
            let renderedSample = Float((n - state * 0.7) * exp(-t * (32 - brightness * 8)) * level)
            output[start + i] += renderedSample
            measurement[start + i] += renderedSample
        }
    }

    private static func clap(_ output: inout [Float], measurement: inout [Float],
                             start: Int, sampleRate: Double, level: Double, brightness: Double,
                             random: inout SeededGenerator) {
        let frames = min(Int(sampleRate * 0.16), output.count - start); guard frames > 0 else { return }
        var low = 0.0
        let bursts = [0.0, 0.011, 0.023]
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            let noise = random.unit() * 2 - 1
            low += (noise - low) * 0.12
            let burstEnvelope = bursts.reduce(0.0) { value, offset in
                guard t >= offset else { return value }
                return value + exp(-(t - offset) * (85 + brightness * 35))
            }
            let tail = t > 0.026 ? exp(-(t - 0.026) * 25) * 0.34 : 0
            let body = sin(2 * .pi * 185 * t) * exp(-t * 31) * 0.22
            let renderedSample = Float(
                ((noise - low * 0.72) * (burstEnvelope * 0.46 + tail) + body) * level
            )
            output[start + i] += renderedSample
            measurement[start + i] += renderedSample
        }
    }

    private static func tom(_ output: inout [Float], measurement: inout [Float],
                            start: Int, sampleRate: Double, level: Double, frequency: Double) {
        let frames = min(Int(sampleRate * 0.22), output.count - start)
        guard frames > 0 else { return }
        var phase = 0.0
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            let glide = frequency * (1.0 + 0.16 * exp(-t * 30))
            phase += 2 * Double.pi * glide / sampleRate
            let envelope = min(1.0, t / 0.004) * exp(-t * 17)
            let body = sin(phase) + sin(phase * 1.97) * 0.08
            let renderedSample = Float(tanh(body * 1.15) * envelope * level)
            output[start + i] += renderedSample
            measurement[start + i] += renderedSample
        }
    }

    private static func metallicPercussion(_ output: inout [Float], measurement: inout [Float],
                                           start: Int, sampleRate: Double,
                                           level: Double, brightness: Double,
                                           random: inout SeededGenerator) {
        let frames = min(Int(sampleRate * 0.065), output.count - start)
        guard frames > 0 else { return }
        let partials = [1_730.0, 2_417.0, 3_101.0, 4_729.0, 6_083.0]
        var noiseState = 0.0
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            let noise = random.unit() * 2 - 1
            noiseState += (noise - noiseState) * 0.17
            let resonances = partials.enumerated().reduce(0.0) { result, partial in
                let detune = 1 + Double(partial.offset) * brightness * 0.017
                return result + sin(2 * .pi * partial.element * detune * t + Double(partial.offset) * 0.7) / Double(partial.offset + 2)
            }
            let envelope = exp(-t * (38 - brightness * 10))
            let renderedSample = Float(
                (resonances * 0.72 + (noise - noiseState) * 0.16) * envelope * level
            )
            output[start + i] += renderedSample
            measurement[start + i] += renderedSample
        }
    }

    private static func openHat(_ output: inout [Float], measurement: inout [Float],
                                start: Int, sampleRate: Double, level: Double,
                                brightness: Double, random: inout SeededGenerator) {
        let frames = min(Int(sampleRate * 0.19), output.count - start)
        guard frames > 0 else { return }
        var filtered = 0.0
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            let noise = random.unit() * 2.0 - 1.0
            filtered += (noise - filtered) * (0.16 + brightness * 0.16)
            let metallic = sin(2.0 * Double.pi * (3_600 + brightness * 3_800) * t)
                + sin(2.0 * Double.pi * (5_100 + brightness * 2_200) * t) * 0.42
            let envelope = min(1.0, t / 0.0015) * exp(-t * (18.0 - brightness * 4.0))
            let renderedSample = Float(
                (noise - filtered * 0.55 + metallic * 0.16) * envelope * level
            )
            output[start + i] += renderedSample
            measurement[start + i] += renderedSample
        }
    }

}
