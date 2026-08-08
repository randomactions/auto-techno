import AutoTechnoCore
import Foundation

enum V2VoiceRenderer {
    static func renderBar(scene: TechnoScene, section: SectionKind, sampleRate: Double, state: inout V2RenderState,
                          treatment: RenderTreatment = .polished,
                          mastering: V2MasteringProfile = .clubPunch,
                          effects: V2EffectProfile = .full,
                          dna: SceneDNA? = nil,
                          performance: PerformanceBar? = nil,
                          journey: DramaticJourneyBar? = nil,
                          patch: InstrumentPatchDNA? = nil,
                          synthEngine: SynthEngineProfile,
                          synthWorld: SynthWorldDNA? = nil,
                          synthPerformance: SynthPerformanceBar? = nil,
                          workspace: inout V2RenderWorkspace,
                          isolatedStem: V2StemKind? = nil) -> RenderedBar {
        let frames = max(1, Int((240.0 / scene.bpm * sampleRate).rounded()))
        let stepFrames = Double(frames) / 16.0
        var checkedOut = workspace.checkout(frameCount: frames)
        var output: [Float] = []
        var kickBus: [Float] = []
        var percussionBus: [Float] = []
        var synthBus: [Float] = []
        swap(&output, &checkedOut.output)
        swap(&kickBus, &checkedOut.kick)
        swap(&percussionBus, &checkedOut.percussion)
        swap(&synthBus, &checkedOut.synth)
        var random = SeededGenerator(seed: performance?.eventSeed ?? (scene.seed ^ UInt64(state.barIndex + 1) ^ 0xA24BAED4963EE407))
        let lowEndPresence = journey?.lowEndPresence ?? 1
        let kickPresence = journey?.kickPresence ?? 1
        let payoffImpact = journey?.payoffStrength ?? 0

        let grooveEvents = dna.map { performanceEvents(dna: $0, performance: performance, bar: state.barIndex) } ?? scene.groove.events
        for event in grooveEvents {
            let start = Int(((Double(event.stepIndex) + event.offsetInStep) * stepFrames).rounded())
            let accent = performance?.accent(at: event.stepIndex) ?? 1
            switch event.kind {
            case .kick where isolatedStem == nil || isolatedStem == .foundation:
                let level = (section == .breakdown ? 0.54 : 0.72) * accent * kickPresence * (1 + payoffImpact * 0.10)
                kick(&output, start: start, sampleRate: sampleRate, level: level, seed: scene.seed, step: event.stepIndex, legacy: performance == nil)
                kick(&kickBus, start: start, sampleRate: sampleRate, level: level, seed: scene.seed, step: event.stepIndex, legacy: performance == nil)
            case .bass where section != .breakdown && lowEndPresence > 0.08 &&
                (isolatedStem == nil || isolatedStem == .foundation) &&
                !(performance?.signatureEvent == .delayedBassEntry && event.stepIndex < 8):
                let frequency = dna.map { relationalBassFrequency(dna: $0, step: event.stepIndex, tension: performance?.tension ?? 0.4) }
                    ?? bassFrequency(seed: scene.seed, step: event.stepIndex)
                bass(&output, start: start, sampleRate: sampleRate,
                     level: (0.11 + (performance?.tension ?? 0.4) * 0.035) * accent * lowEndPresence * (1 + payoffImpact * 0.12),
                     frequency: frequency, articulation: 0.3 + (performance?.tension ?? 0.4) * 0.5,
                     phase: &state.bassPhase, filterState: &state.bassFilter, legacy: performance == nil)
            case .hat where section != .breakdown && (isolatedStem == nil || isolatedStem == .percussion):
                let expectation = journey?.tension.rhythmicExpectation ?? 0
                let level = (section == .build ? 0.09 : 0.075) * accent * (1 + expectation * 0.10)
                hat(&output, start: start, sampleRate: sampleRate, level: level, brightness: scene.character.percussionBrightness, random: &random)
                hat(&percussionBus, start: start, sampleRate: sampleRate, level: level, brightness: scene.character.percussionBrightness, random: &random)
            case .clap where section != .breakdown && (isolatedStem == nil || isolatedStem == .percussion):
                clap(&output, start: start, sampleRate: sampleRate, level: 0.08 * accent, brightness: scene.character.percussionBrightness, random: &random, legacy: performance == nil)
                clap(&percussionBus, start: start, sampleRate: sampleRate, level: 0.08 * accent, brightness: scene.character.percussionBrightness, random: &random, legacy: performance == nil)
            default: break
            }
        }
        if section != .breakdown && (performance?.roles.contains(.percussion) ?? true) &&
            (isolatedStem == nil || isolatedStem == .percussion) {
            let accentStep = 10 + Int((scene.seed ^ UInt64(state.barIndex * 17)) % 5)
            let accentLevel = 0.035 + scene.drumChaos * 0.045
            if section == .build || section == .returnSection || scene.drumChaos > 0.28 {
                tom(&output, start: Int((Double(accentStep) * stepFrames).rounded()), sampleRate: sampleRate,
                    level: accentLevel, frequency: 92 + Double(scene.seed % 4) * 11)
            }
            if scene.drumChaos > 0.18 {
                let metallicStep = 3 + Int((scene.seed >> 4) % 6)
                metallicPercussion(&output, start: Int((Double(metallicStep) * stepFrames).rounded()),
                                   sampleRate: sampleRate, level: 0.018 + scene.drumChaos * 0.028,
                                   brightness: scene.character.percussionBrightness, random: &random, legacy: performance == nil)
            }
            if section == .build || section == .returnSection {
                let openHatStep = section == .build ? 6 : 14
                openHat(&output, start: Int((Double(openHatStep) * stepFrames).rounded()), sampleRate: sampleRate,
                        level: 0.022 + scene.character.percussionBrightness * 0.018,
                        brightness: scene.character.percussionBrightness, random: &random)
            }
            let phraseEnding = performance.map { $0.localBar == $0.phraseLength - 1 } ?? (state.barIndex % 8 == 7)
            if section == .returnSection && phraseEnding && scene.drumChaos > 0.16 {
                for (offset, frequency) in zip(0..<4, stride(from: 142.0, through: 92.0, by: -16.0)) {
                    let fillStep = 12 + offset
                    tom(&output, start: Int((Double(fillStep) * stepFrames).rounded()), sampleRate: sampleRate,
                        level: 0.022 + scene.drumChaos * 0.025, frequency: frequency)
                }
            }
            if (section == .build || section == .returnSection) && scene.polyrhythm > 0.2 {
                let polyStep = (state.barIndex * 3 + 5) % 16
                metallicPercussion(&output, start: Int((Double(polyStep) * stepFrames).rounded()),
                                   sampleRate: sampleRate, level: 0.012 + scene.polyrhythm * 0.018,
                                   brightness: scene.character.percussionBrightness, random: &random, legacy: performance == nil)
            }
        }
        let textureCollapsed = performance?.signatureEvent == .textureCollapse
        let upperRolesActive = performance.map { bar in
            bar.roles.contains { $0 == .motif || $0 == .response || $0 == .atmosphere || $0 == .transition }
        } ?? true
        if synthEngine == .alienAnalogV1, !textureCollapsed, upperRolesActive,
           let synthWorld, let synthPerformance {
            renderAlienWorld(
                &synthBus,
                scene: scene,
                section: section,
                sampleRate: sampleRate,
                frames: frames,
                stepFrames: stepFrames,
                dna: dna,
                performance: performance,
                world: synthWorld,
                synthBar: synthPerformance,
                isolatedStem: isolatedStem,
                state: &state
            )
        }
        if synthEngine == .legacyReference && section != .breakdown && !textureCollapsed && upperRolesActive &&
            (isolatedStem == nil || isolatedStem == .musicalVoices || isolatedStem == .atmosphere || isolatedStem == .returns) {
            let sectionLevel: Double = section == .build ? 1.12 : (section == .returnSection ? 1.0 : 0.78)
            if (performance?.roles.contains(.atmosphere) ?? true) &&
                (isolatedStem == nil || isolatedStem == .atmosphere || isolatedStem == .returns) {
                pad(&synthBus, sampleRate: sampleRate, level: (0.012 + scene.atmosphere * 0.018 + scene.synthPresence * 0.008) * sectionLevel,
                    root: padRoot(seed: scene.seed), darkness: scene.darkness, phase: &state.padPhase)
            }
            if scene.atmosphere > 0.24 && (isolatedStem == nil || isolatedStem == .atmosphere || isolatedStem == .returns) {
                noiseBed(&synthBus, sampleRate: sampleRate,
                         level: (0.004 + scene.atmosphere * 0.012) * sectionLevel,
                         darkness: scene.darkness, chaos: scene.textureChaos,
                         random: &random, filterState: &state.noiseFilter)
            }
            let motifEvents = (performance?.roles.contains(.motif) ?? true) &&
                (isolatedStem == nil || isolatedStem == .musicalVoices || isolatedStem == .returns)
                ? transformedMotif(scene.motif, dna: dna, performance: performance) : []
            if let journey, let patch {
                var authoredNotes: [AuthoredSynthNote] = []
                for event in motifEvents {
                    let start = Int((Double(event.stepIndex) * stepFrames).rounded())
                    let duration = max(1, Int((event.durationInSteps * stepFrames).rounded()))
                    let accent = performance?.accent(at: event.stepIndex) ?? 1
                    authoredNotes.append(AuthoredSynthNote(startFrame: start, durationFrames: duration,
                                                           frequency: event.frequency,
                                                           velocity: min(1, 0.70 + accent * 0.22)))
                    let returnResponse = section == .returnSection &&
                        (performance.map { $0.localBar >= max(1, $0.phraseLength / 2) } ?? (state.barIndex % 8 >= 4)) &&
                        event.stepIndex % 4 == 0
                    if returnResponse {
                        let responseStart = min(frames - 1, start + Int((stepFrames * 0.75).rounded()))
                        authoredNotes.append(AuthoredSynthNote(startFrame: responseStart,
                                                               durationFrames: max(1, Int(Double(duration) * 0.72)),
                                                               frequency: event.frequency * 1.5,
                                                               velocity: 0.38 + journey.patchMacros.impact * 0.20))
                    }
                }
                AuthoredSynthVoice.render(&synthBus, notes: authoredNotes, sampleRate: sampleRate,
                                           level: 0.090 + scene.synthPresence * 0.052,
                                           patch: patch, macros: journey.patchMacros, state: &state)
            } else {
                for event in motifEvents {
                    let start = Int((Double(event.stepIndex) * stepFrames).rounded())
                    // The final half of each return phrase answers selected motif
                    // notes an octave-plus-fifth above. It is sparse, deterministic
                    // and tied to the existing motif, so the arrangement develops
                    // without introducing an unrelated melody or random density.
                    let returnResponse = section == .returnSection &&
                        (performance.map { $0.localBar >= max(1, $0.phraseLength / 2) } ?? (state.barIndex % 8 >= 4)) &&
                        event.stepIndex % 4 == 0
                    synth(&synthBus, start: start, sampleRate: sampleRate, duration: event.durationInSteps * stepFrames / sampleRate, frequency: event.frequency, level: 0.075 + scene.synthPresence * 0.045, phase: &state.synthPhase, detune: &state.modulationPhase, darkness: scene.darkness, timbralFamily: dna?.timbralFamily ?? 0, resonance: scene.synthChaos, motion: scene.hypnosis)
                    if returnResponse {
                        synth(&synthBus, start: start, sampleRate: sampleRate, duration: event.durationInSteps * stepFrames / sampleRate, frequency: event.frequency * 1.5, level: 0.025 + scene.synthPresence * 0.018, phase: &state.synthPhase, detune: &state.modulationPhase, darkness: scene.darkness, timbralFamily: dna?.timbralFamily ?? 0, resonance: scene.synthChaos * 0.8, motion: scene.hypnosis)
                    }
                }
            }
            let sequencerPresence = scene.musicalIntent?[.sequencerPresence] ?? 0
            if sequencerPresence > 0.04 && (performance?.roles.contains(.motif) ?? true) &&
                (isolatedStem == nil || isolatedStem == .musicalVoices || isolatedStem == .returns) {
                let depth = scene.musicalIntent?[.sequencerDepth] ?? 0.35
                for event in scene.sequencer {
                    let start = Int((Double(event.stepIndex) * stepFrames).rounded())
                    let level = (0.018 + sequencerPresence * 0.035) * (1.0 - depth * 0.25)
                    if event.kind == .pulseNetwork {
                        acidVoice(&synthBus, start: start, sampleRate: sampleRate,
                                  duration: event.durationInSteps * stepFrames / sampleRate,
                                  frequency: event.frequency, level: level * 0.9,
                                  darkness: scene.darkness, resonance: scene.synthChaos,
                                  phase: &state.acidPhase, filterState: &state.acidFilter)
                    } else {
                        synth(&synthBus, start: start, sampleRate: sampleRate,
                              duration: event.durationInSteps * stepFrames / sampleRate,
                              frequency: event.kind == .texturalStepField ? 55 : event.frequency,
                              level: event.kind == .texturalStepField ? level * 0.55 : level,
                              phase: &state.sequencerPhase, detune: &state.modulationPhase,
                              darkness: scene.darkness, timbralFamily: dna?.timbralFamily ?? 0)
                    }
                }
            }
            if (isolatedStem == nil || isolatedStem == .musicalVoices || isolatedStem == .returns) &&
                (performance?.roles.contains(.response) ?? (section == .build || section == .returnSection)) && scene.melodicity > 0.22 {
                let motifAnchor = dna?.motif.steps.last ?? (section == .build ? 6 : 14)
                let leadStep = (motifAnchor + (section == .build ? 5 : 7)) % 16
                let leadDegree = (dna?.motif.degrees.last ?? 0) + 7
                let leadFrequency = dna.map { 65.41 * pow(2, Double($0.tonalCenter + leadDegree) / 12.0) }
                    ?? bassFrequency(seed: scene.seed ^ UInt64(state.barIndex), step: leadStep) * 2.0
                lead(&synthBus, start: Int((Double(leadStep) * stepFrames).rounded()), sampleRate: sampleRate,
                     duration: stepFrames * 2.2 / sampleRate, frequency: leadFrequency,
                     level: 0.018 + scene.melodicity * 0.025, darkness: scene.darkness,
                     phase: &state.leadPhase)
            }
            if performance?.roles.contains(.transition) ?? (section == .build && state.barIndex % 8 >= 6) {
                let pressureLift = journey?.tension.spectralPressure ?? 0
                riser(&synthBus, sampleRate: sampleRate,
                      level: (0.006 + scene.atmosphere * 0.008) * (1 + pressureLift * 0.45),
                      darkness: scene.darkness, chaos: scene.textureChaos,
                      random: &random, phase: &state.riserPhase)
            }
            if treatment == .polished && effects.textureRackEnabled {
                V2TextureRack.process(&synthBus, sampleRate: sampleRate, scene: scene, state: &state)
            }
        }
        if synthEngine == .legacyReference && scene.drone > 0.01 && !textureCollapsed &&
            (performance?.roles.contains(.atmosphere) ?? true) &&
            (isolatedStem == nil || isolatedStem == .atmosphere || isolatedStem == .returns) {
            let phrasePhase = Double(state.barIndex % 32) / 32.0
            let emergence = 0.45 + 0.55 * sin(phrasePhase * 2.0 * Double.pi - Double.pi / 2.0)
            let sectionBoost: Double = section == .breakdown ? 1.35 : (section == .build ? 1.08 : 0.82)
            drone(&synthBus, sampleRate: sampleRate, root: padRoot(seed: scene.seed) * 2.0,
                  level: (0.008 + scene.drone * 0.022 + scene.atmosphere * 0.006) * sectionBoost,
                  darkness: scene.darkness, hybrid: scene.drone * (0.45 + emergence * 0.35),
                  phase: &state.dronePhase, noiseState: &state.droneNoise)
        }

        let delayFrames = max(1, Int((60.0 / scene.bpm * 0.5 * sampleRate).rounded()))
        if state.delayBuffer.count != delayFrames { state.delayBuffer = [Float](repeating: 0, count: delayFrames); state.delayWriteIndex = 0 }
        let earlyReflectionFrames = max(8, Int(sampleRate * 0.013))
        if state.earlyReflectionBuffer.count != earlyReflectionFrames {
            state.earlyReflectionBuffer = [Float](repeating: 0, count: earlyReflectionFrames)
            state.earlyReflectionWriteIndex = 0
        }
        let dramaticDistance = journey?.patchMacros.distance ?? scene.atmosphere
        let wet = Float(journey == nil
            ? 0.10 + scene.atmosphere * 0.18
            : 0.08 + dramaticDistance * 0.20)
        let feedback = Float(0.20 + scene.hypnosis * 0.12)
        // Upper voices move over several bars; kick and bass remain centered.
        // The phase lives in V2RenderState so adjacent bars do not reset the
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
        let reverbSeconds = journey == nil ? 12.0 + scene.atmosphere * 8.0 : 18.0
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
        var low = 0.0
        var synthLow = 0.0
        var synthMidLow = 0.0
        var synthTone = 0.0
        var highEnvelope = 0.0
        var midEnvelope = 0.0
        let masking = SpectrumMaskingAnalyzer.analyze(
            signals: [.kickBass: kickBus, .percussion: percussionBus, .synth: synthBus, .texture: synthBus],
            sampleRate: sampleRate)
        let lowMidMask = masking.filter { ($0.band.name == "low-mid" || $0.band.name == "mid") && ($0.yieldingRole == .synth || $0.yieldingRole == .texture) }.map(\.cut).max() ?? 0
        let highMask = masking.filter { $0.band.name == "high" && ($0.yieldingRole == .synth || $0.yieldingRole == .texture) }.map(\.cut).max() ?? 0
        for index in 0..<frames {
            let input = output[index]
            let rawSynthInput = synthBus[index]
            let kickLevel = abs(Double(kickBus[index]))
            kickEnvelope = max(kickEnvelope * 0.992, kickLevel)
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
            // A short independent reflection gives upper voices depth before
            // the longer dark reverb. It is deliberately high-passed by the
            // upper-bus source and never receives kick/bass, preserving mono-
            // compatible low end.
            let earlyRead = state.earlyReflectionBuffer[state.earlyReflectionWriteIndex]
            state.earlyReflectionBuffer[state.earlyReflectionWriteIndex] = synthInput * 0.30
            let earlyMix = Float(0.035 + dramaticDistance * 0.08)
            let reverbRead = state.reverbBuffer[state.reverbWriteIndex]
            let drumSend = percussionBus[index] * Float(scene.atmosphere * 0.08)
            state.reverbBuffer[state.reverbWriteIndex] = synthInput * 0.42 + drumSend + reverbRead * reverbFeedback
            let reverbTail = reverbRead * reverbWet
            state.delayWriteIndex = (state.delayWriteIndex + 1) % delayFrames
            state.earlyReflectionWriteIndex = (state.earlyReflectionWriteIndex + 1) % earlyReflectionFrames
            low += (Double(input) - low) * 0.045
            let duck = Float(1.0 - min(0.20, kickEnvelope * 0.25))
            let upperDuck = Float(1.0 - min(0.38, kickEnvelope * 0.55))
            let dryCenter: Float = isolatedStem == .returns ? 0 : input * duck + Float(low) * 0.18
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
            let spatial = effects.spatialEnabled ? delayed * wet : 0
            let delayPan = Float(0.5 + pan * 0.7)
            let chorusMix = effects.spatialEnabled && treatment == .polished
                ? Float(0.12 + dramaticDistance * 0.12)
                : 0
            let directGain: Float = isolatedStem == .returns ? 0 : 1
            let synthLeftOut = (synthInput * (1 - chorusMix) * synthLeft * directGain + chorusLeft * chorusMix) * upperDuck
            let synthRightOut = (synthInput * (1 - chorusMix) * synthRight * directGain + chorusRight * chorusMix) * upperDuck
            let reflectionPan = min(1.0, max(0.0, 0.5 - pan * 0.85))
            let reflectionLeft = effects.spatialEnabled && treatment == .polished
                ? earlyRead * earlyMix * Float(cos(reflectionPan * Double.pi * 0.5))
                : 0
            let reflectionRight = effects.spatialEnabled && treatment == .polished
                ? earlyRead * earlyMix * Float(sin(reflectionPan * Double.pi * 0.5))
                : 0
            let audibleReverbTail = effects.spatialEnabled && treatment == .polished ? reverbTail : 0
            let leftPreMaster = center + synthLeftOut + reflectionLeft + spatial * (1.0 + delayPan * 0.18) * upperDuck + audibleReverbTail * (1.0 + delayPan * 0.24)
            let rightPreMaster = center + synthRightOut + reflectionRight + spatial * (1.0 + (1.0 - delayPan) * 0.18) * upperDuck + audibleReverbTail * (1.0 + (1.0 - delayPan) * 0.24)
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
            let threshold = mastering.glueThreshold
            let over = max(0, state.masterEnvelope - threshold)
            let compressionGain = over > 0 ? (threshold + over / mastering.glueRatio) / state.masterEnvelope : 1.0
            left[index] = safeMaster(leftCompressed * Float(compressionGain) * Float(mastering.makeupGain), profile: mastering)
            right[index] = safeMaster(rightCompressed * Float(compressionGain) * Float(mastering.makeupGain), profile: mastering)
            state.stereoPanPhase = (state.stereoPanPhase + panRate).truncatingRemainder(dividingBy: 2.0 * Double.pi)
            state.chorusPhase = (state.chorusPhase + chorusRate).truncatingRemainder(dividingBy: 2.0 * Double.pi)
            state.chorusWriteIndex = (state.chorusWriteIndex + 1) % chorusFrames
            state.reverbWriteIndex = (state.reverbWriteIndex + 1) % reverbFrames
        }
        let rendered = RenderedBar(sampleRate: sampleRate,
                                   samples: zip(left, right).map { ($0 + $1) * 0.5 },
                                   leftSamples: left, rightSamples: right, masking: masking)
        swap(&output, &checkedOut.output)
        swap(&kickBus, &checkedOut.kick)
        swap(&percussionBus, &checkedOut.percussion)
        swap(&synthBus, &checkedOut.synth)
        workspace.recycle(&checkedOut)
        return rendered
    }

