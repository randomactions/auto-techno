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

    package static func render(_ output: inout [Float], measurement: inout [Float],
                               start: Int, sampleRate: Double,
                               intensity: Double, seed: UInt64) {
        let frames = min(Int(sampleRate * durationSeconds), output.count - start)
        guard frames > 0 else { return }
        var random = SeededGenerator(seed: seed)
        var highPassState = 0.0
        var lowPassState = 0.0
        let highPassCoefficient = min(
            0.35,
            1 - exp(-2 * .pi * highPassFrequency / sampleRate)
        )
        let lowPassCoefficient = min(
            0.55,
            1 - exp(-2 * .pi * lowPassFrequency / sampleRate)
        )
        for index in 0..<frames {
            let time = Double(index) / sampleRate
            let noise = random.unit() * 2 - 1
            highPassState += (noise - highPassState) * highPassCoefficient
            let highPassed = noise - highPassState
            let mutedClick = sin(2 * .pi * 1_180 * time) * exp(-time * 145) * 0.24
            lowPassState += (highPassed * 0.78 + mutedClick - lowPassState) * lowPassCoefficient
            let attack = min(1, time / 0.0008)
            let envelope = attack * exp(-time * 72)
            let renderedSample = Float(
                tanh(lowPassState * 1.16) * envelope * baseLevel * intensity
            )
            output[start + index] += renderedSample
            measurement[start + index] += renderedSample
        }
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
        var checkedOut = workspace.checkout(frameCount: frames)
        var output: [Float] = []
        var kickBus: [Float] = []
        var kickDetectorBus: [Float] = []
        var foundationStem: [Float] = []
        var percussionStem: [Float] = []
        var upperTonalStem: [Float] = []
        var atmosphereStem: [Float] = []
        var measurementScratch: [Float] = []
        var percussionBus: [Float] = []
        var synthBus: [Float] = []
        var pulseEchoSendBus: [Float] = []
        var spatialReverbSendBus: [Float] = []
        swap(&output, &checkedOut.output)
        swap(&kickBus, &checkedOut.kick)
        swap(&kickDetectorBus, &checkedOut.kickDetector)
        swap(&foundationStem, &checkedOut.foundationStem)
        swap(&percussionStem, &checkedOut.percussionStem)
        swap(&upperTonalStem, &checkedOut.upperTonalStem)
        swap(&atmosphereStem, &checkedOut.atmosphereStem)
        swap(&measurementScratch, &checkedOut.measurementScratch)
        swap(&percussionBus, &checkedOut.percussion)
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
            case .percussion where layer == .full:
                let level = (section == .build ? 0.09 : 0.075) * accent
                hat(&output, measurement: &percussionStem, start: start,
                    sampleRate: sampleRate, level: level,
                    brightness: scene.character.percussionBrightness, random: &random)
                hat(&percussionBus, measurement: &measurementScratch, start: start,
                    sampleRate: sampleRate, level: level,
                    brightness: scene.character.percussionBrightness, random: &random)
            case .clap where layer == .full:
                clap(&output, measurement: &percussionStem,
                     start: start, sampleRate: sampleRate, level: 0.08 * accent,
                     brightness: scene.character.percussionBrightness, random: &random)
                clap(&percussionBus, measurement: &measurementScratch,
                     start: start, sampleRate: sampleRate, level: 0.08 * accent,
                     brightness: scene.character.percussionBrightness, random: &random)
            case .openHat where layer == .full:
                openHat(&output, measurement: &percussionStem,
                        start: start, sampleRate: sampleRate,
                        level: 0.052 * accent,
                        brightness: scene.character.percussionBrightness, random: &random)
                openHat(&percussionBus, measurement: &measurementScratch,
                        start: start, sampleRate: sampleRate,
                        level: 0.052 * accent,
                        brightness: scene.character.percussionBrightness, random: &random)
            case .metallic where layer == .full:
                metallicPercussion(&output, measurement: &percussionStem,
                                   start: start, sampleRate: sampleRate,
                                   level: 0.042 * accent,
                                   brightness: scene.character.percussionBrightness, random: &random)
                metallicPercussion(&percussionBus, measurement: &measurementScratch,
                                   start: start, sampleRate: sampleRate,
                                   level: 0.042 * accent,
                                   brightness: scene.character.percussionBrightness, random: &random)
            case .groovePulse where layer == .full:
                guard let pulseArticulation else { break }
                let pulseSeed = performance.eventSeed ^ UInt64(event.step + 1) ^ 0x6A20_0C15
                GroovePulseVoice.render(
                    &output, measurement: &percussionStem,
                    start: start, sampleRate: sampleRate,
                    intensity: pulseArticulation.intensity, seed: pulseSeed
                )
                GroovePulseVoice.render(
                    &percussionBus, measurement: &measurementScratch,
                    start: start, sampleRate: sampleRate,
                    intensity: pulseArticulation.intensity, seed: pulseSeed
                )
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
        if layer == .full && !textureCollapsed && upperRolesActive {
            renderAlienWorld(
                &synthBus,
                pulseEchoSend: &pulseEchoSendBus,
                spatialReverbSend: &spatialReverbSendBus,
                upperTonalStem: &upperTonalStem,
                atmosphereStem: &atmosphereStem,
                scene: scene,
                section: section,
                sampleRate: sampleRate,
                frames: frames,
                stepFrames: stepFrames,
                dna: dna,
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
            let reconstructedCenter = kickBus[index] + foundationStem[index] + percussionStem[index]
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
        let masking = SpectrumMaskingAnalyzer.analyze(
            signals: [.kickBass: kickBus, .percussion: percussionBus, .synth: synthBus, .texture: synthBus],
            sampleRate: sampleRate)
        let lowMidMask = masking.filter { ($0.band.name == "low-mid" || $0.band.name == "mid") && ($0.yieldingRole == .synth || $0.yieldingRole == .texture) }.map(\.cut).max() ?? 0
        let highMask = masking.filter { $0.band.name == "high" && ($0.yieldingRole == .synth || $0.yieldingRole == .texture) }.map(\.cut).max() ?? 0
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
            let dynamicMidCut = min(0.42, midEnvelope * (0.42 + scene.darkness * 0.24) + kickMidMask + lowMidMask)
            // Dynamic high-band control: a short envelope on the upper band
            // gently closes the top when metallic texture accumulates energy.
            // This preserves transient definition without making the master
            // limiter responsible for harshness.
            synthTone += (Double(rawSynthInput) - synthTone) * 0.11
            let highBand = upper - synthTone * 0.18
            highEnvelope += (abs(highBand) - highEnvelope) * 0.018
            let dynamicDamping = min(0.38, highEnvelope * (0.65 + scene.darkness * 0.45) + highMask)
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
            let drumSend = percussionBus[index] * Float(scene.atmosphere * 0.08)
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
            duckingEnvelopePeak: Float(kickEnvelopePeak),
            maskingInputPeak: audibleKickPeak
        )
        let rendered = RenderedBar(sampleRate: sampleRate,
                                   samples: zip(left, right).map { ($0 + $1) * 0.5 },
                                   leftSamples: left, rightSamples: right,
                                   masking: masking, kickMix: kickMix,
                                   stemObservations: stemObservations,
                                   automaticMix: automaticMix,
                                   stemReconstruction: stemReconstruction)
        swap(&output, &checkedOut.output)
        swap(&kickBus, &checkedOut.kick)
        swap(&kickDetectorBus, &checkedOut.kickDetector)
        swap(&foundationStem, &checkedOut.foundationStem)
        swap(&percussionStem, &checkedOut.percussionStem)
        swap(&upperTonalStem, &checkedOut.upperTonalStem)
        swap(&atmosphereStem, &checkedOut.atmosphereStem)
        swap(&measurementScratch, &checkedOut.measurementScratch)
        swap(&percussionBus, &checkedOut.percussion)
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
        scene: TechnoScene,
        section: SectionKind,
        sampleRate: Double,
        frames: Int,
        stepFrames: Double,
        dna: SceneDNA,
        resolved: ResolvedPerformanceBar,
        world: SynthWorldDNA,
        synthBar: SynthPerformanceBar,
        state: inout RenderState
    ) {
        let performance = resolved.performance
        let ensembleEvents = resolved.ensemble.events
        let motifEvents = transformedMotif(
            dna: dna,
            performance: performance,
            events: ensembleEvents.filter { $0.voice == .motif }
        )
        let baseFrequency = motifEvents.first?.frequency ?? world.rootFrequency * 2

        func spatialScales(for voice: EnsembleVoice, step: Int) -> (dry: Double, send: Double) {
            let spatial = resolved.spatialContrast
            guard spatial.depthPosition == .distant,
                  spatial.carrierVoice == voice,
                  spatial.carrierStep == step else {
                return (1, 0)
            }
            return (spatial.dryScale, spatial.reverbSend)
        }

        var anchorNotes: [AlienVoiceNote] = []
        if !motifEvents.isEmpty {
            anchorNotes = motifEvents.enumerated().map { _, event in
                let accent = performance.accent(at: event.stepIndex)
                let articulation = synthBar.articulation(at: event.stepIndex)
                let spatial = spatialScales(for: .motif, step: event.stepIndex)
                let narrative = resolved.narrative
                return AlienVoiceNote(
                    startFrame: Int((Double(event.stepIndex) * stepFrames).rounded()),
                    durationFrames: max(1, Int((event.durationInSteps * stepFrames).rounded())),
                    frequency: event.frequency,
                    endFrequency: event.frequency,
                    velocity: min(1, (0.66 + accent * 0.24) * articulation.velocityScale),
                    role: .anchor,
                    articulation: articulation,
                    dryScale: spatial.dry,
                    spatialReverbSend: spatial.send,
                    narrativeGainScale: narrative.motifGainScale(atStep: event.stepIndex),
                    narrativeSpectralScale: narrative.motifSpectralScale(atStep: event.stepIndex)
                )
            }
        }
        AlienAnalogVoice.render(
            &output, measurement: &upperTonalStem, pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            notes: anchorNotes, sampleRate: sampleRate,
            level: 0.090 + scene.synthPresence * 0.060,
            world: world, bar: synthBar, role: .anchor,
            state: &state.alienAnchorState
        )

        var shadowNotes: [AlienVoiceNote] = []
        if section != .breakdown {
            shadowNotes = synthBar.interlockEvents.map { event in
                var frequency = baseFrequency * event.frequencyRatio
                while frequency < 92 { frequency *= 2 }
                while frequency > 880 { frequency *= 0.5 }
                return AlienVoiceNote(
                    startFrame: Int((Double(event.stepIndex) * stepFrames).rounded()),
                    durationFrames: max(1, Int((stepFrames * 0.52 *
                        event.articulation.decayScale).rounded())),
                    frequency: frequency,
                    endFrequency: frequency,
                    velocity: min(1, event.velocity * event.articulation.velocityScale),
                    role: .shadow,
                    articulation: event.articulation,
                    dryScale: 1,
                    spatialReverbSend: 0,
                    narrativeGainScale: 1,
                    narrativeSpectralScale: 1
                )
            }
        }
        AlienAnalogVoice.render(
            &output, measurement: &upperTonalStem, pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            notes: shadowNotes, sampleRate: sampleRate,
            level: 0.032 + scene.synthPresence * 0.034,
            world: world, bar: synthBar, role: .shadow,
            state: &state.alienShadowState
        )

        var atmosphereNotes: [AlienVoiceNote] = []
        let atmosphereEvents = ensembleEvents.filter { $0.voice == .atmosphere }
        if !atmosphereEvents.isEmpty, scene.atmosphere > 0.08 || scene.drone > 0.01 {
            let frequency = world.rootFrequency * (section == .breakdown ? 1.5 : 2)
            atmosphereNotes = atmosphereEvents.map { event in
                let start = Int((Double(event.step) * stepFrames).rounded())
                let spatial = spatialScales(for: .atmosphere, step: event.step)
                return AlienVoiceNote(
                    startFrame: start,
                    durationFrames: max(1, frames - start),
                    frequency: frequency,
                    endFrequency: frequency * (synthBar.gesture == .suspend ? 1.018 : 1.003),
                    velocity: min(0.72, event.intensity + scene.atmosphere * 0.22),
                    role: .atmosphere,
                    articulation: .neutral,
                    dryScale: spatial.dry,
                    spatialReverbSend: spatial.send,
                    narrativeGainScale: 1,
                    narrativeSpectralScale: 1
                )
            }
        }
        AlienAnalogVoice.render(
            &output, measurement: &atmosphereStem, pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            notes: atmosphereNotes, sampleRate: sampleRate,
            level: 0.017 + scene.atmosphere * 0.025 + scene.drone * 0.018,
            world: world, bar: synthBar, role: .atmosphere,
            state: &state.alienAtmosphereState
        )

        var responseNotes: [AlienVoiceNote] = []
        let responseEvents = ensembleEvents.filter { $0.voice == .response }
        if synthBar.gesture != .suspend, !responseEvents.isEmpty, scene.melodicity > 0.18 {
            let interval = pow(2, Double(world.responseInterval) / 12)
            let frequency = min(1_200, max(120, baseFrequency * interval))
            responseNotes = responseEvents.map { event in
                let articulation = synthBar.articulation(at: event.step)
                let spatial = spatialScales(for: .response, step: event.step)
                return AlienVoiceNote(
                    startFrame: Int((Double(event.step) * stepFrames).rounded()),
                    durationFrames: max(1, Int((stepFrames * 1.8).rounded())),
                    frequency: frequency,
                    endFrequency: frequency,
                    velocity: min(0.76,
                        (event.intensity + scene.melodicity * 0.24) * articulation.velocityScale),
                    role: .response,
                    articulation: articulation,
                    dryScale: spatial.dry,
                    spatialReverbSend: spatial.send,
                    narrativeGainScale: 1,
                    narrativeSpectralScale: 1
                )
            }
        }
        AlienAnalogVoice.render(
            &output, measurement: &upperTonalStem, pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            notes: responseNotes, sampleRate: sampleRate,
            level: 0.026 + scene.melodicity * 0.030,
            world: world, bar: synthBar, role: .response,
            state: &state.alienResponseState
        )

        var transitionNotes: [AlienVoiceNote] = []
        let transitionEvents = ensembleEvents.filter { $0.voice == .transition }
        if synthBar.gesture != .suspend, !transitionEvents.isEmpty {
            let startFrequency = world.rootFrequency * 2
            transitionNotes = transitionEvents.map { event in
                let start = Int((Double(event.step) * stepFrames).rounded())
                let spatial = spatialScales(for: .transition, step: event.step)
                return AlienVoiceNote(
                    startFrame: start,
                    durationFrames: max(1, frames - start),
                    frequency: startFrequency,
                    endFrequency: startFrequency * (synthBar.gesture == .corrode ? 3.8 : 1.5),
                    velocity: min(0.54, event.intensity + synthBar.mutationAmount * 0.18),
                    role: .transition,
                    articulation: .neutral,
                    dryScale: spatial.dry,
                    spatialReverbSend: spatial.send,
                    narrativeGainScale: 1,
                    narrativeSpectralScale: 1
                )
            }
        }
        AlienAnalogVoice.render(
            &output, measurement: &atmosphereStem, pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            notes: transitionNotes, sampleRate: sampleRate,
            level: 0.008 + scene.atmosphere * 0.012,
            world: world, bar: synthBar, role: .transition,
            state: &state.alienTransitionState
        )
    }

    private static func safeMaster(_ sample: Float) -> Float {
        Float(tanh(Double(sample) * 1.12) * 0.78)
    }

    package static func transformedMotif(dna: SceneDNA, performance: PerformanceBar,
                                         events: [EnsembleResolvedEvent]) -> [SynthEvent] {
        let answer = performance.transformations.contains(.answer) || performance.signatureEvent == .alteredMotifAnswer
        return events.enumerated().map { index, event in
            let shadow = performance.signatureEvent == .harmonicShadow ? 1 : 0
            let requestedDegree = dna.motif.degrees[index % dna.motif.degrees.count] +
                (answer ? 7 : 0) + shadow
            let degree = dna.nearestModalDegree(to: requestedDegree)
            let frequency = 65.41 * pow(2, Double(dna.tonalCenter + degree) / 12.0)
            return SynthEvent(stepIndex: event.step, offsetInStep: 0,
                              scaleDegree: degree, frequency: frequency,
                              durationInSteps: performance.transformations.contains(.extend) ? 2.5 : 1.5,
                              bar: performance.bar, sourceIntent: .hypnosis)
        }
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
