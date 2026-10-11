import AutoTechnoCore
import Foundation

/// Fixed logical taps from one canonical render pass. They are not additive
/// tracks or another renderer. Every channel is exported, including silence.
package enum DiagnosticRoleStemChannel: String, CaseIterable, Codable, Sendable {
    package static let schemaVersion = 1
    case fullDryCenterReference
    case fullDryUpperReference
    case fullKick
    case fullFoundation
    case fullModalFoundation
    case fullPercussion
    case fullUpperTonal
    case fullAtmosphere
    case fullProtectedFoundation
    case fullSourceLeft
    case fullSourceRight
    case protectedDryCenterReference
    case protectedDryUpperReference
    case protectedKick
    case protectedFoundation
    case protectedModalFoundation
    case protectedPercussion
    case protectedUpperTonal
    case protectedAtmosphere
    case protectedProtectedFoundation
    case protectedSourceLeft
    case protectedSourceRight
    case graphInputLeft
    case graphInputRight
    case processedUpperLeft
    case processedUpperRight
    case preClimaxMixLeft
    case preClimaxMixRight
    case outputSafetyResidualLeft
    case outputSafetyResidualRight
    case terminalProcessingResidualLeft
    case terminalProcessingResidualRight
}

extension AutonomousBarRoleStemCapture {
    package func samples(for channel: DiagnosticRoleStemChannel) -> [Float] {
        switch channel {
        case .fullDryCenterReference: full.dryCenterReference
        case .fullDryUpperReference: full.dryUpperReference
        case .fullKick: full.kick
        case .fullFoundation: full.foundation
        case .fullModalFoundation: full.modalFoundation
        case .fullPercussion: full.percussion
        case .fullUpperTonal: full.upperTonal
        case .fullAtmosphere: full.atmosphere
        case .fullProtectedFoundation: full.protectedFoundation
        case .fullSourceLeft: full.sourceLeft
        case .fullSourceRight: full.sourceRight
        case .protectedDryCenterReference: protectedRhythm.dryCenterReference
        case .protectedDryUpperReference: protectedRhythm.dryUpperReference
        case .protectedKick: protectedRhythm.kick
        case .protectedFoundation: protectedRhythm.foundation
        case .protectedModalFoundation: protectedRhythm.modalFoundation
        case .protectedPercussion: protectedRhythm.percussion
        case .protectedUpperTonal: protectedRhythm.upperTonal
        case .protectedAtmosphere: protectedRhythm.atmosphere
        case .protectedProtectedFoundation: protectedRhythm.protectedFoundation
        case .protectedSourceLeft: protectedRhythm.sourceLeft
        case .protectedSourceRight: protectedRhythm.sourceRight
        case .graphInputLeft: graphInputLeft
        case .graphInputRight: graphInputRight
        case .processedUpperLeft: processedUpperLeft
        case .processedUpperRight: processedUpperRight
        case .preClimaxMixLeft: preClimaxMixLeft
        case .preClimaxMixRight: preClimaxMixRight
        case .outputSafetyResidualLeft: outputSafetyResidualLeft
        case .outputSafetyResidualRight: outputSafetyResidualRight
        case .terminalProcessingResidualLeft: terminalProcessingResidualLeft
        case .terminalProcessingResidualRight: terminalProcessingResidualRight
        }
    }

    /// Actual borrowed capture storage, deduplicated by live array identity.
    /// Count capacity, not occupied frames; this is not total render/RSS proof.
    package var uniqueNumericCapacityByteCount: Int {
        var pointers = Set<UInt>()
        var bytes = 0
        for channel in DiagnosticRoleStemChannel.allCases {
            let samples = samples(for: channel)
            samples.withUnsafeBufferPointer { buffer in
                guard let base = buffer.baseAddress, samples.capacity > 0 else { return }
                if pointers.insert(UInt(bitPattern: base)).inserted {
                    let capacityBytes = samples.capacity.multipliedReportingOverflow(by: MemoryLayout<Float>.stride)
                    let total = bytes.addingReportingOverflow(capacityBytes.partialValue)
                    bytes = capacityBytes.overflow || total.overflow ? Int.max : total.partialValue
                }
            }
        }
        return bytes
    }
}

package struct DiagnosticRoleStemBarRecord: Equatable, Sendable {
    package let bar: Int
    package let frameCount: Int
    package let channelFingerprints: [String]
    package let outputFingerprint: String
    package let payloadByteCount: Int
}

