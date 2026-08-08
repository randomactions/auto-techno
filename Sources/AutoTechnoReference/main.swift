import AutoTechnoCore
import AutoTechnoDSP
import Foundation

let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("docs/reference", isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let sampleRate = 44_100.0
let seeds: [UInt64] = [42, 48_291, 90_909]
let treatments: [RenderTreatment] = [.polished, .sketch]
let masteringProfiles: [V2MasteringProfile] = [.clubPunch, .headroomReference]
var manifest: [ReferenceEntry] = []

for seed in seeds {
    let scene = TechnoScene(seed: seed, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
    for treatment in treatments {
        let rendered = SceneRenderer.render(scene: scene, sampleRate: sampleRate, treatment: treatment)
        let name = "mvp_seed\(seed)_\(treatment.rawValue).wav"
        try writeWAV(rendered, to: outputDirectory.appendingPathComponent(name))
        let mvpRMS = ReferenceMetrics(rendered).rms

        for mastering in masteringProfiles {
            var state = V2RenderState()
            let blocks = V2ProceduralEngine.render32Bars(scene: scene, sampleRate: sampleRate,
                                                          state: &state, treatment: treatment, mastering: mastering)
            let left = blocks.flatMap(\.left)
            let right = blocks.flatMap(\.right)
            let suffix = mastering == .clubPunch ? "" : "_headroomReference"
            let v2Name = "v2_seed\(seed)_\(treatment.rawValue)_32bars\(suffix).wav"
            try writeWAV(left: left, right: right, sampleRate: sampleRate,
                         to: outputDirectory.appendingPathComponent(v2Name))
            let report = V2QualityReport(blocks: blocks, sampleRate: sampleRate)
            let matchGain = mvpRMS / max(report.rms, 0.000001)
            let mvpLoudness = Float(-0.691 + 20.0 * log10(max(Double(mvpRMS), 0.000000001)))
            let matchedLoudness = report.loudnessEstimate + Float(20.0 * log10(max(Double(matchGain), 0.000000001)))
            let translationPass = report.finite && report.truePeakEstimate <= 0.95 &&
                report.lowStereoCorrelation > 0.94 && abs(matchedLoudness - mvpLoudness) <= 0.15
            let matchedName = "v2_seed\(seed)_\(treatment.rawValue)_32bars\(suffix)_matched_to_mvp.wav"
            try writeWAV(left: left, right: right, sampleRate: sampleRate, gain: matchGain,
                         to: outputDirectory.appendingPathComponent(matchedName))
            manifest.append(ReferenceEntry(seed: seed, treatment: treatment.rawValue,
                                           mastering: mastering.rawValue,
                                           peak: report.peak, truePeak: report.truePeakEstimate,
                                           rms: report.rms, stereoCorrelation: report.stereoCorrelation,
                                           lowStereoCorrelation: report.lowStereoCorrelation,
                                           sampleHash: report.sampleHash, mvpRMS: mvpRMS, matchGain: matchGain,
                                           loudnessEstimate: report.loudnessEstimate,
                                           integratedLoudness: report.musical.integratedLoudness,
                                           loudnessRange: report.musical.loudnessRange,
                                           maximumShortTermLoudness: report.musical.maximumShortTermLoudness,
                                           crestFactor: report.musical.crestFactor,
                                           spectralCentroid: report.musical.spectralCentroid,
                                           lowEnergy: report.musical.lowEnergy,
                                           midEnergy: report.musical.midEnergy,
                                           highEnergy: report.musical.highEnergy,
                                           transientDensity: report.musical.transientDensity,
                                           matchedLoudness: matchedLoudness, mvpLoudness: mvpLoudness,
                                           translationPass: translationPass))
        }
    }
}

let manifestData = try JSONEncoder().encode(manifest)
try manifestData.write(to: outputDirectory.appendingPathComponent("v2_manifest.json"), options: .atomic)
let translation = TranslationReport(entries: manifest)
try JSONEncoder().encode(translation).write(to: outputDirectory.appendingPathComponent("v2_translation_report.json"), options: .atomic)

// Persistent v3 remains a parallel listening candidate. Keep these renders
// separate from the approved v2 reference set so promotion requires an
// explicit fixed-seed listening verdict.
var persistentEntries: [PersistentReferenceEntry] = []
for seed in seeds {
    let scene = TechnoScene(seed: seed, bpm: 130, drive: 0.65, darkness: 0.78, hypnosis: 0.74)
    var state = V2RenderState()
    let blocks = V2ProceduralEngine.renderPersistent32Bars(scene: scene, sampleRate: sampleRate,
                                                            state: &state, treatment: .polished,
                                                            mastering: .clubPunch,
                                                            synthEngine: .legacyReference,
                                                            synthRhythm: .anchorOnly)
    let report = V2QualityReport(blocks: blocks, sampleRate: sampleRate)
    let name = "v3_seed\(seed)_persistent_32bars.wav"
    try writeWAV(left: blocks.flatMap(\.left), right: blocks.flatMap(\.right), sampleRate: sampleRate,
                 to: outputDirectory.appendingPathComponent(name))
    guard let referenceRMS = manifest.first(where: {
        $0.seed == seed && $0.treatment == RenderTreatment.polished.rawValue &&
            $0.mastering == V2MasteringProfile.clubPunch.rawValue
    })?.rms else { fatalError("Missing v2 reference RMS for seed \(seed)") }
    let matchGain = referenceRMS / max(report.rms, 0.000001)
    let referenceLoudness = Float(-0.691 + 20.0 * log10(max(Double(referenceRMS), 0.000000001)))
    let matchedLoudness = report.loudnessEstimate + Float(20.0 * log10(max(Double(matchGain), 0.000000001)))
    let matchedName = "v3_seed\(seed)_persistent_32bars_matched_to_v2.wav"
    try writeWAV(left: blocks.flatMap(\.left), right: blocks.flatMap(\.right), sampleRate: sampleRate,
                 gain: matchGain, to: outputDirectory.appendingPathComponent(matchedName))
    persistentEntries.append(PersistentReferenceEntry(
        seed: seed, peak: report.peak, truePeak: report.truePeakEstimate, rms: report.rms,
        stereoCorrelation: report.stereoCorrelation, lowStereoCorrelation: report.lowStereoCorrelation,
        maxBoundaryDelta: report.maxBoundaryDelta, sampleHash: report.sampleHash,
        finite: report.finite, performanceModel: V2PerformanceModel.persistentV3.rawValue,
        referenceRMS: referenceRMS, matchGain: matchGain,
        matchedLoudness: matchedLoudness, referenceLoudness: referenceLoudness,
        loudnessDelta: abs(matchedLoudness - referenceLoudness),
        integratedLoudness: report.musical.integratedLoudness,
        loudnessRange: report.musical.loudnessRange, crestFactor: report.musical.crestFactor,
        spectralCentroid: report.musical.spectralCentroid,
        transientDensity: report.musical.transientDensity))
}
let persistentTranslation = PersistentTranslationReport(entries: persistentEntries)
try JSONEncoder().encode(persistentTranslation).write(
    to: outputDirectory.appendingPathComponent("v3_translation_report.json"), options: .atomic)

let jukeboxPlan = JukeboxPlan(sessionSeed: 48_291, profile: TasteProfile(), sceneCount: 4)
var jukeboxBlocks: [V2RenderBlock] = []
var jukeboxSeeds: [UInt64] = []
for planned in jukeboxPlan.scenes {
    var state = V2RenderState()
    jukeboxBlocks += V2ProceduralEngine.render32Bars(scene: planned.scene, sampleRate: sampleRate,
                                                     state: &state, treatment: .polished, mastering: .clubPunch)
    jukeboxSeeds.append(planned.seed)
}
let jukeboxReport = V2QualityReport(blocks: jukeboxBlocks, sampleRate: sampleRate)
try writeWAV(left: jukeboxBlocks.flatMap(\.left), right: jukeboxBlocks.flatMap(\.right), sampleRate: sampleRate,
             to: outputDirectory.appendingPathComponent("jukebox_seed48291_cycle0_4scenes.wav"))
let jukeboxValidation = JukeboxReferenceReport(
    sceneCount: jukeboxPlan.scenes.count,
    uniqueSceneSeeds: Set(jukeboxSeeds).count,
    blockCount: jukeboxBlocks.count,
    finite: jukeboxReport.finite,
    peak: jukeboxReport.peak,
    truePeak: jukeboxReport.truePeakEstimate,
    lowStereoCorrelation: jukeboxReport.lowStereoCorrelation,
    maxBoundaryDelta: jukeboxReport.maxBoundaryDelta,
    sampleHash: jukeboxReport.sampleHash,
    allPass: Set(jukeboxSeeds).count == jukeboxPlan.scenes.count && jukeboxBlocks.count == 128 &&
        jukeboxReport.finite && jukeboxReport.truePeakEstimate <= 0.95 &&
        jukeboxReport.lowStereoCorrelation > 0.94 && jukeboxReport.maxBoundaryDelta < 0.3
)
try JSONEncoder().encode(jukeboxValidation).write(to: outputDirectory.appendingPathComponent("jukebox_translation_report.json"), options: .atomic)

// A longer unattended-session artifact mirrors the four-cycle preparation
// validator while keeping the original four-scene comparison file stable.
let longPlayPlan = JukeboxPlan(sessionSeed: 48_291, profile: TasteProfile(), sceneCount: 8)
var longPlayBlocks: [V2RenderBlock] = []
var longPlaySeeds: [UInt64] = []
for planned in longPlayPlan.scenes {
    var state = V2RenderState()
    longPlayBlocks += V2ProceduralEngine.render32Bars(scene: planned.scene, sampleRate: sampleRate,
                                                      state: &state, treatment: .polished, mastering: .clubPunch)
    longPlaySeeds.append(planned.seed)
}
let longPlayReport = V2QualityReport(blocks: longPlayBlocks, sampleRate: sampleRate)
try writeWAV(left: longPlayBlocks.flatMap(\.left), right: longPlayBlocks.flatMap(\.right), sampleRate: sampleRate,
             to: outputDirectory.appendingPathComponent("jukebox_seed48291_cycle0_8scenes.wav"))
let longPlayValidation = JukeboxReferenceReport(
    sceneCount: longPlayPlan.scenes.count,
    uniqueSceneSeeds: Set(longPlaySeeds).count,
    blockCount: longPlayBlocks.count,
    finite: longPlayReport.finite,
    peak: longPlayReport.peak,
    truePeak: longPlayReport.truePeakEstimate,
    lowStereoCorrelation: longPlayReport.lowStereoCorrelation,
    maxBoundaryDelta: longPlayReport.maxBoundaryDelta,
    sampleHash: longPlayReport.sampleHash,
    allPass: Set(longPlaySeeds).count == longPlayPlan.scenes.count && longPlayBlocks.count == 256 &&
        longPlayReport.finite && longPlayReport.truePeakEstimate <= 0.95 &&
        longPlayReport.lowStereoCorrelation > 0.94 && longPlayReport.maxBoundaryDelta < 0.3
)
try JSONEncoder().encode(longPlayValidation).write(
    to: outputDirectory.appendingPathComponent("jukebox_long_play_translation_report.json"), options: .atomic)

struct ReferenceEntry: Codable {
    let seed: UInt64
    let treatment: String
    let mastering: String
    let peak: Float
    let truePeak: Float
    let rms: Float
    let stereoCorrelation: Float
    let lowStereoCorrelation: Float
    let sampleHash: String
    let mvpRMS: Float
    let matchGain: Float
    let loudnessEstimate: Float
    let integratedLoudness: Double
    let loudnessRange: Double
    let maximumShortTermLoudness: Double
    let crestFactor: Double
    let spectralCentroid: Double
    let lowEnergy: Double
    let midEnergy: Double
    let highEnergy: Double
    let transientDensity: Double
    let matchedLoudness: Float
    let mvpLoudness: Float
    let translationPass: Bool
}

struct TranslationReport: Codable {
    let fixedSeeds: [UInt64]
    let treatments: [String]
    let masteringProfiles: [String]
    let allPass: Bool
    let entries: [ReferenceEntry]

    init(entries: [ReferenceEntry]) {
        fixedSeeds = Array(Set(entries.map(\.seed))).sorted()
        treatments = Array(Set(entries.map(\.treatment))).sorted()
        masteringProfiles = Array(Set(entries.map(\.mastering))).sorted()
        allPass = !entries.isEmpty && entries.allSatisfy(\.translationPass)
        self.entries = entries
    }
}

struct PersistentReferenceEntry: Codable {
    let seed: UInt64
    let peak: Float
    let truePeak: Float
    let rms: Float
    let stereoCorrelation: Float
    let lowStereoCorrelation: Float
    let maxBoundaryDelta: Float
    let sampleHash: String
    let finite: Bool
    let performanceModel: String
    let referenceRMS: Float
    let matchGain: Float
    let matchedLoudness: Float
    let referenceLoudness: Float
    let loudnessDelta: Float
    let integratedLoudness: Double
    let loudnessRange: Double
    let crestFactor: Double
    let spectralCentroid: Double
    let transientDensity: Double
}

struct PersistentTranslationReport: Codable {
    let performanceModel: String
    let fixedSeeds: [UInt64]
    let allPass: Bool
    let entries: [PersistentReferenceEntry]

    init(entries: [PersistentReferenceEntry]) {
        performanceModel = V2PerformanceModel.persistentV3.rawValue
        fixedSeeds = entries.map(\.seed).sorted()
        allPass = entries.count == 3 && Set(fixedSeeds).count == 3 && entries.allSatisfy {
            $0.performanceModel == V2PerformanceModel.persistentV3.rawValue && $0.finite &&
                $0.truePeak <= 0.95 && $0.lowStereoCorrelation > 0.94 && $0.maxBoundaryDelta < 0.3 &&
                $0.loudnessDelta <= 0.15
        }
        self.entries = entries
    }
}

struct JukeboxReferenceReport: Codable {
    let sceneCount: Int
    let uniqueSceneSeeds: Int
    let blockCount: Int
    let finite: Bool
    let peak: Float
    let truePeak: Float
    let lowStereoCorrelation: Float
    let maxBoundaryDelta: Float
    let sampleHash: String
    let allPass: Bool
}

func writeWAV(_ rendered: RenderedBar, to url: URL) throws {
    try writeWAV(left: rendered.leftSamples, right: rendered.rightSamples, sampleRate: rendered.sampleRate, to: url)
}

func writeWAV(left: [Float], right: [Float], sampleRate: Double, gain: Float = 1, to url: URL) throws {
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
