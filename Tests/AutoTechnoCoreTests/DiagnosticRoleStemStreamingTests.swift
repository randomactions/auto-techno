import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Bounded same-pass diagnostic stem streaming", .serialized)
struct DiagnosticRoleStemStreamingTests {
    private func planWithSixteenBars() throws -> AutonomousPhrasePlan {
        let director = AutonomousSessionDirector(rootSeed: 42)
        var state = director.initialState()
        for _ in 0..<32 {
            let plan = director.plan(from: state)
            if plan.barCount == 16 { return plan }
            state.advancePlanning(using: plan)
        }
        throw DiagnosticRoleStemCaptureError.invalidInput
    }

    private func temporaryParent() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "autotechno-stream-test-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    @Test("Streamed files preserve all 32 same-pass channels, PCM and ending state")
    func samePassRoundTrip() throws {
        let plan = try planWithSixteenBars()
        let graph = DSPGraphGenerator.safePlan(sessionSeed: 42)
        var referenceState = RenderState(); var referenceGraph = GeneratedDSPContinuationState()
        let retained = try #require(AutonomousPhraseRenderer.renderProductIfNotCancelled(
            plan: plan, graph: graph, sampleRate: 8_000, state: &referenceState,
            graphState: &referenceGraph, diagnosticRoleStemCapture: true,
            cancellationRequested: { false }))
        let parent = try temporaryParent(); defer { try? FileManager.default.removeItem(at: parent) }
        let spool = try DiagnosticRoleStemCaptureSpool(parentDirectory: parent, plan: plan, sampleRate: 8_000)
        var render = RenderState(); var dsp = GeneratedDSPContinuationState()
        let streamed = try #require(AutonomousPhraseRenderer.renderProductIfNotCancelled(
            plan: plan, graph: graph, sampleRate: 8_000, state: &render, graphState: &dsp,
            diagnosticRoleStemSink: { spool.append($0, block: $1) },
            cancellationRequested: { false }))
        let draft = try #require(spool.finish())
        #expect(DiagnosticRoleStemChannel.allCases.count == 32)
        #expect(streamed.diagnosticRoleStemCaptures.isEmpty)
        #expect(streamed.blocks == retained.blocks)
        #expect(render == referenceState && dsp == referenceGraph)
        #expect(streamed.repeatHoldEvolutionCandidates.count == retained.repeatHoldEvolutionCandidates.count)
        for (actual, reference) in zip(streamed.repeatHoldEvolutionCandidates,
                                      retained.repeatHoldEvolutionCandidates) {
            #expect(actual.patternFamily == reference.patternFamily)
            let exact = actual.blocks == reference.blocks
            #expect(exact)
        }
        #expect(draft.records.count == 16)
        for (index, capture) in retained.diagnosticRoleStemCaptures.enumerated() {
            for channel in DiagnosticRoleStemChannel.allCases {
                let actual = try draft.readChannel(barIndex: index, channel: channel)
                let exact = actual == capture.samples(for: channel)
                #expect(exact)
            }
        }
        #expect(draft.maximumWriteChunkByteCount <= DiagnosticRoleStemCaptureSpool.maximumWriteChunkBytes)
        #expect(draft.planFingerprint == AutonomousCandidateFingerprint.plan(plan))

        #expect(draft.schemaVersion == 1 && draft.channelOrder == DiagnosticRoleStemChannel.allCases)
        #expect(throws: DiagnosticRoleStemCaptureError.invalidInput) {
            try draft.readChannel(barIndex: -1, channel: .fullKick)
        }
        #expect(throws: DiagnosticRoleStemCaptureError.invalidInput) {
            try draft.readChannel(barIndex: 16, channel: .fullKick)
        }
        // Same-size corruption must fail the original channel hash. Truncation
        // must fail the complete bar payload size before any samples are read.
        let corrupt = try FileHandle(forUpdating: draft.directory.appendingPathComponent("bar-0.f32"))
        let original = try #require(try corrupt.read(upToCount: 1)?.first)
        try corrupt.seek(toOffset: 0)
        try corrupt.write(contentsOf: Data([original ^ 1]))
        try corrupt.close()
        #expect(throws: DiagnosticRoleStemCaptureError.invalidInput) {
            try draft.readChannel(barIndex: 0, channel: .fullDryCenterReference)
        }
        let truncated = try FileHandle(forUpdating: draft.directory.appendingPathComponent("bar-1.f32"))
        try truncated.truncate(atOffset: 1)
        try truncated.close()
        #expect(throws: DiagnosticRoleStemCaptureError.invalidInput) {
            try draft.readChannel(barIndex: 1, channel: .fullKick)
        }

        let firstCapture = try #require(retained.diagnosticRoleStemCaptures.first)
        let firstBlock = try #require(retained.blocks.first)
        let sibling = parent.appendingPathComponent("unrelated-marker")
        try Data([42]).write(to: sibling)
        let repeated = try DiagnosticRoleStemCaptureSpool(parentDirectory: parent, plan: plan, sampleRate: 8_000)
        #expect(repeated.append(firstCapture, block: firstBlock))
        #expect(!repeated.append(firstCapture, block: firstBlock))
        #expect(repeated.failureCode == "capture-mismatch" && repeated.finish() == nil)
        #expect(!FileManager.default.fileExists(atPath: repeated.directory.path))
        #expect(try Data(contentsOf: sibling) == Data([42]))
        let unordered = try DiagnosticRoleStemCaptureSpool(parentDirectory: parent, plan: plan, sampleRate: 8_000)
        #expect(!unordered.append(retained.diagnosticRoleStemCaptures[1], block: retained.blocks[1]))
        #expect(unordered.failureCode == "capture-mismatch" && unordered.finish() == nil)
        #expect(!FileManager.default.fileExists(atPath: unordered.directory.path))
        let wrongRate = try DiagnosticRoleStemCaptureSpool(parentDirectory: parent, plan: plan, sampleRate: 44_100)
        #expect(!wrongRate.append(firstCapture, block: firstBlock))
        #expect(wrongRate.failureCode == "capture-mismatch" && wrongRate.finish() == nil)
        #expect(!FileManager.default.fileExists(atPath: wrongRate.directory.path))
    }

    private func nativeReference(_ plan: AutonomousPhrasePlan, rate: Double) throws
        -> (blocks: [String], render: String, graph: String, variants: [[String]]) {
        var state = RenderState(); var graph = GeneratedDSPContinuationState()
        let result = try #require(AutonomousPhraseRenderer.renderProductIfNotCancelled(
            plan: plan, graph: DSPGraphGenerator.safePlan(sessionSeed: 42), sampleRate: rate,
            state: &state, graphState: &graph, cancellationRequested: { false }))
        // Only reduced hashes leave this scope. Reference PCM/state arrays die
        // before the streamed render begins; this is not a prepared live source.
        return (result.blocks.map { ExactPCMFingerprint.stereo(left: $0.left, right: $0.right) },
            AutonomousCandidateFingerprint.renderState(state),
            AutonomousCandidateFingerprint.generatedDSPState(graph),
            result.repeatHoldEvolutionCandidates.map { candidate in
                candidate.blocks.map { ExactPCMFingerprint.stereo(left: $0.left, right: $0.right) }
            })
    }

    @Test("Sixteen native bars retain bounded capture storage while exporting every tap",
          arguments: [44_100.0, 48_000.0])
    func nativeBoundedCapture(sampleRate: Double) throws {
        let plan = try planWithSixteenBars()
        let reference = try nativeReference(plan, rate: sampleRate)
        let parent = try temporaryParent(); defer { try? FileManager.default.removeItem(at: parent) }
        let spool = try DiagnosticRoleStemCaptureSpool(parentDirectory: parent, plan: plan,
            sampleRate: sampleRate)
        let storageProbe = PreparationWorkingStorageProbe()
        var state = RenderState(); var graph = GeneratedDSPContinuationState()
        let result = try #require(AutonomousPhraseRenderer.renderProductIfNotCancelled(
            plan: plan, graph: DSPGraphGenerator.safePlan(sessionSeed: 42), sampleRate: sampleRate,
            state: &state, graphState: &graph,
            diagnosticRoleStemSink: { spool.append($0, block: $1) },
            workingStorageProbe: storageProbe,
            cancellationRequested: { false }))
        #expect(result.blocks.map { ExactPCMFingerprint.stereo(left: $0.left, right: $0.right) }
            == reference.blocks)
        #expect(AutonomousCandidateFingerprint.renderState(state) == reference.render)
        #expect(AutonomousCandidateFingerprint.generatedDSPState(graph) == reference.graph)
        #expect(result.repeatHoldEvolutionCandidates.map { candidate in
            candidate.blocks.map { ExactPCMFingerprint.stereo(left: $0.left, right: $0.right) }
        } == reference.variants)
        #expect(storageProbe.valid && storageProbe.observationCount == plan.barCount * 4)
        let snapshots = storageProbe.snapshots
        #expect(snapshots.map(\.phase) == ["bar-delivery", "full-voice-return",
            "graph-pump-return", "protected-voice-return"])
        #expect(snapshots.allSatisfy { $0.valid && $0.uniqueBufferCapacityBytes > 0 &&
            $0.typedMetadataHeadroomBytes > 0 &&
            $0.ownerRecords.contains { $0.owner.hasPrefix("workspace.") } &&
            $0.ownerRecords.contains { $0.owner.hasPrefix("current.") } &&
            $0.ownerRecords.contains { $0.aliasOf != nil } })
        let delivery = try #require(snapshots.first { $0.phase == "bar-delivery" })
        #expect(delivery.ownerRecords.filter { $0.owner.hasPrefix("capture.") }.count == 32)
        #expect(delivery.ownerRecords.contains { $0.owner.hasPrefix("hold.") })
        let snapshotJSON = try JSONEncoder().encode(snapshots)
        let storageControl: [String: Any] = [
            "schema": "autotechno-render-boundary-storage-control.v1",
            "sampleRate": sampleRate, "barCount": plan.barCount,
            "observations": storageProbe.observationCount,
            "snapshots": try JSONSerialization.jsonObject(with: snapshotJSON),
            "exactPCMStateAndHoldProducts": true,
            "completeWorkingSetQualification": false,
            "instrumentationMayExtendObservedLifetimes": true,
            "uncovered": ["inner-voice-and-graph-transients", "analysis",
                "encoding-and-heap-metadata", "initial-corrected-overlap",
                "incoming-parent-child-storage", "writer-chunk", "process-RSS", "deadlines"],
        ]
        let storageJSON = try JSONSerialization.data(withJSONObject: storageControl, options: [.sortedKeys])
        print("AUTOTECHNO_RENDER_STORAGE_CONTROL " + String(decoding: storageJSON, as: UTF8.self))
        var draft: DiagnosticRoleStemCaptureDraft? = try #require(spool.finish())
        let records = try #require(draft?.records)
        #expect(result.diagnosticRoleStemCaptures.isEmpty && records.count == 16)
        #expect(records.allSatisfy { $0.channelFingerprints.count == 32 })
        let expectedFrames = Int((240 / AutonomousSessionDirector.bpm * sampleRate).rounded())
        #expect(records.allSatisfy { $0.payloadByteCount == expectedFrames * 32 * 4 })
        #expect(records.reduce(0) { $0 + $1.payloadByteCount } > 128 * 1_024 * 1_024)
        #expect(try #require(draft?.maximumBorrowedNumericCapacityByteCount) <= expectedFrames * 32 * 4 * 2)
        #expect(try #require(draft?.maximumWriteChunkByteCount) <= 64 * 1_024)
        for (index, block) in result.blocks.enumerated() {
            #expect(records[index].outputFingerprint == ExactPCMFingerprint.stereo(left: block.left,
                right: block.right))
            let samples = try #require(draft).readChannel(barIndex: index, channel: .fullKick)
            #expect(samples.count == expectedFrames)
        }
        let control: [String: Any] = [
            "schema": "autotechno-native-bar-stream-control.v1",
            "sampleRate": sampleRate, "barCount": records.count, "channelCount": 32,
            "framesPerBar": expectedFrames,
            "totalFilePayloadByteCount": records.reduce(0) { $0 + $1.payloadByteCount },
            "maximumBorrowedCaptureCapacityByteCount": try #require(draft?.maximumBorrowedNumericCapacityByteCount),
            "maximumWriteChunkByteCount": try #require(draft?.maximumWriteChunkByteCount),
            "blockFingerprints": records.map(\.outputFingerprint),
            "endingRenderStateFingerprint": AutonomousCandidateFingerprint.renderState(state),
            "endingGraphStateFingerprint": AutonomousCandidateFingerprint.generatedDSPState(graph),
            "ordinaryBlockFingerprints": reference.blocks,
            "ordinaryEndingRenderStateFingerprint": reference.render,
            "ordinaryEndingGraphStateFingerprint": reference.graph,
            "repeatHoldVariantFingerprints": result.repeatHoldEvolutionCandidates.map { candidate in
                candidate.blocks.map { ExactPCMFingerprint.stereo(left: $0.left, right: $0.right) }
            },
            "ordinaryRepeatHoldVariantFingerprints": reference.variants,
            "completeWorkingSetQualification": false,
            "acceptedSourceOrSuccessorQualification": false,
        ]
        let controlJSON = try JSONSerialization.data(withJSONObject: control, options: [.sortedKeys])
        print("AUTOTECHNO_STEM_STREAM_CONTROL " + String(decoding: controlJSON, as: UTF8.self))
        let directory = try #require(draft?.directory)
        draft = nil
        #expect(!FileManager.default.fileExists(atPath: directory.path))
        // This checks capture ownership only; the full render/chain working
        // set, RSS, deadlines and accepted-source selection remain separate.
    }


    @Test("Invalid routes and dual capture requests refuse before render state advances")
    func invalidDelivery() throws {
        let plan = try planWithSixteenBars()
        let parent = try temporaryParent(); defer { try? FileManager.default.removeItem(at: parent) }
        for rate in [Double.nan, Double.infinity, 7_999, 192_001] {
            #expect(throws: DiagnosticRoleStemCaptureError.invalidInput) {
                try DiagnosticRoleStemCaptureSpool(parentDirectory: parent, plan: plan, sampleRate: rate)
            }
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: parent.path).isEmpty)
        var state = RenderState(); var graph = GeneratedDSPContinuationState()
        let beforeState = state; let beforeGraph = graph
        let result = AutonomousPhraseRenderer.renderProductIfNotCancelled(plan: plan,
            graph: DSPGraphGenerator.safePlan(sessionSeed: 42), sampleRate: 8_000,
            state: &state, graphState: &graph, diagnosticRoleStemCapture: true,
            diagnosticRoleStemSink: { _, _ in
                Issue.record("Conflicting delivery forms must refuse without invoking the sink")
                return true
            }, cancellationRequested: { false })
        #expect(result == nil && state == beforeState && graph == beforeGraph)
    }

    @Test("Incomplete, cancelled and failed writes clean attempt-owned files")
    func failureCleanup() throws {
        let plan = try planWithSixteenBars()
        let parent = try temporaryParent(); defer { try? FileManager.default.removeItem(at: parent) }
        let incomplete = try DiagnosticRoleStemCaptureSpool(parentDirectory: parent, plan: plan,
            sampleRate: 8_000)
        #expect(incomplete.finish() == nil)
        #expect(incomplete.failureCode == "incomplete-capture")
        #expect(!FileManager.default.fileExists(atPath: incomplete.directory.path))
        let cancelled = try DiagnosticRoleStemCaptureSpool(parentDirectory: parent, plan: plan,
            sampleRate: 8_000)
        var state = RenderState(); var graph = GeneratedDSPContinuationState()
        let result = AutonomousPhraseRenderer.renderProductIfNotCancelled(plan: plan,
            graph: DSPGraphGenerator.safePlan(sessionSeed: 42), sampleRate: 8_000,
            state: &state, graphState: &graph,
            diagnosticRoleStemSink: { cancelled.append($0, block: $1,
                cancellationRequested: { true }) }, cancellationRequested: { false })
        #expect(result == nil && cancelled.failureCode == "cancelled")
        #expect(!FileManager.default.fileExists(atPath: cancelled.directory.path))
        let failed = try DiagnosticRoleStemCaptureSpool(parentDirectory: parent, plan: plan,
            sampleRate: 8_000)
        // Remove only this spool's fresh directory to provoke a real file I/O
        // failure. The renderer must not return a partially captured product.
        try FileManager.default.removeItem(at: failed.directory)
        var failedState = RenderState(); var failedGraph = GeneratedDSPContinuationState()
        let missingDirectory = AutonomousPhraseRenderer.renderProductIfNotCancelled(plan: plan,
            graph: DSPGraphGenerator.safePlan(sessionSeed: 42), sampleRate: 8_000,
            state: &failedState, graphState: &failedGraph,
            diagnosticRoleStemSink: { failed.append($0, block: $1) },
            cancellationRequested: { false })
        #expect(missingDirectory == nil && failed.failureCode == "file-create-failed")
        #expect(!FileManager.default.fileExists(atPath: failed.directory.path))
    }
    @Test("Numeric inventory counts unused capacity and COW while deduplicating live aliases")
    func numericStorageAliases() throws {
        var original: [Float] = [1, 2, 3]
        original.reserveCapacity(128)
        let alias = original
        var changed = alias
        changed[0] = 4
        var reservedEmpty: [Float] = []
        reservedEmpty.reserveCapacity(64)
        let doubles: [Double] = [5, 6]
        let bytes: [UInt8] = [7, 8]
        let inventory = NumericStorageInventory()
        inventory.register(original, owner: "original")
        inventory.register(alias, owner: "alias")
        inventory.register(changed, owner: "COW")
        inventory.register(reservedEmpty, owner: "reserved-empty")
        inventory.register(doubles, owner: "double")
        inventory.register(bytes, owner: "byte")
        let snapshot = inventory.snapshot(phase: "live", bar: 0)
        withExtendedLifetime((original, alias, changed, reservedEmpty, doubles, bytes)) {
            #expect(snapshot.valid)
            #expect(snapshot.ownerRecords[1].aliasOf == "original")
            #expect(snapshot.ownerRecords[2].aliasOf == nil)
            #expect(snapshot.ownerRecords[3].elementCount == 0 &&
                snapshot.ownerRecords[3].capacityBytes >= 64 * 4)
            #expect(snapshot.ownerRecords[4].elementStride == 8)
            #expect(snapshot.ownerRecords[5].elementStride == 1)
            #expect(snapshot.uniqueBufferCapacityBytes ==
                (original.capacity + changed.capacity + reservedEmpty.capacity) * 4 +
                doubles.capacity * 8 + bytes.capacity)
        }
    }

    @Test("Probe maxima reset pointer identities per phase and fail closed at finite bounds")
    func numericStorageBounds() throws {
        let samples: [Float] = [1, 2, 3]
        let probe = PreparationWorkingStorageProbe()
        probe.observe(phase: "first", bar: 0) { $0.register(samples, owner: "samples") }
        probe.observe(phase: "second", bar: 1) { $0.register(samples, owner: "samples") }
        probe.observe(phase: "first", bar: 2) { inventory in
            inventory.register(samples, owner: "samples")
            inventory.addTypedMetadataHeadroom(10)
        }
        #expect(probe.valid && probe.observationCount == 3)
        #expect(probe.snapshots.count == 2)
        #expect(probe.snapshots.allSatisfy { $0.uniqueBufferCapacityBytes == samples.capacity * 4 })
        #expect(probe.snapshots.first { $0.phase == "first" }?.bar == 2)
        for index in 2..<PreparationWorkingStorageProbe.maximumPhaseCount {
            probe.observe(phase: "phase-\(index)", bar: index) { _ in }
        }
        #expect(probe.valid && probe.snapshots.count == PreparationWorkingStorageProbe.maximumPhaseCount)
        probe.observe(phase: "overflow", bar: 33) { _ in Issue.record("Phase overflow must refuse") }
        #expect(!probe.valid && probe.snapshots.count == PreparationWorkingStorageProbe.maximumPhaseCount)
        let inventory = NumericStorageInventory()
        for index in 0..<NumericStorageInventory.maximumOwnerCount {
            inventory.register([Float](), owner: "empty-\(index)")
        }
        #expect(inventory.valid)
        inventory.register(samples, owner: "overflow")
        #expect(!inventory.valid)
        let negative = NumericStorageInventory()
        negative.addTypedMetadataHeadroom(-1)
        #expect(!negative.valid)
        let overflow = NumericStorageInventory()
        overflow.addTypedMetadataHeadroom(Int.max)
        overflow.addTypedMetadataHeadroom(1)
        #expect(!overflow.valid)
        let invalidName = PreparationWorkingStorageProbe()
        invalidName.observe(phase: "", bar: 0) { _ in Issue.record("Empty phase must refuse") }
        #expect(!invalidName.valid && invalidName.snapshots.isEmpty)
    }

    @Test("Continuation measurement shares the typed inventory without changing hashes or state")
    func typedStorageIdentity() throws {
        var state = RenderState()
        state.delayBuffer = [1, 2, 3]
        state.delayBuffer.reserveCapacity(128)
        state.pulseEchoBuffer = state.delayBuffer
        state.spatialFDNState.lineOffsets = [0, 2]
        state.spatialFDNState.lineOffsets.reserveCapacity(32)
        state.spatialFDNState.dampingStates = [0.1, 0.2]
        state.spatialFDNState.dampingStates.reserveCapacity(32)
        let graph = GeneratedDSPContinuationState()
        let before = AutonomousTypedFingerprint.renderDSPContinuation(renderState: state,
            generatedDSPState: graph)
        let retainedBytes = AutonomousTypedFingerprint.retainedContinuationNumericByteCount(
            renderState: state, generatedDSPState: graph, cancellationRequested: { false })
        let counted = try #require(retainedBytes)
        let inventory = NumericStorageInventory()
        AutonomousTypedFingerprint.registerContinuationStorage(renderState: state,
            generatedDSPState: graph, inventory: inventory, owner: "first")
        let first = inventory.snapshot(phase: "first", bar: 0)
        let rawFloatCapacity = first.ownerRecords.filter { $0.elementStride == 4 }
            .reduce(0) { $0 + $1.capacityBytes }
        #expect(first.valid && rawFloatCapacity + first.typedMetadataHeadroomBytes == counted)
        #expect(first.ownerRecords.contains { $0.owner.hasSuffix(".pulseEchoBuffer") && $0.aliasOf != nil })
        #expect(first.ownerRecords.contains { $0.owner.hasSuffix(".spatialFDNLineOffsets") &&
            $0.capacityBytes >= 32 * 8 })
        #expect(first.ownerRecords.contains { $0.owner.hasSuffix(".spatialFDNDampingStates") &&
            $0.capacityBytes >= 32 * 8 })
        AutonomousTypedFingerprint.registerContinuationStorage(renderState: state,
            generatedDSPState: graph, inventory: inventory, owner: "alias")
        let second = inventory.snapshot(phase: "second", bar: 0)
        #expect(second.valid && second.uniqueBufferCapacityBytes == first.uniqueBufferCapacityBytes)
        #expect(second.typedMetadataHeadroomBytes == first.typedMetadataHeadroomBytes * 2)
        #expect(AutonomousTypedFingerprint.renderDSPContinuation(renderState: state,
            generatedDSPState: graph) == before)
        withExtendedLifetime((state, graph)) {}
    }

}