    private static func renderAlienWorld(
        _ output: inout [Float],
        scene: TechnoScene,
        section: SectionKind,
        sampleRate: Double,
        frames: Int,
        stepFrames: Double,
        dna: SceneDNA?,
        performance: PerformanceBar?,
        world: SynthWorldDNA,
        synthBar: SynthPerformanceBar,
        isolatedStem: V2StemKind?,
        state: inout V2RenderState
    ) {
        func allowed(_ role: SynthRole) -> Bool {
            switch isolatedStem {
            case nil, .returns: return true
            case .musicalVoices: return role != .atmosphere
            case .atmosphere: return role == .atmosphere
            case .foundation, .percussion: return false
            }
        }

        let motifEvents = section == .breakdown ? [] : transformedMotif(scene.motif, dna: dna, performance: performance)
        let baseFrequency = motifEvents.first?.frequency ?? world.rootFrequency * 2
        let barIndex = performance?.bar ?? state.barIndex

        var anchorNotes: [AlienVoiceNote] = []
        if allowed(.anchor), (performance?.roles.contains(.motif) ?? (section != .breakdown)) {
            anchorNotes = motifEvents.map { event in
                let globalStep = barIndex * 16 + event.stepIndex
                let accent = performance?.accent(at: event.stepIndex) ?? 1
                return AlienVoiceNote(
                    startFrame: Int((Double(event.stepIndex) * stepFrames).rounded()),
                    durationFrames: max(1, Int((event.durationInSteps * stepFrames).rounded())),
                    frequency: event.frequency,
                    endFrequency: event.frequency * (synthBar.gesture == .corrode ? 1.006 : 1),
                    velocity: min(1, 0.66 + accent * 0.24),
                    role: .anchor,
                    sevenStepAccent: (globalStep + world.shadowRotation) % 7 == 0,
                    echoGate: (globalStep + world.echoRotation) % 3 == 0
                )
            }
        }
        if allowed(.anchor) {
            AlienAnalogVoice.render(
                &output,
                notes: anchorNotes,
                sampleRate: sampleRate,
                level: 0.090 + scene.synthPresence * 0.060,
                world: world,
                bar: synthBar,
                role: .anchor,
                state: &state.alienAnchorState
            )
        }

        var shadowNotes: [AlienVoiceNote] = []
        if allowed(.shadow), section != .breakdown {
            shadowNotes = synthBar.interlockEvents.map { event in
                var frequency = baseFrequency * event.frequencyRatio
                while frequency < 92 { frequency *= 2 }
                while frequency > 880 { frequency *= 0.5 }
                return AlienVoiceNote(
                    startFrame: Int((Double(event.stepIndex) * stepFrames).rounded()),
                    durationFrames: max(1, Int((stepFrames * (event.echoGate ? 0.82 : 0.52)).rounded())),
                    frequency: frequency,
                    endFrequency: frequency * (event.sevenStepAccent ? 1.012 : 0.997),
                    velocity: event.velocity,
                    role: .shadow,
                    sevenStepAccent: event.sevenStepAccent,
                    echoGate: event.echoGate
                )
            }
            let sequencerPresence = scene.musicalIntent?[.sequencerPresence] ?? 0
            if sequencerPresence > 0.04 {
                shadowNotes += scene.sequencer.map { event in
                    let globalStep = barIndex * 16 + event.stepIndex
                    return AlienVoiceNote(
                        startFrame: Int((Double(event.stepIndex) * stepFrames).rounded()),
                        durationFrames: max(1, Int((event.durationInSteps * stepFrames).rounded())),
                        frequency: max(92, event.frequency),
                        endFrequency: max(92, event.frequency) * (event.kind == .texturalStepField ? 0.75 : 1.004),
                        velocity: min(0.64, 0.24 + sequencerPresence * 0.34),
                        role: .shadow,
                        sevenStepAccent: (globalStep + world.shadowRotation) % 7 == 0,
                        echoGate: (globalStep + world.echoRotation) % 3 == 0
                    )
                }
            }
        }
        if allowed(.shadow) {
            AlienAnalogVoice.render(
                &output,
                notes: shadowNotes,
                sampleRate: sampleRate,
                level: 0.032 + scene.synthPresence * 0.034,
                world: world,
                bar: synthBar,
                role: .shadow,
                state: &state.alienShadowState
            )
        }

        var atmosphereNotes: [AlienVoiceNote] = []
        let atmosphereActive = (performance?.roles.contains(.atmosphere) ?? true) || section == .breakdown
        if synthBar.gesture != .suspend, allowed(.atmosphere), atmosphereActive,
           scene.atmosphere > 0.08 || scene.drone > 0.01 {
            let frequency = world.rootFrequency * (section == .breakdown ? 1.5 : 2)
            atmosphereNotes = [AlienVoiceNote(
                startFrame: 0,
                durationFrames: frames,
                frequency: frequency,
                endFrequency: frequency * (synthBar.gesture == .suspend ? 1.018 : 1.003),
                velocity: min(0.72, 0.28 + scene.atmosphere * 0.30 + scene.drone * 0.18),
                role: .atmosphere,
                sevenStepAccent: false,
                echoGate: synthBar.gesture == .suspend
            )]
        }
        if allowed(.atmosphere) {
            AlienAnalogVoice.render(
                &output,
                notes: atmosphereNotes,
                sampleRate: sampleRate,
                level: 0.017 + scene.atmosphere * 0.025 + scene.drone * 0.018,
                world: world,
                bar: synthBar,
                role: .atmosphere,
                state: &state.alienAtmosphereState
            )
        }

        var responseNotes: [AlienVoiceNote] = []
        let responseActive = performance?.roles.contains(.response) ??
            (section == .build || section == .returnSection)
        if synthBar.gesture != .suspend, allowed(.response), responseActive, scene.melodicity > 0.18 {
            let motifAnchor = dna?.motif.steps.last ?? (section == .build ? 6 : 14)
            let step = (motifAnchor + (section == .build ? 5 : 7)) % 16
            let interval = pow(2, Double(world.responseInterval) / 12)
            let frequency = min(1_200, max(120, baseFrequency * interval))
            let globalStep = barIndex * 16 + step
            responseNotes = [AlienVoiceNote(
                startFrame: Int((Double(step) * stepFrames).rounded()),
                durationFrames: max(1, Int((stepFrames * 1.8).rounded())),
                frequency: frequency,
                endFrequency: frequency * (section == .build ? 1.018 : 0.994),
                velocity: min(0.76, 0.34 + scene.melodicity * 0.38),
                role: .response,
                sevenStepAccent: (globalStep + world.shadowRotation) % 7 == 0,
                echoGate: (globalStep + world.echoRotation) % 3 == 0
            )]
        }
        if allowed(.response) {
            AlienAnalogVoice.render(
                &output,
                notes: responseNotes,
                sampleRate: sampleRate,
                level: 0.026 + scene.melodicity * 0.030,
                world: world,
                bar: synthBar,
                role: .response,
                state: &state.alienResponseState
            )
        }

        var transitionNotes: [AlienVoiceNote] = []
        let transitionActive = performance?.roles.contains(.transition) ?? (section == .build)
        if synthBar.gesture != .suspend, allowed(.transition), transitionActive {
            let startFrequency = world.rootFrequency * 2
            transitionNotes = [AlienVoiceNote(
                startFrame: 0,
                durationFrames: frames,
                frequency: startFrequency,
                endFrequency: startFrequency * (synthBar.gesture == .corrode ? 3.8 : 1.5),
                velocity: min(0.54, 0.24 + synthBar.mutationAmount * 0.26),
                role: .transition,
                sevenStepAccent: false,
                echoGate: true
            )]
        }
        if allowed(.transition) {
            AlienAnalogVoice.render(
                &output,
                notes: transitionNotes,
                sampleRate: sampleRate,
                level: 0.008 + scene.atmosphere * 0.012,
                world: world,
                bar: synthBar,
                role: .transition,
                state: &state.alienTransitionState
            )
        }
    }

