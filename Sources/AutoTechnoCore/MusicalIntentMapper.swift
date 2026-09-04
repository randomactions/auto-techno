import Foundation

/// Translates the mapped `MusicalIntent` controls into the concrete parameters
/// needed to construct a `TechnoScene`. The reachability audit explicitly
/// quarantines the legacy intent-only and score-only members that do not reach
/// PCM. Every mapping is deterministic and runs off the audio callback.
package struct MusicalIntentMapper: Sendable {

    /// Produces the deterministic scene parameters derived from a musical
    /// intention. Tempo remains the session director's responsibility.
    package static func map(intent: MusicalIntent) -> (
        drive: Double,
        darkness: Double,
        hypnosis: Double,
        beatShape: Double,
        // Aggression & atmosphere — stored on TechnoScene for the renderer
        aggression: Double,
        machineTexture: Double,
        drone: Double,
        atmosphere: Double,
        atmosphericDarkness: Double,
        // Chaos values — per-voice perturbation amounts
        drumChaos: Double,
        synthChaos: Double,
        textureChaos: Double,
        // Musicality — motif richness parameters
        melodicity: Double,
        synthPresence: Double,
        noteActivity: Double,
        // Motion — groove and pattern controls
        syncopation: Double,
        polyrhythm: Double,
        sequencerPresence: Double,
        sequencerStyle: Double,
        sequencerDensity: Double,
        sequencerRegister: Double,
        sequencerRepetition: Double,
        sequencerDrift: Double,
        sequencerDepth: Double
    ) {
        // --- Character branch ---
        let aggression = intent[.aggression]
        let atmosphere = intent[.atmosphere]
        let atmosphericDarkness = intent[.atmosphericDarkness]
        let hypnosis = intent[.hypnosis]
        let darkness = intent[.darkness]

        // Darkness and atmosphericDarkness correlate — shadowed space deepens darkness
        let effectiveDarkness = min(1.0, darkness + atmosphericDarkness * 0.25)

        // --- Motion branch ---
        let groove = intent[.groove]  // minimum 0.05 already enforced
        let syncopation = intent[.syncopation]
        let beatShape = intent[.beatShape]
        let polyrhythm = intent[.polyrhythm]

        // Drive: derived from groove (forward momentum) + syncopation (rhythmic density).
        // High groove = locked, propulsive. High syncopation = busy.
        let drive = min(1.0, groove * 0.7 + syncopation * 0.5)

        // --- Musicality branch ---
        let melodicity = intent[.melodicity]
        let synthPresence = intent[.synthPresence]
        let noteActivity = intent[.noteActivity]

        // --- Uncertainty branch ---
        let overallChaos = intent[.overallChaos]
        let drumChaos = min(1.0, intent[.drumChaos] + overallChaos * 0.3)
        let synthChaos = min(1.0, intent[.synthChaos] + overallChaos * 0.3)
        let textureChaos = min(1.0, intent[.textureChaos] + overallChaos * 0.3)

        return (
            drive: drive,
            darkness: effectiveDarkness,
            hypnosis: hypnosis,
            beatShape: beatShape,
            aggression: aggression,
            machineTexture: intent[.machineTexture],
            drone: min(1.0, intent[.drone] * (0.72 + atmosphere * 0.28)),
            atmosphere: atmosphere,
            atmosphericDarkness: atmosphericDarkness,
            drumChaos: drumChaos,
            synthChaos: synthChaos,
            textureChaos: textureChaos,
            melodicity: melodicity,
            synthPresence: synthPresence,
            noteActivity: noteActivity,
            syncopation: syncopation,
            polyrhythm: polyrhythm
            , sequencerPresence: intent[.sequencerPresence]
            , sequencerStyle: intent[.sequencerStyle]
            , sequencerDensity: intent[.sequencerDensity]
            , sequencerRegister: intent[.sequencerRegister]
            , sequencerRepetition: intent[.sequencerRepetition]
            , sequencerDrift: intent[.sequencerDrift]
            , sequencerDepth: intent[.sequencerDepth]
        )
    }
}
