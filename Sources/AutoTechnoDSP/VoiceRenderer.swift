import AutoTechnoCore
import Foundation

enum VoiceRenderer {
    static func renderBar(scene: TechnoScene, sampleRate: Double, state: inout RenderState,
                          dna: SceneDNA, performance: PerformanceBar,
                          synthWorld: SynthWorldDNA, synthPerformance: SynthPerformanceBar,
                          workspace: inout RenderWorkspace, layer: RenderLayer) -> RenderedBar {
        let section = performance.section
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
        var random = SeededGenerator(seed: performance.eventSeed)

        let grooveEvents = performanceEvents(dna: dna, performance: performance, bar: state.barIndex)
        for event in grooveEvents {
            let start = Int(((Double(event.stepIndex) + event.offsetInStep) * stepFrames).rounded())
            let accent = performance.accent(at: event.stepIndex)
            switch event.kind {
            case .kick:
                let level = (section == .breakdown ? 0.54 : 0.72) * accent
                kick(&output, start: start, sampleRate: sampleRate, level: level,
                     seed: scene.seed, step: event.stepIndex)
                kick(&kickBus, start: start, sampleRate: sampleRate, level: level,
                     seed: scene.seed, step: event.stepIndex)
            case .bass where section != .breakdown &&
                !(performance.signatureEvent == .delayedBassEntry && event.stepIndex < 8):
                let frequency = relationalBassFrequency(
                    dna: dna, step: event.stepIndex, tension: performance.tension
                )
                bass(&output, start: start, sampleRate: sampleRate,
                     level: (0.11 + performance.tension * 0.035) * accent,
                     frequency: frequency, articulation: 0.3 + performance.tension * 0.5,
                     phase: &state.bassPhase, filterState: &state.bassFilter)
            case .hat where section != .breakdown && layer == .full:
                let level = (section == .build ? 0.09 : 0.075) * accent
                hat(&output, start: start, sampleRate: sampleRate, level: level, brightness: scene.character.percussionBrightness, random: &random)
                hat(&percussionBus, start: start, sampleRate: sampleRate, level: level, brightness: scene.character.percussionBrightness, random: &random)
            case .clap where section != .breakdown && layer == .full:
                clap(&output, start: start, sampleRate: sampleRate, level: 0.08 * accent,
                     brightness: scene.character.percussionBrightness, random: &random)
                clap(&percussionBus, start: start, sampleRate: sampleRate, level: 0.08 * accent,
                     brightness: scene.character.percussionBrightness, random: &random)
            default: break
            }
        }
        if layer == .full && section != .breakdown && performance.roles.contains(.percussion) {
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
                                   brightness: scene.character.percussionBrightness, random: &random)
            }
            if section == .build || section == .returnSection {
                let openHatStep = section == .build ? 6 : 14
                openHat(&output, start: Int((Double(openHatStep) * stepFrames).rounded()), sampleRate: sampleRate,
                        level: 0.022 + scene.character.percussionBrightness * 0.018,
                        brightness: scene.character.percussionBrightness, random: &random)
            }
            let phraseEnding = performance.localBar == performance.phraseLength - 1
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
                                   brightness: scene.character.percussionBrightness, random: &random)
            }
        }
        let textureCollapsed = performance.signatureEvent == .textureCollapse
        let upperRolesActive = performance.roles.contains {
            $0 == .motif || $0 == .response || $0 == .atmosphere || $0 == .transition
        }
        if layer == .full && !textureCollapsed && upperRolesActive {
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
                state: &state
            )
        }

        let delayFrames = max(1, Int((60.0 / scene.bpm * 0.5 * sampleRate).rounded()))
        if state.delayBuffer.count != delayFrames { state.delayBuffer = [Float](repeating: 0, count: delayFrames); state.delayWriteIndex = 0 }
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
        dna: SceneDNA,
        performance: PerformanceBar,
        world: SynthWorldDNA,
        synthBar: SynthPerformanceBar,
        state: inout RenderState
    ) {
        let motifEvents = section == .breakdown ? [] : transformedMotif(dna: dna, performance: performance)
        let baseFrequency = motifEvents.first?.frequency ?? world.rootFrequency * 2
        let barIndex = performance.bar

        var anchorNotes: [AlienVoiceNote] = []
        if performance.roles.contains(.motif) {
            anchorNotes = motifEvents.map { event in
                let globalStep = barIndex * 16 + event.stepIndex
                let accent = performance.accent(at: event.stepIndex)
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
        AlienAnalogVoice.render(
            &output, notes: anchorNotes, sampleRate: sampleRate,
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
                    durationFrames: max(1, Int((stepFrames * (event.echoGate ? 0.82 : 0.52)).rounded())),
                    frequency: frequency,
                    endFrequency: frequency * (event.sevenStepAccent ? 1.012 : 0.997),
                    velocity: event.velocity,
                    role: .shadow,
                    sevenStepAccent: event.sevenStepAccent,
                    echoGate: event.echoGate
                )
            }
            let sequencerPresence = scene.musicalIntent[.sequencerPresence]
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
        AlienAnalogVoice.render(
            &output, notes: shadowNotes, sampleRate: sampleRate,
            level: 0.032 + scene.synthPresence * 0.034,
            world: world, bar: synthBar, role: .shadow,
            state: &state.alienShadowState
        )

        var atmosphereNotes: [AlienVoiceNote] = []
        let atmosphereActive = performance.roles.contains(.atmosphere) || section == .breakdown
        if synthBar.gesture != .suspend, atmosphereActive,
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
        AlienAnalogVoice.render(
            &output, notes: atmosphereNotes, sampleRate: sampleRate,
            level: 0.017 + scene.atmosphere * 0.025 + scene.drone * 0.018,
            world: world, bar: synthBar, role: .atmosphere,
            state: &state.alienAtmosphereState
        )

        var responseNotes: [AlienVoiceNote] = []
        let responseActive = performance.roles.contains(.response)
        if synthBar.gesture != .suspend, responseActive, scene.melodicity > 0.18 {
            let motifAnchor = dna.motif.steps.last ?? (section == .build ? 6 : 14)
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
        AlienAnalogVoice.render(
            &output, notes: responseNotes, sampleRate: sampleRate,
            level: 0.026 + scene.melodicity * 0.030,
            world: world, bar: synthBar, role: .response,
            state: &state.alienResponseState
        )

        var transitionNotes: [AlienVoiceNote] = []
        let transitionActive = performance.roles.contains(.transition)
        if synthBar.gesture != .suspend, transitionActive {
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
        AlienAnalogVoice.render(
            &output, notes: transitionNotes, sampleRate: sampleRate,
            level: 0.008 + scene.atmosphere * 0.012,
            world: world, bar: synthBar, role: .transition,
            state: &state.alienTransitionState
        )
    }

    private static func safeMaster(_ sample: Float) -> Float {
        Float(tanh(Double(sample) * 1.12) * 0.78)
    }

    private static func performanceEvents(dna: SceneDNA, performance: PerformanceBar, bar: Int) -> [TimedEvent] {
        let transformations = performance.transformations
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
        if performance.section != .breakdown {
            events += dna.rhythm.hatSteps.map {
                let step = shifted($0)
                return TimedEvent(stepIndex: step, kind: .hat, offsetInStep: offset(for: step, kind: .hat), bar: bar)
            }
            events += [4, 12].filter { !dna.rhythm.kickSteps.contains($0) }.map { TimedEvent(stepIndex: $0, kind: .clap, bar: bar) }
        }
        if performance.signatureEvent == .displacedKickRecovery, let lastKick = dna.rhythm.kickSteps.last {
            events.removeAll { $0.kind == .kick && $0.stepIndex == lastKick }
            events.append(TimedEvent(stepIndex: min(15, lastKick + 1), kind: .kick, bar: bar))
        }
        return events.sorted { $0.stepIndex < $1.stepIndex }
    }

    private static func transformedMotif(dna: SceneDNA, performance: PerformanceBar) -> [SynthEvent] {
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

    private static func bass(_ output: inout [Float], start: Int, sampleRate: Double, level: Double,
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
            output[start + i] += Float(tanh(filterState * 1.35) * envelope * level)
        }
    }

    private static func hat(_ output: inout [Float], start: Int, sampleRate: Double, level: Double, brightness: Double, random: inout SeededGenerator) {
        let frames = min(Int(sampleRate * 0.05), output.count - start); guard frames > 0 else { return }; var state = 0.0
        for i in 0..<frames { let t = Double(i) / sampleRate; let n = random.unit() * 2 - 1; state += (n - state) * (0.25 + brightness * 0.25); output[start + i] += Float((n - state * 0.7) * exp(-t * (32 - brightness * 8)) * level) }
    }

    private static func clap(_ output: inout [Float], start: Int, sampleRate: Double, level: Double, brightness: Double,
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

}