    private static func safeMaster(_ sample: Float, profile: V2MasteringProfile) -> Float {
        Float(tanh(Double(sample) * profile.limiterDrive) * profile.limiterCeiling)
    }

    private static func performanceEvents(dna: SceneDNA, performance: PerformanceBar?, bar: Int) -> [TimedEvent] {
        let transformations = performance?.transformations ?? [.`repeat`]
        let rotation = transformations.contains(.rotate) ? 2 : 0
        let displacement = transformations.contains(.displace) ? 1 : 0
        let omit = transformations.contains(.omit)
        func shifted(_ step: Int) -> Int { (step + rotation + displacement) % 16 }

        let swingOffset = max(0, min(0.24, (dna.rhythm.swingPercent - 0.5) * 2.0))
        func offset(for step: Int, kind: TimedEventKind) -> Double {
            guard kind == .hat || kind == .bass else { return 0 }
            return step.isMultiple(of: 2) ? 0 : swingOffset
        }
        var events = dna.rhythm.kickSteps.map { TimedEvent(stepIndex: $0, kind: .kick, bar: bar) }
        if !omit {
            events += dna.rhythm.bassSteps.map {
                let step = shifted($0)
                return TimedEvent(stepIndex: step, kind: .bass, offsetInStep: offset(for: step, kind: .bass), bar: bar)
            }
        }
        if performance?.section != .breakdown {
            events += dna.rhythm.hatSteps.map {
                let step = shifted($0)
                return TimedEvent(stepIndex: step, kind: .hat, offsetInStep: offset(for: step, kind: .hat), bar: bar)
            }
            events += [4, 12].filter { !dna.rhythm.kickSteps.contains($0) }.map { TimedEvent(stepIndex: $0, kind: .clap, bar: bar) }
        }
        if performance?.signatureEvent == .displacedKickRecovery, let lastKick = dna.rhythm.kickSteps.last {
            events.removeAll { $0.kind == .kick && $0.stepIndex == lastKick }
            events.append(TimedEvent(stepIndex: min(15, lastKick + 1), kind: .kick, bar: bar))
        }
        return events.sorted { $0.stepIndex < $1.stepIndex }
    }

