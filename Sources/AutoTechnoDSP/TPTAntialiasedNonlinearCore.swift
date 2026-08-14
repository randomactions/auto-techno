import Foundation

/// Stable identity and bounds for the shared nonlinear filter primitive. The
/// score still owns patch, role, and semantic automation; this contract only
/// translates those existing coordinates into one deterministic DSP topology.
package enum TPTAntialiasedNonlinearCoreContract {
    package static let version = "tpt-svf-adaa-tanh.v1"
    package static let minimumCutoffHz = 20.0
    package static let maximumCutoffFraction = 0.22
    package static let minimumQ = 0.5
    package static let maximumQ = 4.5
    package static let minimumDrive = 1.0
    package static let maximumDrive = 3.2
    package static let maximumBandMix = 0.45
    package static let antialiasOrder = 1

    package static func q(for resonance: Double) -> Double {
        let bounded = min(1, max(0, resonance.isFinite ? resonance : 0))
        return min(
            maximumQ,
            max(minimumQ, 0.707_106_781_186_547_6 + 4.0 * bounded * bounded)
        )
    }
}

/// First-order antiderivative antialiasing for tanh waveshaping. The
/// antiderivative is log(cosh(x)); the stable formulation avoids overflow for
/// large magnitudes. State is one prior input sample and is therefore bounded,
/// deterministic, and suitable for phrase-to-phrase renderer continuation.
struct AntiderivativeAntialiasedTanhState: Equatable, Sendable {
    private(set) var previousInput = 0.0
    private(set) var hasPreviousInput = false

    mutating func process(_ input: Double) -> Double {
        guard input.isFinite else {
            reset()
            return 0
        }
        // tanh is indistinguishable from its asymptote at this bound while the
        // antiderivative remains comfortably conditioned.
        let current = min(18, max(-18, input))
        guard hasPreviousInput else {
            previousInput = current
            hasPreviousInput = true
            return tanh(current)
        }

        let previous = previousInput
        previousInput = current
        let delta = current - previous
        let scale = max(1, abs(current), abs(previous))
        guard abs(delta) > 1e-7 * scale else {
            return tanh((current + previous) * 0.5)
        }
        let output = (Self.logCosh(current) - Self.logCosh(previous)) / delta
        return output.isFinite ? output : tanh((current + previous) * 0.5)
    }

    mutating func reset() {
        previousInput = 0
        hasPreviousInput = false
    }

    private static func logCosh(_ value: Double) -> Double {
        let magnitude = abs(value)
        return magnitude + log1p(exp(-2 * magnitude)) - log(2)
    }
}

struct TPTStateVariableFilterResponse: Equatable, Sendable {
    let lowPass: Double
    let bandPass: Double
    let highPass: Double
}

/// Two-integrator topology-preserving-transform state-variable filter. The
/// trapezoidal integrator states remain well behaved under per-sample cutoff
/// modulation; no coefficient or signal history allocation is required.
struct TPTStateVariableFilterState: Equatable, Sendable {
    private(set) var integrator1 = 0.0
    private(set) var integrator2 = 0.0

    mutating func process(
        _ input: Double,
        sampleRate: Double,
        cutoffHz: Double,
        q: Double
    ) -> TPTStateVariableFilterResponse {
        guard input.isFinite, sampleRate.isFinite, sampleRate > 0,
              cutoffHz.isFinite, q.isFinite else {
            reset()
            return TPTStateVariableFilterResponse(
                lowPass: 0,
                bandPass: 0,
                highPass: 0
            )
        }
        let cutoff = min(
            sampleRate * TPTAntialiasedNonlinearCoreContract.maximumCutoffFraction,
            max(TPTAntialiasedNonlinearCoreContract.minimumCutoffHz, cutoffHz)
        )
        let boundedQ = min(
            TPTAntialiasedNonlinearCoreContract.maximumQ,
            max(TPTAntialiasedNonlinearCoreContract.minimumQ, q)
        )
        let g = tan(.pi * cutoff / sampleRate)
        let k = 1 / boundedQ
        let denominator = 1 + g * (g + k)
        guard denominator.isFinite, denominator > 0 else {
            reset()
            return TPTStateVariableFilterResponse(
                lowPass: 0,
                bandPass: 0,
                highPass: 0
            )
        }
        let a1 = 1 / denominator
        let a2 = g * a1
        let a3 = g * a2
        let v3 = input - integrator2
        let bandPass = a1 * integrator1 + a2 * v3
        let lowPass = integrator2 + a2 * integrator1 + a3 * v3
        let highPass = input - k * bandPass - lowPass
        integrator1 = 2 * bandPass - integrator1
        integrator2 = 2 * lowPass - integrator2

        guard lowPass.isFinite, bandPass.isFinite, highPass.isFinite,
              integrator1.isFinite, integrator2.isFinite else {
            reset()
            return TPTStateVariableFilterResponse(
                lowPass: 0,
                bandPass: 0,
                highPass: 0
            )
        }
        return TPTStateVariableFilterResponse(
            lowPass: lowPass,
            bandPass: bandPass,
            highPass: highPass
        )
    }

