import AutoTechnoCore
import Foundation

/// One fixed source-local transfer for the complete canonical kick. The score
/// still owns every kick event; this contract only conditions the already
/// resolved body + sub + click sum before detector and audible routing.
package enum KickSourceDynamicsContract {
    package static let version = "kick-source-dynamics.adaa-tanh.v2"
    package static let antialiasOrder = 1
    package static let drive = 1.35
    package static let outputGain = 0.88
    package static let maximumEventsPerBar = 16
    package static let maximumEventDurationSeconds = 0.32
    package static let attackWindowSeconds = 0.008
    package static let bodyWindowStartSeconds = 0.024
    package static let bodyWindowEndSeconds = 0.120
    package static let upperMidLowCutHz = 1_000.0
    package static let upperMidHighCutHz = 4_000.0

    static func process(
        _ input: Float,
        state: inout AntiderivativeAntialiasedTanhState
    ) -> Float {
        guard input.isFinite else {
            state.reset()
            return 0
        }
        guard input != 0 else {
            // Preserve both signed zeros while still advancing the ADAA state
            // through its exact zero coordinate.
            _ = state.process(Double(input) * drive)
            return input
        }
        let shaped = state.process(Double(input) * drive) * outputGain
        guard shaped.isFinite else {
            state.reset()
            return 0
        }
        return Float(min(outputGain, max(-outputGain, shaped)))
    }

    package static func maximumProcessedSampleCount(sampleRate: Double) -> Int {
        guard sampleRate.isFinite, sampleRate > 0 else { return 0 }
        let perEvent = Int((sampleRate * maximumEventDurationSeconds).rounded(.down))
        guard perEvent >= 0, perEvent <= Int.max / maximumEventsPerBar else {
            return 0
        }
        return perEvent * maximumEventsPerBar
    }

    package static func morphologyScoreHash(
        _ morphology: KickMorphologyArticulation
    ) -> String {
        var fingerprint = StreamingFNV1a()
        fingerprint.domain("kick-morphology.score.v2")
        fingerprint.aggregate("KickMorphologyArticulation")
        fingerprint.string(morphology.version)
        fingerprint.int(morphology.absoluteBar)
        fingerprint.int(morphology.presentationBar)
        fingerprint.int(morphology.segmentIndex)
        fingerprint.uint64(morphology.episodeID)
        fingerprint.raw(morphology.operatorKind.rawValue)
        fingerprint.int(morphology.episodeRelativeBar)
        fingerprint.raw(morphology.fromHome.rawValue)
        fingerprint.raw(morphology.toHome.rawValue)
        fingerprint.double(morphology.startProgress)
        fingerprint.double(morphology.endProgress)
        append(morphology.start, to: &fingerprint)
        append(morphology.end, to: &fingerprint)
        return fixedWidthFingerprintHex(fingerprint.value)
    }

    private static func append(
        _ parameters: KickMorphologyParameters,
        to fingerprint: inout StreamingFNV1a
    ) {
        fingerprint.double(parameters.fundamentalHz)
        fingerprint.double(parameters.pitchDepthHz)
        fingerprint.double(parameters.fastPitchDepthHz)
        fingerprint.double(parameters.pitchDecayPerSecond)
        fingerprint.double(parameters.fastPitchDecayPerSecond)
        fingerprint.double(parameters.bodyDecayPerSecond)
        fingerprint.double(parameters.subDecayPerSecond)
        fingerprint.double(parameters.secondHarmonicLevel)
        fingerprint.double(parameters.bodyDrive)
        fingerprint.double(parameters.subLevel)
        fingerprint.double(parameters.noiseClickLevel)
        fingerprint.double(parameters.tonalClickLevel)
        fingerprint.double(parameters.clickFrequencyHz)
        fingerprint.double(parameters.presenceScale)
    }
}