    private static func transformedMotif(_ source: [SynthEvent], dna: SceneDNA?, performance: PerformanceBar?) -> [SynthEvent] {
        guard let dna, let performance else { return source }
        if performance.transformations.contains(.omit) { return [] }
        let fragment = performance.transformations.contains(.fragment)
        let answer = performance.transformations.contains(.answer) || performance.signatureEvent == .alteredMotifAnswer
        let displacement = performance.transformations.contains(.displace) ? 1 : 0
        let count = fragment ? 1 : dna.motif.steps.count
        return (0..<count).map { index in
            let shadow = performance.signatureEvent == .harmonicShadow ? 1 : 0
            let degree = dna.motif.degrees[index % dna.motif.degrees.count] + (answer ? 7 : 0) + shadow
            let step = (dna.motif.steps[index % dna.motif.steps.count] + displacement) % 16
            let frequency = 65.41 * pow(2, Double(dna.tonalCenter + degree) / 12.0)
            return SynthEvent(stepIndex: step, offsetInStep: 0, scaleDegree: degree, frequency: frequency,
                              durationInSteps: performance.transformations.contains(.extend) ? 2.5 : 1.5,
                              bar: performance.bar, sourceIntent: .hypnosis)
        }
    }

    private static func relationalBassFrequency(dna: SceneDNA, step: Int, tension: Double) -> Double {
        let index = (dna.rhythm.bassSteps.firstIndex(of: step) ?? (step / 2)) % dna.modalDegrees.count
        var degree = dna.modalDegrees[index]
        if tension > 0.72 && index == dna.modalDegrees.count - 1 { degree += 1 }
        return 43.65 * pow(2, Double(dna.tonalCenter + degree) / 12.0)
    }

