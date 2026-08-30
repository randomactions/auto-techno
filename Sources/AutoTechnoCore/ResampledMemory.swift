import Foundation

/// A reconstructable, score-owned description of one accepted kick. It keeps
/// no PCM or renderer state: DSP regenerates the source through the canonical
/// kick voice before the existing slice renderer transforms it.
package final class ResampledMemorySource: @unchecked Sendable, Equatable {
    package let absoluteBar: Int
    package let sourceStep: Int
    package let synthesisSeed: UInt64
    package let bpm: Double
    package let section: SectionKind
    package let combinedAccent: Double
    package let kickMorphology: KickMorphologyArticulation

    package init(
        absoluteBar: Int,
        sourceStep: Int,
        synthesisSeed: UInt64,
        bpm: Double,
        section: SectionKind,
        combinedAccent: Double,
        kickMorphology: KickMorphologyArticulation
    ) {
        self.absoluteBar = max(0, absoluteBar)
        self.sourceStep = min(15, max(0, sourceStep))
        self.synthesisSeed = synthesisSeed
        self.bpm = min(240, max(40, bpm.isFinite ? bpm : 130))
        self.section = section
        self.combinedAccent = min(
            1.5,
            max(0, combinedAccent.isFinite ? combinedAccent : 0)
        )
        self.kickMorphology = kickMorphology
    }

    package var isComplete: Bool {
        kickMorphology.isComplete &&
            kickMorphology.absoluteBar == absoluteBar &&
            combinedAccent > 0 && bpm.isFinite
    }

    package static func == (
        lhs: ResampledMemorySource,
        rhs: ResampledMemorySource
    ) -> Bool {
        lhs.absoluteBar == rhs.absoluteBar &&
            lhs.sourceStep == rhs.sourceStep &&
            lhs.synthesisSeed == rhs.synthesisSeed &&
            lhs.bpm == rhs.bpm &&
            lhs.section == rhs.section &&
            lhs.combinedAccent == rhs.combinedAccent &&
            lhs.kickMorphology == rhs.kickMorphology
    }

    /// Stable score identity used by detached signal evidence. The hash binds
    /// every value needed to reconstruct the source, including both endpoints
    /// of the kick material trajectory, without retaining the source samples.
    package var fingerprint: UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        func append(_ value: UInt64, to hash: inout UInt64) {
            var remaining = value
            for _ in 0..<8 {
                hash ^= remaining & 0xff
                hash &*= 0x0000_0100_0000_01b3
                remaining >>= 8
            }
        }
        func append(_ value: String, to hash: inout UInt64) {
            for byte in value.utf8 {
                hash ^= UInt64(byte)
                hash &*= 0x0000_0100_0000_01b3
            }
        }
        func append(_ parameters: KickMorphologyParameters, to hash: inout UInt64) {
            append(parameters.fundamentalHz.bitPattern, to: &hash)
            append(parameters.pitchDepthHz.bitPattern, to: &hash)
            append(parameters.fastPitchDepthHz.bitPattern, to: &hash)
            append(parameters.pitchDecayPerSecond.bitPattern, to: &hash)
            append(parameters.fastPitchDecayPerSecond.bitPattern, to: &hash)
            append(parameters.bodyDecayPerSecond.bitPattern, to: &hash)
            append(parameters.subDecayPerSecond.bitPattern, to: &hash)
            append(parameters.secondHarmonicLevel.bitPattern, to: &hash)
            append(parameters.bodyDrive.bitPattern, to: &hash)
            append(parameters.subLevel.bitPattern, to: &hash)
            append(parameters.noiseClickLevel.bitPattern, to: &hash)
            append(parameters.tonalClickLevel.bitPattern, to: &hash)
            append(parameters.clickFrequencyHz.bitPattern, to: &hash)
            append(parameters.presenceScale.bitPattern, to: &hash)
        }

        append("resampled-memory-source.score.v1", to: &hash)
        append(UInt64(absoluteBar), to: &hash)
        append(UInt64(sourceStep), to: &hash)
        append(synthesisSeed, to: &hash)
        append(bpm.bitPattern, to: &hash)
        append(section.rawValue, to: &hash)
        append(combinedAccent.bitPattern, to: &hash)
        append(kickMorphology.version, to: &hash)
        append(UInt64(kickMorphology.absoluteBar), to: &hash)
        append(UInt64(kickMorphology.presentationBar), to: &hash)
        append(UInt64(kickMorphology.segmentIndex), to: &hash)
        append(kickMorphology.episodeID, to: &hash)
        append(kickMorphology.operatorKind.rawValue, to: &hash)
        append(UInt64(kickMorphology.episodeRelativeBar), to: &hash)
        append(kickMorphology.fromHome.rawValue, to: &hash)
        append(kickMorphology.toHome.rawValue, to: &hash)
        append(kickMorphology.startProgress.bitPattern, to: &hash)
        append(kickMorphology.endProgress.bitPattern, to: &hash)
        append(kickMorphology.start, to: &hash)
        append(kickMorphology.end, to: &hash)
        return hash
    }
}

/// Accepted-only, fixed-capacity source memory. Eviction is oldest-first and
/// recall is age-bounded, so long sessions cannot accumulate recordings or an
/// unbounded history of score recipes.
package struct ResampledMemoryContinuationState: Equatable, Sendable {
    package static let maximumSourceCount = 4
    package static let maximumRecallAgeBars = 256

    package let sources: [ResampledMemorySource]

    package init(sources: [ResampledMemorySource] = []) {
        self.sources = Array(
            sources.filter(\.isComplete).sorted {
                $0.absoluteBar < $1.absoluteBar
            }.suffix(Self.maximumSourceCount)
        )
    }

    package func source(recalledAt bar: Int, rotation: Int) -> ResampledMemorySource? {
        let eligible = sources.filter {
            $0.absoluteBar < bar && bar - $0.absoluteBar <= Self.maximumRecallAgeBars
        }
        guard !eligible.isEmpty else { return nil }
        let index = ((rotation % eligible.count) + eligible.count) % eligible.count
        return eligible[index]
    }

    package func advancing(
        scene: TechnoScene,
        resolvedBars: [ResolvedPerformanceBar]
    ) -> Self {
        let candidate: ResampledMemorySource? = resolvedBars.lazy.compactMap { resolved in
            guard let event = resolved.ensemble.events.first(where: {
                $0.voice == .kick && (0..<16).contains($0.step)
            }) else { return nil }
            return ResampledMemorySource(
                absoluteBar: resolved.performance.bar,
                sourceStep: event.step,
                synthesisSeed: scene.seed,
                bpm: scene.bpm,
                section: resolved.performance.section,
                combinedAccent: resolved.performance.accent(at: event.step) *
                    event.intensity,
                kickMorphology: resolved.kickMorphology
            )
        }.first
        guard let candidate, candidate.isComplete else { return self }
        let retained = sources.filter { $0.absoluteBar != candidate.absoluteBar }
        return Self(sources: retained + [candidate])
    }
}