package struct KickSourceDynamicsRenderEvidence: Codable, Equatable, Sendable {
    package let version: String
    package let antialiasOrder: Int
    package let morphologyVersion: String
    package let morphologyScoreHash: String
    package let morphologyPresentationBar: Int
    package let morphologyEpisodeID: UInt64
    package let morphologyOperatorKind: String
    package let morphologyEpisodeRelativeBar: Int
    package let morphologyFromHome: String
    package let morphologyToHome: String
    package let morphologyStartProgress: Double
    package let morphologyEndProgress: Double
    package let fundamentalStartHz: Double
    package let fundamentalEndHz: Double
    package let pitchDepthStartHz: Double
    package let pitchDepthEndHz: Double
    package let bodyDecayStartPerSecond: Double
    package let bodyDecayEndPerSecond: Double
    package let clickLevelStart: Double
    package let clickLevelEnd: Double
    package let bodyDriveStart: Double
    package let bodyDriveEnd: Double
    package let presenceScaleStart: Double
    package let presenceScaleEnd: Double
    package let morphologyBound: Bool
    package let renderedEventCount: Int
    package let processedSampleCount: Int
    package let inputSampleHash: String
    package let outputSampleHash: String
    package let inputPeak: Double
    package let inputRMS: Double
    package let inputCrestFactor: Double
    package let outputPeak: Double
    package let outputRMS: Double
    package let outputCrestFactor: Double
    package let inputAttackRMS: Double
    package let outputAttackRMS: Double
    package let inputBodyRMS: Double
    package let outputBodyRMS: Double
    package let inputUpperMidEnergyRatio: Double
    package let outputUpperMidEnergyRatio: Double
    package let finite: Bool

    package static var empty: Self {
        KickSourceDynamicsEvidenceAccumulator().evidence
    }

    package static func empty(
        morphology: KickMorphologyArticulation
    ) -> Self {
        var accumulator = KickSourceDynamicsEvidenceAccumulator()
        accumulator.bind(morphology: morphology)
        return accumulator.evidence
    }
}

/// Same-pass reduction of event-local pre/post kick samples. It retains only
/// bounded scalars and typed hashes; no reconstructable PCM escapes rendering.
struct KickSourceDynamicsEvidenceAccumulator {
    private var morphology: KickMorphologyArticulation?
    private var morphologyFingerprint = StreamingFNV1a()
    private var renderedEventCount = 0
    private var processedSampleCount = 0
    private var eventFrame = 0
    private var sampleRate = 0.0
    private var attackFrameCount = 0
    private var bodyStartFrame = 0
    private var bodyEndFrame = 0
    private var inputPeak = 0.0
    private var outputPeak = 0.0
    private var inputEnergy = 0.0
    private var outputEnergy = 0.0
    private var inputAttackEnergy = 0.0
    private var outputAttackEnergy = 0.0
    private var attackSampleCount = 0
    private var inputBodyEnergy = 0.0
    private var outputBodyEnergy = 0.0
    private var bodySampleCount = 0
    private var inputUpperMidEnergy = 0.0
    private var outputUpperMidEnergy = 0.0
    private var inputLowState = 0.0
    private var inputHighState = 0.0
    private var outputLowState = 0.0
    private var outputHighState = 0.0
    private var lowCoefficient = 0.0
    private var highCoefficient = 0.0
    private var finite = true
    private var inputFingerprint = StreamingFNV1a()
    private var outputFingerprint = StreamingFNV1a()

    init() {
        morphologyFingerprint.domain("kick-morphology.score.v2")
        inputFingerprint.domain("kick-source-dynamics.input.v1")
        outputFingerprint.domain("kick-source-dynamics.output.v1")
    }

    mutating func bind(morphology: KickMorphologyArticulation) {
        guard self.morphology == nil else {
            finite = false
            return
        }
        self.morphology = morphology
        morphologyFingerprint.aggregate("KickMorphologyArticulation")
        morphologyFingerprint.string(morphology.version)
        morphologyFingerprint.int(morphology.absoluteBar)
        morphologyFingerprint.int(morphology.presentationBar)
        morphologyFingerprint.int(morphology.segmentIndex)
        morphologyFingerprint.uint64(morphology.episodeID)
        morphologyFingerprint.raw(morphology.operatorKind.rawValue)
        morphologyFingerprint.int(morphology.episodeRelativeBar)
        morphologyFingerprint.raw(morphology.fromHome.rawValue)
        morphologyFingerprint.raw(morphology.toHome.rawValue)
        morphologyFingerprint.double(morphology.startProgress)
        morphologyFingerprint.double(morphology.endProgress)
        appendMorphologyParameters(morphology.start)
        appendMorphologyParameters(morphology.end)
        finite = finite && morphology.isComplete
    }

    private mutating func appendMorphologyParameters(
        _ parameters: KickMorphologyParameters
    ) {
        morphologyFingerprint.double(parameters.fundamentalHz)
        morphologyFingerprint.double(parameters.pitchDepthHz)
        morphologyFingerprint.double(parameters.fastPitchDepthHz)
        morphologyFingerprint.double(parameters.pitchDecayPerSecond)
        morphologyFingerprint.double(parameters.fastPitchDecayPerSecond)
        morphologyFingerprint.double(parameters.bodyDecayPerSecond)
        morphologyFingerprint.double(parameters.subDecayPerSecond)
        morphologyFingerprint.double(parameters.secondHarmonicLevel)
        morphologyFingerprint.double(parameters.bodyDrive)
        morphologyFingerprint.double(parameters.subLevel)
        morphologyFingerprint.double(parameters.noiseClickLevel)
        morphologyFingerprint.double(parameters.tonalClickLevel)
        morphologyFingerprint.double(parameters.clickFrequencyHz)
        morphologyFingerprint.double(parameters.presenceScale)
    }