    private static func kick(_ output: inout [Float], start: Int, sampleRate: Double, level: Double, seed: UInt64, step: Int,
                             legacy: Bool) {
        if legacy {
            let frames = min(Int(sampleRate * 0.24), output.count - start); guard frames > 0 else { return }
            var random = SeededGenerator(seed: seed ^ UInt64(step + 1) ^ 0x9E3779B97F4A7C15); var phase = 0.0
            for i in 0..<frames { let t = Double(i) / sampleRate; phase += 2 * Double.pi * (42 + 180 * exp(-t * 58)) / sampleRate; let body = sin(phase) * exp(-t * 20); let sub = sin(phase * 0.5) * exp(-t * 14) * 0.34; let click = i < Int(sampleRate * 0.003) ? (random.unit() * 2 - 1) * exp(-t * 900) * 0.14 : 0; output[start + i] += Float((body + sub + click) * level) }
            return
        }
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

    private static func bass(_ output: inout [Float], start: Int, sampleRate: Double, level: Double,
                             frequency: Double, articulation: Double, phase: inout Double, filterState: inout Double,
                             legacy: Bool) {
        if legacy {
            let frames = min(Int(sampleRate * 0.22), output.count - start); guard frames > 0 else { return }
            for i in 0..<frames { let t = Double(i) / sampleRate; phase += 2 * Double.pi * frequency / sampleRate; let env = min(1.0, t / 0.006) * exp(-t * 8.5); output[start + i] += Float(tanh((sin(phase) + sin(phase * 2) * 0.12) * 1.2) * env * level) }
            return
        }
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
            output[start + i] += Float(tanh(filterState * 1.35) * envelope * level)
        }
    }