    var isFinite: Bool {
        integrator1.isFinite && integrator2.isFinite
    }

    mutating func reset() {
        integrator1 = 0
        integrator2 = 0
    }
}

struct TPTAntialiasedNonlinearCoreState: Equatable, Sendable {
    private(set) var inputShaper = AntiderivativeAntialiasedTanhState()
    private(set) var filter = TPTStateVariableFilterState()
    private(set) var outputShaper = AntiderivativeAntialiasedTanhState()

    mutating func process(
        input: Double,
        sampleRate: Double,
        cutoffHz: Double,
        q: Double,
        inputDrive: Double,
        outputDrive: Double,
        bandMix: Double
    ) -> Double {
        let shapedInput = inputShaper.process(input * inputDrive) / inputDrive
        let response = filter.process(
            shapedInput,
            sampleRate: sampleRate,
            cutoffHz: cutoffHz,
            q: q
        )
        let filtered = response.lowPass * (1 - bandMix) +
            response.bandPass * bandMix
        return outputShaper.process(filtered * outputDrive) / outputDrive
    }

    var isFinite: Bool {
        inputShaper.previousInput.isFinite && filter.isFinite &&
            outputShaper.previousInput.isFinite
    }

    mutating func reset() {
        inputShaper.reset()
        filter.reset()
        outputShaper.reset()
    }
}

package struct TPTAntialiasedNonlinearCoreRenderEvidence: Equatable, Sendable {
    package let version: String
    package let antialiasOrder: Int
    package let sourceAssignmentCount: Int
    package let sourceEventCount: Int
    package let processedSampleCount: Int
    package let minimumCutoffHz: Double
    package let maximumCutoffHz: Double
    package let minimumQ: Double
    package let maximumQ: Double
    package let minimumInputDrive: Double
    package let maximumInputDrive: Double
    package let minimumOutputDrive: Double
    package let maximumOutputDrive: Double
    package let minimumBandMix: Double
    package let maximumBandMix: Double
    package let inputSampleHash: String
    package let outputSampleHash: String
    package let inputPeak: Double
    package let inputRMS: Double
    package let outputPeak: Double
    package let outputRMS: Double
    package let bindingValid: Bool
    package let finite: Bool
}

/// Same-pass scalar and fingerprint reducer. It never retains reconstructable
/// PCM and is discarded as soon as the immutable architecture evidence forms.
struct TPTAntialiasedNonlinearCoreEvidenceAccumulator {
    private var processedSampleCount = 0
    private var minimumCutoffHz = Double.infinity
    private var maximumCutoffHz = 0.0
    private var minimumQ = Double.infinity
    private var maximumQ = 0.0
    private var minimumInputDrive = Double.infinity
    private var maximumInputDrive = 0.0
    private var minimumOutputDrive = Double.infinity
    private var maximumOutputDrive = 0.0
    private var minimumBandMix = Double.infinity
    private var maximumBandMix = 0.0
    private var inputPeak = 0.0
    private var outputPeak = 0.0
    private var inputEnergy = 0.0
    private var outputEnergy = 0.0
    private var finite = true
    private var inputFingerprint = StreamingFNV1a()
    private var outputFingerprint = StreamingFNV1a()

    init() {
        inputFingerprint.domain("tpt-adaa-core.input.v1")
        outputFingerprint.domain("tpt-adaa-core.output.v1")
    }

    mutating func observe(
        input: Double,
        output: Double,
        cutoffHz: Double,
        q: Double,
        inputDrive: Double,
        outputDrive: Double,
        bandMix: Double,
        stateIsFinite: Bool
    ) {
        processedSampleCount += 1
        inputFingerprint.double(input)
        outputFingerprint.double(output)
        minimumCutoffHz = min(minimumCutoffHz, cutoffHz)
        maximumCutoffHz = max(maximumCutoffHz, cutoffHz)
        minimumQ = min(minimumQ, q)
        maximumQ = max(maximumQ, q)
        minimumInputDrive = min(minimumInputDrive, inputDrive)
        maximumInputDrive = max(maximumInputDrive, inputDrive)
        minimumOutputDrive = min(minimumOutputDrive, outputDrive)
        maximumOutputDrive = max(maximumOutputDrive, outputDrive)
        minimumBandMix = min(minimumBandMix, bandMix)
        maximumBandMix = max(maximumBandMix, bandMix)
        inputPeak = max(inputPeak, abs(input))
        outputPeak = max(outputPeak, abs(output))
        inputEnergy += input * input
        outputEnergy += output * output
        finite = finite && stateIsFinite && [
            input, output, cutoffHz, q, inputDrive, outputDrive, bandMix,
            inputEnergy, outputEnergy,
        ].allSatisfy(\.isFinite)
    }