    mutating func beginEvent(sampleRate: Double) {
        renderedEventCount += 1
        eventFrame = 0
        self.sampleRate = sampleRate
        attackFrameCount = max(
            1,
            Int((sampleRate * KickSourceDynamicsContract.attackWindowSeconds).rounded())
        )
        bodyStartFrame = max(
            attackFrameCount,
            Int((sampleRate * KickSourceDynamicsContract.bodyWindowStartSeconds).rounded())
        )
        bodyEndFrame = max(
            bodyStartFrame + 1,
            Int((sampleRate * KickSourceDynamicsContract.bodyWindowEndSeconds).rounded())
        )
        let boundedHighCut = min(
            KickSourceDynamicsContract.upperMidHighCutHz,
            sampleRate * 0.42
        )
        lowCoefficient = min(
            0.55,
            1 - exp(-2 * .pi *
                KickSourceDynamicsContract.upperMidLowCutHz / sampleRate)
        )
        highCoefficient = min(
            0.55,
            1 - exp(-2 * .pi * boundedHighCut / sampleRate)
        )
        inputLowState = 0
        inputHighState = 0
        outputLowState = 0
        outputHighState = 0
        inputFingerprint.aggregate("event")
        inputFingerprint.int(renderedEventCount - 1)
        outputFingerprint.aggregate("event")
        outputFingerprint.int(renderedEventCount - 1)
        finite = finite && sampleRate.isFinite && sampleRate > 0 &&
            lowCoefficient.isFinite && highCoefficient.isFinite &&
            lowCoefficient > 0 && highCoefficient >= lowCoefficient
    }

    mutating func append(input: Float, output: Float) {
        processedSampleCount += 1
        inputFingerprint.float(input)
        outputFingerprint.float(output)
        let inputValue = Double(input)
        let outputValue = Double(output)
        inputPeak = max(inputPeak, abs(inputValue))
        outputPeak = max(outputPeak, abs(outputValue))
        inputEnergy += inputValue * inputValue
        outputEnergy += outputValue * outputValue
        if eventFrame < attackFrameCount {
            inputAttackEnergy += inputValue * inputValue
            outputAttackEnergy += outputValue * outputValue
            attackSampleCount += 1
        }
        if eventFrame >= bodyStartFrame, eventFrame < bodyEndFrame {
            inputBodyEnergy += inputValue * inputValue
            outputBodyEnergy += outputValue * outputValue
            bodySampleCount += 1
        }
        inputLowState += (inputValue - inputLowState) * lowCoefficient
        inputHighState += (inputValue - inputHighState) * highCoefficient
        outputLowState += (outputValue - outputLowState) * lowCoefficient
        outputHighState += (outputValue - outputHighState) * highCoefficient
        let inputUpperMid = inputHighState - inputLowState
        let outputUpperMid = outputHighState - outputLowState
        inputUpperMidEnergy += inputUpperMid * inputUpperMid
        outputUpperMidEnergy += outputUpperMid * outputUpperMid
        finite = finite && input.isFinite && output.isFinite &&
            inputLowState.isFinite && inputHighState.isFinite &&
            outputLowState.isFinite && outputHighState.isFinite
        eventFrame += 1
    }

