import Foundation

/// One fixed source-local transfer for the complete canonical kick. The score
/// still owns every kick event; this contract only conditions the already
/// resolved body + sub + click sum before detector and audible routing.
package enum KickSourceDynamicsContract {
    package static let version = "kick-source-dynamics.adaa-tanh.v1"
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
}

package struct KickSourceDynamicsRenderEvidence: Codable, Equatable, Sendable {
    package let version: String
    package let antialiasOrder: Int
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
}

/// Same-pass reduction of event-local pre/post kick samples. It retains only
/// bounded scalars and typed hashes; no reconstructable PCM escapes rendering.
struct KickSourceDynamicsEvidenceAccumulator {
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
        inputFingerprint.domain("kick-source-dynamics.input.v1")
        outputFingerprint.domain("kick-source-dynamics.output.v1")
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
        let scalars = [
            sampleRate, inputPeak, outputPeak, inputRMS, outputRMS,
            inputCrest, outputCrest, inputAttackRMS, outputAttackRMS,
            inputBodyRMS, outputBodyRMS, inputUpperMidRatio,
            outputUpperMidRatio,
        ]
        return KickSourceDynamicsRenderEvidence(
            version: KickSourceDynamicsContract.version,
            antialiasOrder: KickSourceDynamicsContract.antialiasOrder,
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
            finite: finite && scalars.allSatisfy(\.isFinite)
        )
    }
}
