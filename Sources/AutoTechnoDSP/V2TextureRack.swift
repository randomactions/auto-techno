import AutoTechnoCore
import Foundation

/// A deterministic, procedural texture chain. The stages are intentionally
/// small and bounded; the rack creates identity through interaction rather
/// than relying on one extreme effect.
enum V2TextureRack {
    static let stageNames = [
        "pre-emphasis", "wave fold", "low-pass", "high-pass", "resonance",
        "ring motion", "tremolo", "phaser", "chorus", "comb", "diffusion", "feedback",
        "sample texture", "analog ladder", "saturation", "tape memory", "glue", "spectral tilt", "wet gain"
    ]

    static func process(
        _ buffer: inout [Float],
        sampleRate: Double,
        scene: TechnoScene,
        state: inout V2RenderState
    ) {
        guard !buffer.isEmpty else { return }

        // 1. Pre-emphasis: make the voice react to its own movement.
        var previous = 0.0
        // 3–5. Filter and resonance memory.
        var low = 0.0
        var high = 0.0
        var resonant = 0.0
        // 8–10. Short deterministic texture feedback memory.
        let delayFrames = max(1, Int(sampleRate * (0.021 + scene.atmosphere * 0.017)))
        if state.textureDelay.count != delayFrames {
            state.textureDelay = [Float](repeating: 0, count: delayFrames)
            state.textureWriteIndex = 0
        }
        let phaseIncrement = 2.0 * Double.pi / (sampleRate * (2.0 + scene.hypnosis * 3.0))
        let filterCoefficient = 1.0 - exp(-2.0 * Double.pi * (500.0 + scene.synthPresence * 1_800.0) / sampleRate)
        let highCoefficient = 1.0 - exp(-2.0 * Double.pi * 170.0 / sampleRate)
        let resonance = 0.10 + scene.synthPresence * 0.16
        let feedback = 0.14 + scene.hypnosis * 0.13
        let ladderCutoff = 780.0 + scene.synthPresence * 1_900.0 + scene.character.percussionBrightness * 900.0
        let ladderCoefficient = min(0.42, 1.0 - exp(-2.0 * Double.pi * ladderCutoff / sampleRate))
        let ladderResonance = min(0.22, 0.06 + scene.synthPresence * 0.10 + scene.hypnosis * 0.05)

        for index in buffer.indices {
            var value = Double(buffer[index])

            // 1–2. Pre-emphasis and restrained wavefold.
            let emphasized = value + (value - previous) * (0.12 + scene.aggression * 0.10)
            previous = value
            value = tanh(emphasized * (1.05 + scene.aggression * 0.4))
            value += sin(value * 2.2 + state.texturePhase) * 0.035 * scene.synthChaos

            // 3–5. Two-pole-ish low/high split with bounded resonance.
            low += (value - low) * filterCoefficient
            high += (value - high) * highCoefficient
            let band = low - high
            resonant += (band - resonant) * (filterCoefficient * 0.45)
            value = low + (band - resonant) * resonance

            // 6. Ring modulation is slow and never replaces the source.
            let ring = 0.88 + sin(state.texturePhase * 0.37) * 0.12 * scene.textureChaos
            value *= ring

            // 7.5. Two bounded moving all-pass stages create a slow phaser
            // coloration without adding unbounded feedback energy.
            let phaserCoefficient = -0.22 + sin(state.texturePhase * 0.11) * (0.08 + scene.textureChaos * 0.05)
            let phaserA = -phaserCoefficient * value + state.phaserStateA
            state.phaserStateA = value + phaserCoefficient * phaserA
            let phaserB = -phaserCoefficient * phaserA + state.phaserStateB
            state.phaserStateB = phaserA + phaserCoefficient * phaserB
            value = value * 0.76 + (phaserA + phaserB) * 0.12

            // 7. Tempo-independent slow tremolo, shaped by hypnosis.
            value *= 0.90 + 0.10 * sin(state.texturePhase * 0.19 + 0.7)

            // 8–10. Short comb, diffusion, and feedback.
            let delayed = Double(state.textureDelay[state.textureWriteIndex])
            let diffused = delayed * 0.42 + value * 0.58
            state.textureDelay[state.textureWriteIndex] = Float(value + delayed * feedback)
            state.textureWriteIndex = (state.textureWriteIndex + 1) % delayFrames
            value = diffused + delayed * (0.08 + scene.atmosphere * 0.12)

            // 11. Very gentle sample texture; never reduce to audible bitcrush.
            let textureStep = 0.0007 + scene.textureChaos * 0.0012
            value = (value / textureStep).rounded() * textureStep * 0.18 + value * 0.82

            // 12. Bounded four-stage ladder coloration. This is an analog-
            // inspired voice behavior, not a literal circuit model: the
            // feedback and coefficient limits keep resonance stable while
            // the persistent state gives repeated phrases a living filter
            // memory across bar boundaries.
            let ladderInput = value - state.textureLadder4 * ladderResonance
            state.textureLadder1 += (tanh(ladderInput * 1.08) - state.textureLadder1) * ladderCoefficient
            state.textureLadder2 += (state.textureLadder1 - state.textureLadder2) * ladderCoefficient
            state.textureLadder3 += (state.textureLadder2 - state.textureLadder3) * ladderCoefficient
            state.textureLadder4 += (state.textureLadder3 - state.textureLadder4) * ladderCoefficient
            value = state.textureLadder4 * 0.72 + value * 0.28

            // 13–14. Saturation and glue.
            let asymmetric = value + value * abs(value) * (0.035 + scene.aggression * 0.025)
            value = tanh(asymmetric * (1.12 + scene.aggression * 0.24)) * 0.94
            // 12.5. Bounded tape/console memory: a slow state gives repeated
            // material a little hysteresis without creating a feedback loop.
            state.tapeMemory += (value - state.tapeMemory) * 0.006
            value += (value - state.tapeMemory) * (0.045 + scene.textureChaos * 0.025)
            value *= 0.98 + scene.hypnosis * 0.02

            // 14. Dark scenes gently tilt the top down without deleting air.
            value -= (value - low) * (0.018 + scene.darkness * 0.035)

            // 15. Bounded wet gain.
            buffer[index] = Float(value * (0.92 + scene.synthPresence * 0.08))
            state.texturePhase = (state.texturePhase + phaseIncrement).truncatingRemainder(dividingBy: 2.0 * Double.pi)
        }
    }
}
