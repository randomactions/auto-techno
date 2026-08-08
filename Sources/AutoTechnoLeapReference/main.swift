import AutoTechnoCore
import AutoTechnoDSP
import Foundation

let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("docs/reference", isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let requestedSeeds = CommandLine.arguments.dropFirst().compactMap(UInt64.init)
let seeds: [UInt64] = requestedSeeds.isEmpty ? [42, 48_291, 90_909] : requestedSeeds
let sampleRate = 44_100.0
var entries: [LeapReferenceEntry] = []

for seed in seeds {
    let scene = TechnoScene(seed: seed, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)

    var baselineState = V2RenderState()
    let baselineCycle = V2ProceduralEngine.renderPersistent32Bars(
        scene: scene, sampleRate: sampleRate, state: &baselineState,
        treatment: .polished, mastering: .clubPunch,
        synthEngine: .legacyReference, synthRhythm: .anchorOnly)
    let baseline = baselineCycle + baselineCycle + baselineCycle
    let baselineReport = V2QualityReport(blocks: baseline, sampleRate: sampleRate)

    var scoreState = V2RenderState()
    let score = V2ProceduralEngine.renderDramaticJourney96Bars(
        scene: scene, sampleRate: sampleRate, state: &scoreState,
        treatment: .polished, mastering: .clubPunch, instrument: .legacyVoice)
    let scoreReport = V2QualityReport(blocks: score, sampleRate: sampleRate)

    var authoredState = V2RenderState()
    let authored = V2ProceduralEngine.renderDramaticJourney96Bars(
        scene: scene, sampleRate: sampleRate, state: &authoredState,
        treatment: .polished, mastering: .clubPunch, instrument: .authoredPatch)
    let authoredReport = V2QualityReport(blocks: authored, sampleRate: sampleRate)
    let scoreDeterministic = scoreReport.sampleHash == dramaticHash(
        scene: scene, sampleRate: sampleRate, instrument: .legacyVoice)
    let authoredDeterministic = authoredReport.sampleHash == dramaticHash(
        scene: scene, sampleRate: sampleRate, instrument: .authoredPatch)

    var legacyVoiceState = V2RenderState()
    let legacyVoiceJourney = V2ProceduralEngine.renderDramaticJourney96Bars(
        scene: scene, sampleRate: sampleRate, state: &legacyVoiceState,
        treatment: .polished, mastering: .headroomReference,
        instrument: .legacyVoice, isolatedStem: .musicalVoices)
    var authoredVoiceState = V2RenderState()
    let authoredVoiceJourney = V2ProceduralEngine.renderDramaticJourney96Bars(
        scene: scene, sampleRate: sampleRate, state: &authoredVoiceState,
        treatment: .polished, mastering: .headroomReference,
        instrument: .authoredPatch, isolatedStem: .musicalVoices)
    let voiceRange = 64..<88
    let legacyVoice = Array(legacyVoiceJourney[voiceRange])
    let authoredVoice = Array(authoredVoiceJourney[voiceRange])
    let legacyVoiceReport = V2QualityReport(blocks: legacyVoice, sampleRate: sampleRate)
    let authoredVoiceReport = V2QualityReport(blocks: authoredVoice, sampleRate: sampleRate)
    let authoredVoiceGain = safeMatchGain(targetRMS: legacyVoiceReport.rms, candidate: authoredVoiceReport)

    let scoreGain = safeMatchGain(targetRMS: baselineReport.rms, candidate: scoreReport)
    let authoredGain = safeMatchGain(targetRMS: baselineReport.rms, candidate: authoredReport)
    try writeWAV(
        blocks: baseline,
        gain: 1,
        sampleRate: sampleRate,
        to: outputDirectory.appendingPathComponent("leap_seed\(seed)_A_current_v3_repeated_96bars.wav")
    )
    try writeWAV(
        blocks: score,
        gain: scoreGain,
        sampleRate: sampleRate,
        to: outputDirectory.appendingPathComponent("leap_seed\(seed)_B_dramatic_legacy_matched.wav")
    )
    try writeWAV(
        blocks: authored,
        gain: authoredGain,
        sampleRate: sampleRate,
        to: outputDirectory.appendingPathComponent("leap_seed\(seed)_C_dramatic_authored_matched.wav")
    )
    try writeWAV(
        blocks: legacyVoice,
        gain: 1,
        sampleRate: sampleRate,
        to: outputDirectory.appendingPathComponent("leap_seed\(seed)_B_voice_focus_bars64_87.wav")
    )
    try writeWAV(
        blocks: authoredVoice,
        gain: authoredVoiceGain,
        sampleRate: sampleRate,
        to: outputDirectory.appendingPathComponent("leap_seed\(seed)_C_voice_focus_bars64_87_matched.wav")
    )

    let plan = DramaticJourneyPlan(scene: scene)
    let scorePass = qualityPass(scoreReport)
    let authoredPass = qualityPass(authoredReport)
    let contractsPass = plan.unpaidDebtIDs.isEmpty && score.count == DramaticJourneyPlan.barCount &&
        score[79].events.allSatisfy { $0.voice != .bass } &&
        score[80].events.contains { $0.voice == .bass } &&
        plan.bars[79].tension.overall > 0.80 && plan.bars[80].tension.overall < 0.30 &&
        plan.bars[79].roles.contains(.transition) &&
        plan.bars[80].payoffStrength > plan.bars[24].payoffStrength + 0.35 &&
        score[80].rms > score[79].rms * 3 && authored[80].rms > authored[79].rms * 3
    entries.append(LeapReferenceEntry(
        seed: seed,
        barCount: authored.count,
        baselineHash: baselineReport.sampleHash,
        scoreHash: scoreReport.sampleHash,
        authoredHash: authoredReport.sampleHash,
        baselineRMS: baselineReport.rms,
        scoreRMS: scoreReport.rms,
        authoredRMS: authoredReport.rms,
        scoreMatchGain: scoreGain,
        authoredMatchGain: authoredGain,
        scoreTruePeak: scoreReport.truePeakEstimate,
        authoredTruePeak: authoredReport.truePeakEstimate,
        scoreLowStereoCorrelation: scoreReport.lowStereoCorrelation,
        authoredLowStereoCorrelation: authoredReport.lowStereoCorrelation,
        anticipationTension: plan.bars[79].tension.overall,
        returnTension: plan.bars[80].tension.overall,
        falseReturnStrength: plan.bars[24].payoffStrength,
        decisiveReturnStrength: plan.bars[80].payoffStrength,
        scoreAnticipationRMS: score[79].rms,
        scoreReturnRMS: score[80].rms,
        authoredAnticipationRMS: authored[79].rms,
        authoredReturnRMS: authored[80].rms,
        legacyVoiceHash: legacyVoiceReport.sampleHash,
        authoredVoiceHash: authoredVoiceReport.sampleHash,
        legacyVoiceRMS: legacyVoiceReport.rms,
        authoredVoiceRMS: authoredVoiceReport.rms,
        authoredVoiceMatchGain: authoredVoiceGain,
        legacyVoiceTruePeak: legacyVoiceReport.truePeakEstimate,
        authoredVoiceTruePeak: authoredVoiceReport.truePeakEstimate,
        legacyVoiceBoundaryDelta: legacyVoiceReport.maxBoundaryDelta,
        authoredVoiceBoundaryDelta: authoredVoiceReport.maxBoundaryDelta,
        voiceFocusPass: voiceQualityPass(legacyVoiceReport) && voiceQualityPass(authoredVoiceReport),
        scoreDeterministic: scoreDeterministic,
        authoredDeterministic: authoredDeterministic,
        scorePass: scorePass,
        authoredPass: authoredPass,
        contractsPass: contractsPass
    ))
}

let report = LeapReferenceReport(entries: entries)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(report).write(
    to: outputDirectory.appendingPathComponent("leap_translation_report.json"),
    options: .atomic)
print("Leap reference: \(report.allPass ? "PASS" : "FAIL") · seeds \(seeds)")

struct LeapReferenceEntry: Codable {
    let seed: UInt64
    let barCount: Int
    let baselineHash: String
    let scoreHash: String
    let authoredHash: String
    let baselineRMS: Float
    let scoreRMS: Float
    let authoredRMS: Float
    let scoreMatchGain: Float
    let authoredMatchGain: Float
    let scoreTruePeak: Float
    let authoredTruePeak: Float
    let scoreLowStereoCorrelation: Float
    let authoredLowStereoCorrelation: Float
    let anticipationTension: Double
    let returnTension: Double
    let falseReturnStrength: Double
    let decisiveReturnStrength: Double
    let scoreAnticipationRMS: Float
    let scoreReturnRMS: Float
    let authoredAnticipationRMS: Float
    let authoredReturnRMS: Float
    let legacyVoiceHash: String
    let authoredVoiceHash: String
    let legacyVoiceRMS: Float
    let authoredVoiceRMS: Float
    let authoredVoiceMatchGain: Float
    let legacyVoiceTruePeak: Float
    let authoredVoiceTruePeak: Float
    let legacyVoiceBoundaryDelta: Float
    let authoredVoiceBoundaryDelta: Float
    let voiceFocusPass: Bool
    let scoreDeterministic: Bool
    let authoredDeterministic: Bool
    let scorePass: Bool
    let authoredPass: Bool
    let contractsPass: Bool
}

struct LeapReferenceReport: Codable {
    let fixedSeeds: [UInt64]
    let allPass: Bool
    let entries: [LeapReferenceEntry]

    init(entries: [LeapReferenceEntry]) {
        fixedSeeds = entries.map(\.seed).sorted()
        allPass = !entries.isEmpty && entries.allSatisfy { entry in
            entry.barCount == DramaticJourneyPlan.barCount &&
                entry.baselineHash != entry.scoreHash && entry.scoreHash != entry.authoredHash &&
                entry.legacyVoiceHash != entry.authoredVoiceHash &&
                entry.scoreDeterministic && entry.authoredDeterministic &&
                entry.scorePass && entry.authoredPass && entry.voiceFocusPass && entry.contractsPass
        }
        self.entries = entries
    }
}

func qualityPass(_ report: V2QualityReport) -> Bool {
    report.finite && report.truePeakEstimate <= 0.95 && report.lowStereoCorrelation > 0.94 &&
        report.maxBoundaryDelta < 0.3 && report.rms > 0
}

/// A musical-voice stem intentionally excludes the mono foundation, so the
/// whole-mix low-band correlation contract is not meaningful here. Preserve
/// the finite, peak, continuity, and audible-signal contracts for focused A/Bs.
func voiceQualityPass(_ report: V2QualityReport) -> Bool {
    report.finite && report.truePeakEstimate <= 0.95 &&
        report.maxBoundaryDelta < 0.3 && report.rms > 0
}

func safeMatchGain(targetRMS: Float, candidate: V2QualityReport) -> Float {
    let loudnessGain = targetRMS / max(candidate.rms, 0.000_001)
    let peakGain = 0.92 / max(candidate.truePeakEstimate, 0.000_001)
    return min(loudnessGain, peakGain)
}

func dramaticHash(scene: TechnoScene, sampleRate: Double,
                  instrument: DramaticInstrumentProfile) -> String {
    var state = V2RenderState()
    let blocks = V2ProceduralEngine.renderDramaticJourney96Bars(
        scene: scene, sampleRate: sampleRate, state: &state,
        treatment: .polished, mastering: .clubPunch, instrument: instrument)
    return V2QualityReport(blocks: blocks, sampleRate: sampleRate).sampleHash
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
    wav.append(contentsOf: Data("WAVE".utf8))
    wav.append(contentsOf: Data("fmt ".utf8))
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
    var little = value.littleEndian
    withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
}

func appendUInt32(_ value: UInt32, to data: inout Data) {
    var little = value.littleEndian
    withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
}

func appendInt16(_ value: Int16, to data: inout Data) {
    appendUInt16(UInt16(bitPattern: value), to: &data)
}
