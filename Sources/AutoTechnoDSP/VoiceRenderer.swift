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

/// Fixed renderer for the score-owned percussion-return relation. The delay
/// line is bar-local, the return is band-limited, and exact-zero endpoints
/// protect both the established gate and anticipation-swell boundaries without
/// adding continuation state.
package enum PercussionEchoTextureVoice {
    package static let feedback = 0.72
    package static let returnGain = 0.42
    package static let highPassHz = 650.0
    package static let lowPassHz = 4_200.0
    package static let transitionSeconds = 0.008

    package static func transitionFrameCount(sampleRate: Double) -> Int {
        max(1, Int((sampleRate * transitionSeconds).rounded()))
    }

    package static func render(
        source: [Float],
        returnStem: inout [Float],
        articulation: PercussionEchoTextureArticulation?,
        bpm: Double,
        sampleRate: Double
    ) -> PercussionEchoTextureRenderEvidence {
        let frameCount = min(source.count, returnStem.count)
        let neutralInputHash = ExactPCMFingerprint.mono([])
        guard let articulation else {
            var returnFingerprint = ExactPCMFingerprint.MonoAccumulator(
                sampleCount: frameCount
            )
            for _ in 0..<frameCount { returnFingerprint.append(0) }
            return PercussionEchoTextureRenderEvidence(
                active: false,
                relation: nil,
                bpm: bpm,
                sampleRate: sampleRate,
                inputStep: -1,
                outputStartStep: -1,
                outputEndStep: -1,
                renderedFrameCount: frameCount,
                inputWindowFrameCount: 0,
                outputWindowFrameCount: 0,
                delayFrameCount: 0,
                transitionFrameCount: 0,
                inputSampleHash: neutralInputHash,
                returnSampleHash: returnFingerprint.fingerprint,
                inputPeak: 0,
                inputRMS: 0,
                returnPeak: 0,
                returnRMS: 0,
                earlyOutputRMS: 0,
                lateOutputRMS: 0,
                lateToEarlyDB: 0,
                inputNonzeroSampleCount: 0,
                returnNonzeroSampleCount: 0,
                outOfWindowNonzeroSampleCount: 0,
                firstOutputSampleBitPattern: 0,
                lastOutputSampleBitPattern: 0,
                finite: bpm.isFinite && sampleRate.isFinite && frameCount > 0
            )
        }

        let stepFrames = Double(frameCount) / 16
        func frame(for step: Int) -> Int {
            guard step >= 0, step <= 16 else { return -1 }
            return min(frameCount, max(0, Int((Double(step) * stepFrames).rounded())))
        }
        let inputStartFrame = frame(for: articulation.inputStep)
        let inputEndFrame = frame(
            for: articulation.inputStep +
                PercussionEchoTextureResolver.inputWindowLengthInSteps
        )
        let outputStartFrame = frame(for: articulation.outputStartStep)
        let outputEndFrame = frame(for: articulation.outputEndStep)
        let geometryValid = inputStartFrame >= 0 && inputEndFrame > inputStartFrame &&
            outputStartFrame >= inputEndFrame && outputEndFrame > outputStartFrame &&
            outputEndFrame <= frameCount
        let inputWindowFrameCount = geometryValid
            ? inputEndFrame - inputStartFrame : 0
        let outputWindowFrameCount = geometryValid
            ? outputEndFrame - outputStartFrame : 0
        let delayFrameCount = max(1, Int(stepFrames.rounded()))
        let transitionFrames = transitionFrameCount(sampleRate: sampleRate)
        var delay = [Float](repeating: 0, count: delayFrameCount)
        var delayIndex = 0
        var highPassState = 0.0
        var lowPassState = 0.0
        let highPassCoefficient = min(
            0.35,
            1 - exp(-2 * .pi * highPassHz / sampleRate)
        )
        let lowPassCoefficient = min(
            0.55,
            1 - exp(-2 * .pi * lowPassHz / sampleRate)
        )
        var inputFingerprint = ExactPCMFingerprint.MonoAccumulator(
            sampleCount: inputWindowFrameCount
        )
        var returnFingerprint = ExactPCMFingerprint.MonoAccumulator(
            sampleCount: frameCount
        )
        var inputPeak = 0.0
        var inputEnergy = 0.0
        var returnPeak = 0.0
        var returnEnergy = 0.0
        var inputNonzeroSampleCount = 0
        var returnNonzeroSampleCount = 0
        var outOfWindowNonzeroSampleCount = 0
        var finite = geometryValid && bpm.isFinite && sampleRate.isFinite &&
            feedback.isFinite && returnGain.isFinite &&
            highPassCoefficient.isFinite && lowPassCoefficient.isFinite
        func recordInput(_ sample: Float) {
            inputFingerprint.append(sample)
            let value = Double(sample)
            inputPeak = max(inputPeak, abs(value))
            inputEnergy += value * value
            if sample.bitPattern & 0x7fff_ffff != 0 {
                inputNonzeroSampleCount += 1
            }
        }
        func recordOutput(_ sample: Float, insideOutput: Bool) {
            returnFingerprint.append(sample)
            let value = Double(sample)
            if insideOutput {
                returnPeak = max(returnPeak, abs(value))
                returnEnergy += value * value
            }
            if sample.bitPattern & 0x7fff_ffff != 0 {
                returnNonzeroSampleCount += 1
                if !insideOutput { outOfWindowNonzeroSampleCount += 1 }
            }
        }

        if articulation.relation == .gatedEcho {
            for index in 0..<frameCount {
                let read = delay[delayIndex]
                let admittedInput = geometryValid &&
                    index >= inputStartFrame && index < inputEndFrame
                    ? source[index] : 0
                delay[delayIndex] = admittedInput + read * Float(feedback)
                delayIndex = (delayIndex + 1) % delayFrameCount

                let readValue = Double(read)
                highPassState += (readValue - highPassState) * highPassCoefficient
                let highPassed = readValue - highPassState
                lowPassState += (highPassed - lowPassState) * lowPassCoefficient
                let insideOutput = geometryValid &&
                    index >= outputStartFrame && index < outputEndFrame
                let gate: Double
                if insideOutput {
                    let fadeIn = Double(index - outputStartFrame) /
                        Double(transitionFrames)
                    let fadeOut = Double(outputEndFrame - 1 - index) /
                        Double(transitionFrames)
                    gate = min(1, max(0, min(fadeIn, fadeOut)))
                } else {
                    gate = 0
                }
                let renderedSample = Float(lowPassState * returnGain * gate)
                returnStem[index] = renderedSample
                recordOutput(renderedSample, insideOutput: insideOutput)

                if geometryValid && index >= inputStartFrame && index < inputEndFrame {
                    recordInput(source[index])
                }
                finite = finite && admittedInput.isFinite && read.isFinite &&
                    renderedSample.isFinite && highPassState.isFinite &&
                    lowPassState.isFinite
            }
        } else {
            var forwardWet = [Float](repeating: 0, count: frameCount)
            for index in 0..<frameCount {
                let read = delay[delayIndex]
                let admittedInput = geometryValid &&
                    index >= inputStartFrame && index < inputEndFrame
                    ? source[index] : 0
                delay[delayIndex] = admittedInput + read * Float(feedback)
                delayIndex = (delayIndex + 1) % delayFrameCount

                let readValue = Double(read)
                highPassState += (readValue - highPassState) * highPassCoefficient
                let highPassed = readValue - highPassState
                lowPassState += (highPassed - lowPassState) * lowPassCoefficient
                let wetSample = Float(lowPassState * returnGain)
                forwardWet[index] = wetSample
                if geometryValid && index >= inputStartFrame && index < inputEndFrame {
                    recordInput(source[index])
                }
                finite = finite && admittedInput.isFinite && read.isFinite &&
                    wetSample.isFinite && highPassState.isFinite &&
                    lowPassState.isFinite
            }
            for index in 0..<frameCount {
                let insideOutput = geometryValid &&
                    index >= outputStartFrame && index < outputEndFrame
                let renderedSample: Float
                if insideOutput {
                    let relativeIndex = index - outputStartFrame
                    let reverseIndex = outputEndFrame - 1 - relativeIndex
                    let progress = Double(relativeIndex) /
                        Double(max(1, outputWindowFrameCount - 1))
                    let crescendo = 0.5 - 0.5 * cos(.pi * progress)
                    let fadeOut = min(
                        1,
                        max(0, Double(outputEndFrame - 1 - index) /
                            Double(transitionFrames))
                    )
                    renderedSample = forwardWet[reverseIndex] *
                        Float(crescendo * fadeOut)
                } else {
                    renderedSample = 0
                }
                returnStem[index] = renderedSample
                recordOutput(renderedSample, insideOutput: insideOutput)
                finite = finite && renderedSample.isFinite
            }
        }
        let inputRMS = inputWindowFrameCount > 0
            ? sqrt(inputEnergy / Double(inputWindowFrameCount)) : 0
        let returnRMS = outputWindowFrameCount > 0
            ? sqrt(returnEnergy / Double(outputWindowFrameCount)) : 0
        let riseAnalysisEnd = max(
            outputStartFrame,
            outputEndFrame - transitionFrames
        )
        let riseAnalysisFrameCount = max(0, riseAnalysisEnd - outputStartFrame)
        let riseSegmentFrameCount = max(1, riseAnalysisFrameCount / 4)
        let earlyEnd = min(
            riseAnalysisEnd,
            outputStartFrame + riseSegmentFrameCount
        )
        let lateStart = max(
            outputStartFrame,
            riseAnalysisEnd - riseSegmentFrameCount
        )
        func rms(in range: Range<Int>) -> Double {
            guard !range.isEmpty,
                  range.lowerBound >= 0,
                  range.upperBound <= returnStem.count else { return 0 }
            let energy = range.reduce(0.0) {
                let sample = Double(returnStem[$1])
                return $0 + sample * sample
            }
            return sqrt(energy / Double(range.count))
        }
        let earlyOutputRMS = geometryValid
            ? rms(in: outputStartFrame..<earlyEnd) : 0
        let lateOutputRMS = geometryValid
            ? rms(in: lateStart..<riseAnalysisEnd) : 0
        let lateToEarlyDB: Double
        if lateOutputRMS > 0, earlyOutputRMS > 0 {
            lateToEarlyDB = min(120, max(-120,
                20 * (log10(lateOutputRMS) - log10(earlyOutputRMS))
            ))
        } else if lateOutputRMS > 0 {
            lateToEarlyDB = 120
        } else {
            lateToEarlyDB = 0
        }
        let firstOutputBits = geometryValid
            ? returnStem[outputStartFrame].bitPattern : 0
        let lastOutputBits = geometryValid
            ? returnStem[outputEndFrame - 1].bitPattern : 0
        return PercussionEchoTextureRenderEvidence(
            active: true,
            relation: articulation.relation,
            bpm: bpm,
            sampleRate: sampleRate,
            inputStep: articulation.inputStep,
            outputStartStep: articulation.outputStartStep,
            outputEndStep: articulation.outputEndStep,
            renderedFrameCount: frameCount,
            inputWindowFrameCount: inputWindowFrameCount,
            outputWindowFrameCount: outputWindowFrameCount,
            delayFrameCount: delayFrameCount,
            transitionFrameCount: transitionFrames,
            inputSampleHash: inputFingerprint.fingerprint,
            returnSampleHash: returnFingerprint.fingerprint,
            inputPeak: inputPeak,
            inputRMS: inputRMS,
            returnPeak: returnPeak,
            returnRMS: returnRMS,
            earlyOutputRMS: earlyOutputRMS,
            lateOutputRMS: lateOutputRMS,
            lateToEarlyDB: lateToEarlyDB,
            inputNonzeroSampleCount: inputNonzeroSampleCount,
            returnNonzeroSampleCount: returnNonzeroSampleCount,
            outOfWindowNonzeroSampleCount: outOfWindowNonzeroSampleCount,
            firstOutputSampleBitPattern: firstOutputBits,
            lastOutputSampleBitPattern: lastOutputBits,
            finite: finite && inputPeak.isFinite && inputRMS.isFinite &&
                returnPeak.isFinite && returnRMS.isFinite &&
                earlyOutputRMS.isFinite && lateOutputRMS.isFinite &&
                lateToEarlyDB.isFinite
        )
    }
}

/// Fixed DSP contract for the existing ordinary closed-hat voice. The score
/// chooses only a semantic decay role; these engine-owned values remain
/// bounded and versioned with the canonical renderer.
package enum ClosedHatVoiceContract {
    package static let durationSeconds = 0.05
    package static let openHatCompanionDecayRateScale = 1.35

    package static func level(section: SectionKind,
                              combinedAccent: Double) -> Double {
        (section == .build ? 0.09 : 0.075) * combinedAccent
    }

    package static func frameCount(sampleRate: Double) -> Int {
        max(0, Int(sampleRate * durationSeconds))
    }

    package static func decayRate(brightness: Double,
                                  role: ClosedHatDecayRole) -> Double {
        let neutral = 32 - brightness * 8
        switch role {
        case .neutral:
            return neutral
        case .openHatCompanion:
            return neutral * openHatCompanionDecayRateScale
        }
    }

    package static func appliedParametersMatch(
        level: Double,
        decayRate: Double,
        brightness: Double,
        reportedSection: SectionKind,
        scoreSection: SectionKind,
        combinedAccent: Double,
        role: ClosedHatDecayRole
    ) -> Bool {
        reportedSection == scoreSection &&
            level == self.level(
                section: scoreSection,
                combinedAccent: combinedAccent
            ) &&
            decayRate == self.decayRate(brightness: brightness, role: role)
    }
}

