import AutoTechnoCore
import AutoTechnoDSP
import Foundation

let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("docs/reference", isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let requestedSeeds = CommandLine.arguments.dropFirst().compactMap(UInt64.init)
let seeds: [UInt64] = requestedSeeds.isEmpty ? [42, 48_291, 90_909] : requestedSeeds
let sampleRate = 44_100.0
var entries: [SynthReferenceEntry] = []

for seed in seeds {
    let scene = TechnoScene(
        seed: seed, bpm: 130, drive: 0.65, darkness: 0.78,
        hypnosis: 0.74, atmosphere: 0.34,
        melodicity: 0.36, synthPresence: 0.46
    )

    let legacy = timedRender(
        scene: scene, sampleRate: sampleRate,
        engine: .legacyReference, rhythm: .anchorOnly)
    let alienVoice = timedRender(
        scene: scene, sampleRate: sampleRate,
        engine: .alienAnalogV1, rhythm: .anchorOnly)
    let alienInterlocked = timedRender(
        scene: scene, sampleRate: sampleRate,
        engine: .alienAnalogV1, rhythm: .interlocked)

    let legacyReport = V2QualityReport(blocks: legacy.blocks, sampleRate: sampleRate)
    let voiceReport = V2QualityReport(blocks: alienVoice.blocks, sampleRate: sampleRate)
    let interlockedReport = V2QualityReport(blocks: alienInterlocked.blocks, sampleRate: sampleRate)
    let voiceGain = safeMatchGain(targetRMS: legacyReport.rms, candidate: voiceReport)
    let interlockedGain = safeMatchGain(targetRMS: legacyReport.rms, candidate: interlockedReport)

    try writeWAV(
        blocks: legacy.blocks, gain: 1, sampleRate: sampleRate,
        to: outputDirectory.appendingPathComponent("alien_seed\(seed)_A_current_persistent_v3.wav")
    )
    try writeWAV(
        blocks: alienVoice.blocks, gain: voiceGain, sampleRate: sampleRate,
        to: outputDirectory.appendingPathComponent("alien_seed\(seed)_B_voice_existing_rhythm_matched.wav")
    )
    try writeWAV(
        blocks: alienInterlocked.blocks, gain: interlockedGain, sampleRate: sampleRate,
        to: outputDirectory.appendingPathComponent("alien_seed\(seed)_C_interlocked_matched.wav")
    )

    let legacyStem = renderVoiceStem(
        scene: scene, sampleRate: sampleRate,
        engine: .legacyReference, rhythm: .anchorOnly)
    let voiceStem = renderVoiceStem(
        scene: scene, sampleRate: sampleRate,
        engine: .alienAnalogV1, rhythm: .anchorOnly)
    let interlockedStem = renderVoiceStem(
        scene: scene, sampleRate: sampleRate,
        engine: .alienAnalogV1, rhythm: .interlocked)
    let legacyStemReport = V2QualityReport(blocks: legacyStem, sampleRate: sampleRate)
    let voiceStemReport = V2QualityReport(blocks: voiceStem, sampleRate: sampleRate)
    let interlockedStemReport = V2QualityReport(blocks: interlockedStem, sampleRate: sampleRate)
    let voiceStemGain = safeMatchGain(targetRMS: legacyStemReport.rms, candidate: voiceStemReport)
    let interlockedStemGain = safeMatchGain(targetRMS: legacyStemReport.rms, candidate: interlockedStemReport)
    try writeWAV(
        blocks: legacyStem, gain: 1, sampleRate: sampleRate,
        to: outputDirectory.appendingPathComponent("alien_seed\(seed)_A_voice_focus.wav")
    )
    try writeWAV(
        blocks: voiceStem, gain: voiceStemGain, sampleRate: sampleRate,
        to: outputDirectory.appendingPathComponent("alien_seed\(seed)_B_voice_focus_matched.wav")
    )
    try writeWAV(
        blocks: interlockedStem, gain: interlockedStemGain, sampleRate: sampleRate,
        to: outputDirectory.appendingPathComponent("alien_seed\(seed)_C_voice_focus_matched.wav")
    )

    let voiceTimbre = TimbreComplexityMetrics(blocks: voiceStem, sampleRate: sampleRate)
    let interlockedTimbre = TimbreComplexityMetrics(blocks: interlockedStem, sampleRate: sampleRate)
    let foundationPreserved = foundationSchedule(legacy.blocks) == foundationSchedule(alienVoice.blocks) &&
        foundationSchedule(alienVoice.blocks) == foundationSchedule(alienInterlocked.blocks)
    let gestures = Set(alienInterlocked.blocks.compactMap { $0.synthPerformance?.gesture.rawValue }).sorted()
    let cycleContinuity = alienInterlocked.blocks.allSatisfy { block in
        guard let synth = block.synthPerformance else { return false }
        return synth.sevenStepPhase == (block.bar * 16) % 7 &&
            synth.echoGatePhase == (block.bar * 16 + (block.synthWorld?.echoRotation ?? 0)) % 3
    }
    let kickSafe = alienInterlocked.blocks.allSatisfy { block in
        guard let events = block.synthPerformance?.interlockEvents,
              let kicks = block.sceneDNA?.rhythm.kickSteps else { return false }
        return events.allSatisfy { !kicks.contains($0.stepIndex) }
    }

    entries.append(SynthReferenceEntry(
        seed: seed,
        legacyHash: legacyReport.sampleHash,
        alienVoiceHash: voiceReport.sampleHash,
        alienInterlockedHash: interlockedReport.sampleHash,
        legacyPreparationSeconds: legacy.seconds,
        alienVoicePreparationSeconds: alienVoice.seconds,
        alienInterlockedPreparationSeconds: alienInterlocked.seconds,
        alienInterlockedToLegacyRatio: alienInterlocked.seconds / max(legacy.seconds, 0.000_001),
        legacyTruePeak: legacyReport.truePeakEstimate,
        alienVoiceTruePeak: voiceReport.truePeakEstimate,
        alienInterlockedTruePeak: interlockedReport.truePeakEstimate,
        alienVoiceDCOffset: voiceReport.dcOffset,
        alienInterlockedDCOffset: interlockedReport.dcOffset,
        alienVoiceLowStereoCorrelation: voiceReport.lowStereoCorrelation,
        alienInterlockedLowStereoCorrelation: interlockedReport.lowStereoCorrelation,
        alienVoiceBoundaryDelta: voiceReport.maxBoundaryDelta,
        alienInterlockedBoundaryDelta: interlockedReport.maxBoundaryDelta,
        alienVoiceMatchGain: voiceGain,
        alienInterlockedMatchGain: interlockedGain,
        alienVoicePartials: voiceTimbre.significantNonFundamentalPartials,
        alienInterlockedPartials: interlockedTimbre.significantNonFundamentalPartials,
        alienVoiceCentroidRange: voiceTimbre.spectralCentroidRange,
        alienInterlockedCentroidRange: interlockedTimbre.spectralCentroidRange,
        alienVoiceTimbrePass: voiceTimbre.passesComplexityGuard,
        alienInterlockedTimbrePass: interlockedTimbre.passesComplexityGuard,
        foundationSchedulesIdentical: foundationPreserved,
        crossCycleClocksContinuous: cycleContinuity,
        interlocksAvoidKickStarts: kickSafe,
        gestures: gestures,
        legacyQualityPass: qualityPass(legacyReport),
        alienVoiceQualityPass: qualityPass(voiceReport),
        alienInterlockedQualityPass: qualityPass(interlockedReport)
    ))
    print(String(
        format: "seed %llu · A %.2fs · B %.2fs · C %.2fs · C/A %.2fx",
        seed, legacy.seconds, alienVoice.seconds, alienInterlocked.seconds,
        alienInterlocked.seconds / max(legacy.seconds, 0.000_001)
    ))
}

let report = SynthReferenceReport(entries: entries)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(report).write(
    to: outputDirectory.appendingPathComponent("alien_synth_translation_report.json"),
    options: .atomic
)
print("Alien synth automated gate: \(report.automatedGatePass ? "PASS" : "FAIL")")
print("Listening promotion remains pending a fixed-seed A/B/C verdict.")

struct TimedRender {
    let blocks: [V2RenderBlock]
    let seconds: Double
}

struct SynthReferenceEntry: Encodable {
    let seed: UInt64
    let legacyHash: String
    let alienVoiceHash: String
    let alienInterlockedHash: String
    let legacyPreparationSeconds: Double
    let alienVoicePreparationSeconds: Double
    let alienInterlockedPreparationSeconds: Double
    let alienInterlockedToLegacyRatio: Double
    let legacyTruePeak: Float
    let alienVoiceTruePeak: Float
    let alienInterlockedTruePeak: Float
    let alienVoiceDCOffset: Float
    let alienInterlockedDCOffset: Float
    let alienVoiceLowStereoCorrelation: Float
    let alienInterlockedLowStereoCorrelation: Float
    let alienVoiceBoundaryDelta: Float
    let alienInterlockedBoundaryDelta: Float
    let alienVoiceMatchGain: Float
    let alienInterlockedMatchGain: Float
    let alienVoicePartials: Int
    let alienInterlockedPartials: Int
    let alienVoiceCentroidRange: Double
    let alienInterlockedCentroidRange: Double
    let alienVoiceTimbrePass: Bool
    let alienInterlockedTimbrePass: Bool
    let foundationSchedulesIdentical: Bool
    let crossCycleClocksContinuous: Bool
    let interlocksAvoidKickStarts: Bool
    let gestures: [String]
    let legacyQualityPass: Bool
    let alienVoiceQualityPass: Bool
    let alienInterlockedQualityPass: Bool
}

struct SynthReferenceReport: Encodable {
    let engineVersion = SynthEngineProfile.alienAnalogV1.rawValue
    let fixedSeeds: [UInt64]
    let medianLegacyPreparationSeconds: Double
    let medianAlienInterlockedPreparationSeconds: Double
    let preparationRatio: Double
    let performanceGatePass: Bool
    let automatedGatePass: Bool
    let listeningGate = "pending"
    let entries: [SynthReferenceEntry]

    init(entries: [SynthReferenceEntry]) {
        fixedSeeds = entries.map(\.seed).sorted()
        medianLegacyPreparationSeconds = Self.median(entries.map(\.legacyPreparationSeconds))
        medianAlienInterlockedPreparationSeconds = Self.median(entries.map(\.alienInterlockedPreparationSeconds))
        preparationRatio = medianAlienInterlockedPreparationSeconds /
            max(medianLegacyPreparationSeconds, 0.000_001)
        performanceGatePass = preparationRatio <= 1.10
        automatedGatePass = entries.count == 3 && Set(fixedSeeds).count == 3 &&
            performanceGatePass && entries.allSatisfy { entry in
                entry.legacyHash != entry.alienVoiceHash &&
                    entry.alienVoiceHash != entry.alienInterlockedHash &&
                    entry.foundationSchedulesIdentical && entry.crossCycleClocksContinuous &&
                    entry.interlocksAvoidKickStarts && entry.legacyQualityPass &&
                    entry.alienVoiceQualityPass && entry.alienInterlockedQualityPass &&
                    entry.alienVoiceTimbrePass && entry.alienInterlockedTimbrePass
            }
        self.entries = entries
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        return sorted[sorted.count / 2]
    }
}

func timedRender(scene: TechnoScene, sampleRate: Double,
                 engine: SynthEngineProfile, rhythm: SynthRhythmProfile) -> TimedRender {
    var state = V2RenderState()
    let start = DispatchTime.now().uptimeNanoseconds
    let blocks = V2ProceduralEngine.renderPersistent32Bars(
        scene: scene, sampleRate: sampleRate, state: &state,
        treatment: .polished, mastering: .clubPunch,
        synthEngine: engine, synthRhythm: rhythm
    )
    let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000
    return TimedRender(blocks: blocks, seconds: elapsed)
}

func renderVoiceStem(scene: TechnoScene, sampleRate: Double,
                     engine: SynthEngineProfile, rhythm: SynthRhythmProfile) -> [V2RenderBlock] {
    var state = V2RenderState()
    return V2ProceduralEngine.render32Bars(
        scene: scene, sampleRate: sampleRate, state: &state,
        treatment: .polished, mastering: .headroomReference,
        isolatedStem: .musicalVoices, performanceModel: .persistentV3,
        synthEngine: engine, synthRhythm: rhythm
    )
}

func foundationSchedule(_ blocks: [V2RenderBlock]) -> [[V2VoiceEvent]] {
    blocks.map { block in
        block.events.filter { event in
            event.voice == .kick || event.voice == .bass ||
                event.voice == .hats || event.voice == .clap
        }
    }
}

func qualityPass(_ report: V2QualityReport) -> Bool {
    report.finite && report.rms > 0 && report.truePeakEstimate <= 0.95 &&
        abs(report.dcOffset) <= 0.001 && report.lowStereoCorrelation > 0.94 &&
        report.maxBoundaryDelta < 0.3
}

func safeMatchGain(targetRMS: Float, candidate: V2QualityReport) -> Float {
    let loudnessGain = targetRMS / max(candidate.rms, 0.000_001)
    let peakGain = 0.92 / max(candidate.truePeakEstimate, 0.000_001)
    return min(loudnessGain, peakGain)
}

func writeWAV(blocks: [V2RenderBlock], gain: Float, sampleRate: Double, to url: URL) throws {
    let left = blocks.flatMap(\.left)
    let right = blocks.flatMap(\.right)
    let frameCount = min(left.count, right.count)
    var pcm = Data(capacity: frameCount * 4)
    for index in 0..<frameCount {
        let leftSample = max(-1, min(1, left[index] * gain))
        let rightSample = max(-1, min(1, right[index] * gain))
        appendInt16(Int16(clamping: Int32((leftSample * 32_767).rounded())), to: &pcm)
        appendInt16(Int16(clamping: Int32((rightSample * 32_767).rounded())), to: &pcm)
    }

    var wav = Data()
    wav.append(contentsOf: Data("RIFF".utf8))
    appendUInt32(UInt32(36 + pcm.count), to: &wav)
    wav.append(contentsOf: Data("WAVEfmt ".utf8))
    appendUInt32(16, to: &wav)
    appendUInt16(1, to: &wav)
    appendUInt16(2, to: &wav)
    appendUInt32(UInt32(sampleRate), to: &wav)
    appendUInt32(UInt32(sampleRate) * 4, to: &wav)
    appendUInt16(4, to: &wav)
    appendUInt16(16, to: &wav)
    wav.append(contentsOf: Data("data".utf8))
    appendUInt32(UInt32(pcm.count), to: &wav)
    wav.append(pcm)
    try wav.write(to: url, options: .atomic)
}

func appendUInt16(_ value: UInt16, to data: inout Data) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
}

func appendInt16(_ value: Int16, to data: inout Data) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
}

func appendUInt32(_ value: UInt32, to data: inout Data) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
}