    private static func hat(_ output: inout [Float], start: Int, sampleRate: Double, level: Double, brightness: Double, random: inout SeededGenerator) {
        let frames = min(Int(sampleRate * 0.05), output.count - start); guard frames > 0 else { return }; var state = 0.0
        for i in 0..<frames { let t = Double(i) / sampleRate; let n = random.unit() * 2 - 1; state += (n - state) * (0.25 + brightness * 0.25); output[start + i] += Float((n - state * 0.7) * exp(-t * (32 - brightness * 8)) * level) }
    }

    private static func clap(_ output: inout [Float], start: Int, sampleRate: Double, level: Double, brightness: Double,
                             random: inout SeededGenerator, legacy: Bool) {
        if legacy {
            let frames = min(Int(sampleRate * 0.12), output.count - start); guard frames > 0 else { return }
            for i in 0..<frames { let t = Double(i) / sampleRate; let env = (t < 0.008 ? t / 0.008 : exp(-(t - 0.008) * 34)) * (0.7 + brightness * 0.3); output[start + i] += Float((random.unit() * 2 - 1) * env * level) }
            return
        }
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
            output[start + i] += Float(((noise - low * 0.72) * (burstEnvelope * 0.46 + tail) + body) * level)
        }
    }

    private static func tom(_ output: inout [Float], start: Int, sampleRate: Double, level: Double, frequency: Double) {
        let frames = min(Int(sampleRate * 0.22), output.count - start)
        guard frames > 0 else { return }
        var phase = 0.0
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            let glide = frequency * (1.0 + 0.16 * exp(-t * 30))
            phase += 2 * Double.pi * glide / sampleRate
            let envelope = min(1.0, t / 0.004) * exp(-t * 17)
            let body = sin(phase) + sin(phase * 1.97) * 0.08
            output[start + i] += Float(tanh(body * 1.15) * envelope * level)
        }
    }

    private static func metallicPercussion(_ output: inout [Float], start: Int, sampleRate: Double,
                                           level: Double, brightness: Double,
                                           random: inout SeededGenerator, legacy: Bool) {
        let frames = min(Int(sampleRate * 0.065), output.count - start)
        guard frames > 0 else { return }
        if legacy {
            var states = (0.0, 0.0)
            for i in 0..<frames {
                let t = Double(i) / sampleRate; let noise = random.unit() * 2 - 1
                states.0 += (noise - states.0) * (0.18 + brightness * 0.12); states.1 += (states.0 - states.1) * 0.42
                let ring = sin(2 * Double.pi * (1_900 + brightness * 1_700) * t); let envelope = exp(-t * (38 - brightness * 10))
                output[start + i] += Float((states.0 - states.1 * 0.65) * ring * envelope * level)
            }
            return
        }
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
            output[start + i] += Float((resonances * 0.72 + (noise - noiseState) * 0.16) * envelope * level)
        }
    }

    private static func openHat(_ output: inout [Float], start: Int, sampleRate: Double, level: Double,
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
            output[start + i] += Float((noise - filtered * 0.55 + metallic * 0.16) * envelope * level)
        }
    }

    private static func synth(_ output: inout [Float], start: Int, sampleRate: Double, duration: Double, frequency: Double, level: Double, phase: inout Double, detune: inout Double, darkness: Double, timbralFamily: Int = 0, resonance: Double = 0.2, motion: Double = 0.4) {
        let frames = min(Int(sampleRate * duration), output.count - start); guard frames > 0 else { return }; var filter = 0.0; var filterVelocity = 0.0
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            phase += 2 * Double.pi * frequency / sampleRate
            detune += 2 * Double.pi * frequency * 1.003 / sampleRate
            let env = min(1.0, t / 0.012) * exp(-t * (0.85 + darkness * 0.8))
            let phaseUnit = (phase / (2.0 * Double.pi)).truncatingRemainder(dividingBy: 1.0)
            let detuneUnit = (detune / (2.0 * Double.pi)).truncatingRemainder(dividingBy: 1.0)
            let saw = bandLimitedSaw(phaseUnit, increment: frequency / sampleRate)
            let detunedSaw = bandLimitedSaw(detuneUnit, increment: frequency * 1.003 / sampleRate)
            // Analog-inspired PWM and oscillator drift: the movement is slow,
            // deterministic, and bounded by the semantic darkness control.
            // It gives the voice a living synth character without adding a
            // second unstable modulation source.
            let width = min(0.56, max(0.30, 0.34 + (1.0 - darkness) * 0.16))
            let pwmWidth = min(0.60, max(0.28, width + sin(detuneUnit * 2.0 * Double.pi * 0.031) * 0.035))
            let pulse = bandLimitedPulse(phaseUnit, increment: frequency / sampleRate, width: pwmWidth)
            let drift = sin(detuneUnit * 2.0 * Double.pi * 0.017 + darkness) * 0.035
            let raw: Double
            switch timbralFamily {
            case 1: raw = pulse * (0.42 + drift) + saw * 0.20 + sin(detune * 0.5) * 0.10
            case 2: raw = saw * 0.34 + detunedSaw * 0.16 + sin(phase * 0.5) * (0.22 + drift)
            case 3: raw = sin(phase) * 0.31 + pulse * 0.22 + sin(phase * 1.498) * 0.13 + detunedSaw * 0.10
            default: raw = saw * (0.42 + drift) + detunedSaw * 0.22 + pulse * 0.14
            }
            // A bounded two-pole-ish resonant stage gives the voice a real
            // patch identity: oscillator interaction feeds a moving filter,
            // while resonance remains deliberately below runaway territory.
            let lfo = sin(detuneUnit * 2.0 * Double.pi * (0.009 + motion * 0.012))
            let cutoff = 210.0 + (1.0 - darkness) * 1_450.0 + lfo * (80.0 + motion * 180.0)
            let coefficient = min(0.32, max(0.012, 1.0 - exp(-2.0 * Double.pi * cutoff / sampleRate)))
            let boundedResonance = min(0.30, max(0.0, resonance * 0.22))
            let driven = tanh((raw - filterVelocity * boundedResonance) * (1.15 + resonance * 0.75))
            filterVelocity += (driven - filterVelocity) * coefficient
            filter += (filterVelocity - filter) * min(0.38, coefficient * 1.35)
            let shaped = tanh(filter * (1.0 + resonance * 0.55))
            output[start + i] += Float(shaped * env * level)
        }
    }

    private static func acidVoice(_ output: inout [Float], start: Int, sampleRate: Double,
                                  duration: Double, frequency: Double, level: Double,
                                  darkness: Double, resonance: Double,
                                  phase: inout Double, filterState: inout Double) {
        let frames = min(Int(sampleRate * duration), output.count - start)
        guard frames > 0 else { return }
        let cutoff = 520.0 + (1.0 - darkness) * 1_350.0
        let coefficient = min(0.34, 1.0 - exp(-2.0 * Double.pi * cutoff / sampleRate))
        let boundedResonance = min(0.24, resonance * 0.20)
        for index in 0..<frames {
            let time = Double(index) / sampleRate
            phase += 2.0 * Double.pi * frequency / sampleRate
            let unit = (phase / (2.0 * Double.pi)).truncatingRemainder(dividingBy: 1.0)
            let oscillator = bandLimitedSaw(unit, increment: frequency / sampleRate)
            let envelope = min(1.0, time / 0.004) * exp(-time * (3.2 + darkness * 1.8))
            let driven = tanh((oscillator - filterState * boundedResonance) * 1.35)
            filterState += (driven - filterState) * coefficient
            output[start + index] += Float(filterState * envelope * level)
        }
    }

    private static func lead(_ output: inout [Float], start: Int, sampleRate: Double, duration: Double,
                             frequency: Double, level: Double, darkness: Double, phase: inout Double) {
        let frames = min(Int(sampleRate * duration), output.count - start)
        guard frames > 0 else { return }
        var filter = 0.0
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            phase += 2.0 * Double.pi * frequency / sampleRate
            let unit = (phase / (2.0 * Double.pi)).truncatingRemainder(dividingBy: 1.0)
            let raw = bandLimitedPulse(unit, increment: frequency / sampleRate, width: 0.46) * 0.62
                + bandLimitedSaw(unit, increment: frequency / sampleRate) * 0.28
            filter += (raw - filter) * (0.10 + (1.0 - darkness) * 0.10)
            let attack = min(1.0, t / 0.012)
            let release = exp(-t * (2.4 + darkness * 1.6))
            output[start + i] += Float(filter * attack * release * level)
        }
    }

    private static func drone(_ output: inout [Float], sampleRate: Double, root: Double,
                              level: Double, darkness: Double, hybrid: Double,
                              phase: inout Double, noiseState: inout Double) {
        guard !output.isEmpty else { return }
        var filtered = 0.0
        let coefficient = 1.0 - exp(-2.0 * Double.pi * (130.0 + (1.0 - darkness) * 220.0) / sampleRate)
        let noiseCoefficient = 1.0 - exp(-2.0 * Double.pi * (260.0 + (1.0 - darkness) * 900.0) / sampleRate)
        for index in output.indices {
            phase += 2.0 * Double.pi * root / sampleRate
            let unit = (phase / (2.0 * Double.pi)).truncatingRemainder(dividingBy: 1.0)
            let harmonic = bandLimitedSaw(unit, increment: root / sampleRate) * 0.34
                + sin(phase * 0.5) * 0.24
                + sin(phase * 1.1892) * 0.14
            // Deterministic pseudo-noise from the continuous phase avoids
            // allocating or reseeding a random source inside the render loop.
            let rawNoise = sin(phase * 0.071 + Double(index) * 1.731) * 0.5
                + sin(phase * 0.113 + Double(index) * 2.417) * 0.5
            noiseState += (rawNoise - noiseState) * noiseCoefficient
            filtered += (harmonic - filtered) * coefficient
            let shaped = filtered * (1.0 - hybrid * 0.55) + noiseState * hybrid * 0.32
            output[index] += Float(shaped * level)
        }
    }

    private static func riser(_ output: inout [Float], sampleRate: Double, level: Double,
                              darkness: Double, chaos: Double, random: inout SeededGenerator,
                              phase: inout Double) {
        guard !output.isEmpty else { return }
        var filtered = 0.0
        let coefficient = 1.0 - exp(-2.0 * Double.pi * (700.0 + (1.0 - darkness) * 2_000.0) / sampleRate)
        let duration = Double(output.count) / sampleRate
        for index in output.indices {
            let t = Double(index) / sampleRate
            let normalized = min(1.0, t / duration)
            let frequency = 260.0 + normalized * normalized * 2_600.0
            phase += 2.0 * Double.pi * frequency / sampleRate
            let raw = random.unit() * 2.0 - 1.0
            filtered += (raw - filtered) * coefficient
            let sweep = sin(phase) * 0.22
            let envelope = normalized * normalized * (0.7 + chaos * 0.3)
            output[index] += Float((filtered * 0.42 + sweep) * envelope * level)
        }
    }

    private static func bandLimitedSaw(_ phase: Double, increment: Double) -> Double {
        let t = phase - floor(phase)
        return 2.0 * t - 1.0 - polyBLEP(t, increment: increment)
    }

    private static func bandLimitedPulse(_ phase: Double, increment: Double, width: Double) -> Double {
        let t = phase - floor(phase)
        let shifted = (t + (1.0 - width)).truncatingRemainder(dividingBy: 1.0)
        return (t < width ? 1.0 : -1.0) + polyBLEP(t, increment: increment) - polyBLEP(shifted, increment: increment)
    }

    private static func polyBLEP(_ phase: Double, increment: Double) -> Double {
        let t = phase - floor(phase)
        let dt = min(0.5, max(0.000001, increment))
        if t < dt {
            let x = t / dt
            return x + x - x * x - 1.0
        }
        if t > 1.0 - dt {
            let x = (t - 1.0) / dt
            return x * x + x + x + 1.0
        }
        return 0
    }

    private static func pad(_ output: inout [Float], sampleRate: Double, level: Double, root: Double,
                            darkness: Double, phase: inout Double) {
        guard !output.isEmpty else { return }
        var filtered = 0.0
        let coefficient = 1.0 - exp(-2.0 * Double.pi * (260.0 + (1.0 - darkness) * 260.0) / sampleRate)
        let duration = Double(output.count) / sampleRate
        for index in output.indices {
            let t = Double(index) / sampleRate
            let attack = min(1.0, t / 0.18)
            let release = min(1.0, max(0.0, (duration - t) / 0.28))
            phase += 2.0 * Double.pi * root / sampleRate
            let chord = sin(phase) * 0.58 + sin(phase * 1.1892) * 0.28 + sin(phase * 1.4983) * 0.18
            filtered += (chord - filtered) * coefficient
            output[index] += Float(filtered * attack * release * level)
        }
    }

    private static func noiseBed(_ output: inout [Float], sampleRate: Double, level: Double,
                                 darkness: Double, chaos: Double, random: inout SeededGenerator,
                                 filterState: inout Double) {
        guard !output.isEmpty else { return }
        let coefficient = 1.0 - exp(-2.0 * Double.pi * (380.0 + (1.0 - darkness) * 1_100.0) / sampleRate)
        let duration = Double(output.count) / sampleRate
        for index in output.indices {
            let t = Double(index) / sampleRate
            let attack = min(1.0, t / 0.24)
            let release = min(1.0, max(0.0, (duration - t) / 0.4))
            let raw = random.unit() * 2.0 - 1.0
            filterState += (raw - filterState) * coefficient
            let high = raw - filterState
            let darkMix = 0.76 - darkness * 0.34
            let shaped = filterState * darkMix + high * (0.10 + chaos * 0.12)
            output[index] += Float(shaped * attack * release * level)
        }
    }

    private static func bassFrequency(seed: UInt64, step: Int) -> Double { let degrees = [0, 0, 3, 0, 5, 0, 3, 7]; return 43.65 * pow(2, Double(degrees[(step / 2 + Int(seed % 8)) % degrees.count]) / 12) }
    private static func padRoot(seed: UInt64) -> Double { 65.41 * pow(2.0, Double((seed >> 3) % 5) / 12.0) }
}