/// Pure pointwise contract for the existing band-limited pulse-echo return.
/// The delay line and feedback write remain outside this shaper.
package enum PulseEchoReturnDriveContract {
    package static let maximumAmount = PulseEchoTextureArticulation.maximumAppliedAmount
    package static let boundaryTransitionSeconds = 0.008
    package static let normalizationAmplitude = 0.18
    package static let maximumLowLevelGain = 1 + maximumAmount * 4

    package static func transitionFrameCount(sampleRate: Double) -> Int {
        guard sampleRate.isFinite, sampleRate > 0 else { return 1 }
        return max(1, Int((sampleRate * boundaryTransitionSeconds).rounded()))
    }

    /// A state-free boundary window for the drive contribution. The existing
    /// filtered return and feedback state continue uninterrupted; only the
    /// pointwise nonlinear delta reaches exact neutral at either bar edge.
    package static func effectiveAmount(
        targetAmount: Double,
        frame: Int,
        totalFrameCount: Int,
        transitionFrameCount: Int
    ) -> Double {
        let boundedTarget = targetAmount.isFinite
            ? min(maximumAmount, max(0, targetAmount)) : 0
        guard boundedTarget > 0,
              totalFrameCount > 1,
              frame > 0,
              frame < totalFrameCount - 1 else {
            return 0
        }
        let transition = max(1, transitionFrameCount)
        let boundaryDistance = min(frame, totalFrameCount - 1 - frame)
        let window = min(1, Double(boundaryDistance) / Double(transition))
        return boundedTarget * window
    }

    package static func process(preDriveSample: Float, amount: Double) -> Float {
        let boundedAmount = amount.isFinite
            ? min(maximumAmount, max(0, amount)) : 0
        if boundedAmount == 0 || preDriveSample == 0 {
            return preDriveSample
        }
        let filteredSample = Double(preDriveSample) / normalizationAmplitude
        let drive = 1 + boundedAmount * 4
        let wet = boundedAmount / maximumAmount
        let saturated = tanh(filteredSample * drive)
        let processed = filteredSample + (saturated - filteredSample) * wet
        let processedSample = processed * normalizationAmplitude
        let roundedSample = Float(processedSample)
        if roundedSample == preDriveSample,
           processedSample != Double(preDriveSample) {
            return processedSample > Double(preDriveSample)
                ? preDriveSample.nextUp : preDriveSample.nextDown
        }
        return roundedSample
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

    /// Exact upper-note scheduling geometry shared by rendering and evidence.
    /// The note's requested duration is deliberately absent: a positive onset
    /// displacement does not subtract from the requested gate length.
    package static func upperNoteStartFrame(note: ResolvedUpperNote,
                                            stepFrames: Double,
                                            frameCount: Int) -> Int {
        guard frameCount > 0, stepFrames.isFinite, stepFrames > 0 else { return 0 }
        let requested = (Double(note.onsetStep) + note.timingOffsetInSteps) * stepFrames
        guard requested.isFinite else { return 0 }
        return Int(min(Double(frameCount - 1), max(0, requested.rounded())))
    }

    package static func upperNoteDurationFrames(note: ResolvedUpperNote,
                                                stepFrames: Double) -> Int {
        guard stepFrames.isFinite, stepFrames > 0 else { return 1 }
        let requested = note.durationInSteps * stepFrames
        guard requested.isFinite else { return 1 }
        return max(1, Int(requested.rounded()))
    }

    static func renderBar(scene: TechnoScene, sampleRate: Double, state: inout RenderState,
                          dna: SceneDNA, resolved: ResolvedPerformanceBar,
                          synthWorld: SynthWorldDNA, synthPerformance: SynthPerformanceBar,
                          workspace: inout RenderWorkspace, layer: RenderLayer,
                          phraseKind: AutonomousPhraseKind = .lock) -> RenderedBar {
        let performance = resolved.performance
        let section = performance.section
        let frames = max(1, Int((240.0 / scene.bpm * sampleRate).rounded()))
        let stepFrames = Double(frames) / 16.0
        let preKickPocketGeometry: (
            articulation: FoundationPreKickPocketArticulation,
            releaseStartFrame: Int,
            releaseEndFrame: Int,
            kickFrame: Int
        )? = FoundationPreKickPocketResolver.articulation(in: resolved).flatMap {
            articulation in
            let kickOffset = timingOffsetInSteps(
                for: .kick,
                step: articulation.kickStep,
                dna: dna
            )
            let kickFrame = Int((
                (Double(articulation.kickStep) + kickOffset) * stepFrames
            ).rounded())
            let releaseStartFrame = Int(((
                articulation.releaseStartStep + kickOffset
            ) * stepFrames).rounded())
            let releaseEndFrame = Int(((
                articulation.releaseEndStep + kickOffset
            ) * stepFrames).rounded())
            guard releaseStartFrame > 0,
                  releaseStartFrame < releaseEndFrame,
                  releaseEndFrame < kickFrame,
                  kickFrame <= frames else { return nil }
            return (
                articulation,
                releaseStartFrame,
                releaseEndFrame,
                kickFrame
            )
        }
        var checkedOut = workspace.checkout(
            frameCount: frames,
            includeUpperRoleTaps: layer == .full
        )
        var output: [Float] = []
        var kickBus: [Float] = []
        var kickDetectorBus: [Float] = []
        var foundationStem: [Float] = []
        var modalPercussionStem: [Float] = []
        var percussionStem: [Float] = []
        var percussionTextureStem: [Float] = []
        var audioSliceStem = [Float](repeating: 0, count: frames)
        var polyphonicPadStem = [Float](repeating: 0, count: frames)
        var upperTonalStem: [Float] = []
        var atmosphereStem: [Float] = []
        var resonantAnchorStem: [Float] = []
        var detunedCompanionStem: [Float] = []
        var shadowTimingStem: [Float] = []
        var responseTimingStem: [Float] = []
        var resonantMonoInstrumentStem: [Float] = []
        var resonantMonoModulationStem: [Float] = []
        var tonalMotionInstrumentStem: [Float] = []
        var tonalEnvelopeExpansionStem: [Float] = []
        var spectralTextureInstrumentStem: [Float] = []
        var spectralTextureClusterStem: [Float] = []
        var spectralTextureHarmonicTailStem: [Float] = []
        var spectralTextureIndefinitePitchStem: [Float] = []
        var maskingFoundationBus: [Float] = []
        var synthBus: [Float] = []
        var pulseEchoSendBus: [Float] = []
        var spatialReverbSendBus: [Float] = []
        var groovePulseRenderEvidence: [GroovePulseRenderEvidence] = []
        groovePulseRenderEvidence.reserveCapacity(resolved.groovePulses.count)
        var closedHatRenderEvidence: [ClosedHatRenderEvidence] = []
        closedHatRenderEvidence.reserveCapacity(
            resolved.closedHatDecayArticulations.count
        )
        var upperPercussionTailRenderEvidence:
            [UpperPercussionTailRenderEvidence] = []
        upperPercussionTailRenderEvidence.reserveCapacity(
            resolved.upperPercussionTailArticulations.count
        )
        var sourceTerminalDeclickRenderEvidence:
            [SourceTerminalDeclickRenderEvidence] = []
        sourceTerminalDeclickRenderEvidence.reserveCapacity(
            resolved.ensemble.events.count
        )
        var resonantMonoNonlinearCoreEvidence =
            TPTAntialiasedNonlinearCoreEvidenceAccumulator()
        swap(&output, &checkedOut.output)
        swap(&kickBus, &checkedOut.kick)
        swap(&kickDetectorBus, &checkedOut.kickDetector)
        swap(&foundationStem, &checkedOut.foundationStem)
        swap(&modalPercussionStem, &checkedOut.modalPercussionStem)
        swap(&percussionStem, &checkedOut.percussionStem)
        swap(&percussionTextureStem, &checkedOut.percussionTextureStem)
        swap(&upperTonalStem, &checkedOut.upperTonalStem)
        swap(&atmosphereStem, &checkedOut.atmosphereStem)
        swap(&resonantAnchorStem, &checkedOut.resonantAnchorStem)
        swap(&detunedCompanionStem, &checkedOut.detunedCompanionStem)
        swap(&shadowTimingStem, &checkedOut.shadowTimingStem)
        swap(&responseTimingStem, &checkedOut.responseTimingStem)
        swap(&resonantMonoInstrumentStem, &checkedOut.resonantMonoInstrumentStem)
        swap(&resonantMonoModulationStem, &checkedOut.resonantMonoModulationStem)
        swap(&tonalMotionInstrumentStem, &checkedOut.tonalMotionInstrumentStem)
        swap(&tonalEnvelopeExpansionStem, &checkedOut.tonalEnvelopeExpansionStem)
        swap(&spectralTextureInstrumentStem, &checkedOut.spectralTextureInstrumentStem)
        swap(&spectralTextureClusterStem, &checkedOut.spectralTextureClusterStem)
        swap(
            &spectralTextureHarmonicTailStem,
            &checkedOut.spectralTextureHarmonicTailStem
        )
        swap(
            &spectralTextureIndefinitePitchStem,
            &checkedOut.spectralTextureIndefinitePitchStem
        )
        swap(&maskingFoundationBus, &checkedOut.maskingFoundation)
        swap(&synthBus, &checkedOut.synth)
        swap(&pulseEchoSendBus, &checkedOut.pulseEchoSend)
        swap(&spatialReverbSendBus, &checkedOut.spatialReverbSend)
        var random = SeededGenerator(seed: performance.eventSeed)
        var renderedKickEventCount = 0
        var renderedKickStepMask: UInt16 = 0
        var kickSourceDynamics = KickSourceDynamicsEvidenceAccumulator()
        kickSourceDynamics.bind(morphology: resolved.kickMorphology)
        var renderedBassEventCount = 0
        var renderedBassStepMask: UInt16 = 0
        var renderedBassStartFrames: [Int] = []
        renderedBassStartFrames.reserveCapacity(6)
        var preKickPocketFoundationResult: (
            eventStartFrame: Int,
            render: ResonantMonoFoundationRenderResult
        )?
        var scheduledModalPercussion: [ScheduledModalPercussionEvent] = []
        scheduledModalPercussion.reserveCapacity(
            resolved.modalPercussionArticulations.count
        )

        for (scoreEventIndex, event) in resolved.ensemble.events.enumerated() {
            let pulseArticulation = event.voice == .groovePulse
                ? resolved.groovePulse(at: event.step) : nil
            let offset = pulseArticulation?.timingOffsetInSteps ??
                timingOffsetInSteps(for: event.voice, step: event.step, dna: dna)
            let start = Int(((Double(event.step) + offset) * stepFrames).rounded())
            let accent = performance.accent(at: event.step) * event.intensity
            switch event.voice {
            case .kick:
                let detectorLevel = KickMixBalance.detectorLevel(for: section) * accent
                if (0..<16).contains(event.step),
                   let terminalEvidence = kick(
                        &kickDetectorBus,
                        scoreEventIndex: scoreEventIndex,
                        start: start,
                        sampleRate: sampleRate,
                        level: detectorLevel, seed: scene.seed, step: event.step,
                        barDurationSeconds: 240.0 / scene.bpm,
                        morphology: resolved.kickMorphology,
                        sourceDynamics: &kickSourceDynamics
                   ) {
                    // Count only events that produced a bounded render window,
                    // rather than inferring production from score membership.
                    renderedKickEventCount += 1
                    renderedKickStepMask |= UInt16(1) << UInt16(event.step)
                    sourceTerminalDeclickRenderEvidence.append(terminalEvidence)
                }
            case .bass where !(performance.signatureEvent == .delayedBassEntry && event.step < 8):
                let frequency = FoundationPitchResolver.frequency(
                    dna: dna, step: event.step
                )
                let pocket = preKickPocketGeometry.flatMap { geometry in
                    geometry.articulation.scoreEventIndex == scoreEventIndex
                        ? geometry : nil
                }
                let renderedBass = ResonantMonoVoice.renderFoundation(
                    &output,
                    measurement: &foundationStem,
                    architectureMeasurement: &resonantMonoInstrumentStem,
                    pulseEchoSend: &pulseEchoSendBus,
                    spatialReverbSend: &spatialReverbSendBus,
                    start: start,
                    sampleRate: sampleRate,
                    level: 0.11 + performance.tension * 0.035,
                    frequency: frequency,
                    assignment: synthPerformance.foundationInstrument,
                    velocity: accent,
                    terminalReleaseStartFrame: pocket?.releaseStartFrame,
                    terminalReleaseEndFrame: pocket?.releaseEndFrame,
                    state: &state.resonantFoundationState,
                    nonlinearCoreEvidence: &resonantMonoNonlinearCoreEvidence
                )
                if pocket != nil {
                    preKickPocketFoundationResult = (
                        eventStartFrame: start,
                        render: renderedBass
                    )
                }
                if renderedBass.naturalFrameCount > 0,
                   (0..<16).contains(event.step) {
                    renderedBassEventCount += 1
                    renderedBassStepMask |= UInt16(1) << UInt16(event.step)
                    renderedBassStartFrames.append(start)
                }
            case .rumble:
                if let terminalEvidence = rumble(
                    &output,
                    measurement: &foundationStem,
                    scoreEventIndex: scoreEventIndex,
                    start: start,
                    sampleRate: sampleRate,
                    level: 0.072 * accent,
                    seed: scene.seed,
                    step: event.step
                ) {
                    sourceTerminalDeclickRenderEvidence.append(terminalEvidence)
                }
            case .tunedTom:
                guard let articulation = resolved.modalPercussion(
                    atEventIndex: scoreEventIndex
                ), articulation.step == event.step,
                   articulation.use == .foundationCompanion else {
                    break
                }
                scheduledModalPercussion.append(ScheduledModalPercussionEvent(
                    articulation: articulation,
                    startFrame: start,
                    level: 0.085 * performance.accent(at: event.step)
                ))
            case .percussion:
                let level = ClosedHatVoiceContract.level(
                    section: section,
                    combinedAccent: accent
                )
                let role = resolved.closedHatDecay(
                    atEventIndex: scoreEventIndex
                )?.role ?? .neutral
                if let evidence = hat(
                    &output, measurement: &percussionStem, start: start,
                    sampleRate: sampleRate, level: level,
                    brightness: scene.character.percussionBrightness,
                    random: &random,
                    scoreEventIndex: scoreEventIndex,
                    event: event,
                    timingOffsetInSteps: offset,
                    role: role
                ) {
                    closedHatRenderEvidence.append(evidence)
                }
            case .clap:
                guard let articulation = resolved.upperPercussionTail(
                    atEventIndex: scoreEventIndex
                ), articulation.voice == event.voice,
                   articulation.step == event.step else { break }
                if let evidence = clap(
                    &output,
                    measurement: &percussionStem,
                    start: start,
                    sampleRate: sampleRate,
                    level: 0.08 * accent,
                    brightness: scene.character.percussionBrightness,
                    random: &random,
                    articulation: articulation,
                    event: event,
                    timingOffsetInSteps: offset
                ) {
                    upperPercussionTailRenderEvidence.append(evidence)
                    sourceTerminalDeclickRenderEvidence.append(
                        evidence.terminalDeclick
                    )
                }
            case .openHat:
                guard let articulation = resolved.upperPercussionTail(
                    atEventIndex: scoreEventIndex
                ), articulation.voice == event.voice,
                   articulation.step == event.step else { break }
                if let evidence = openHat(
                    &output,
                    measurement: &percussionStem,
                    start: start,
                    sampleRate: sampleRate,
                    level: 0.052 * accent,
                    brightness: scene.character.percussionBrightness,
                    random: &random,
                    articulation: articulation,
                    event: event,
                    timingOffsetInSteps: offset
                ) {
                    upperPercussionTailRenderEvidence.append(evidence)
                    sourceTerminalDeclickRenderEvidence.append(
                        evidence.terminalDeclick
                    )
                }
            case .metallic:
                guard let articulation = resolved.upperPercussionTail(
                    atEventIndex: scoreEventIndex
                ), articulation.voice == event.voice,
                   articulation.step == event.step else { break }
                if let evidence = metallicPercussion(
                    &output,
                    measurement: &percussionStem,
                    start: start,
                    sampleRate: sampleRate,
                    level: 0.042 * accent,
                    brightness: scene.character.percussionBrightness,
                    random: &random,
                    articulation: articulation,
                    event: event,
                    timingOffsetInSteps: offset
                ) {
                    upperPercussionTailRenderEvidence.append(evidence)
                    sourceTerminalDeclickRenderEvidence.append(
                        evidence.terminalDeclick
                    )
                }
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
        let modalPercussionRenderEvidence = ModalPercussionVoice.renderBar(
            into: &modalPercussionStem,
            bar: performance.bar,
            sampleRate: sampleRate,
            events: scheduledModalPercussion,
            state: &state.modalPercussionState
        )
        let foundationPeak = foundationStem.reduce(0.0) {
            max($0, abs(Double($1)))
        }
        let foundationEnergy = foundationStem.reduce(0.0) {
            $0 + Double($1) * Double($1)
        }
        let foundationRMS = sqrt(
            foundationEnergy / Double(max(1, foundationStem.count))
        )
        let preKickPocketRenderEvidence: FoundationPreKickPocketRenderEvidence = {
            guard let geometry = preKickPocketGeometry,
                  let result = preKickPocketFoundationResult,
                  geometry.releaseEndFrame <= foundationStem.count,
                  geometry.kickFrame <= foundationStem.count else {
                return .neutral
            }
            let silenceFrameCount = geometry.kickFrame -
                geometry.releaseEndFrame
            var fingerprint = ExactPCMFingerprint.MonoAccumulator(
                sampleCount: silenceFrameCount
            )
            var silencePeak = 0.0
            var silenceEnergy = 0.0
            var finite = silenceFrameCount > 0
            if silenceFrameCount > 0 {
                for frame in geometry.releaseEndFrame..<geometry.kickFrame {
                    let sample = foundationStem[frame]
                    fingerprint.append(sample)
                    let value = Double(sample)
                    finite = finite && value.isFinite
                    silencePeak = max(silencePeak, abs(value))
                    silenceEnergy += value * value
                }
            }
            let silenceRMS = silenceFrameCount > 0
                ? sqrt(silenceEnergy / Double(silenceFrameCount)) : 0
            return FoundationPreKickPocketRenderEvidence(
                relation: geometry.articulation.relation,
                scoreEventIndex: geometry.articulation.scoreEventIndex,
                bassStep: geometry.articulation.bassStep,
                kickStep: geometry.articulation.kickStep,
                eventStartFrame: result.eventStartFrame,
                naturalEndFrame: result.eventStartFrame +
                    result.render.naturalFrameCount,
                releaseStartFrame: geometry.releaseStartFrame,
                releaseEndFrame: geometry.releaseEndFrame,
                kickFrame: geometry.kickFrame,
                releaseFrameCount: geometry.releaseEndFrame -
                    geometry.releaseStartFrame,
                silenceFrameCount: silenceFrameCount,
                silenceSampleHash: fingerprint.fingerprint,
                silencePeak: silencePeak,
                silenceRMS: silenceRMS,
                applied: result.render.terminalReleaseApplied &&
                    result.eventStartFrame + result.render.appliedFrameCount ==
                        geometry.releaseEndFrame,
                finite: finite && silencePeak.isFinite && silenceRMS.isFinite
            )
        }()
        let foundationRhythmRenderEvidence = FoundationRhythmRenderEvidence(
            bar: performance.bar,
            relation: resolved.foundationRhythmicRelation,
            sampleRate: sampleRate,
            renderedFrameCount: frames,
            renderedBassEventCount: renderedBassEventCount,
            renderedBassStepMask: renderedBassStepMask,
            renderedStartFrames: renderedBassStartFrames,
            dryFoundationSampleHash: ExactPCMFingerprint.mono(foundationStem),
            peak: foundationPeak,
            rms: foundationRMS,
            preKickPocket: preKickPocketRenderEvidence,
            finite: foundationPeak.isFinite && foundationRMS.isFinite &&
                foundationStem.allSatisfy(\.isFinite)
        )
        for index in 0..<frames {
            let modalSample = modalPercussionStem[index]
            foundationStem[index] += modalSample
        }
        let dryModalPercussionSampleHash = ExactPCMFingerprint.mono(
            modalPercussionStem
        )
        let modalPercussionFoundationRoutingValid =
            modalPercussionRenderEvidence.dryBarSampleHash ==
                dryModalPercussionSampleHash &&
            modalPercussionRenderEvidence.events.allSatisfy {
                $0.articulation.use == .foundationCompanion
            }
        let percussionEchoTextureRenderEvidence =
            PercussionEchoTextureVoice.render(
                source: percussionStem,
                returnStem: &percussionTextureStem,
                articulation: resolved.percussionEchoTexture,
                bpm: scene.bpm,
                sampleRate: sampleRate
            )
        let audioSlicePlan = synthPerformance.composition.audioSlice
        let audioSliceRenderEvidence: AudioSliceRenderEvidence
        if audioSlicePlan?.sourceKind == .kick {
            audioSliceRenderEvidence = AudioSliceRenderer.render(
                source: kickDetectorBus,
                output: &audioSliceStem,
                plan: audioSlicePlan,
                stepFrames: stepFrames,
                sampleRate: sampleRate
            )
        } else {
            audioSliceRenderEvidence = AudioSliceRenderer.render(
                source: percussionStem,
                output: &audioSliceStem,
                plan: audioSlicePlan,
                stepFrames: stepFrames,
                sampleRate: sampleRate
            )
        }
        // Preserve the dry tap for its existing fingerprint and reverb send;
        // the reused texture buffer becomes the complete audible percussion
        // role for reconstruction, masking, and automatic-mix observation.
        for index in 0..<frames {
            output[index] += percussionTextureStem[index] + audioSliceStem[index]
            percussionTextureStem[index] +=
                percussionStem[index] + audioSliceStem[index]
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
        let renderScheduledUpperNotes = !textureCollapsed && upperRolesActive
        var upperNoteRenderEvidence: [UpperNoteRenderEvidence] = []
        var polyphonicPadRenderEvidence = PolyphonicPadRenderEvidence.neutral
        if layer == .full {
            renderInstrumentWorld(
                &synthBus,
                pulseEchoSend: &pulseEchoSendBus,
                spatialReverbSend: &spatialReverbSendBus,
                upperTonalStem: &upperTonalStem,
                atmosphereStem: &atmosphereStem,
                resonantAnchorStem: &resonantAnchorStem,
                detunedCompanionStem: &detunedCompanionStem,
                shadowTimingStem: &shadowTimingStem,
                responseTimingStem: &responseTimingStem,
                resonantMonoInstrumentStem: &resonantMonoInstrumentStem,
                resonantMonoModulationStem: &resonantMonoModulationStem,
                tonalMotionInstrumentStem: &tonalMotionInstrumentStem,
                tonalEnvelopeExpansionStem: &tonalEnvelopeExpansionStem,
                spectralTextureInstrumentStem: &spectralTextureInstrumentStem,
                spectralTextureClusterStem: &spectralTextureClusterStem,
                spectralTextureHarmonicTailStem:
                    &spectralTextureHarmonicTailStem,
                spectralTextureIndefinitePitchStem:
                    &spectralTextureIndefinitePitchStem,
                polyphonicPadStem: &polyphonicPadStem,
                polyphonicPadRenderEvidence: &polyphonicPadRenderEvidence,
                noteRenderEvidence: &upperNoteRenderEvidence,
                resonantMonoNonlinearCoreEvidence:
                    &resonantMonoNonlinearCoreEvidence,
                renderScheduledNotes: renderScheduledUpperNotes,
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
        let upperTonalOnsets = Array(Set(upperNoteRenderEvidence.compactMap { evidence in
            switch evidence.role {
            case .anchor, .shadow, .response:
                evidence.onsetFrame
            case .atmosphere, .transition:
                nil
            }
        })).sorted()
        let kickOnsets = onsetFrames(for: [.kick])
        var stemObservations: [MixRole: StemObservation] = [
            .kick: StemObservationAnalyzer.analyze(
                kickBus, sampleRate: sampleRate, onsetFrames: kickOnsets
            ),
            .foundation: StemObservationAnalyzer.analyze(
                foundationStem, sampleRate: sampleRate, onsetFrames: kickOnsets
            ),
            .percussion: StemObservationAnalyzer.analyze(
                percussionTextureStem, sampleRate: sampleRate,
                onsetFrames: onsetFrames(for: [
                    .percussion, .clap, .openHat, .metallic, .groovePulse,
                ])
            ),
            .upperTonal: StemObservationAnalyzer.analyze(
                upperTonalStem, sampleRate: sampleRate,
                onsetFrames: upperTonalOnsets
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
            let reconstructedCenter = maskingFoundationBus[index] +
                percussionTextureStem[index]
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
        // One canonical eight-line late field replaces the former single long
        // repeating delay. Its immutable configuration is derived from the
        // same score-owned scene and persists through detached continuation.
        let requestedSpatialFDNConfiguration = FeedbackDelayNetworkConfiguration(
            scene: scene,
            sampleRate: sampleRate,
            phraseKind: phraseKind
        )
        let resolvedSpatialFDN = state.spatialFDNState.resolveConfiguration(
            for: requestedSpatialFDNConfiguration
        )
        let spatialFDNConfiguration = resolvedSpatialFDN.configuration
        let spatialFDNInitialMaximumFeedbackGain =
            state.spatialFDNState.appliedFeedbackGains.max() ?? 0
        let spatialFDNInitialDampingCoefficient =
            state.spatialFDNState.appliedDampingCoefficient
        let spatialFDNInitialSynthSendGain =
            state.spatialFDNState.appliedSynthSendGain
        let spatialFDNInitialPercussionSendGain =
            state.spatialFDNState.appliedPercussionSendGain
        let spatialFDNInitialWetGain = state.spatialFDNState.appliedWetGain
        let spatialFDNParameterTransitionFrameCount =
            state.spatialFDNState.beginParameterTransition(
                toward: spatialFDNConfiguration
            )
        var spatialFDNScratch = [Double](
            repeating: 0,
            count: FeedbackDelayNetworkConfiguration.lineCount
        )
        var spatialFDNInputFingerprint = ExactPCMFingerprint.MonoAccumulator(
            sampleCount: frames
        )
        var spatialFDNWetLeftFingerprint = ExactPCMFingerprint.MonoAccumulator(
            sampleCount: frames
        )
        var spatialFDNWetRightFingerprint = ExactPCMFingerprint.MonoAccumulator(
            sampleCount: frames
        )
        var spatialFDNInputEnergy = 0.0
        var spatialFDNSpatialSendEnergy = 0.0
        var spatialFDNWetEnergy = 0.0
        var spatialFDNWetLeftEnergy = 0.0
        var spatialFDNWetRightEnergy = 0.0
        var spatialFDNWetCrossEnergy = 0.0
        var spatialFDNWetPeak = 0.0
        let spatialFDNTailWindowFrameCount = min(
            frames,
            max(1, Int((sampleRate * 0.25).rounded()))
        )
        var spatialFDNOpeningWetEnergy = 0.0
        var spatialFDNTerminalWetEnergy = 0.0
        var spatialFDNActiveInputFrameCount = 0
        var spatialFDNActiveWetFrameCount = 0
        var spatialFDNFirstWetFrameIndex = -1
        var spatialFDNFinite =
            requestedSpatialFDNConfiguration.isBoundedAndStable &&
            spatialFDNConfiguration.isBoundedAndStable &&
            state.spatialFDNState.isPrepared
        let pulseEchoTexture = synthPerformance.pulseEchoTextureArticulation
        let pulseEchoDriveAmount = layer == .full
            ? pulseEchoTexture.appliedAmount : 0
        let pulseEchoTransitionFrameCount =
            PulseEchoReturnDriveContract.transitionFrameCount(sampleRate: sampleRate)
        let pulseEchoEvidenceLowPassCoefficient = min(
            0.25,
            1 - exp(-2 * .pi * 180 / sampleRate)
        )
        var pulseEchoPreDriveFingerprint = ExactPCMFingerprint.MonoAccumulator(
            sampleCount: frames
        )
        var pulseEchoPostDriveFingerprint = ExactPCMFingerprint.MonoAccumulator(
            sampleCount: frames
        )
        var pulseEchoCurrentSendEnergy = 0.0
        var pulseEchoPreDriveEnergy = 0.0
        var pulseEchoPostDriveEnergy = 0.0
        var pulseEchoPreDriveLowBandEnergy = 0.0
        var pulseEchoPostDriveLowBandEnergy = 0.0
        var pulseEchoDifferenceEnergy = 0.0
        var pulseEchoFirstPreDriveSampleBitPattern: UInt32 = 0
        var pulseEchoFirstPostDriveSampleBitPattern: UInt32 = 0
        var pulseEchoLastPreDriveSampleBitPattern: UInt32 = 0
        var pulseEchoLastPostDriveSampleBitPattern: UInt32 = 0
        var pulseEchoChangedFrameIndex = -1
        var pulseEchoChangedPreDriveSampleBitPattern: UInt32 = 0
        var pulseEchoPreDrivePeak = 0.0
        var pulseEchoPreDrivePeakFrameIndex = 0
        var pulseEchoPostDrivePeak = 0.0
        var pulseEchoPostDrivePeakFrameIndex = 0
        var pulseEchoPostDrivePeakPreDriveSample = 0.0
        var pulseEchoPostDrivePeakEffectiveAmount = 0.0
        var pulseEchoPreDriveLowBandState = 0.0
        var pulseEchoPostDriveLowBandState = 0.0
        var pulseEchoReturnDriveFinite = scene.bpm.isFinite &&
            sampleRate.isFinite &&
            pulseEchoTexture.machineTexture.isFinite &&
            pulseEchoDriveAmount.isFinite
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
                    .percussion: percussionTextureStem,
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
            let filteredPulseEcho = state.pulseEchoLowPassState
            let preDrivePulseEcho = Float(filteredPulseEcho * 0.18)
            let pulseEchoEffectiveAmount = PulseEchoReturnDriveContract.effectiveAmount(
                targetAmount: pulseEchoDriveAmount,
                frame: index,
                totalFrameCount: frames,
                transitionFrameCount: pulseEchoTransitionFrameCount
            )
            let pulseEcho = PulseEchoReturnDriveContract.process(
                preDriveSample: preDrivePulseEcho,
                amount: pulseEchoEffectiveAmount
            )
            let currentSend = pulseEchoSendBus[index]
            pulseEchoPreDriveFingerprint.append(preDrivePulseEcho)
            pulseEchoPostDriveFingerprint.append(pulseEcho)
            let currentSendValue = Double(currentSend)
            let preDriveValue = Double(preDrivePulseEcho)
            let postDriveValue = Double(pulseEcho)
            if index == 0 {
                pulseEchoFirstPreDriveSampleBitPattern = preDrivePulseEcho.bitPattern
                pulseEchoFirstPostDriveSampleBitPattern = pulseEcho.bitPattern
            }
            if index == frames - 1 {
                pulseEchoLastPreDriveSampleBitPattern = preDrivePulseEcho.bitPattern
                pulseEchoLastPostDriveSampleBitPattern = pulseEcho.bitPattern
            }
            if pulseEchoChangedFrameIndex == -1,
               pulseEcho.bitPattern != preDrivePulseEcho.bitPattern {
                pulseEchoChangedFrameIndex = index
                pulseEchoChangedPreDriveSampleBitPattern =
                    preDrivePulseEcho.bitPattern
            }
            let difference = postDriveValue - preDriveValue
            pulseEchoCurrentSendEnergy += currentSendValue * currentSendValue
            pulseEchoPreDriveEnergy += preDriveValue * preDriveValue
            pulseEchoPostDriveEnergy += postDriveValue * postDriveValue
            pulseEchoDifferenceEnergy += difference * difference
            if index == 0 || abs(preDriveValue) > pulseEchoPreDrivePeak {
                pulseEchoPreDrivePeak = abs(preDriveValue)
                pulseEchoPreDrivePeakFrameIndex = index
            }
            if index == 0 || abs(postDriveValue) > pulseEchoPostDrivePeak {
                pulseEchoPostDrivePeak = abs(postDriveValue)
                pulseEchoPostDrivePeakFrameIndex = index
                pulseEchoPostDrivePeakPreDriveSample = preDriveValue
                pulseEchoPostDrivePeakEffectiveAmount = pulseEchoEffectiveAmount
            }
            pulseEchoPreDriveLowBandState +=
                (preDriveValue - pulseEchoPreDriveLowBandState) *
                pulseEchoEvidenceLowPassCoefficient
            pulseEchoPostDriveLowBandState +=
                (postDriveValue - pulseEchoPostDriveLowBandState) *
                pulseEchoEvidenceLowPassCoefficient
            pulseEchoPreDriveLowBandEnergy +=
                pulseEchoPreDriveLowBandState * pulseEchoPreDriveLowBandState
            pulseEchoPostDriveLowBandEnergy +=
                pulseEchoPostDriveLowBandState * pulseEchoPostDriveLowBandState
            pulseEchoReturnDriveFinite = pulseEchoReturnDriveFinite &&
                currentSend.isFinite &&
                preDrivePulseEcho.isFinite &&
                pulseEcho.isFinite &&
                pulseEchoEffectiveAmount.isFinite &&
                pulseEchoPreDriveLowBandState.isFinite &&
                pulseEchoPostDriveLowBandState.isFinite &&
                difference.isFinite
            // A short independent reflection gives upper voices depth before
            // the late FDN. Neither path receives kick or bass, preserving the
            // centered, mono-compatible low end.
            let earlyRead = state.earlyReflectionBuffer[state.earlyReflectionWriteIndex]
            state.earlyReflectionBuffer[state.earlyReflectionWriteIndex] = synthInput * 0.30
            let earlyMix = Float(0.035 + dramaticDistance * 0.08)
            state.spatialFDNState.advanceParameterTransition()
            let drumSend = percussionStem[index] *
                Float(state.spatialFDNState.appliedPercussionSendGain)
            let rawSpatialSend = Double(spatialReverbSendBus[index])
            state.spatialSendHighPassState +=
                (rawSpatialSend - state.spatialSendHighPassState) *
                spatialHighPassCoefficient
            let highPassedSpatialSend = rawSpatialSend -
                state.spatialSendHighPassState
            state.spatialSendLowPassState +=
                (highPassedSpatialSend - state.spatialSendLowPassState) *
                spatialLowPassCoefficient
            let spatialFDNInput = synthInput *
                Float(state.spatialFDNState.appliedSynthSendGain) + drumSend +
                Float(state.spatialSendLowPassState)
            let spatialFDNFrame = FeedbackDelayNetwork.processPrepared(
                input: spatialFDNInput,
                configuration: spatialFDNConfiguration,
                state: &state.spatialFDNState,
                scratch: &spatialFDNScratch
            )
            spatialFDNInputFingerprint.append(spatialFDNInput)
            let spatialFDNInputValue = Double(spatialFDNInput)
            spatialFDNInputEnergy += spatialFDNInputValue * spatialFDNInputValue
            spatialFDNSpatialSendEnergy +=
                state.spatialSendLowPassState * state.spatialSendLowPassState
            if spatialFDNInput.bitPattern != 0 &&
                spatialFDNInput.bitPattern != 0x8000_0000 {
                spatialFDNActiveInputFrameCount += 1
            }
            spatialFDNFinite = spatialFDNFinite && spatialFDNInput.isFinite &&
                spatialFDNFrame.left.isFinite && spatialFDNFrame.right.isFinite &&
                state.spatialSendHighPassState.isFinite &&
                state.spatialSendLowPassState.isFinite
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
            let spatialFDNScale = Float(
                state.spatialFDNState.appliedWetGain
            ) * upperDuck
            let spatialFDNLeft = spatialFDNFrame.left * spatialFDNScale
            let spatialFDNRight = spatialFDNFrame.right * spatialFDNScale
            spatialFDNWetLeftFingerprint.append(spatialFDNLeft)
            spatialFDNWetRightFingerprint.append(spatialFDNRight)
            let spatialFDNLeftValue = Double(spatialFDNLeft)
            let spatialFDNRightValue = Double(spatialFDNRight)
            spatialFDNWetLeftEnergy += spatialFDNLeftValue * spatialFDNLeftValue
            spatialFDNWetRightEnergy += spatialFDNRightValue * spatialFDNRightValue
            spatialFDNWetCrossEnergy += spatialFDNLeftValue * spatialFDNRightValue
            spatialFDNWetEnergy += spatialFDNLeftValue * spatialFDNLeftValue +
                spatialFDNRightValue * spatialFDNRightValue
            let spatialFDNFrameEnergy =
                spatialFDNLeftValue * spatialFDNLeftValue +
                spatialFDNRightValue * spatialFDNRightValue
            if index < spatialFDNTailWindowFrameCount {
                spatialFDNOpeningWetEnergy += spatialFDNFrameEnergy
            }
            if index >= frames - spatialFDNTailWindowFrameCount {
                spatialFDNTerminalWetEnergy += spatialFDNFrameEnergy
            }
            spatialFDNWetPeak = max(
                spatialFDNWetPeak,
                abs(spatialFDNLeftValue),
                abs(spatialFDNRightValue)
            )
            let wetIsActive = (spatialFDNLeft.bitPattern != 0 &&
                spatialFDNLeft.bitPattern != 0x8000_0000) ||
                (spatialFDNRight.bitPattern != 0 &&
                    spatialFDNRight.bitPattern != 0x8000_0000)
            if wetIsActive {
                spatialFDNActiveWetFrameCount += 1
                if spatialFDNFirstWetFrameIndex == -1 {
                    spatialFDNFirstWetFrameIndex = index
                }
            }
            let leftPreMaster = center + synthLeftOut + reflectionLeft +
                (spatial + pulseEcho) * (1.0 + delayPan * 0.18) * upperDuck +
                spatialFDNLeft
            let rightPreMaster = center + synthRightOut + reflectionRight +
                (spatial + pulseEcho) * (1.0 + (1.0 - delayPan) * 0.18) * upperDuck +
                spatialFDNRight
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
        }
        // Modal foundation remains a protected center contribution, but its
        // identical full/protected consequence must not leak into the upper
        // graph remainder through the shared nonlinear center/upper master.
        // The existing terminal master safety still receives the recombined
        // protected signal in AutonomousPhraseRenderer.
        let graphRemainderReferenceLeftSamples = left
        let graphRemainderReferenceRightSamples = right
        for index in 0..<frames where modalPercussionStem[index] != 0 {
            let modalMasterSample = safeMaster(
                modalPercussionStem[index] * 1.015
            )
            left[index] += modalMasterSample
            right[index] += modalMasterSample
        }
        // One bounded pass reduces the exact terminal detector and audible
        // kick buses. Fingerprints stream over sample bits without retaining
        // another PCM buffer, and nonzero counts use the same exact bits.
        var audibleKickPeak = 0.0
        var detectorKickPeak = 0.0
        var audibleKickEnergy = 0.0
        var detectorKickEnergy = 0.0
        var detectorKickFingerprint = ExactPCMFingerprint.MonoAccumulator(
            sampleCount: frames
        )
        var audibleKickFingerprint = ExactPCMFingerprint.MonoAccumulator(
            sampleCount: frames
        )
        var detectorNonzeroSampleCount = 0
        var audibleNonzeroSampleCount = 0
        var detectorToAudibleScaleMatches = true
        for index in 0..<frames {
            let detectorSample = kickDetectorBus[index]
            let audibleSample = kickBus[index]
            let detectorValue = Double(detectorSample)
            let audibleValue = Double(audibleSample)
            detectorKickPeak = max(detectorKickPeak, abs(detectorValue))
            audibleKickPeak = max(audibleKickPeak, abs(audibleValue))
            detectorKickEnergy += detectorValue * detectorValue
            audibleKickEnergy += audibleValue * audibleValue
            detectorKickFingerprint.append(detectorSample)
            audibleKickFingerprint.append(audibleSample)
            if detectorSample != 0 {
                detectorNonzeroSampleCount += 1
            }
            if audibleSample != 0 {
                audibleNonzeroSampleCount += 1
            }
            let expectedAudible = detectorSample *
                Float(KickMixBalance.audibleGain) * automaticKickGain
            detectorToAudibleScaleMatches = detectorToAudibleScaleMatches &&
                audibleSample.bitPattern == expectedAudible.bitPattern
        }
        let kickEvidenceFrameCount = Double(max(1, frames))
        let audibleKickRMS = sqrt(audibleKickEnergy / kickEvidenceFrameCount)
        let detectorKickRMS = sqrt(detectorKickEnergy / kickEvidenceFrameCount)
        let kickMix = KickMixEvidence(
            renderedFrameCount: frames,
            renderedKickEventCount: renderedKickEventCount,
            renderedKickStepMask: renderedKickStepMask,
            audibleGain: KickMixBalance.audibleGain * Double(automaticKickGain),
            audiblePeak: audibleKickPeak,
            audibleRMS: audibleKickRMS,
            detectorPeak: detectorKickPeak,
            detectorRMS: detectorKickRMS,
            duckingEnvelopePeak: kickEnvelopePeak,
            detectorSampleHash: detectorKickFingerprint.fingerprint,
            audibleSampleHash: audibleKickFingerprint.fingerprint,
            detectorNonzeroSampleCount: detectorNonzeroSampleCount,
            audibleNonzeroSampleCount: audibleNonzeroSampleCount,
            sourceDynamics: kickSourceDynamics.evidence,
            detectorToAudibleScaleMatches: detectorToAudibleScaleMatches
        )
        let pulseEchoEvidenceFrameCount = Double(max(1, frames))
        let pulseEchoCurrentSendRMS = sqrt(
            pulseEchoCurrentSendEnergy / pulseEchoEvidenceFrameCount
        )
        let pulseEchoPreDriveRMS = sqrt(
            pulseEchoPreDriveEnergy / pulseEchoEvidenceFrameCount
        )
        let pulseEchoPostDriveRMS = sqrt(
            pulseEchoPostDriveEnergy / pulseEchoEvidenceFrameCount
        )
        let pulseEchoPreDriveLowBandRMS = sqrt(
            pulseEchoPreDriveLowBandEnergy / pulseEchoEvidenceFrameCount
        )
        let pulseEchoPostDriveLowBandRMS = sqrt(
            pulseEchoPostDriveLowBandEnergy / pulseEchoEvidenceFrameCount
        )
        let pulseEchoDifferenceRMS = sqrt(
            pulseEchoDifferenceEnergy / pulseEchoEvidenceFrameCount
        )
        pulseEchoReturnDriveFinite = pulseEchoReturnDriveFinite && [
            pulseEchoCurrentSendRMS,
            pulseEchoPreDrivePeak,
            pulseEchoPostDrivePeak,
            pulseEchoPreDriveRMS,
            pulseEchoPostDriveRMS,
            pulseEchoPreDriveLowBandRMS,
            pulseEchoPostDriveLowBandRMS,
            pulseEchoDifferenceRMS,
            pulseEchoPostDrivePeakPreDriveSample,
            pulseEchoPostDrivePeakEffectiveAmount,
        ].allSatisfy { $0.isFinite }
        let pulseEchoReturnDriveRenderEvidence = PulseEchoReturnDriveRenderEvidence(
            bar: performance.bar,
            bpm: scene.bpm,
            delayFrameCount: pulseEchoFrames,
            machineTexture: pulseEchoTexture.machineTexture,
            scoreEnabled: resolved.pulseEchoEnabled,
            earliestPulseEchoOnsetStep:
                pulseEchoTexture.earliestPulseEchoOnsetStep,
            driveEligible: pulseEchoTexture.driveEligible,
            appliedAmount: pulseEchoDriveAmount,
            transitionFrameCount: pulseEchoTransitionFrameCount,
            renderedFrameCount: frames,
            currentSendRMS: pulseEchoCurrentSendRMS,
            preDriveSampleHash: pulseEchoPreDriveFingerprint.fingerprint,
            postDriveSampleHash: pulseEchoPostDriveFingerprint.fingerprint,
            firstPreDriveSampleBitPattern:
                pulseEchoFirstPreDriveSampleBitPattern,
            firstPostDriveSampleBitPattern:
                pulseEchoFirstPostDriveSampleBitPattern,
            lastPreDriveSampleBitPattern:
                pulseEchoLastPreDriveSampleBitPattern,
            lastPostDriveSampleBitPattern:
                pulseEchoLastPostDriveSampleBitPattern,
            changedFrameIndex: pulseEchoChangedFrameIndex,
            changedPreDriveSampleBitPattern:
                pulseEchoChangedPreDriveSampleBitPattern,
            preDrivePeak: pulseEchoPreDrivePeak,
            preDrivePeakFrameIndex: pulseEchoPreDrivePeakFrameIndex,
            postDrivePeak: pulseEchoPostDrivePeak,
            postDrivePeakFrameIndex: pulseEchoPostDrivePeakFrameIndex,
            postDrivePeakPreDriveSample:
                pulseEchoPostDrivePeakPreDriveSample,
            postDrivePeakEffectiveAmount:
                pulseEchoPostDrivePeakEffectiveAmount,
            preDriveRMS: pulseEchoPreDriveRMS,
            postDriveRMS: pulseEchoPostDriveRMS,
            preDriveLowBandRMS: pulseEchoPreDriveLowBandRMS,
            postDriveLowBandRMS: pulseEchoPostDriveLowBandRMS,
            differenceRMS: pulseEchoDifferenceRMS,
            finite: pulseEchoReturnDriveFinite
        )
        let spatialFDNEvidenceFrameCount = Double(max(1, frames))
        let spatialFDNInputRMS = sqrt(
            spatialFDNInputEnergy / spatialFDNEvidenceFrameCount
        )
        let spatialFDNSpatialSendRMS = sqrt(
            spatialFDNSpatialSendEnergy / spatialFDNEvidenceFrameCount
        )
        let spatialFDNWetRMS = sqrt(
            spatialFDNWetEnergy / (spatialFDNEvidenceFrameCount * 2)
        )
        let spatialFDNOpeningWetRMS = sqrt(
            spatialFDNOpeningWetEnergy /
                Double(max(1, spatialFDNTailWindowFrameCount * 2))
        )
        let spatialFDNTerminalWetRMS = sqrt(
            spatialFDNTerminalWetEnergy /
                Double(max(1, spatialFDNTailWindowFrameCount * 2))
        )
        let spatialFDNWetStereoDenominator = sqrt(max(
            0.000_000_000_000_000_001,
            spatialFDNWetLeftEnergy * spatialFDNWetRightEnergy
        ))
        let spatialFDNWetStereoCorrelation =
            spatialFDNWetLeftEnergy > 0 && spatialFDNWetRightEnergy > 0
            ? min(1, max(-1,
                spatialFDNWetCrossEnergy / spatialFDNWetStereoDenominator
            )) : 0
        spatialFDNFinite = spatialFDNFinite && [
            spatialFDNInputRMS,
            spatialFDNSpatialSendRMS,
            spatialFDNWetPeak,
            spatialFDNWetRMS,
            spatialFDNOpeningWetRMS,
            spatialFDNTerminalWetRMS,
            spatialFDNWetStereoCorrelation,
        ].allSatisfy(\.isFinite)
        let spatialFDNRenderEvidence = SpatialFDNRenderEvidence(
            bar: performance.bar,
            sampleRate: sampleRate,
            renderedFrameCount: frames,
            lineCount: FeedbackDelayNetworkConfiguration.lineCount,
            delayFrameCounts: spatialFDNConfiguration.delayFrameCounts,
            requestedRoomScale: requestedSpatialFDNConfiguration.roomScale,
            roomScale: spatialFDNConfiguration.roomScale,
            decayTimeSeconds: spatialFDNConfiguration.decayTimeSeconds,
            dampingHz: spatialFDNConfiguration.dampingHz,
            maximumFeedbackGain:
                spatialFDNConfiguration.maximumFeedbackGain,
            synthSendGain: spatialFDNConfiguration.synthSendGain,
            percussionSendGain:
                spatialFDNConfiguration.percussionSendGain,
            wetGain: spatialFDNConfiguration.wetGain,
            geometryRetained: resolvedSpatialFDN.geometryRetained,
            parameterTransitionFrameCount:
                spatialFDNParameterTransitionFrameCount,
            initialMaximumFeedbackGain:
                spatialFDNInitialMaximumFeedbackGain,
            finalMaximumFeedbackGain:
                state.spatialFDNState.appliedFeedbackGains.max() ?? 0,
            initialDampingCoefficient:
                spatialFDNInitialDampingCoefficient,
            finalDampingCoefficient:
                state.spatialFDNState.appliedDampingCoefficient,
            initialSynthSendGain: spatialFDNInitialSynthSendGain,
            finalSynthSendGain: state.spatialFDNState.appliedSynthSendGain,
            initialPercussionSendGain:
                spatialFDNInitialPercussionSendGain,
            finalPercussionSendGain:
                state.spatialFDNState.appliedPercussionSendGain,
            initialWetGain: spatialFDNInitialWetGain,
            finalWetGain: state.spatialFDNState.appliedWetGain,
            spatialDepthPosition: resolved.spatialContrast.depthPosition,
            carrierVoice: resolved.spatialContrast.carrierVoice,
            carrierStep: resolved.spatialContrast.carrierStep,
            scoreReverbSend: resolved.spatialContrast.reverbSend,
            scoreHighPassHz: resolved.spatialContrast.highPassHz,
            scoreLowPassHz: resolved.spatialContrast.lowPassHz,
            inputSampleHash: spatialFDNInputFingerprint.fingerprint,
            wetLeftSampleHash: spatialFDNWetLeftFingerprint.fingerprint,
            wetRightSampleHash: spatialFDNWetRightFingerprint.fingerprint,
            inputRMS: spatialFDNInputRMS,
            spatialSendRMS: spatialFDNSpatialSendRMS,
            wetPeak: spatialFDNWetPeak,
            wetRMS: spatialFDNWetRMS,
            wetStereoCorrelation: spatialFDNWetStereoCorrelation,
            activeInputFrameCount: spatialFDNActiveInputFrameCount,
            activeWetFrameCount: spatialFDNActiveWetFrameCount,
            firstWetFrameIndex: spatialFDNFirstWetFrameIndex,
            openingWindowFrameCount: spatialFDNTailWindowFrameCount,
            openingWetRMS: spatialFDNOpeningWetRMS,
            terminalWindowFrameCount: spatialFDNTailWindowFrameCount,
            terminalWetRMS: spatialFDNTerminalWetRMS,
            finite: spatialFDNFinite
        )
        let upperTimingEvents: [UpperTimingRenderEvent]
        if layer == .full, renderScheduledUpperNotes {
            var unmatchedNoteEvidence = upperNoteRenderEvidence
            upperTimingEvents = synthPerformance.upperNotes.map { note in
                let expectedStartFrame = upperNoteStartFrame(
                    note: note,
                    stepFrames: stepFrames,
                    frameCount: frames
                )
                let requestedStartFrequency = synthWorld.rootFrequency *
                    note.startFrequencyRatio
                let targetEndFrequency = synthWorld.rootFrequency *
                    note.endFrequencyRatio
                let evidenceIndex = unmatchedNoteEvidence.firstIndex { evidence in
                    evidence.role == note.role &&
                        evidence.requestedStartFrequency == requestedStartFrequency &&
                        evidence.requestedEndFrequency == targetEndFrequency &&
                        evidence.requestedGate == note.gate &&
                        evidence.timbreIntent == note.timbreIntent &&
                        evidence.requestedVelocity == note.velocity &&
                        evidence.instrument == note.instrument
                }
                let appliedEvidence = evidenceIndex.map {
                    unmatchedNoteEvidence.remove(at: $0)
                }
                return UpperTimingRenderEvent(
                    role: note.role,
                    baseOnsetStep: note.onsetStep,
                    requestedOffsetInSteps: note.timingOffsetInSteps,
                    expectedOnsetFrame: expectedStartFrame,
                    appliedOnsetFrame: appliedEvidence?.onsetFrame ?? -1,
                    requestedGateEndFrame:
                        appliedEvidence?.requestedGateEndFrame ?? -1,
                    appliedGateEndFrame:
                        appliedEvidence?.appliedGateEndFrame ?? -1
                )
            }
        } else {
            upperTimingEvents = []
        }
        let upperTimingRenderEvidence = UpperTimingRenderEvidence(
            bar: performance.bar,
            chapter: resolved.interlockChapter,
            relation: synthPerformance.upperTimingRelation,
            performanceCharacter: resolved.performanceCharacter,
            bpm: scene.bpm,
            sampleRate: sampleRate,
            renderedFrameCount: frames,
            events: upperTimingEvents,
            anchorSignal: UpperTimingRoleSignalEvidence.analyze(
                eventCount: upperTimingEvents.filter { $0.role == .anchor }.count,
                samples: resonantAnchorStem
            ),
            shadowSignal: UpperTimingRoleSignalEvidence.analyze(
                eventCount: upperTimingEvents.filter { $0.role == .shadow }.count,
                samples: shadowTimingStem
            ),
            responseSignal: UpperTimingRoleSignalEvidence.analyze(
                eventCount: upperTimingEvents.filter { $0.role == .response }.count,
                samples: responseTimingStem
            )
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
                                   foundationRhythmRenderEvidence:
                                    foundationRhythmRenderEvidence,
                                   dryPercussionSampleHash: ExactPCMFingerprint.mono(
                                    percussionStem
                                   ),
                                   dryModalPercussionSampleHash:
                                    dryModalPercussionSampleHash,
                                   modalPercussionRenderEvidence:
                                    modalPercussionRenderEvidence,
                                   modalPercussionFoundationRoutingValid:
                                    modalPercussionFoundationRoutingValid,
                                   groovePulseRenderEvidence: groovePulseRenderEvidence,
                                   closedHatRenderEvidence: closedHatRenderEvidence,
                                   upperPercussionTailRenderEvidence:
                                    upperPercussionTailRenderEvidence,
                                   sourceTerminalDeclickRenderEvidence:
                                    sourceTerminalDeclickRenderEvidence,
                                   instrumentRenderEvidence: instrumentEvidence(
                                    resolved: resolved,
                                    synthPerformance: synthPerformance,
                                    upperNoteRenderEvidence: upperNoteRenderEvidence,
                                    anchorSamples: resonantAnchorStem,
                                    resonantMono: resonantMonoInstrumentStem,
                                    resonantMonoModulation: resonantMonoModulationStem,
                                    resonantMonoNonlinearCore:
                                        resonantMonoNonlinearCoreEvidence,
                                    sampleRate: sampleRate,
                                    tonalMotion: tonalMotionInstrumentStem,
                                    tonalEnvelopeExpansion:
                                        tonalEnvelopeExpansionStem,
                                    spectralTexture: spectralTextureInstrumentStem,
                                    spectralTextureCluster: spectralTextureClusterStem,
                                    spectralTextureHarmonicTail:
                                        spectralTextureHarmonicTailStem,
                                    spectralTextureIndefinitePitch:
                                        spectralTextureIndefinitePitchStem
                                    ),
                                   percussionEchoTextureRenderEvidence:
                                    percussionEchoTextureRenderEvidence,
                                   audioSliceRenderEvidence:
                                    audioSliceRenderEvidence,
                                   polyphonicPadRenderEvidence:
                                    polyphonicPadRenderEvidence,
                                   pulseEchoReturnDriveRenderEvidence:
                                    pulseEchoReturnDriveRenderEvidence,
                                   spatialFDNRenderEvidence:
                                    spatialFDNRenderEvidence,
                                   upperNoteRenderEvidence: upperNoteRenderEvidence,
                                   upperTimingRenderEvidence: upperTimingRenderEvidence,
                                   audibleKickSamples: kickBus,
                                   upperPercussionSamples: percussionTextureStem,
                                   graphRemainderReferenceLeftSamples:
                                    graphRemainderReferenceLeftSamples,
                                   graphRemainderReferenceRightSamples:
                                    graphRemainderReferenceRightSamples,
                                   resonantAnchorSamples: resonantAnchorStem,
                                   detunedCompanionSamples: detunedCompanionStem)
        swap(&output, &checkedOut.output)
        swap(&kickBus, &checkedOut.kick)
        swap(&kickDetectorBus, &checkedOut.kickDetector)
        swap(&foundationStem, &checkedOut.foundationStem)
        swap(&modalPercussionStem, &checkedOut.modalPercussionStem)
        swap(&percussionStem, &checkedOut.percussionStem)
        swap(&percussionTextureStem, &checkedOut.percussionTextureStem)
        swap(&upperTonalStem, &checkedOut.upperTonalStem)
        swap(&atmosphereStem, &checkedOut.atmosphereStem)
        swap(&resonantAnchorStem, &checkedOut.resonantAnchorStem)
        swap(&detunedCompanionStem, &checkedOut.detunedCompanionStem)
        swap(&shadowTimingStem, &checkedOut.shadowTimingStem)
        swap(&responseTimingStem, &checkedOut.responseTimingStem)
        swap(&resonantMonoInstrumentStem, &checkedOut.resonantMonoInstrumentStem)
        swap(&resonantMonoModulationStem, &checkedOut.resonantMonoModulationStem)
        swap(&tonalMotionInstrumentStem, &checkedOut.tonalMotionInstrumentStem)
        swap(&tonalEnvelopeExpansionStem, &checkedOut.tonalEnvelopeExpansionStem)
        swap(&spectralTextureInstrumentStem, &checkedOut.spectralTextureInstrumentStem)
        swap(&spectralTextureClusterStem, &checkedOut.spectralTextureClusterStem)
        swap(
            &spectralTextureHarmonicTailStem,
            &checkedOut.spectralTextureHarmonicTailStem
        )
        swap(
            &spectralTextureIndefinitePitchStem,
            &checkedOut.spectralTextureIndefinitePitchStem
        )
        swap(&maskingFoundationBus, &checkedOut.maskingFoundation)
        swap(&synthBus, &checkedOut.synth)
        swap(&pulseEchoSendBus, &checkedOut.pulseEchoSend)
        swap(&spatialReverbSendBus, &checkedOut.spatialReverbSend)
        workspace.recycle(&checkedOut)
        return rendered
    }

    private static func renderInstrumentWorld(
        _ output: inout [Float],
        pulseEchoSend: inout [Float],
        spatialReverbSend: inout [Float],
        upperTonalStem: inout [Float],
        atmosphereStem: inout [Float],
        resonantAnchorStem: inout [Float],
        detunedCompanionStem: inout [Float],
        shadowTimingStem: inout [Float],
        responseTimingStem: inout [Float],
        resonantMonoInstrumentStem: inout [Float],
        resonantMonoModulationStem: inout [Float],
        tonalMotionInstrumentStem: inout [Float],
        tonalEnvelopeExpansionStem: inout [Float],
        spectralTextureInstrumentStem: inout [Float],
        spectralTextureClusterStem: inout [Float],
        spectralTextureHarmonicTailStem: inout [Float],
        spectralTextureIndefinitePitchStem: inout [Float],
        polyphonicPadStem: inout [Float],
        polyphonicPadRenderEvidence: inout PolyphonicPadRenderEvidence,
        noteRenderEvidence: inout [UpperNoteRenderEvidence],
        resonantMonoNonlinearCoreEvidence:
            inout TPTAntialiasedNonlinearCoreEvidenceAccumulator,
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
                    startFrame: upperNoteStartFrame(
                        note: note,
                        stepFrames: stepFrames,
                        frameCount: output.count
                    ),
                    durationFrames: upperNoteDurationFrames(
                        note: note,
                        stepFrames: stepFrames
                    ),
                    frequency: world.rootFrequency * note.startFrequencyRatio,
                    endFrequency: world.rootFrequency * note.endFrequencyRatio,
                    velocity: note.velocity,
                    gate: note.gate,
                    timbreIntent: note.timbreIntent,
                    envelopeRelation: note.envelopeRelation,
                    spectralReveal: note.spectralReveal,
                    instrument: note.instrument,
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
        ResonantMonoVoice.renderUpper(
            &output,
            measurement: &resonantAnchorStem,
            architectureMeasurement: &resonantMonoInstrumentStem,
            pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            modulationMeasurement: &resonantMonoModulationStem,
            noteRenderEvidence: &noteRenderEvidence,
            notes: anchorNotes,
            sampleRate: sampleRate,
            level: 0.090 + scene.synthPresence * 0.060,
            state: &state.resonantAnchorState,
            nonlinearCoreEvidence: &resonantMonoNonlinearCoreEvidence
        )
        AlienAnalogVoice.render(
            &output,
            measurement: &resonantAnchorStem,
            architectureMeasurement: &tonalMotionInstrumentStem,
            envelopeExpansionMeasurement: &tonalEnvelopeExpansionStem,
            pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            noteRenderEvidence: &noteRenderEvidence,
            notes: anchorNotes, sampleRate: sampleRate,
            level: 0.090 + scene.synthPresence * 0.060,
            world: world, bar: synthBar, role: .anchor,
            state: &state.alienAnchorState
        )

        let shadowNotes = notes(for: .shadow)
        ResonantMonoVoice.renderUpper(
            &output,
            measurement: &shadowTimingStem,
            architectureMeasurement: &resonantMonoInstrumentStem,
            pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            modulationMeasurement: &resonantMonoModulationStem,
            noteRenderEvidence: &noteRenderEvidence,
            notes: shadowNotes,
            sampleRate: sampleRate,
            level: 0.032 + scene.synthPresence * 0.034,
            state: &state.resonantShadowState,
            nonlinearCoreEvidence: &resonantMonoNonlinearCoreEvidence
        )
        AlienAnalogVoice.render(
            &output,
            measurement: &shadowTimingStem,
            architectureMeasurement: &tonalMotionInstrumentStem,
            envelopeExpansionMeasurement: &tonalEnvelopeExpansionStem,
            pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            noteRenderEvidence: &noteRenderEvidence,
            notes: shadowNotes, sampleRate: sampleRate,
            level: 0.032 + scene.synthPresence * 0.034,
            world: world, bar: synthBar, role: .shadow,
            state: &state.alienShadowState
        )

        let atmosphereNotes = notes(for: .atmosphere)
        polyphonicPadRenderEvidence = PolyphonicPadVoice.render(
            &output,
            measurement: &polyphonicPadStem,
            spatialReverbSend: &spatialReverbSend,
            voicing: renderScheduledNotes ? synthBar.composition.padVoicing : nil,
            rootFrequency: world.rootFrequency,
            sampleRate: sampleRate,
            stepFrames: stepFrames,
            level: 0.014 + scene.atmosphere * 0.022 + scene.drone * 0.014,
            state: &state.polyphonicPadState
        )
        if polyphonicPadRenderEvidence.active {
            for index in atmosphereStem.indices {
                atmosphereStem[index] += polyphonicPadStem[index]
            }
        }
        AlienAnalogVoice.render(
            &output,
            measurement: &atmosphereStem,
            architectureMeasurement: &tonalMotionInstrumentStem,
            envelopeExpansionMeasurement: &tonalEnvelopeExpansionStem,
            pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            noteRenderEvidence: &noteRenderEvidence,
            notes: atmosphereNotes, sampleRate: sampleRate,
            level: 0.017 + scene.atmosphere * 0.025 + scene.drone * 0.018,
            world: world, bar: synthBar, role: .atmosphere,
            state: &state.alienAtmosphereState
        )
        SpectralTextureVoice.render(
            &output,
            measurement: &atmosphereStem,
            architectureMeasurement: &spectralTextureInstrumentStem,
            indefinitePitchMeasurement: &spectralTextureIndefinitePitchStem,
            clusterMeasurement: &spectralTextureClusterStem,
            harmonicTailMeasurement: &spectralTextureHarmonicTailStem,
            pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            noteRenderEvidence: &noteRenderEvidence,
            notes: atmosphereNotes,
            sampleRate: sampleRate,
            level: 0.017 + scene.atmosphere * 0.025 + scene.drone * 0.018,
            state: &state.spectralAtmosphereState
        )

        let responseNotes = notes(for: .response)
        ResonantMonoVoice.renderUpper(
            &output,
            measurement: &responseTimingStem,
            architectureMeasurement: &resonantMonoInstrumentStem,
            pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            modulationMeasurement: &resonantMonoModulationStem,
            noteRenderEvidence: &noteRenderEvidence,
            notes: responseNotes,
            sampleRate: sampleRate,
            level: 0.026 + scene.melodicity * 0.030,
            state: &state.resonantResponseState,
            nonlinearCoreEvidence: &resonantMonoNonlinearCoreEvidence
        )
        AlienAnalogVoice.render(
            &output,
            measurement: &responseTimingStem,
            architectureMeasurement: &tonalMotionInstrumentStem,
            envelopeExpansionMeasurement: &tonalEnvelopeExpansionStem,
            pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            noteRenderEvidence: &noteRenderEvidence,
            notes: responseNotes, sampleRate: sampleRate,
            level: 0.026 + scene.melodicity * 0.030,
            world: world, bar: synthBar, role: .response,
            state: &state.alienResponseState
        )
        SpectralTextureVoice.render(
            &output,
            measurement: &responseTimingStem,
            architectureMeasurement: &spectralTextureInstrumentStem,
            indefinitePitchMeasurement: &spectralTextureIndefinitePitchStem,
            clusterMeasurement: &spectralTextureClusterStem,
            harmonicTailMeasurement: &spectralTextureHarmonicTailStem,
            pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            noteRenderEvidence: &noteRenderEvidence,
            notes: responseNotes,
            sampleRate: sampleRate,
            level: 0.026 + scene.melodicity * 0.030,
            state: &state.spectralResponseState
        )

        let transitionNotes = notes(for: .transition)
        AlienAnalogVoice.render(
            &output,
            measurement: &atmosphereStem,
            architectureMeasurement: &tonalMotionInstrumentStem,
            envelopeExpansionMeasurement: &tonalEnvelopeExpansionStem,
            pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            noteRenderEvidence: &noteRenderEvidence,
            notes: transitionNotes, sampleRate: sampleRate,
            level: 0.008 + scene.atmosphere * 0.012,
            world: world, bar: synthBar, role: .transition,
            state: &state.alienTransitionState
        )
        SpectralTextureVoice.render(
            &output,
            measurement: &atmosphereStem,
            architectureMeasurement: &spectralTextureInstrumentStem,
            indefinitePitchMeasurement: &spectralTextureIndefinitePitchStem,
            clusterMeasurement: &spectralTextureClusterStem,
            harmonicTailMeasurement: &spectralTextureHarmonicTailStem,
            pulseEchoSend: &pulseEchoSend,
            spatialReverbSend: &spatialReverbSend,
            noteRenderEvidence: &noteRenderEvidence,
            notes: transitionNotes,
            sampleRate: sampleRate,
            level: 0.008 + scene.atmosphere * 0.012,
            state: &state.spectralTransitionState
        )
        for frame in upperTonalStem.indices {
            detunedCompanionStem[frame] =
                shadowTimingStem[frame] + responseTimingStem[frame]
            upperTonalStem[frame] = resonantAnchorStem[frame] + detunedCompanionStem[frame]
        }
    }

    private static func instrumentEvidence(
        resolved: ResolvedPerformanceBar,
        synthPerformance: SynthPerformanceBar,
        upperNoteRenderEvidence: [UpperNoteRenderEvidence],
        anchorSamples: [Float],
        resonantMono: [Float],
        resonantMonoModulation: [Float],
        resonantMonoNonlinearCore:
            TPTAntialiasedNonlinearCoreEvidenceAccumulator,
        sampleRate: Double,
        tonalMotion: [Float],
        tonalEnvelopeExpansion: [Float],
        spectralTexture: [Float],
        spectralTextureCluster: [Float],
        spectralTextureHarmonicTail: [Float],
        spectralTextureIndefinitePitch: [Float]
    ) -> [InstrumentArchitectureRenderEvidence] {
        var assignments = upperNoteRenderEvidence.map(\.instrument)
        let audibleBassEvents = resolved.ensemble.events.filter { event in
            event.voice == .bass &&
                !(resolved.performance.signatureEvent == .delayedBassEntry && event.step < 8)
        }
        assignments.append(contentsOf: audibleBassEvents.map { _ in
            synthPerformance.foundationInstrument
        })
        let buffers: [(InstrumentArchitecture, [Float])] = [
            (.resonantMono, resonantMono),
            (.tonalMotion, tonalMotion),
            (.spectralTexture, spectralTexture),
        ]
        return buffers.compactMap { architecture, samples in
            let matching = assignments.filter { $0.architecture == architecture }
            guard !matching.isEmpty else { return nil }
            let peak = samples.reduce(Float.zero) { max($0, abs($1)) }
            let energy = samples.reduce(0.0) { $0 + Double($1 * $1) }
            let rms = Float(sqrt(energy / Double(max(1, samples.count))))
            var uniqueAssignments: [InstrumentAssignment] = []
            for assignment in matching where !uniqueAssignments.contains(assignment) {
                uniqueAssignments.append(assignment)
            }
            uniqueAssignments.sort {
                (InstrumentUse.allCases.firstIndex(of: $0.use) ?? 0) <
                    (InstrumentUse.allCases.firstIndex(of: $1.use) ?? 0)
            }
            let patchSet = Set(matching.map(\.patch))
            let useSet = Set(matching.map(\.use))
            let effectSet = Set(matching.flatMap(\.effects))
            let modulation = architecture == .resonantMono
                ? resonantMonoModulationEvidence(
                    noteEvidence: upperNoteRenderEvidence,
                    uniqueAssignments: uniqueAssignments,
                    samples: resonantMonoModulation,
                    sampleRate: sampleRate
                ) : nil
            let nonlinearCore = architecture == .resonantMono
                ? resonantMonoNonlinearCore.evidence(
                    sourceAssignmentCount: uniqueAssignments.count,
                    sourceEventCount: matching.count
                ) : nil
            let cluster = architecture == .spectralTexture
                ? spectralTextureClusterEvidence(
                    noteEvidence: upperNoteRenderEvidence,
                    uniqueAssignments: uniqueAssignments,
                    samples: spectralTextureCluster
                ) : nil
            let harmonicTail = architecture == .spectralTexture
                ? spectralTextureHarmonicTailEvidence(
                    noteEvidence: upperNoteRenderEvidence,
                    uniqueAssignments: uniqueAssignments,
                    samples: spectralTextureHarmonicTail,
                    sampleRate: sampleRate
                ) : nil
            let indefinitePitch = architecture == .spectralTexture
                ? indefinitePitchEvidence(
                    noteEvidence: upperNoteRenderEvidence,
                    uniqueAssignments: uniqueAssignments,
                    samples: spectralTextureIndefinitePitch,
                    sampleRate: sampleRate
                ) : nil
            let envelopeExpansion = architecture == .tonalMotion
                ? tonalEnvelopeExpansionEvidence(
                    synthPerformance: synthPerformance,
                    noteEvidence: upperNoteRenderEvidence,
                    samples: tonalEnvelopeExpansion,
                    sampleRate: sampleRate
                ) : nil
            let spectralReveal = upperSpectralRevealEvidence(
                architecture: architecture,
                synthPerformance: synthPerformance,
                noteEvidence: upperNoteRenderEvidence,
                anchorSamples: anchorSamples
            )
            return InstrumentArchitectureRenderEvidence(
                architecture: architecture,
                assignments: uniqueAssignments,
                patches: InstrumentPatch.allCases.filter(patchSet.contains),
                uses: InstrumentUse.allCases.filter(useSet.contains),
                effects: InstrumentEffect.allCases.filter(effectSet.contains),
                eventCount: matching.count,
                sampleHash: ExactPCMFingerprint.mono(samples),
                peak: peak,
                rms: rms,
                finite: samples.allSatisfy(\.isFinite) && peak.isFinite && rms.isFinite,
                nonlinearCore: nonlinearCore,
                resonantMonoModulation: modulation,
                spectralTextureCluster: cluster,
                spectralTextureHarmonicTail: harmonicTail,
                indefinitePitch: indefinitePitch,
                tonalEnvelopeExpansion: envelopeExpansion,
                upperSpectralReveal: spectralReveal
            )
        }
    }

    private struct UpperSpectralRevealScoreFact {
        let role: SynthRole
        let onsetStep: Int
        let patch: InstrumentPatch
        let relation: UpperSpectralRevealRelation
        let aperture: Double
    }

    private struct UpperSpectralRevealRenderFact {
        let role: SynthRole
        let onsetFrame: Int
        let patch: InstrumentPatch
        let relation: UpperSpectralRevealRelation
        let aperture: Double
        let minimumAppliedCutoffHz: Double
        let maximumAppliedCutoffHz: Double
    }

    @inline(never)
    private static func upperSpectralRevealEvidence(
        architecture: InstrumentArchitecture,
        synthPerformance: SynthPerformanceBar,
        noteEvidence: [UpperNoteRenderEvidence],
        anchorSamples: [Float]
    ) -> UpperSpectralRevealRenderEvidence? {
        guard architecture == .resonantMono || architecture == .tonalMotion else {
            return nil
        }
        let scoreEvents = synthPerformance.upperNotes.filter {
            $0.role == .anchor && $0.instrument.architecture == architecture
        }
        guard !scoreEvents.isEmpty else { return nil }
        let renderEvents = noteEvidence.filter {
            $0.role == .anchor && $0.instrument.architecture == architecture
        }
        var unmatchedRenderEvents = renderEvents
        var bindingValid = scoreEvents.count == renderEvents.count
        for score in scoreEvents {
            let index = unmatchedRenderEvents.firstIndex { rendered in
                rendered.role == score.role &&
                    rendered.requestedGate == score.gate &&
                    rendered.timbreIntent == score.timbreIntent &&
                    rendered.spectralReveal == score.spectralReveal &&
                    rendered.requestedVelocity == score.velocity &&
                    rendered.instrument == score.instrument
            }
            guard let index else {
                bindingValid = false
                continue
            }
            unmatchedRenderEvents.remove(at: index)
        }
        bindingValid = bindingValid && unmatchedRenderEvents.isEmpty

        let scoreFacts = scoreEvents.map {
            UpperSpectralRevealScoreFact(
                role: $0.role,
                onsetStep: $0.onsetStep,
                patch: $0.instrument.patch,
                relation: $0.spectralReveal.relation,
                aperture: $0.spectralReveal.aperture
            )
        }.sorted {
            if $0.onsetStep != $1.onsetStep {
                return $0.onsetStep < $1.onsetStep
            }
            return $0.patch.rawValue < $1.patch.rawValue
        }
        let renderFacts = renderEvents.map {
            UpperSpectralRevealRenderFact(
                role: $0.role,
                onsetFrame: $0.onsetFrame,
                patch: $0.instrument.patch,
                relation: $0.spectralReveal.relation,
                aperture: $0.spectralReveal.aperture,
                minimumAppliedCutoffHz: $0.minimumAppliedCutoffHz,
                maximumAppliedCutoffHz: $0.maximumAppliedCutoffHz
            )
        }.sorted {
            if $0.onsetFrame != $1.onsetFrame {
                return $0.onsetFrame < $1.onsetFrame
            }
            return $0.patch.rawValue < $1.patch.rawValue
        }
        var scoreSink = StreamingFNV1a()
        scoreSink.domain("upper-spectral-reveal.score.v1")
        scoreSink.collection(scoreFacts.count)
        for fact in scoreFacts {
            scoreSink.raw(fact.role.rawValue)
            scoreSink.int(fact.onsetStep)
            scoreSink.raw(fact.patch.rawValue)
            scoreSink.raw(fact.relation.rawValue)
            scoreSink.double(fact.aperture)
        }
        var renderSink = StreamingFNV1a()
        renderSink.domain("upper-spectral-reveal.render.v1")
        renderSink.collection(renderFacts.count)
        for fact in renderFacts {
            renderSink.raw(fact.role.rawValue)
            renderSink.int(fact.onsetFrame)
            renderSink.raw(fact.patch.rawValue)
            renderSink.raw(fact.relation.rawValue)
            renderSink.double(fact.aperture)
            renderSink.double(fact.minimumAppliedCutoffHz)
            renderSink.double(fact.maximumAppliedCutoffHz)
        }
        let activeFacts = renderFacts.filter {
            $0.relation == .emerging
        }
        let measuredFacts = activeFacts.isEmpty ? renderFacts : activeFacts
        let activeApertures = activeFacts.map(\.aperture)
        let minimumCutoffs = measuredFacts.map(\.minimumAppliedCutoffHz)
        let maximumCutoffs = measuredFacts.map(\.maximumAppliedCutoffHz)
        bindingValid = bindingValid && renderFacts.allSatisfy {
            $0.minimumAppliedCutoffHz > 0 &&
                $0.maximumAppliedCutoffHz >= $0.minimumAppliedCutoffHz
        }
        let peak = anchorSamples.reduce(0.0) {
            max($0, abs(Double($1)))
        }
        let energy = anchorSamples.reduce(0.0) {
            $0 + Double($1) * Double($1)
        }
        let rms = sqrt(energy / Double(max(1, anchorSamples.count)))
        let active = !activeFacts.isEmpty
        let scalars = activeApertures + minimumCutoffs + maximumCutoffs + [peak, rms]
        return UpperSpectralRevealRenderEvidence(
            eligible: synthPerformance.spectralRevealEligible,
            active: active,
            sourceScoreEventCount: scoreFacts.count,
            renderedEventCount: renderFacts.count,
            activeEventCount: activeFacts.count,
            minimumActiveAperture: activeApertures.min() ?? 1,
            maximumActiveAperture: activeApertures.max() ?? 1,
            minimumAppliedCutoffHz: minimumCutoffs.min() ?? 0,
            maximumAppliedCutoffHz: maximumCutoffs.max() ?? 0,
            scoreFingerprint: fixedWidthFingerprintHex(scoreSink.value),
            renderFingerprint: fixedWidthFingerprintHex(renderSink.value),
            anchorSampleHash: ExactPCMFingerprint.mono(anchorSamples),
            anchorPeak: peak,
            anchorRMS: rms,
            bindingValid: bindingValid,
            finite: anchorSamples.allSatisfy(\.isFinite) &&
                scalars.allSatisfy(\.isFinite)
        )
    }

    private struct SpectralTextureClusterFact {
        let role: SynthRole
        let onsetFrame: Int
        let patch: InstrumentPatch
        let relation: SpectralTextureClusterRelation
        let componentRatios: [Double]
        let startFrequency: Double
        let appliedEndFrequency: Double
        let renderedFrameCount: Int
    }

    private struct SpectralTextureHarmonicTailFact {
        let role: SynthRole
        let onsetFrame: Int
        let patch: InstrumentPatch
        let relation: SpectralTextureHarmonicTailRelation
        let minimumFoldedSourceFrequency: Double
        let maximumFoldedSourceFrequency: Double
        let minimumBandCenterHz: Double
        let maximumBandCenterHz: Double
        let resonance: Double
        let prefilterDrive: Double
        let lfoRateHz: Double
        let renderedFrameCount: Int
    }

    private struct TonalEnvelopeExpansionFact {
        let role: SynthRole
        let onsetFrame: Int
        let patch: InstrumentPatch
        let relation: UpperEnvelopeRelation
        let baseSustain: Double
        let baseReleaseSeconds: Double
        let appliedSustain: Double
        let appliedReleaseSeconds: Double
    }

    @inline(never)
    private static func tonalEnvelopeExpansionEvidence(
        synthPerformance: SynthPerformanceBar,
        noteEvidence: [UpperNoteRenderEvidence],
        samples: [Float],
        sampleRate: Double
    ) -> TonalEnvelopeExpansionRenderEvidence? {
        let eligible = synthPerformance.tonalEnvelopeExpansionEligible
        let scoreEvents = synthPerformance.upperNotes.filter {
            $0.instrument.architecture == .tonalMotion &&
                $0.envelopeRelation == .sustainedWash
        }
        let events = noteEvidence.filter {
            $0.instrument.architecture == .tonalMotion &&
                $0.envelopeRelation == .sustainedWash
        }
        guard eligible || !events.isEmpty else { return nil }

        var facts: [TonalEnvelopeExpansionFact] = []
        facts.reserveCapacity(events.count)
        var bindingValid = scoreEvents.count <= 1 &&
            events.count == scoreEvents.count
        for evidence in noteEvidence where
            evidence.instrument.architecture == .tonalMotion {
            if evidence.envelopeRelation == .sustainedWash {
                let expected = TonalEnvelopeExpansionContract.resolve(
                    baseSustain: evidence.baseEnvelopeSustain,
                    baseReleaseSeconds: evidence.baseEnvelopeReleaseSeconds,
                    relation: evidence.envelopeRelation
                )
                bindingValid = bindingValid &&
                    evidence.role == .anchor &&
                    evidence.appliedGate == .retrigger &&
                    evidence.appliedEnvelopeSustain == expected.sustain &&
                    evidence.appliedEnvelopeReleaseSeconds ==
                        expected.releaseSeconds
                facts.append(TonalEnvelopeExpansionFact(
                    role: evidence.role,
                    onsetFrame: evidence.onsetFrame,
                    patch: evidence.instrument.patch,
                    relation: evidence.envelopeRelation,
                    baseSustain: evidence.baseEnvelopeSustain,
                    baseReleaseSeconds: evidence.baseEnvelopeReleaseSeconds,
                    appliedSustain: evidence.appliedEnvelopeSustain,
                    appliedReleaseSeconds:
                        evidence.appliedEnvelopeReleaseSeconds
                ))
            }
        }
        facts.sort { lhs, rhs in
            if lhs.onsetFrame != rhs.onsetFrame {
                return lhs.onsetFrame < rhs.onsetFrame
            }
            return lhs.patch.rawValue < rhs.patch.rawValue
        }
        let stepFrames = Double(samples.count) / 16
        let sortedScoreEvents = scoreEvents.sorted {
            if $0.onsetStep != $1.onsetStep { return $0.onsetStep < $1.onsetStep }
            return $0.instrument.patch.rawValue < $1.instrument.patch.rawValue
        }
        bindingValid = bindingValid && zip(sortedScoreEvents, facts).allSatisfy {
            score, rendered in
            rendered.role == score.role &&
                rendered.onsetFrame == upperNoteStartFrame(
                    note: score,
                    stepFrames: stepFrames,
                    frameCount: samples.count
                ) &&
                rendered.patch == score.instrument.patch &&
                rendered.relation == score.envelopeRelation
        }
        var sink = StreamingFNV1a()
        sink.domain("tonal-envelope-expansion-events.typed.v1")
        sink.collection(facts.count)
        for fact in facts {
            sink.aggregate("TonalEnvelopeExpansionFact")
            sink.field("role"); sink.raw(fact.role.rawValue)
            sink.field("onsetFrame"); sink.int(fact.onsetFrame)
            sink.field("patch"); sink.raw(fact.patch.rawValue)
            sink.field("relation"); sink.raw(fact.relation.rawValue)
            sink.field("baseSustain"); sink.double(fact.baseSustain)
            sink.field("baseReleaseSeconds")
            sink.double(fact.baseReleaseSeconds)
            sink.field("appliedSustain"); sink.double(fact.appliedSustain)
            sink.field("appliedReleaseSeconds")
            sink.double(fact.appliedReleaseSeconds)
        }
        var peak = 0.0
        var energy = 0.0
        var nonzero = 0
        var finite = sampleRate.isFinite && sampleRate > 0
        for sample in samples {
            let value = Double(sample)
            peak = max(peak, abs(value))
            energy += value * value
            if sample.bitPattern & 0x7fff_ffff != 0 { nonzero += 1 }
            finite = finite && sample.isFinite && peak.isFinite && energy.isFinite
        }
        let rms = sqrt(energy / Double(max(1, samples.count)))
        let attackFrames = min(samples.count, max(1, Int((sampleRate * 0.024).rounded())))
        let tailFrames = min(samples.count, max(1, Int((sampleRate * 0.240).rounded())))
        func windowRMS(_ range: Range<Int>) -> Double {
            guard !range.isEmpty else { return 0 }
            let windowEnergy = range.reduce(0.0) { partial, index in
                let value = Double(samples[index])
                return partial + value * value
            }
            return sqrt(windowEnergy / Double(range.count))
        }
        let attackStart = min(samples.count, max(0, facts.first?.onsetFrame ?? 0))
        let attackEnd = min(samples.count, attackStart + attackFrames)
        let attackRMS = windowRMS(attackStart..<attackEnd)
        let tailRMS = windowRMS((samples.count - tailFrames)..<samples.count)
        let tailToAttackDB = attackRMS > 0
            ? 20 * log10(max(1e-12, tailRMS) / attackRMS) : 0
        finite = finite && rms.isFinite && attackRMS.isFinite &&
            tailRMS.isFinite && tailToAttackDB.isFinite
        bindingValid = bindingValid && facts.count == scoreEvents.count &&
            (!eligible || scoreEvents.count <= 1)
        return TonalEnvelopeExpansionRenderEvidence(
            eligible: eligible,
            active: !facts.isEmpty,
            eventCount: facts.count,
            relation: facts.first?.relation ?? .home,
            baseSustain: facts.first?.baseSustain ?? 0,
            baseReleaseSeconds: facts.first?.baseReleaseSeconds ?? 0,
            appliedSustain: facts.first?.appliedSustain ?? 0,
            appliedReleaseSeconds:
                facts.first?.appliedReleaseSeconds ?? 0,
            eventFingerprint: fixedWidthFingerprintHex(sink.value),
            sampleHash: ExactPCMFingerprint.mono(samples),
            peak: peak,
            rms: rms,
            attackRMS: attackRMS,
            tailRMS: tailRMS,
            tailToAttackDB: tailToAttackDB,
            nonzeroSampleCount: nonzero,
            bindingValid: bindingValid,
            finite: finite
        )
    }

    private struct IndefinitePitchFact {
        let role: SynthRole
        let onsetFrame: Int
        let gateEndFrame: Int
        let patch: InstrumentPatch
        let requestedStartFrequency: Double
        let requestedEndFrequency: Double
    }

    @inline(never)
    private static func indefinitePitchEvidence(
        noteEvidence: [UpperNoteRenderEvidence],
        uniqueAssignments: [InstrumentAssignment],
        samples: [Float],
        sampleRate: Double
    ) -> IndefinitePitchRenderEvidence? {
        let assignments = uniqueAssignments.filter {
            $0.musicalPitchIdentity == .indefinitePitch
        }
        let events = noteEvidence.filter {
            $0.instrument.musicalPitchIdentity == .indefinitePitch
        }
        guard !assignments.isEmpty || !events.isEmpty else { return nil }

        var facts: [IndefinitePitchFact] = []
        facts.reserveCapacity(events.count)
        var frequencyInfluenceDisabled = true
        var bindingValid = !assignments.isEmpty && !events.isEmpty
        for evidence in noteEvidence where
            evidence.instrument.architecture == .spectralTexture {
            if evidence.instrument.musicalPitchIdentity == .indefinitePitch {
                frequencyInfluenceDisabled = frequencyInfluenceDisabled &&
                    evidence.appliedStartFrequency == 0 &&
                    evidence.targetEndFrequency == 0 &&
                    evidence.frequencyAtAppliedGateEnd == 0
                bindingValid = bindingValid &&
                    evidence.spectralTextureCluster == nil &&
                    evidence.spectralTextureHarmonicTail == nil
                facts.append(IndefinitePitchFact(
                    role: evidence.role,
                    onsetFrame: evidence.onsetFrame,
                    gateEndFrame: evidence.appliedGateEndFrame,
                    patch: evidence.instrument.patch,
                    requestedStartFrequency:
                        evidence.requestedStartFrequency,
                    requestedEndFrequency: evidence.requestedEndFrequency
                ))
            } else {
                bindingValid = bindingValid &&
                    evidence.appliedStartFrequency > 0 &&
                    evidence.targetEndFrequency > 0 &&
                    evidence.frequencyAtAppliedGateEnd > 0
            }
        }
        facts.sort { lhs, rhs in
            if lhs.onsetFrame != rhs.onsetFrame {
                return lhs.onsetFrame < rhs.onsetFrame
            }
            if lhs.role != rhs.role {
                return (SynthRole.allCases.firstIndex(of: lhs.role) ?? 0) <
                    (SynthRole.allCases.firstIndex(of: rhs.role) ?? 0)
            }
            return (InstrumentPatch.allCases.firstIndex(of: lhs.patch) ?? 0) <
                (InstrumentPatch.allCases.firstIndex(of: rhs.patch) ?? 0)
        }
        var sink = StreamingFNV1a()
        sink.domain("indefinite-pitch-events.typed.v1")
        sink.collection(facts.count)
        for fact in facts {
            sink.aggregate("IndefinitePitchFact")
            sink.field("role"); sink.raw(fact.role.rawValue)
            sink.field("onsetFrame"); sink.int(fact.onsetFrame)
            sink.field("gateEndFrame"); sink.int(fact.gateEndFrame)
            sink.field("patch"); sink.raw(fact.patch.rawValue)
            sink.field("requestedStartFrequency")
            sink.double(fact.requestedStartFrequency)
            sink.field("requestedEndFrequency")
            sink.double(fact.requestedEndFrequency)
        }
        var peak = 0.0
        var energy = 0.0
        var finite = sampleRate.isFinite && sampleRate > 0
        for sample in samples {
            let value = Double(sample)
            peak = max(peak, abs(value))
            energy += value * value
            finite = finite && sample.isFinite && peak.isFinite && energy.isFinite
        }
        let rms = sqrt(energy / Double(max(1, samples.count)))
        let crest = rms > 0 ? peak / rms : 0
        let periodicity = IndefinitePitchContract.normalizedPeriodicity(
            samples: samples,
            sampleRate: sampleRate
        )
        bindingValid = bindingValid && facts.count == events.count
        finite = finite && rms.isFinite && crest.isFinite &&
            periodicity.maximum.isFinite
        return IndefinitePitchRenderEvidence(
            evidenceVersion: IndefinitePitchContract.evidenceVersion,
            sourceAssignmentCount: assignments.count,
            eventCount: facts.count,
            noteFrequencyInfluenceDisabled: frequencyInfluenceDisabled,
            eventFingerprint: fixedWidthFingerprintHex(sink.value),
            sampleHash: ExactPCMFingerprint.mono(samples),
            peak: peak,
            rms: rms,
            crestFactor: crest,
            maximumNormalizedPeriodicity: periodicity.maximum,
            analyzedSampleCount: periodicity.analyzedSampleCount,
            bindingValid: bindingValid,
            finite: finite
        )
    }

    @inline(never)
    private static func spectralTextureClusterEvidence(
        noteEvidence: [UpperNoteRenderEvidence],
        uniqueAssignments: [InstrumentAssignment],
        samples: [Float]
    ) -> SpectralTextureClusterRenderEvidence? {
        let clusterAssignments = uniqueAssignments.filter {
            $0.spectralTextureClusterRelation != nil
        }
        let clusterEvents = noteEvidence.filter {
            $0.instrument.spectralTextureClusterRelation != nil
        }
        guard !clusterAssignments.isEmpty || !clusterEvents.isEmpty else {
            return nil
        }

        var facts: [SpectralTextureClusterFact] = []
        facts.reserveCapacity(clusterEvents.count)
        var bindingValid = !clusterAssignments.isEmpty && !clusterEvents.isEmpty
        for evidence in noteEvidence where
            evidence.instrument.architecture == .spectralTexture {
            let expected = SpectralTextureClusterContract.treatment(
                for: evidence.instrument
            )
            if let expected {
                guard let actual = evidence.spectralTextureCluster else {
                    bindingValid = false
                    continue
                }
                let renderedFrames = evidence.appliedGateEndFrame - evidence.onsetFrame
                bindingValid = bindingValid &&
                    evidence.role == .transition &&
                    evidence.targetEndFrequency > evidence.appliedStartFrequency &&
                    evidence.frequencyAtAppliedGateEnd >
                        evidence.appliedStartFrequency &&
                    actual.relation == expected.relation &&
                    actual.componentRatios == expected.componentRatios &&
                    actual.renderedFrameCount == renderedFrames
                facts.append(SpectralTextureClusterFact(
                    role: evidence.role,
                    onsetFrame: evidence.onsetFrame,
                    patch: evidence.instrument.patch,
                    relation: actual.relation,
                    componentRatios: actual.componentRatios,
                    startFrequency: evidence.appliedStartFrequency,
                    appliedEndFrequency: evidence.frequencyAtAppliedGateEnd,
                    renderedFrameCount: actual.renderedFrameCount
                ))
            } else if evidence.spectralTextureCluster != nil {
                bindingValid = false
            }
        }
        facts.sort { lhs, rhs in
            if lhs.onsetFrame != rhs.onsetFrame {
                return lhs.onsetFrame < rhs.onsetFrame
            }
            return lhs.patch.rawValue < rhs.patch.rawValue
        }
        var sink = StreamingFNV1a()
        sink.domain("spectral-texture-cluster-events.typed.v1")
        sink.collection(facts.count)
        for fact in facts {
            sink.aggregate("SpectralTextureClusterFact")
            sink.field("role"); sink.raw(fact.role.rawValue)
            sink.field("onsetFrame"); sink.int(fact.onsetFrame)
            sink.field("patch"); sink.raw(fact.patch.rawValue)
            sink.field("relation"); sink.raw(fact.relation.rawValue)
            sink.field("componentRatios"); sink.collection(fact.componentRatios.count)
            for ratio in fact.componentRatios { sink.double(ratio) }
            sink.field("startFrequency"); sink.double(fact.startFrequency)
            sink.field("appliedEndFrequency"); sink.double(fact.appliedEndFrequency)
            sink.field("renderedFrameCount"); sink.int(fact.renderedFrameCount)
        }
        var peak = 0.0
        var energy = 0.0
        var finite = true
        for sample in samples {
            let value = Double(sample)
            peak = max(peak, abs(value))
            energy += value * value
            finite = finite && sample.isFinite && peak.isFinite && energy.isFinite
        }
        let rms = sqrt(energy / Double(max(1, samples.count)))
        let crest = rms > 0 ? peak / rms : 0
        finite = finite && rms.isFinite && crest.isFinite
        bindingValid = bindingValid && facts.count == clusterEvents.count
        return SpectralTextureClusterRenderEvidence(
            sourceAssignmentCount: clusterAssignments.count,
            eventCount: facts.count,
            relation: .risingAdjacentCluster,
            adjacentRatio: SpectralTextureClusterContract.adjacentSemitoneRatio,
            maximumComponentRatio:
                SpectralTextureClusterContract.maximumComponentRatio,
            minimumStartFrequency: facts.map(\.startFrequency).min() ?? 0,
            maximumAppliedEndFrequency:
                facts.map(\.appliedEndFrequency).max() ?? 0,
            eventFingerprint: fixedWidthFingerprintHex(sink.value),
            clusterSampleHash: ExactPCMFingerprint.mono(samples),
            clusterPeak: peak,
            clusterRMS: rms,
            clusterCrestFactor: crest,
            bindingValid: bindingValid,
            finite: finite
        )
    }

    @inline(never)
    private static func spectralTextureHarmonicTailEvidence(
        noteEvidence: [UpperNoteRenderEvidence],
        uniqueAssignments: [InstrumentAssignment],
        samples: [Float],
        sampleRate: Double
    ) -> SpectralTextureHarmonicTailRenderEvidence? {
        let assignments = uniqueAssignments.filter {
            $0.spectralTextureHarmonicTailRelation != nil
        }
        let events = noteEvidence.filter {
            $0.instrument.spectralTextureHarmonicTailRelation != nil
        }
        guard !assignments.isEmpty || !events.isEmpty else { return nil }

        var facts: [SpectralTextureHarmonicTailFact] = []
        facts.reserveCapacity(events.count)
        var bindingValid = !assignments.isEmpty && !events.isEmpty
        for evidence in noteEvidence where
            evidence.instrument.architecture == .spectralTexture {
            let expected = SpectralTextureHarmonicTailContract.treatment(
                for: evidence.instrument,
                startFrequency: evidence.appliedStartFrequency,
                endFrequency: evidence.targetEndFrequency,
                sampleRate: sampleRate
            )
            if let expected {
                guard let actual = evidence.spectralTextureHarmonicTail else {
                    bindingValid = false
                    continue
                }
                let renderedFrames =
                    evidence.appliedGateEndFrame - evidence.onsetFrame
                bindingValid = bindingValid &&
                    evidence.role == .response &&
                    actual.relation == expected.relation &&
                    actual.minimumFoldedSourceFrequency >=
                        min(
                            expected.startFoldedSourceFrequency,
                            expected.endFoldedSourceFrequency
                        ) &&
                    actual.maximumFoldedSourceFrequency <=
                        max(
                            expected.startFoldedSourceFrequency,
                            expected.endFoldedSourceFrequency
                        ) &&
                    actual.minimumBandCenterHz >=
                        SpectralTextureHarmonicTailContract.minimumBandCenterHz(
                            sampleRate: sampleRate
                        ) &&
                    actual.maximumBandCenterHz <=
                        SpectralTextureHarmonicTailContract.maximumBandCenterHz(
                            sampleRate: sampleRate
                        ) &&
                    actual.maximumBandCenterHz > actual.minimumBandCenterHz &&
                    actual.resonance == expected.resonance &&
                    actual.prefilterDrive == expected.prefilterDrive &&
                    actual.lfoRateHz == expected.lfoRateHz &&
                    actual.renderedFrameCount == renderedFrames
                facts.append(SpectralTextureHarmonicTailFact(
                    role: evidence.role,
                    onsetFrame: evidence.onsetFrame,
                    patch: evidence.instrument.patch,
                    relation: actual.relation,
                    minimumFoldedSourceFrequency:
                        actual.minimumFoldedSourceFrequency,
                    maximumFoldedSourceFrequency:
                        actual.maximumFoldedSourceFrequency,
                    minimumBandCenterHz: actual.minimumBandCenterHz,
                    maximumBandCenterHz: actual.maximumBandCenterHz,
                    resonance: actual.resonance,
                    prefilterDrive: actual.prefilterDrive,
                    lfoRateHz: actual.lfoRateHz,
                    renderedFrameCount: actual.renderedFrameCount
                ))
            } else if evidence.spectralTextureHarmonicTail != nil {
                bindingValid = false
            }
        }
        facts.sort { lhs, rhs in
            if lhs.onsetFrame != rhs.onsetFrame {
                return lhs.onsetFrame < rhs.onsetFrame
            }
            return lhs.patch.rawValue < rhs.patch.rawValue
        }

        var sink = StreamingFNV1a()
        sink.domain("spectral-texture-harmonic-tail-events.typed.v1")
        sink.collection(facts.count)
        for fact in facts {
            sink.aggregate("SpectralTextureHarmonicTailFact")
            sink.field("role"); sink.raw(fact.role.rawValue)
            sink.field("onsetFrame"); sink.int(fact.onsetFrame)
            sink.field("patch"); sink.raw(fact.patch.rawValue)
            sink.field("relation"); sink.raw(fact.relation.rawValue)
            sink.field("minimumFoldedSourceFrequency")
            sink.double(fact.minimumFoldedSourceFrequency)
            sink.field("maximumFoldedSourceFrequency")
            sink.double(fact.maximumFoldedSourceFrequency)
            sink.field("minimumBandCenterHz")
            sink.double(fact.minimumBandCenterHz)
            sink.field("maximumBandCenterHz")
            sink.double(fact.maximumBandCenterHz)
            sink.field("resonance"); sink.double(fact.resonance)
            sink.field("prefilterDrive"); sink.double(fact.prefilterDrive)
            sink.field("lfoRateHz"); sink.double(fact.lfoRateHz)
            sink.field("renderedFrameCount"); sink.int(fact.renderedFrameCount)
        }

        let lowCutoff = min(500, sampleRate * 0.04)
        let upperCutoff = min(5_000, sampleRate * 0.20)
        let lowCoefficient = min(
            1,
            1 - exp(-2 * .pi * lowCutoff / sampleRate)
        )
        let upperCoefficient = min(
            1,
            1 - exp(-2 * .pi * upperCutoff / sampleRate)
        )
        var lowState = 0.0
        var upperState = 0.0
        var lowEnergy = 0.0
        var middleEnergy = 0.0
        var upperEnergy = 0.0
        var peak = 0.0
        var totalEnergy = 0.0
        var finite = true
        for sample in samples {
            let value = Double(sample)
            lowState += (value - lowState) * lowCoefficient
            upperState += (value - upperState) * upperCoefficient
            let middle = upperState - lowState
            let upper = value - upperState
            lowEnergy += lowState * lowState
            middleEnergy += middle * middle
            upperEnergy += upper * upper
            peak = max(peak, abs(value))
            totalEnergy += value * value
            finite = finite && sample.isFinite && lowState.isFinite &&
                upperState.isFinite && lowEnergy.isFinite &&
                middleEnergy.isFinite && upperEnergy.isFinite &&
                peak.isFinite && totalEnergy.isFinite
        }
        let bandEnergy = lowEnergy + middleEnergy + upperEnergy
        let lowRatio = bandEnergy > 0 ? lowEnergy / bandEnergy : 0
        let upperRatio = bandEnergy > 0 ? upperEnergy / bandEnergy : 0
        let rms = sqrt(totalEnergy / Double(max(1, samples.count)))
        let crest = rms > 0 ? peak / rms : 0
        finite = finite && lowRatio.isFinite && upperRatio.isFinite &&
            rms.isFinite && crest.isFinite
        bindingValid = bindingValid && facts.count == events.count
        return SpectralTextureHarmonicTailRenderEvidence(
            sourceAssignmentCount: assignments.count,
            eventCount: facts.count,
            relation: .drivenUpperBand,
            minimumFoldedSourceFrequency:
                facts.map(\.minimumFoldedSourceFrequency).min() ?? 0,
            maximumFoldedSourceFrequency:
                facts.map(\.maximumFoldedSourceFrequency).max() ?? 0,
            minimumBandCenterHz:
                facts.map(\.minimumBandCenterHz).min() ?? 0,
            maximumBandCenterHz:
                facts.map(\.maximumBandCenterHz).max() ?? 0,
            minimumResonance: facts.map(\.resonance).min() ?? 0,
            maximumResonance: facts.map(\.resonance).max() ?? 0,
            minimumPrefilterDrive: facts.map(\.prefilterDrive).min() ?? 0,
            maximumPrefilterDrive: facts.map(\.prefilterDrive).max() ?? 0,
            minimumLFORateHz: facts.map(\.lfoRateHz).min() ?? 0,
            maximumLFORateHz: facts.map(\.lfoRateHz).max() ?? 0,
            lowBandEnergyRatio: lowRatio,
            upperBandEnergyRatio: upperRatio,
            eventFingerprint: fixedWidthFingerprintHex(sink.value),
            sampleHash: ExactPCMFingerprint.mono(samples),
            peak: peak,
            rms: rms,
            crestFactor: crest,
            bindingValid: bindingValid,
            finite: finite
        )
    }

    private struct ResonantMonoModulationFact {
        let role: SynthRole
        let onsetFrame: Int
        let patch: InstrumentPatch
        let relation: ResonantMonoSpectralRelation
        let modulatorRatio: Double
        let requestedPeakIndex: Double
        let appliedPeakIndex: Double
        let renderedFrameCount: Int
    }

    @inline(never)
    private static func resonantMonoModulationEvidence(
        noteEvidence: [UpperNoteRenderEvidence],
        uniqueAssignments: [InstrumentAssignment],
        samples: [Float],
        sampleRate: Double
    ) -> ResonantMonoModulationRenderEvidence? {
        let acidAssignments = uniqueAssignments.filter {
            $0.resonantMonoSpectralRelation != nil
        }
        let acidEvents = noteEvidence.filter {
            $0.instrument.architecture == .resonantMono &&
                $0.instrument.resonantMonoSpectralRelation != nil
        }
        guard !acidAssignments.isEmpty || !acidEvents.isEmpty else { return nil }

        var facts: [ResonantMonoModulationFact] = []
        facts.reserveCapacity(acidEvents.count)
        var bindingValid = !acidAssignments.isEmpty && !acidEvents.isEmpty
        for evidence in noteEvidence where
            evidence.instrument.architecture == .resonantMono {
            let expected = ResonantMonoModulationContract.treatment(
                for: evidence.instrument
            )
            if let expected {
                guard let actual = evidence.resonantMonoModulation else {
                    bindingValid = false
                    continue
                }
                let renderedFrames = evidence.appliedGateEndFrame - evidence.onsetFrame
                bindingValid = bindingValid &&
                    actual.relation == expected.relation &&
                    actual.modulatorRatio == expected.modulatorRatio &&
                    actual.requestedPeakIndex == expected.requestedPeakIndex &&
                    actual.appliedPeakIndex > 0 &&
                    actual.appliedPeakIndex <= actual.requestedPeakIndex &&
                    actual.renderedFrameCount == renderedFrames
                facts.append(ResonantMonoModulationFact(
                    role: evidence.role,
                    onsetFrame: evidence.onsetFrame,
                    patch: evidence.instrument.patch,
                    relation: actual.relation,
                    modulatorRatio: actual.modulatorRatio,
                    requestedPeakIndex: actual.requestedPeakIndex,
                    appliedPeakIndex: actual.appliedPeakIndex,
                    renderedFrameCount: actual.renderedFrameCount
                ))
            } else if evidence.resonantMonoModulation != nil {
                bindingValid = false
            }
        }
        facts.sort { lhs, rhs in
            if lhs.onsetFrame != rhs.onsetFrame {
                return lhs.onsetFrame < rhs.onsetFrame
            }
            let lhsRole = SynthRole.allCases.firstIndex(of: lhs.role) ?? 0
            let rhsRole = SynthRole.allCases.firstIndex(of: rhs.role) ?? 0
            if lhsRole != rhsRole { return lhsRole < rhsRole }
            return lhs.patch.rawValue < rhs.patch.rawValue
        }
        var sink = StreamingFNV1a()
        sink.domain("resonant-mono-modulation-events.typed.v1")
        sink.collection(facts.count)
        for fact in facts {
            sink.aggregate("ResonantMonoModulationFact")
            sink.field("role"); sink.raw(fact.role.rawValue)
            sink.field("onsetFrame"); sink.int(fact.onsetFrame)
            sink.field("patch"); sink.raw(fact.patch.rawValue)
            sink.field("relation"); sink.raw(fact.relation.rawValue)
            sink.field("modulatorRatio"); sink.double(fact.modulatorRatio)
            sink.field("requestedPeakIndex"); sink.double(fact.requestedPeakIndex)
            sink.field("appliedPeakIndex"); sink.double(fact.appliedPeakIndex)
            sink.field("renderedFrameCount"); sink.int(fact.renderedFrameCount)
        }

        var peak = 0.0
        var energy = 0.0
        var lowEnergy = 0.0
        var low1 = 0.0
        var low2 = 0.0
        let lowCoefficient = 1 - exp(
            -2 * .pi * ResonantMonoModulationContract.highPassHz / sampleRate
        )
        var finite = sampleRate.isFinite && sampleRate > 0
        for sample in samples {
            let value = Double(sample)
            low1 += (value - low1) * lowCoefficient
            low2 += (low1 - low2) * lowCoefficient
            peak = max(peak, abs(value))
            energy += value * value
            lowEnergy += low2 * low2
            finite = finite && sample.isFinite && low1.isFinite && low2.isFinite &&
                peak.isFinite && energy.isFinite && lowEnergy.isFinite
        }
        let rms = sqrt(energy / Double(max(1, samples.count)))
        let crestFactor = rms > 0 ? peak / rms : 0
        let lowBandEnergyRatio = energy > 0 ? lowEnergy / energy : 0
        finite = finite && rms.isFinite && crestFactor.isFinite &&
            lowBandEnergyRatio.isFinite
        bindingValid = bindingValid && facts.count == acidEvents.count &&
            samples.count > 1 && samples.first?.bitPattern == 0 &&
            samples.last?.bitPattern == 0
        return ResonantMonoModulationRenderEvidence(
            sourceAssignmentCount: acidAssignments.count,
            eventCount: facts.count,
            orderedEventCount: facts.filter {
                $0.relation == .orderedHollow
            }.count,
            metallicEventCount: facts.filter {
                $0.relation == .metallicTension
            }.count,
            orderedModulatorRatio: facts.contains {
                $0.relation == .orderedHollow
            } ? 2.0 : 0,
            metallicModulatorRatio: facts.contains {
                $0.relation == .metallicTension
            } ? 1.414_213_562_373_095_1 : 0,
            maximumRequestedPeakIndex:
                facts.map(\.requestedPeakIndex).max() ?? 0,
            minimumAppliedPeakIndex:
                facts.map(\.appliedPeakIndex).min() ?? 0,
            maximumAppliedPeakIndex:
                facts.map(\.appliedPeakIndex).max() ?? 0,
            eventFingerprint: fixedWidthFingerprintHex(sink.value),
            operatorSampleHash: ExactPCMFingerprint.mono(samples),
            operatorPeak: peak,
            operatorRMS: rms,
            operatorCrestFactor: crestFactor,
            lowBandEnergyRatio: lowBandEnergyRatio,
            bindingValid: bindingValid,
            finite: finite
        )
    }

    private static func safeMaster(_ sample: Float) -> Float {
        Float(tanh(Double(sample) * 1.12) * 0.78)
    }

    @discardableResult
    private static func kick(
        _ output: inout [Float],
        scoreEventIndex: Int,
        start: Int,
        sampleRate: Double,
        level: Double,
        seed: UInt64,
        step: Int,
        barDurationSeconds: Double,
        morphology: KickMorphologyArticulation,
        sourceDynamics: inout KickSourceDynamicsEvidenceAccumulator
    ) -> SourceTerminalDeclickRenderEvidence? {
        guard start >= 0, start < output.count else { return nil }
        let frames = min(Int(sampleRate * 0.32), output.count - start)
        guard frames > 0 else { return nil }
        sourceDynamics.beginEvent(sampleRate: sampleRate)
        var terminalEvidence = SourceTerminalDeclickEvidenceAccumulator(
            scoreEventIndex: scoreEventIndex,
            voice: .kick,
            step: step,
            sampleRate: sampleRate,
            renderedFrameCount: frames
        )
        var dynamicsState = AntiderivativeAntialiasedTanhState()
        var random = SeededGenerator(seed: seed ^ UInt64(step + 1) ^ 0x9E3779B97F4A7C15)
        var bodyPhase = 0.0
        var subPhase = 0.0
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            let barProgress = min(
                1,
                max(0, Double(step) / 16.0 + t / barDurationSeconds)
            )
            let parameters = morphology.parameters(atBarProgress: barProgress)
            let pitch = parameters.fundamentalHz +
                parameters.pitchDepthHz * exp(
                    -t * parameters.pitchDecayPerSecond
                ) +
                parameters.fastPitchDepthHz * exp(
                    -t * parameters.fastPitchDecayPerSecond
                )
            bodyPhase += 2 * Double.pi * pitch / sampleRate
            subPhase += 2 * Double.pi * parameters.fundamentalHz / sampleRate
            let attack = min(1, t / 0.0012)
            let bodyEnvelope = attack * exp(-t * parameters.bodyDecayPerSecond)
            let subEnvelope = min(1, t / 0.006) *
                exp(-t * parameters.subDecayPerSecond)
            let body = tanh((
                sin(bodyPhase) +
                    sin(bodyPhase * 2) * parameters.secondHarmonicLevel
            ) * parameters.bodyDrive) * bodyEnvelope
            let sub = sin(subPhase) * subEnvelope * parameters.subLevel
            let transientEnvelope = exp(-t * 1_050)
            let transient = i < Int(sampleRate * 0.0045)
                ? ((random.unit() * 2 - 1) * parameters.noiseClickLevel +
                    sin(2 * .pi * parameters.clickFrequencyHz * t) *
                        parameters.tonalClickLevel) * transientEnvelope
                : 0
            let authoredSource = body + sub + transient
            // Balanced is the exact pre-v2 anchor. Avoid inserting even an
            // identity multiply on that path; softer material presence is
            // authored before dynamics, detector, ducking, and audible mix.
            let presenceAdjustedSource = parameters.presenceScale == 1
                ? authoredSource
                : authoredSource * parameters.presenceScale
            let sourceSample = Float(presenceAdjustedSource * level)
            let conditionedSample = KickSourceDynamicsContract.process(
                sourceSample,
                state: &dynamicsState
            )
            let renderedSample = SourceTerminalDeclickContract.process(
                sample: conditionedSample,
                voice: .kick,
                frame: i,
                renderedFrameCount: frames,
                sampleRate: sampleRate
            )
            output[start + i] += renderedSample
            sourceDynamics.append(input: sourceSample, output: renderedSample)
            terminalEvidence.append(
                frame: i,
                preFade: conditionedSample,
                rendered: renderedSample
            )
        }
        return terminalEvidence.evidence
    }

    private static func rumble(
        _ output: inout [Float],
        measurement: inout [Float],
        scoreEventIndex: Int,
        start: Int,
        sampleRate: Double,
        level: Double,
        seed: UInt64,
        step: Int
    ) -> SourceTerminalDeclickRenderEvidence? {
        let frames = min(Int(sampleRate * 0.68), output.count - start)
        guard frames > 0 else { return nil }
        var terminalEvidence = SourceTerminalDeclickEvidenceAccumulator(
            scoreEventIndex: scoreEventIndex,
            voice: .rumble,
            step: step,
            sampleRate: sampleRate,
            renderedFrameCount: frames
        )
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
            let preFadeSample = Float(tanh(body * 1.12) * envelope * level)
            let renderedSample = SourceTerminalDeclickContract.process(
                sample: preFadeSample,
                voice: .rumble,
                frame: index,
                renderedFrameCount: frames,
                sampleRate: sampleRate
            )
            output[start + index] += renderedSample
            measurement[start + index] += renderedSample
            terminalEvidence.append(
                frame: index,
                preFade: preFadeSample,
                rendered: renderedSample
            )
        }
        return terminalEvidence.evidence
    }

    private static func hat(_ output: inout [Float], measurement: inout [Float],
                            start: Int, sampleRate: Double, level: Double,
                            brightness: Double, random: inout SeededGenerator,
                            scoreEventIndex: Int, event: EnsembleResolvedEvent,
                            timingOffsetInSteps: Double,
                            role: ClosedHatDecayRole) -> ClosedHatRenderEvidence? {
        let frames = min(
            ClosedHatVoiceContract.frameCount(sampleRate: sampleRate),
            output.count - start
        )
        guard frames > 0 else { return nil }
        var state = 0.0
        let decayRate = ClosedHatVoiceContract.decayRate(
            brightness: brightness,
            role: role
        )
        let attackFrameCount = min(
            frames,
            max(1, Int((sampleRate * 0.008).rounded()))
        )
        let tailStartFrame = min(
            frames,
            max(0, Int((sampleRate * 0.024).rounded()))
        )
        let lowCoefficient = min(1, 1 - exp(-2 * .pi * 2_000 / sampleRate))
        let midCoefficient = min(1, 1 - exp(-2 * .pi * 8_000 / sampleRate))
        var fingerprint = ExactPCMFingerprint.MonoAccumulator(sampleCount: frames)
        var peak = 0.0
        var energy = 0.0
        var attackEnergy = 0.0
        var tailEnergy = 0.0
        var lowState = 0.0
        var midState = 0.0
        var lowEnergy = 0.0
        var middleEnergy = 0.0
        var highEnergy = 0.0
        var finite = decayRate.isFinite && level.isFinite
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            let n = random.unit() * 2 - 1
            state += (n - state) * (0.25 + brightness * 0.25)
            let renderedSample = Float(
                (n - state * 0.7) * exp(-t * decayRate) * level
            )
            output[start + i] += renderedSample
            measurement[start + i] += renderedSample
            fingerprint.append(renderedSample)
            let value = Double(renderedSample)
            let sampleEnergy = value * value
            peak = max(peak, abs(value))
            energy += sampleEnergy
            if i < attackFrameCount { attackEnergy += sampleEnergy }
            if i >= tailStartFrame { tailEnergy += sampleEnergy }
            lowState += (value - lowState) * lowCoefficient
            midState += (value - midState) * midCoefficient
            let middle = midState - lowState
            let high = value - midState
            lowEnergy += lowState * lowState
            middleEnergy += middle * middle
            highEnergy += high * high
            finite = finite && renderedSample.isFinite
        }
        let rms = sqrt(energy / Double(frames))
        let attackRMS = sqrt(attackEnergy / Double(attackFrameCount))
        let tailRMS = sqrt(tailEnergy / Double(max(1, frames - tailStartFrame)))
        let tailToAttackDB = attackRMS > 0
            ? min(120, max(-120, 20 * log10(max(tailRMS / attackRMS, 0.000_001))))
            : -120
        let bandEnergy = lowEnergy + middleEnergy + highEnergy
        let lowRatio = bandEnergy > 0 ? lowEnergy / bandEnergy : 0
        let middleRatio = bandEnergy > 0 ? middleEnergy / bandEnergy : 0
        let highRatio = bandEnergy > 0 ? highEnergy / bandEnergy : 0
        let spectralCentroid = lowRatio * min(1_000, sampleRate * 0.10) +
            middleRatio * min(4_000, sampleRate * 0.30) +
            highRatio * min(10_000, sampleRate * 0.45)
        let scalars = [
            decayRate, level, peak, rms, attackRMS, tailRMS,
            tailToAttackDB, spectralCentroid,
        ]
        return ClosedHatRenderEvidence(
            scoreEventIndex: scoreEventIndex,
            step: event.step,
            role: role,
            eventIntensity: event.intensity,
            timingOffsetInSteps: timingOffsetInSteps,
            relocated: event.relocated,
            appliedLevel: level,
            appliedDecayRate: decayRate,
            renderedFrameCount: frames,
            sampleHash: fingerprint.fingerprint,
            peak: peak,
            rms: rms,
            attackRMS: attackRMS,
            tailRMS: tailRMS,
            tailToAttackDB: tailToAttackDB,
            spectralCentroidHz: spectralCentroid,
            finite: finite && scalars.allSatisfy(\.isFinite)
        )
    }

    private static func clap(
        _ output: inout [Float],
        measurement: inout [Float],
        start: Int,
        sampleRate: Double,
        level: Double,
        brightness: Double,
        random: inout SeededGenerator,
        articulation: UpperPercussionTailArticulation,
        event: EnsembleResolvedEvent,
        timingOffsetInSteps: Double
    ) -> UpperPercussionTailRenderEvidence? {
        let durationSeconds = articulation.body == .rim ? 0.08 : 0.16
        let frames = min(Int(sampleRate * durationSeconds), output.count - start)
        guard frames > 0 else { return nil }
        var evidence = UpperPercussionTailEvidenceAccumulator(
            articulation: articulation,
            event: event,
            timingOffsetInSteps: timingOffsetInSteps,
            sampleRate: sampleRate,
            renderedFrameCount: frames
        )
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
            let clapSample =
                ((noise - low * 0.72) * (burstEnvelope * 0.46 + tail) + body) * level
            let baseSample: Float = switch articulation.body {
            case .snare:
                Float(snareBodySample(
                    time: t,
                    noise: noise,
                    lowNoise: low,
                    brightness: brightness,
                    level: level
                ))
            case .rim:
                Float(rimBodySample(
                    time: t,
                    noise: noise,
                    lowNoise: low,
                    brightness: brightness,
                    level: level
                ))
            case .native, .clap:
                Float(clapSample)
            }
            let articulatedSample = UpperPercussionTailDSPContract.process(
                sample: baseSample,
                role: articulation.role,
                frame: i,
                renderedFrameCount: frames,
                sampleRate: sampleRate
            )
            let renderedSample = SourceTerminalDeclickContract.process(
                sample: articulatedSample,
                voice: articulation.voice,
                frame: i,
                renderedFrameCount: frames,
                sampleRate: sampleRate
            )
            output[start + i] += renderedSample
            measurement[start + i] += renderedSample
            evidence.append(
                frame: i,
                base: baseSample,
                preTerminalFade: articulatedSample,
                rendered: renderedSample
            )
        }
        return evidence.evidence
    }

    /// A bounded pitched membrane plus filtered wire noise. The analytic phase
    /// is the integral of a 220-to-168 Hz exponential pitch fall, keeping the
    /// articulation sample-rate independent and state free.
    private static func snareBodySample(
        time: Double,
        noise: Double,
        lowNoise: Double,
        brightness: Double,
        level: Double
    ) -> Double {
        let pitchFall = 52.0
        let pitchRate = 75.0
        let phase = 2 * .pi * (
            168 * time + pitchFall * (1 - exp(-pitchRate * time)) / pitchRate
        )
        let membrane = sin(phase) * exp(-time * 24) * 0.58
        let overtone = sin(phase * 1.93 + 0.42) * exp(-time * 38) * 0.16
        let wireAttack = min(1, time / 0.000_8)
        let wire = (noise - lowNoise * 0.78) * wireAttack *
            exp(-time * (17 - brightness * 3)) * 0.62
        let transient = (noise - lowNoise) * exp(-time * 145) * 0.24
        return (membrane + overtone + wire + transient) * level
    }

    /// A short damped shell/edge articulation. It is deliberately leaner than
    /// the snare so suspension chapters can imply ritual syncopation without
    /// introducing a second percussion scheduler.
    private static func rimBodySample(
        time: Double,
        noise: Double,
        lowNoise: Double,
        brightness: Double,
        level: Double
    ) -> Double {
        let envelope = min(1, time / 0.000_45) * exp(-time * 66)
        let shell = sin(2 * .pi * (430 + brightness * 36) * time) * 0.66 +
            sin(2 * .pi * (1_120 + brightness * 180) * time + 0.54) * 0.31 +
            sin(2 * .pi * 2_480 * time + 1.1) * 0.13
        let edge = (noise - lowNoise * 0.86) * exp(-time * 115) * 0.32
        return (shell * envelope + edge) * level
    }

    private static func metallicPercussion(
        _ output: inout [Float],
        measurement: inout [Float],
        start: Int,
        sampleRate: Double,
        level: Double,
        brightness: Double,
        random: inout SeededGenerator,
        articulation: UpperPercussionTailArticulation,
        event: EnsembleResolvedEvent,
        timingOffsetInSteps: Double
    ) -> UpperPercussionTailRenderEvidence? {
        let frames = min(Int(sampleRate * 0.065), output.count - start)
        guard frames > 0 else { return nil }
        var evidence = UpperPercussionTailEvidenceAccumulator(
            articulation: articulation,
            event: event,
            timingOffsetInSteps: timingOffsetInSteps,
            sampleRate: sampleRate,
            renderedFrameCount: frames
        )
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
            let baseSample = Float(
                (resonances * 0.72 + (noise - noiseState) * 0.16) * envelope * level
            )
            let articulatedSample = UpperPercussionTailDSPContract.process(
                sample: baseSample,
                role: articulation.role,
                frame: i,
                renderedFrameCount: frames,
                sampleRate: sampleRate
            )
            let renderedSample = SourceTerminalDeclickContract.process(
                sample: articulatedSample,
                voice: articulation.voice,
                frame: i,
                renderedFrameCount: frames,
                sampleRate: sampleRate
            )
            output[start + i] += renderedSample
            measurement[start + i] += renderedSample
            evidence.append(
                frame: i,
                base: baseSample,
                preTerminalFade: articulatedSample,
                rendered: renderedSample
            )
        }
        return evidence.evidence
    }

    private static func openHat(
        _ output: inout [Float],
        measurement: inout [Float],
        start: Int,
        sampleRate: Double,
        level: Double,
        brightness: Double,
        random: inout SeededGenerator,
        articulation: UpperPercussionTailArticulation,
        event: EnsembleResolvedEvent,
        timingOffsetInSteps: Double
    ) -> UpperPercussionTailRenderEvidence? {
        let frames = min(Int(sampleRate * 0.19), output.count - start)
        guard frames > 0 else { return nil }
        var evidence = UpperPercussionTailEvidenceAccumulator(
            articulation: articulation,
            event: event,
            timingOffsetInSteps: timingOffsetInSteps,
            sampleRate: sampleRate,
            renderedFrameCount: frames
        )
        var filtered = 0.0
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            let noise = random.unit() * 2.0 - 1.0
            filtered += (noise - filtered) * (0.16 + brightness * 0.16)
            let metallic = sin(2.0 * Double.pi * (3_600 + brightness * 3_800) * t)
                + sin(2.0 * Double.pi * (5_100 + brightness * 2_200) * t) * 0.42
            let envelope = min(1.0, t / 0.0015) * exp(-t * (18.0 - brightness * 4.0))
            let baseSample = Float(
                (noise - filtered * 0.55 + metallic * 0.16) * envelope * level
            )
            let articulatedSample = UpperPercussionTailDSPContract.process(
                sample: baseSample,
                role: articulation.role,
                frame: i,
                renderedFrameCount: frames,
                sampleRate: sampleRate
            )
            let renderedSample = SourceTerminalDeclickContract.process(
                sample: articulatedSample,
                voice: articulation.voice,
                frame: i,
                renderedFrameCount: frames,
                sampleRate: sampleRate
            )
            output[start + i] += renderedSample
            measurement[start + i] += renderedSample
            evidence.append(
                frame: i,
                base: baseSample,
                preTerminalFade: articulatedSample,
                rendered: renderedSample
            )
        }
        return evidence.evidence
    }

}