    var evidence: KickSourceDynamicsRenderEvidence {
        let morphologyStart = morphology?.start
        let morphologyEnd = morphology?.end
        let sampleDivisor = Double(max(1, processedSampleCount))
        let attackDivisor = Double(max(1, attackSampleCount))
        let bodyDivisor = Double(max(1, bodySampleCount))
        let inputRMS = sqrt(inputEnergy / sampleDivisor)
        let outputRMS = sqrt(outputEnergy / sampleDivisor)
        let inputAttackRMS = sqrt(inputAttackEnergy / attackDivisor)
        let outputAttackRMS = sqrt(outputAttackEnergy / attackDivisor)
        let inputBodyRMS = sqrt(inputBodyEnergy / bodyDivisor)
        let outputBodyRMS = sqrt(outputBodyEnergy / bodyDivisor)
        let inputCrest = inputRMS > 0 ? inputPeak / inputRMS : 0
        let outputCrest = outputRMS > 0 ? outputPeak / outputRMS : 0
        let inputUpperMidRatio = inputEnergy > 0
            ? min(1, max(0, inputUpperMidEnergy / inputEnergy)) : 0
        let outputUpperMidRatio = outputEnergy > 0
            ? min(1, max(0, outputUpperMidEnergy / outputEnergy)) : 0
        let signalScalars: [Double] = [
            sampleRate, inputPeak, outputPeak, inputRMS, outputRMS,
            inputCrest, outputCrest, inputAttackRMS, outputAttackRMS,
            inputBodyRMS, outputBodyRMS, inputUpperMidRatio,
            outputUpperMidRatio,
        ]
        let morphologyScalars: [Double] = [
            morphology?.startProgress ?? 0,
            morphology?.endProgress ?? 0,
            morphologyStart?.fundamentalHz ?? 0,
            morphologyEnd?.fundamentalHz ?? 0,
            morphologyStart?.pitchDepthHz ?? 0,
            morphologyEnd?.pitchDepthHz ?? 0,
            morphologyStart?.bodyDecayPerSecond ?? 0,
            morphologyEnd?.bodyDecayPerSecond ?? 0,
            morphologyStart?.noiseClickLevel ?? 0,
            morphologyEnd?.noiseClickLevel ?? 0,
            morphologyStart?.bodyDrive ?? 0,
            morphologyEnd?.bodyDrive ?? 0,
            morphologyStart?.presenceScale ?? 0,
            morphologyEnd?.presenceScale ?? 0,
        ]
        let scalars = signalScalars + morphologyScalars
        return KickSourceDynamicsRenderEvidence(
            version: KickSourceDynamicsContract.version,
            antialiasOrder: KickSourceDynamicsContract.antialiasOrder,
            morphologyVersion: morphology?.version ?? "",
            morphologyScoreHash: fixedWidthFingerprintHex(
                morphologyFingerprint.value
            ),
            morphologyPresentationBar: morphology?.presentationBar ?? 0,
            morphologyEpisodeID: morphology?.episodeID ?? 0,
            morphologyOperatorKind: morphology?.operatorKind.rawValue ?? "",
            morphologyEpisodeRelativeBar: morphology?.episodeRelativeBar ?? 0,
            morphologyFromHome: morphology?.fromHome.rawValue ?? "",
            morphologyToHome: morphology?.toHome.rawValue ?? "",
            morphologyStartProgress: morphology?.startProgress ?? 0,
            morphologyEndProgress: morphology?.endProgress ?? 0,
            fundamentalStartHz: morphologyStart?.fundamentalHz ?? 0,
            fundamentalEndHz: morphologyEnd?.fundamentalHz ?? 0,
            pitchDepthStartHz: morphologyStart?.pitchDepthHz ?? 0,
            pitchDepthEndHz: morphologyEnd?.pitchDepthHz ?? 0,
            bodyDecayStartPerSecond:
                morphologyStart?.bodyDecayPerSecond ?? 0,
            bodyDecayEndPerSecond: morphologyEnd?.bodyDecayPerSecond ?? 0,
            clickLevelStart: morphologyStart?.noiseClickLevel ?? 0,
            clickLevelEnd: morphologyEnd?.noiseClickLevel ?? 0,
            bodyDriveStart: morphologyStart?.bodyDrive ?? 0,
            bodyDriveEnd: morphologyEnd?.bodyDrive ?? 0,
            presenceScaleStart: morphologyStart?.presenceScale ?? 0,
            presenceScaleEnd: morphologyEnd?.presenceScale ?? 0,
            morphologyBound: morphology != nil,
            renderedEventCount: renderedEventCount,
            processedSampleCount: processedSampleCount,
            inputSampleHash: fixedWidthFingerprintHex(inputFingerprint.value),
            outputSampleHash: fixedWidthFingerprintHex(outputFingerprint.value),
            inputPeak: inputPeak,
            inputRMS: inputRMS,
            inputCrestFactor: inputCrest,
            outputPeak: outputPeak,
            outputRMS: outputRMS,
            outputCrestFactor: outputCrest,
            inputAttackRMS: inputAttackRMS,
            outputAttackRMS: outputAttackRMS,
            inputBodyRMS: inputBodyRMS,
            outputBodyRMS: outputBodyRMS,
            inputUpperMidEnergyRatio: inputUpperMidRatio,
            outputUpperMidEnergyRatio: outputUpperMidRatio,
            finite: finite && scalars.allSatisfy { $0.isFinite }
        )
    }
}