/// Owns only local files and bounded metadata. It never enters a playback
/// request, affects evidence, or establishes accepted-source authority.
package final class DiagnosticRoleStemCaptureDraft: @unchecked Sendable {
    package let schemaVersion = DiagnosticRoleStemChannel.schemaVersion
    package let channelOrder = DiagnosticRoleStemChannel.allCases
    package let directory: URL
    package let planFingerprint: String
    package let sampleRate: Double
    package let records: [DiagnosticRoleStemBarRecord]
    package let maximumBorrowedNumericCapacityByteCount: Int
    package let maximumWriteChunkByteCount: Int

    fileprivate init(directory: URL, planFingerprint: String, sampleRate: Double,
        records: [DiagnosticRoleStemBarRecord], maximumBorrowedNumericCapacityByteCount: Int,
        maximumWriteChunkByteCount: Int) {
        self.directory = directory; self.planFingerprint = planFingerprint
        self.sampleRate = sampleRate; self.records = records
        self.maximumBorrowedNumericCapacityByteCount = maximumBorrowedNumericCapacityByteCount
        self.maximumWriteChunkByteCount = maximumWriteChunkByteCount
    }

    deinit { try? FileManager.default.removeItem(at: directory) }

    package func readChannel(barIndex: Int, channel: DiagnosticRoleStemChannel) throws -> [Float] {
        guard records.indices.contains(barIndex),
            let ordinal = DiagnosticRoleStemChannel.allCases.firstIndex(of: channel) else {
            throw DiagnosticRoleStemCaptureError.invalidInput
        }
        let record = records[barIndex]
        let url = directory.appendingPathComponent("bar-\(barIndex).f32")
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (attributes[.size] as? NSNumber)?.intValue == record.payloadByteCount else {
            throw DiagnosticRoleStemCaptureError.invalidInput
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let bytes = record.frameCount * MemoryLayout<Float>.stride
        try handle.seek(toOffset: UInt64(ordinal * bytes))
        guard let data = try handle.read(upToCount: bytes), data.count == bytes else {
            throw DiagnosticRoleStemCaptureError.invalidInput
        }
        let samples = data.withUnsafeBytes { buffer in
            (0..<record.frameCount).map { Float(bitPattern:
                UInt32(littleEndian: buffer.loadUnaligned(fromByteOffset: $0 * 4, as: UInt32.self))) }
        }
        guard ExactPCMFingerprint.mono(samples) == record.channelFingerprints[ordinal] else {
            throw DiagnosticRoleStemCaptureError.invalidInput
        }
        return samples
    }
}

package enum DiagnosticRoleStemCaptureError: Error { case invalidInput, ioFailure }

/// Single-writer, detached-only spool. It consumes one same-pass bar, then
/// releases every borrowed array before another bar is rendered. Cancellation,
/// malformed/incomplete input and I/O failure remove this attempt's files.
/// A finished draft remains diagnostic-only until the preparation transaction
/// binds it to its selected candidate and exact owned successor.
package final class DiagnosticRoleStemCaptureSpool: @unchecked Sendable {
    package static let maximumWriteChunkBytes = 64 * 1_024
    package let directory: URL
    package let planFingerprint: String
    package let sampleRate: Double
    private let startBar: Int
    private let barCount: Int
    private let framesPerBar: Int
    private var records: [DiagnosticRoleStemBarRecord] = []
    private var open = true
    private var transferred = false
    package private(set) var maximumBorrowedNumericCapacityByteCount = 0
    package private(set) var maximumWriteChunkByteCount = 0
    package private(set) var failureCode: String?

    package init(parentDirectory: URL, plan: AutonomousPhrasePlan, sampleRate: Double) throws {
        guard sampleRate.isFinite,
            (QualityQualificationContract.minimumSupportedSampleRate...QualityQualificationContract.maximumSupportedSampleRate).contains(sampleRate),
            (1...QualityQualificationContract.maximumPhraseBars).contains(plan.barCount),
            MemoryLayout<Float>.stride == 4, UInt16(1).littleEndian == 1 else {
            throw DiagnosticRoleStemCaptureError.invalidInput
        }
        self.sampleRate = sampleRate; startBar = plan.startBar; barCount = plan.barCount
        framesPerBar = max(1, Int((240 / AutonomousSessionDirector.bpm * sampleRate).rounded()))
        planFingerprint = AutonomousCandidateFingerprint.plan(plan)
        directory = parentDirectory.appendingPathComponent("stem-attempt-" + UUID().uuidString,
            isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        records.reserveCapacity(barCount)
    }

    deinit { if !transferred { try? FileManager.default.removeItem(at: directory) } }

    @discardableResult package func discard() -> Bool {
        open = false
        guard !transferred else { return false }
        do {
            if FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
            records.removeAll(keepingCapacity: false)
            return true
        } catch { failureCode = "cleanup-failed"; return false }
    }

    package func append(_ capture: AutonomousBarRoleStemCapture, block: RenderBlock,
        cancellationRequested: @Sendable () -> Bool = { false }) -> Bool {
        guard open else { return false }
        guard !cancellationRequested(), records.count < barCount,
            capture.bar == startBar + records.count, capture.bar == block.bar,
            capture.sampleRate == sampleRate, capture.frameCount == framesPerBar,
            block.left.count == framesPerBar, block.right.count == framesPerBar,
            capture.frameCountsAreAligned, capture.samplesAreFinite,
            capture.uniqueNumericCapacityByteCount <= framesPerBar * 32 * 4 * 2,
            block.left.allSatisfy(\.isFinite), block.right.allSatisfy(\.isFinite) else {
            failureCode = cancellationRequested() ? "cancelled" : "capture-mismatch"
            discard(); return false
        }
        maximumBorrowedNumericCapacityByteCount = max(maximumBorrowedNumericCapacityByteCount,
            capture.uniqueNumericCapacityByteCount)
        let url = directory.appendingPathComponent("bar-\(records.count).f32")
        guard !FileManager.default.fileExists(atPath: url.path),
            FileManager.default.createFile(atPath: url.path, contents: nil) else {
            failureCode = "file-create-failed"; discard(); return false
        }
        do {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            var fingerprints: [String] = []
            fingerprints.reserveCapacity(DiagnosticRoleStemChannel.allCases.count)
            for channel in DiagnosticRoleStemChannel.allCases {
                guard !cancellationRequested() else { throw DiagnosticRoleStemCaptureError.invalidInput }
                let samples = capture.samples(for: channel)
                try samples.withUnsafeBytes { raw in
                    var offset = 0
                    while offset < raw.count {
                        guard !cancellationRequested() else { throw DiagnosticRoleStemCaptureError.invalidInput }
                        let count = min(Self.maximumWriteChunkBytes, raw.count - offset)
                        // Foundation owns at most one byte chunk; no Float array
                        // or entire bar/phrase is copied into an encoding buffer.
                        let chunk = Data(bytes: raw.baseAddress!.advanced(by: offset), count: count)
                        maximumWriteChunkByteCount = max(maximumWriteChunkByteCount, chunk.count)
                        try handle.write(contentsOf: chunk)
                        offset += count
                    }
                }
                fingerprints.append(ExactPCMFingerprint.mono(samples))
            }
            try handle.close()
            guard !cancellationRequested() else { throw DiagnosticRoleStemCaptureError.invalidInput }
            records.append(DiagnosticRoleStemBarRecord(bar: capture.bar, frameCount: framesPerBar,
                channelFingerprints: fingerprints,
                outputFingerprint: ExactPCMFingerprint.stereo(left: block.left, right: block.right),
                payloadByteCount: framesPerBar * 4 * DiagnosticRoleStemChannel.allCases.count))
            return true
        } catch {
            failureCode = cancellationRequested() ? "cancelled" : "file-write-failed"
            discard(); return false
        }
    }

    package func finish() -> DiagnosticRoleStemCaptureDraft? {
        guard open, records.count == barCount else {
            if open { failureCode = "incomplete-capture"; discard() }
            return nil
        }
        open = false; transferred = true
        return DiagnosticRoleStemCaptureDraft(directory: directory, planFingerprint: planFingerprint,
            sampleRate: sampleRate, records: records,
            maximumBorrowedNumericCapacityByteCount: maximumBorrowedNumericCapacityByteCount,
            maximumWriteChunkByteCount: maximumWriteChunkByteCount)
    }
}


/// Reduced association made only after the normal detached chain admits the
/// actual source and its exact child. It is not live-playback/callback evidence.
package struct DiagnosticRoleStemSelectedBinding: Sendable {
    package let draft: DiagnosticRoleStemCaptureDraft
    package let sourceIdentityFingerprint: String
    package let planFingerprint: String
    package let candidateFingerprint: String
    package let transactionFingerprint: String
    package let replayFingerprint: String?
    package let graphFingerprint: String
    package let routeFingerprint: String
    package let endingRenderStateFingerprint: String
    package let endingGraphStateFingerprint: String
    package let selectedAttemptKind: AutonomousCandidateAttemptKind
    package let forceHomeUpperTimbre: Bool
    package let qualifiedChildIdentityFingerprint: String?
}

/// One opt-in detached preparation transaction. Normal hosts never instantiate
/// this owner. It retains files/private immutable aliases during reverse proof
/// finalization and exposes only reduced bindings after the entire chain passes.
/// Single writer: not safe for concurrent prepares/resolutions or export reads
/// before sealing. No mutable file owner enters scheduled playback products.
package final class DiagnosticRoleStemCaptureSession: @unchecked Sendable {
    private struct Selected {
        let source: PreparedAutonomousPhrase
        let draft: DiagnosticRoleStemCaptureDraft
    }
    private enum State { case fresh, collecting, sealed, discarded }
    // More than the maximum two attempts per source admitted by the unchanged
    // full-capture reservations, even at minimum rate and one authored bar.
    private static let maximumAttemptDirectoryCount = 256
    package let parentDirectory: URL
    private var state: State = .fresh
    private var ownedDirectories: [URL] = []
    private var selected: [Selected] = []
    package private(set) var bindings: [DiagnosticRoleStemSelectedBinding] = []
    package private(set) var discardedSupersededDraftCount = 0
    package private(set) var failureCode: String?

    package init(parentDirectory: URL) {
        self.parentDirectory = parentDirectory
    }

    deinit { removeOwnedFiles() }

    package var isSealed: Bool { state == .sealed }

    /// Only the shared chain owner begins this session. Reuse refuses without
    /// modifying an earlier sealed export; this is a single-use transaction.
    package func begin() -> Bool {
        guard state == .fresh else { return false }
        state = .collecting
        return true
    }

    package func makeSpool(plan: AutonomousPhrasePlan, sampleRate: Double) throws
        -> DiagnosticRoleStemCaptureSpool {
        guard state == .collecting,
            ownedDirectories.count < Self.maximumAttemptDirectoryCount else {
            failureCode = "capture-session-unavailable"
            throw DiagnosticRoleStemCaptureError.invalidInput
        }
        let spool = try DiagnosticRoleStemCaptureSpool(parentDirectory: parentDirectory,
            plan: plan, sampleRate: sampleRate)
        ownedDirectories.append(spool.directory)
        return spool
    }

    package func discardDraft(_ draft: DiagnosticRoleStemCaptureDraft) -> Bool {
        do {
            if FileManager.default.fileExists(atPath: draft.directory.path) {
                try FileManager.default.removeItem(at: draft.directory)
            }
            ownedDirectories.removeAll { $0 == draft.directory }
            discardedSupersededDraftCount += 1
            return true
        } catch { failureCode = "capture-cleanup-failed"; return false }
    }

    /// Called by the canonical finalizer for its actual final object, never a
    /// prospective preview or reconstructed lookalike. Other private aliases
    /// may exist until this call unwinds but own no distinct mutable PCM.
    package func stage(_ draft: DiagnosticRoleStemCaptureDraft,
        source: PreparedAutonomousPhrase) -> Bool {
        guard state == .collecting, source.commitEligible,
            source.preparedValidationRequired, source.preparedValidation != nil,
            ownedDirectories.contains(draft.directory),
            !selected.contains(where: { $0.source === source || $0.draft === draft }),
            draft.planFingerprint == AutonomousCandidateFingerprint.plan(source.plan),
            draft.sampleRate == source.selectedCandidateEvidence.routeContinuation.sampleRate,
            draft.records.count == source.blocks.count,
            let index = source.candidateEvaluation.selectedAttemptIndex,
            source.candidateEvaluation.attempts.indices.contains(index),
            source.candidateEvaluation.attempts[index].vector == source.selectedCandidateEvidence,
            source.candidateEvaluation.attempts[index].forceHomeUpperTimbre == source.usedHomeTimbreCorrection
        else { failureCode = "capture-selected-source-mismatch"; return false }
        for (record, block) in zip(draft.records, source.blocks) {
            guard record.bar == block.bar, record.frameCount == block.left.count,
                record.channelFingerprints.count == DiagnosticRoleStemChannel.allCases.count,
                record.outputFingerprint == ExactPCMFingerprint.stereo(left: block.left, right: block.right)
            else { failureCode = "capture-selected-pcm-mismatch"; return false }
        }
        selected.append(Selected(source: source, draft: draft))
        return true
    }

    /// The shared owner supplies the actual root and its flat retained chain,
    /// after every reverse validation and long-horizon/presentation package.
    /// Object identity prevents a bit-identical replacement from claiming the
    /// selected pass. Required children must be these exact admitted objects.
    package func seal(admittedSources: [PreparedAutonomousPhrase],
        cancellationRequested: @Sendable () -> Bool = { false }) -> Bool {
        guard !cancellationRequested(), state == .collecting, !admittedSources.isEmpty,
            admittedSources.count == selected.count else {
            failureCode = "capture-chain-incomplete"; return false
        }
        var result: [DiagnosticRoleStemSelectedBinding] = []
        result.reserveCapacity(admittedSources.count)
        for (ordinal, source) in admittedSources.enumerated() {
            guard !cancellationRequested(), source.commitEligible, source.preparedValidationRequired,
                let entry = selected.first(where: { $0.source === source }),
                let proof = source.preparedValidation,
                let attemptIndex = source.candidateEvaluation.selectedAttemptIndex,
                source.candidateEvaluation.attempts.indices.contains(attemptIndex) else {
                failureCode = "capture-chain-source-mismatch"; return false
            }
            let child = ordinal + 1 < admittedSources.count ? admittedSources[ordinal + 1] : nil
            if proof.requiresQualifiedSuccessor {
                guard let child, proof.qualifiedSuccessor === child else {
                    failureCode = "capture-chain-child-mismatch"; return false
                }
            } else {
                guard child == nil, proof.qualifiedSuccessor == nil else {
                    failureCode = "capture-chain-leaf-mismatch"; return false
                }
            }
            guard !result.contains(where: { $0.sourceIdentityFingerprint ==
                source.preparedValidationSourceIdentityFingerprint }),
                let identity = source.preparedValidationSourceIdentityFingerprint else {
                failureCode = "capture-chain-identity-mismatch"; return false
            }
            let attempt = source.candidateEvaluation.attempts[attemptIndex]
            result.append(DiagnosticRoleStemSelectedBinding(draft: entry.draft,
                sourceIdentityFingerprint: identity,
                planFingerprint: entry.draft.planFingerprint,
                candidateFingerprint: source.selectedCandidateEvidence.fullMix.sampleHash,
                transactionFingerprint: source.candidateEvaluationFingerprint,
                replayFingerprint: source.preparationReplayFingerprint,
                graphFingerprint: AutonomousCandidateFingerprint.graph(source.graph),
                routeFingerprint: source.selectedCandidateEvidence.routeContinuation.routeFingerprint,
                endingRenderStateFingerprint: AutonomousCandidateFingerprint.renderState(source.endingRenderState),
                endingGraphStateFingerprint: AutonomousCandidateFingerprint.generatedDSPState(source.endingGraphState),
                selectedAttemptKind: attempt.kind, forceHomeUpperTimbre: attempt.forceHomeUpperTimbre,
                qualifiedChildIdentityFingerprint: child?.preparedValidationSourceIdentityFingerprint))
        }
        guard !cancellationRequested() else { failureCode = "capture-cancelled"; return false }
        bindings = result
        selected.removeAll(keepingCapacity: false)
        // Each sealed draft owns its files independently of session lifetime.
        // Never delete them when a reader retains a binding after this session.
        ownedDirectories.removeAll(keepingCapacity: false)
        state = .sealed
        return true
    }

    package func discard() {
        // Explicit failed-chain cleanup applies even while another private
        // pending finalizer still holds a draft alias. No partial export escapes.
        guard state != .sealed else { return }
        state = .discarded
        selected.removeAll(keepingCapacity: false)
        bindings.removeAll(keepingCapacity: false)
        removeOwnedFiles()
    }

    private func removeOwnedFiles() {
        var remaining: [URL] = []
        for directory in ownedDirectories {
            do {
                if FileManager.default.fileExists(atPath: directory.path) {
                    try FileManager.default.removeItem(at: directory)
                }
            } catch { remaining.append(directory); failureCode = "capture-cleanup-failed" }
        }
        ownedDirectories = remaining
    }
}