    mutating func observeInvalidInput() {
        finite = false
    }

    func evidence(
        sourceAssignmentCount: Int,
        sourceEventCount: Int
    ) -> TPTAntialiasedNonlinearCoreRenderEvidence {
        let active = processedSampleCount > 0
        let divisor = Double(max(1, processedSampleCount))
        return TPTAntialiasedNonlinearCoreRenderEvidence(
            version: TPTAntialiasedNonlinearCoreContract.version,
            antialiasOrder: TPTAntialiasedNonlinearCoreContract.antialiasOrder,
            sourceAssignmentCount: sourceAssignmentCount,
            sourceEventCount: sourceEventCount,
            processedSampleCount: processedSampleCount,
            minimumCutoffHz: active ? minimumCutoffHz : 0,
            maximumCutoffHz: active ? maximumCutoffHz : 0,
            minimumQ: active ? minimumQ : 0,
            maximumQ: active ? maximumQ : 0,
            minimumInputDrive: active ? minimumInputDrive : 0,
            maximumInputDrive: active ? maximumInputDrive : 0,
            minimumOutputDrive: active ? minimumOutputDrive : 0,
            maximumOutputDrive: active ? maximumOutputDrive : 0,
            minimumBandMix: active ? minimumBandMix : 0,
            maximumBandMix: active ? maximumBandMix : 0,
            inputSampleHash: fixedWidthFingerprintHex(inputFingerprint.value),
            outputSampleHash: fixedWidthFingerprintHex(outputFingerprint.value),
            inputPeak: inputPeak,
            inputRMS: sqrt(inputEnergy / divisor),
            outputPeak: outputPeak,
            outputRMS: sqrt(outputEnergy / divisor),
            bindingValid: sourceAssignmentCount > 0 && sourceEventCount > 0 &&
                sourceEventCount >= sourceAssignmentCount && active,
            finite: finite
        )
    }
}

enum TPTAntialiasedNonlinearCore {
    static func process(
        input: Double,
        sampleRate: Double,
        cutoffHz: Double,
        resonance: Double,
        inputDrive: Double,
        outputDrive: Double,
        bandMix: Double,
        state: inout TPTAntialiasedNonlinearCoreState,
        evidence: inout TPTAntialiasedNonlinearCoreEvidenceAccumulator
    ) -> Double {
        guard input.isFinite, sampleRate.isFinite, sampleRate > 0,
              cutoffHz.isFinite, resonance.isFinite, inputDrive.isFinite,
              outputDrive.isFinite, bandMix.isFinite else {
            state.reset()
            evidence.observeInvalidInput()
            return 0
        }
        let cutoff = min(
            sampleRate * TPTAntialiasedNonlinearCoreContract.maximumCutoffFraction,
            max(TPTAntialiasedNonlinearCoreContract.minimumCutoffHz, cutoffHz)
        )
        let q = TPTAntialiasedNonlinearCoreContract.q(for: resonance)
        let inputDrive = min(
            TPTAntialiasedNonlinearCoreContract.maximumDrive,
            max(TPTAntialiasedNonlinearCoreContract.minimumDrive, inputDrive)
        )
        let outputDrive = min(
            TPTAntialiasedNonlinearCoreContract.maximumDrive,
            max(TPTAntialiasedNonlinearCoreContract.minimumDrive, outputDrive)
        )
        let bandMix = min(
            TPTAntialiasedNonlinearCoreContract.maximumBandMix,
            max(0, bandMix)
        )
        let output = state.process(
            input: input,
            sampleRate: sampleRate,
            cutoffHz: cutoff,
            q: q,
            inputDrive: inputDrive,
            outputDrive: outputDrive,
            bandMix: bandMix
        )
        let finite = output.isFinite && state.isFinite
        evidence.observe(
            input: input,
            output: finite ? output : 0,
            cutoffHz: cutoff,
            q: q,
            inputDrive: inputDrive,
            outputDrive: outputDrive,
            bandMix: bandMix,
            stateIsFinite: finite
        )
        if !finite {
            state.reset()
            return 0
        }
        return output
    }
}
