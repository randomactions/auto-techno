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

    static func checkAnalyzerStorage(_ probe: PreparationWorkingStorageProbe,
        prefix: String, sampleRate: Double) throws {
        #expect(probe.valid && probe.snapshots.allSatisfy { $0.valid })
        let expected: [String: [String]] = [
            "true-peak": ["true-peak.left.history", "true-peak.right.history"],
            "loudness.rings": ["loudness.momentary.ring", "loudness.short-term.ring",
                "loudness.momentary.emitted", "loudness.short-term.emitted"],
            "loudness.values": ["loudness.momentary-values", "loudness.short-term-values"],
            "loudness.gates": ["loudness.momentary-loudness", "loudness.absolute-gated",
                "loudness.relative-gated", "loudness.short-term-loudness",
                "loudness.range-candidates", "loudness.range-population"],
            "perceptual.workspace": ["perceptual.ring", "perceptual.real", "perceptual.imaginary",
                "perceptual.previous-magnitude"],
            "perceptual.evidence": ["perceptual.evidence-values"],
            "preflight.movement": ["preflight.loudness-values", "preflight.spectral-values",
                "preflight.transient-values", "preflight.crest-values"]]
        for (phase, owners) in expected {
            let snapshot = try #require(probe.snapshots.first { $0.phase == prefix + "." + phase })
            for owner in owners {
                let record = try #require(snapshot.ownerRecords.first { $0.owner == owner })
                #expect(record.elementStride == 8 && record.elementCapacity >= record.elementCount)
                #expect(record.capacityBytes == record.elementCapacity * record.elementStride)
            }
        }
        let peak = try #require(probe.snapshots.first { $0.phase == prefix + ".true-peak" })
        #expect(peak.ownerRecords.filter { $0.owner.hasPrefix("true-peak.") }.allSatisfy { $0.elementCount == 12 })
        let rings = try #require(probe.snapshots.first { $0.phase == prefix + ".loudness.rings" })
        #expect(rings.ownerRecords.first { $0.owner == "loudness.momentary.ring" }?.elementCount == Int((sampleRate * 0.4).rounded()))
        #expect(rings.ownerRecords.first { $0.owner == "loudness.short-term.ring" }?.elementCount == Int((sampleRate * 3).rounded()))
        #expect(rings.ownerRecords.first { $0.owner == "loudness.momentary.emitted" }?.elementCount == 320)
        #expect(rings.ownerRecords.first { $0.owner == "loudness.short-term.emitted" }?.elementCount == 32)
        let spectrum = try #require(probe.snapshots.first { $0.phase == prefix + ".perceptual.workspace" })
        #expect(spectrum.ownerRecords.first { $0.owner == "perceptual.ring" }?.elementCount ==
            StreamingPerceptualEvidenceAnalyzer.analysisFrameCount(sampleRate: sampleRate))
        #expect(spectrum.ownerRecords.first { $0.owner == "perceptual.real" }?.elementCount ==
            StreamingPerceptualEvidenceAnalyzer.fftFrameCount(sampleRate: sampleRate))
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

    @Test("Native echo and dust helper observations preserve PCM, evidence and exhausted fallback",
          arguments: [44_100.0, 48_000.0])
    func nativeHelperStorage(sampleRate: Double) throws {
        let frames = Int((240 / AutonomousSessionDirector.bpm * sampleRate).rounded())
        let source: [Float] = (0..<frames).map { index in
            Float(sin(Double(index) * 0.031) * exp(-Double(index % 4096) / 420) * 0.14)
        }
        let retained: [Float] = [0.3, 0.2, 0.1]
        let cases: [PercussionEchoTextureArticulation?] = [nil,
            .init(relation: .gatedEcho, inputStep: 3, outputStartStep: 7, outputEndStep: 11),
            .init(relation: .anticipationSwell, inputStep: 3, outputStartStep: 4, outputEndStep: 12),
            .init(relation: .spatialDust, inputStep: 1, outputStartStep: 0, outputEndStep: 16,
                worldID: 91, cadencePhase: 1, gapPhase: 3, dominantSide: .left)]
        for (index, articulation) in cases.enumerated() {
            var ordinary = [Float](repeating: 0, count: frames)
            var ordinaryLeft = ordinary, ordinaryRight = ordinary
            let ordinaryEcho = PercussionEchoTextureVoice.render(source: source, returnStem: &ordinary,
                articulation: articulation, bpm: AutonomousSessionDirector.bpm, sampleRate: sampleRate)
            let ordinaryDust = PercussionEchoTextureVoice.renderSpatialDust(source: source,
                leftReturn: &ordinaryLeft, rightReturn: &ordinaryRight,
                articulation: articulation, sampleRate: sampleRate)
            var observed = [Float](repeating: 0, count: frames)
            var observedLeft = observed, observedRight = observed
            let probe = PreparationWorkingStorageProbe()
            let scope = PreparationStorageObservation(probe: probe, prefix: "helper", bar: index,
                additionalMaximumPhase: "corrective-overlap") { inventory in
                inventory.register(source, owner: "outer.source")
                inventory.register(retained, owner: "outer.retained")
                withExtendedLifetime((source, retained)) {}
            }
            let echo = PercussionEchoTextureVoice.render(source: source, returnStem: &observed,
                articulation: articulation, bpm: AutonomousSessionDirector.bpm,
                sampleRate: sampleRate, storageObservation: scope)
            let dust = PercussionEchoTextureVoice.renderSpatialDust(source: source,
                leftReturn: &observedLeft, rightReturn: &observedRight,
                articulation: articulation, sampleRate: sampleRate, storageObservation: scope)
            #expect(observed == ordinary && observedLeft == ordinaryLeft && observedRight == ordinaryRight)
            #expect(echo == ordinaryEcho && dust == ordinaryDust)
            let active = echo.active || dust.active
            #expect(active == (index != 0))
            #expect(probe.valid && probe.observationCount == (active ? 3 : 2))
            #expect(probe.phaseObservationCounts == ["helper.helper-working": active ? 3 : 2])
            let snapshot = try #require(probe.snapshots.first { $0.phase == "helper.helper-working" })
            #expect(snapshot.ownerRecords.contains { $0.owner == "outer.retained" && $0.elementCount == 3 })
            let expectedTemps: [String: Int]
            if index == 1 { expectedTemps = ["echo.delay": max(1, Int((Double(frames) / 16).rounded()))] }
            else if index == 2 { expectedTemps = ["echo.delay": max(1, Int((Double(frames) / 16).rounded())), "echo.forwardWet": frames] }
            else if index == 3 { expectedTemps = ["dust.leftDelay": max(1, Int((Double(frames) / 16).rounded())),
                "dust.rightDelay": max(1, Int((Double(frames) / 16 * 1.375).rounded()))] }
            else { expectedTemps = [:] }
            for (owner, count) in expectedTemps {
                let record = try #require(snapshot.ownerRecords.first { $0.owner == owner })
                #expect(record.elementCount == count && record.elementCapacity >= count && record.elementStride == 4)
                #expect(record.capacityBytes == record.elementCapacity * 4 && record.aliasOf == nil)
            }
            let innerSource = try #require(snapshot.ownerRecords.first { $0.owner == "echo.source" || $0.owner == "dust.source" })
            #expect(innerSource.aliasOf == "outer.source")
            let exhausted = PreparationWorkingStorageProbe()
            for slot in 0..<PreparationWorkingStorageProbe.maximumPhaseCount {
                exhausted.observe(phase: "occupied-\(slot)", bar: slot) { _ in }
            }
            let beforeCounts = exhausted.phaseObservationCounts
            var outerVisits = 0
            let exhaustedScope = PreparationStorageObservation(probe: exhausted, prefix: "overflow", bar: index) { _ in outerVisits += 1 }
            var refused = [Float](repeating: 0, count: frames), refusedLeft = refused, refusedRight = refused
            let refusedEcho = PercussionEchoTextureVoice.render(source: source, returnStem: &refused,
                articulation: articulation, bpm: AutonomousSessionDirector.bpm,
                sampleRate: sampleRate, storageObservation: exhaustedScope)
            let refusedDust = PercussionEchoTextureVoice.renderSpatialDust(source: source,
                leftReturn: &refusedLeft, rightReturn: &refusedRight,
                articulation: articulation, sampleRate: sampleRate, storageObservation: exhaustedScope)
            #expect(!exhausted.valid && outerVisits == 0 && exhausted.observationCount == 32)
            #expect(exhausted.phaseObservationCounts == beforeCounts)
            #expect(refused == ordinary && refusedLeft == ordinaryLeft && refusedRight == ordinaryRight)
            #expect(refusedEcho == ordinaryEcho && refusedDust == ordinaryDust)
            let report: [String: Any] = ["schema": "autotechno-helper-storage-control.v1",
                "sampleRate": sampleRate, "caseIndex": index, "frames": frames,
                "observations": probe.observationCount, "phaseObservationCounts": probe.phaseObservationCounts,
                "expectedTemporaryCounts": expectedTemps,
                "exactPCMAndEvidence": true, "exhaustedObserverPreservesOutput": true,
                "snapshots": try JSONSerialization.jsonObject(with: JSONEncoder().encode(probe.snapshots)),
                "completeWorkingSetQualification": false, "instrumentationMayExtendObservedLifetimes": true]
            print("AUTOTECHNO_HELPER_STORAGE_CONTROL " + String(decoding:
                try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
        }
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
        let nodeCount = DSPGraphGenerator.safePlan(sessionSeed: 42).nodes.count
        let activeHelperBars = result.blocks.filter {
            $0.percussionEchoTextureRenderEvidence.active || $0.spatialDustRenderEvidence.active
        }.count
        let memoryBars = result.blocks.filter {
            $0.synthPerformance.composition.audioSlice?.resampledMemorySource != nil
        }.count
        let helperObservations = plan.barCount * 4 + (activeHelperBars + memoryBars) * 2
        #expect(storageProbe.valid && storageProbe.observationCount ==
            plan.barCount * (9 + 2 * nodeCount) + helperObservations)
        var expectedCounts: [String: Int] = [:]
        for phase in ["bar-delivery", "full-voice-return", "full-voice.product",
            "generated-graph.current.mixed", "generated-graph.output", "generated-graph.split",
            "graph-pump-return", "protected-voice-return", "protected-voice.product"] {
            expectedCounts[phase] = plan.barCount
        }
        expectedCounts["generated-graph.current.branches"] = plan.barCount * nodeCount
        expectedCounts["generated-graph.current.node-return"] = plan.barCount * nodeCount
        expectedCounts["full-voice.helper-working"] = plan.barCount * 2 + activeHelperBars + memoryBars
        expectedCounts["protected-voice.helper-working"] = plan.barCount * 2 + activeHelperBars + memoryBars
        #expect(storageProbe.phaseObservationCounts == expectedCounts)
        let snapshots = storageProbe.snapshots
        #expect(snapshots.map(\.phase) == ["bar-delivery", "full-voice-return", "full-voice.helper-working", "full-voice.product",
            "generated-graph.current.branches", "generated-graph.current.mixed",
            "generated-graph.current.node-return", "generated-graph.output", "generated-graph.split",
            "graph-pump-return", "protected-voice-return", "protected-voice.helper-working", "protected-voice.product"])
        #expect(snapshots.allSatisfy { $0.valid && $0.uniqueBufferCapacityBytes > 0 &&
            $0.typedMetadataHeadroomBytes > 0 && $0.ownerRecords.contains { $0.aliasOf != nil } })
        for snapshot in snapshots {
            if snapshot.phase.contains(".product") {
                #expect(snapshot.ownerRecords.contains { $0.owner == "voice.spatialFDNScratch" &&
                    $0.elementStride == 8 && $0.elementCount > 0 })
                #expect(snapshot.ownerRecords.contains { $0.owner == "voice.spatialDustLeftStem" })
                #expect(snapshot.ownerRecords.contains { $0.owner.hasPrefix("outer.continuation.") })
            } else if snapshot.phase.hasSuffix(".helper-working") {
                #expect(snapshot.ownerRecords.contains { $0.owner == "voice.checked-out.output" })
                #expect(snapshot.ownerRecords.contains { $0.owner == "voice.output" })
                #expect(snapshot.ownerRecords.contains { $0.owner.hasPrefix("voice.state.") })
                #expect(snapshot.ownerRecords.contains { $0.owner.hasPrefix("outer.continuation.") })
                #expect(!snapshot.ownerRecords.contains { $0.owner == "voice.percussionTextureStem" } ||
                    snapshot.ownerRecords.contains { $0.owner.hasPrefix("dust.") || $0.owner == "memory.regenerated" })
            } else if snapshot.phase.hasPrefix("generated-graph.") {
                #expect(snapshot.ownerRecords.contains { $0.owner.hasPrefix("outer.workspace.") })
                #expect(snapshot.ownerRecords.contains { $0.owner.hasPrefix("outer.state.") })
            } else {
                #expect(snapshot.ownerRecords.contains { $0.owner.hasPrefix("workspace.") })
                #expect(snapshot.ownerRecords.contains { $0.owner.hasPrefix("current.") })
            }
        }
        let delivery = try #require(snapshots.first { $0.phase == "bar-delivery" })
        #expect(delivery.ownerRecords.filter { $0.owner.hasPrefix("capture.") }.count == 32)
        #expect(delivery.ownerRecords.contains { $0.owner.hasPrefix("hold.") })
        let snapshotJSON = try JSONEncoder().encode(snapshots)
        let storageControl: [String: Any] = [
            "schema": "autotechno-render-inner-storage-control.v2",
            "sampleRate": sampleRate, "barCount": plan.barCount,
            "observations": storageProbe.observationCount,
            "phaseObservationCounts": storageProbe.phaseObservationCounts,
            "expectedOriginalPhaseCounts": expectedCounts.filter { !$0.key.hasSuffix(".helper-working") },
            "expectedHelperObservations": helperObservations,
            "activeHelperBars": activeHelperBars, "memorySourceBars": memoryBars,
            "snapshots": try JSONSerialization.jsonObject(with: snapshotJSON),
            "exactPCMStateAndHoldProducts": true,
            "completeWorkingSetQualification": false,
            "instrumentationMayExtendObservedLifetimes": true,
            "uncovered": ["nested-voice-helper-and-internal-node-transients", "analysis",
                "encoding-and-heap-metadata", "initial-corrected-overlap",
                "incoming-parent-child-storage", "writer-chunk", "process-RSS", "deadlines"],
        ]
        let storageJSON = try JSONSerialization.data(withJSONObject: storageControl, options: [.sortedKeys])
        print("AUTOTECHNO_RENDER_STORAGE_CONTROL " + String(decoding: storageJSON, as: UTF8.self))
        let ordinaryPreflightValue = PhraseAudioPreflight(blocks: result.blocks,
            sampleRate: sampleRate, cancellationRequested: { false })
        let ordinaryPreflight = try #require(ordinaryPreflightValue)
        let analysisProbe = PreparationWorkingStorageProbe()
        let analysisScope = PreparationStorageObservation(probe: analysisProbe,
            prefix: "analysis", bar: plan.startBar) { inventory in
            inventory.register(result, owner: "actual.render-product")
            AutonomousTypedFingerprint.registerContinuationStorage(renderState: state,
                generatedDSPState: graph, inventory: inventory, owner: "actual.ending")
        }
        let observedPreflightValue = PhraseAudioPreflight(blocks: result.blocks,
            sampleRate: sampleRate, storageObservation: analysisScope, cancellationRequested: { false })
        let observedPreflight = try #require(observedPreflightValue)
        #expect(observedPreflight == ordinaryPreflight)
        try Self.checkAnalyzerStorage(analysisProbe, prefix: "analysis", sampleRate: sampleRate)
        #expect(analysisProbe.observationCount == plan.barCount * 5 + 7)
        #expect(analysisProbe.snapshots.allSatisfy { snapshot in snapshot.ownerRecords.contains {
            $0.owner.hasPrefix("actual.render-product.primary") && $0.capacityBytes > 0 } })
        let exhaustedProbe = PreparationWorkingStorageProbe()
        for index in 0..<PreparationWorkingStorageProbe.maximumPhaseCount {
            exhaustedProbe.observe(phase: "occupied.\(index)", bar: 0) { _ in }
        }
        var exhaustedOuterVisits = 0
        let exhaustedScope = PreparationStorageObservation(probe: exhaustedProbe,
            prefix: "analysis", bar: plan.startBar) { _ in exhaustedOuterVisits += 1 }
        let exhaustedPreflightValue = PhraseAudioPreflight(blocks: result.blocks,
            sampleRate: sampleRate, storageObservation: exhaustedScope, cancellationRequested: { false })
        let exhaustedPreflight = try #require(exhaustedPreflightValue)
        #expect(exhaustedPreflight == ordinaryPreflight && !exhaustedProbe.valid)
        #expect(exhaustedOuterVisits == 0 && exhaustedProbe.observationCount == 32)
        let cancelledPreflight = PhraseAudioPreflight(blocks: result.blocks, sampleRate: sampleRate,
            storageObservation: analysisScope, cancellationRequested: { true })
        #expect(cancelledPreflight == nil)
        let analysisControl: [String: Any] = ["schema": "autotechno-analyzer-storage-control.v1",
            "sampleRate": sampleRate, "barCount": plan.barCount, "observations": analysisProbe.observationCount,
            "snapshots": try JSONSerialization.jsonObject(with: JSONEncoder().encode(analysisProbe.snapshots)),
            "exactPreflightReports": observedPreflight == ordinaryPreflight,
            "exhaustedObserverPreservesReport": exhaustedPreflight == ordinaryPreflight && exhaustedOuterVisits == 0,
            "qualification": "mechanical-only-not-installed", "completeWorkingSetQualification": false,
            "instrumentationMayExtendObservedLifetimes": true]
        print("AUTOTECHNO_ANALYZER_STORAGE_CONTROL " + String(decoding:
            try JSONSerialization.data(withJSONObject: analysisControl, options: [.sortedKeys]), as: UTF8.self))
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
        #expect(probe.phaseObservationCounts == ["first": 2, "second": 1])
        #expect(probe.snapshots.count == 2)
        #expect(probe.snapshots.allSatisfy { $0.uniqueBufferCapacityBytes == samples.capacity * 4 })
        #expect(probe.snapshots.first { $0.phase == "first" }?.bar == 2)
        for index in 2..<PreparationWorkingStorageProbe.maximumPhaseCount {
            probe.observe(phase: "phase-\(index)", bar: index) { _ in }
        }
        #expect(probe.valid && probe.snapshots.count == PreparationWorkingStorageProbe.maximumPhaseCount)
        probe.observe(phase: "overflow", bar: 33) { _ in Issue.record("Phase overflow must refuse") }
        #expect(!probe.valid && probe.snapshots.count == PreparationWorkingStorageProbe.maximumPhaseCount)
        let grouped = PreparationWorkingStorageProbe()
        grouped.observe(phase: "render", bar: 0, additionalMaximumPhase: "correction") {
            $0.register(samples, owner: "corrective-owner")
        }
        let larger = [Float](repeating: 0, count: 64)
        grouped.observe(phase: "render", bar: 1) { $0.register(larger, owner: "later-child") }
        #expect(grouped.valid && grouped.observationCount == 2 && grouped.snapshots.count == 2)
        #expect(grouped.phaseObservationCounts == ["render": 2])
        let conditional = try #require(grouped.snapshots.first { $0.phase == "correction" })
        #expect(conditional.observedPhase == "render" && conditional.bar == 0 &&
            conditional.ownerRecords.first?.owner == "corrective-owner")
        #expect(grouped.snapshots.first { $0.phase == "render" }?.bar == 1)
        for index in 2..<PreparationWorkingStorageProbe.maximumPhaseCount - 1 {
            grouped.observe(phase: "group-\(index)", bar: index) { _ in }
        }
        let countBefore = grouped.observationCount
        grouped.observe(phase: "last", bar: 32, additionalMaximumPhase: "would-overflow") {
            _ in Issue.record("All maximum slots must be reserved before registering any owner")
        }
        #expect(!grouped.valid && grouped.snapshots.count == 31 && grouped.observationCount == countBefore)
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

    private final class ObservationLifetimeOwner {
        let samples: [Float] = [1, 2, 3, 4]
    }

    @Test("Nested observation scopes release all outer owners after the synchronous call")
    func nestedObservationLifetime() throws {
        weak var observedOwner: ObservationLifetimeOwner?
        let probe = PreparationWorkingStorageProbe()
        var capacity = 0
        func call() {
            let owner = ObservationLifetimeOwner()
            observedOwner = owner
            capacity = owner.samples.capacity * 4
            let outer = PreparationStorageObservation(probe: probe, prefix: "outer", bar: 0) { inventory in
                inventory.register(owner.samples, owner: "outer.samples")
            }
            let nested = outer.extending("inner") { _ in #expect(observedOwner != nil) }
            nested.observe("borrow") { inventory in
                #expect(observedOwner != nil)
                inventory.register(owner.samples, owner: "inner.alias")
            }
        }
        call()
        #expect(observedOwner == nil && probe.valid && probe.observationCount == 1)
        let snapshot = try #require(probe.snapshots.first)
        #expect(snapshot.phase == "outer.inner.borrow" && snapshot.uniqueBufferCapacityBytes == capacity)
        #expect(snapshot.ownerRecords.last?.aliasOf == "outer.samples")
    }

    @Test("Graph branch, node COW and retiring observations preserve exact products and continuation",
        arguments: [44_100.0, 48_000.0])
    func innerGraphRetirement(sampleRate: Double) throws {
        let safe = DSPGraphGenerator.safePlan(sessionSeed: 42)
        let changed = DSPGraphPlan(sessionSeed: 42, revision: 1,
            nodes: safe.nodes + [DSPGraphNode(id: 8, kind: .echo, branch: 0, order: 2,
                amount: 0.42, mix: 0.2, feedback: 0.3, delaySeconds: 0.125)],
            mutation: DSPGraphMutation(kind: .insert, phraseIndex: 1, affectedNodeIDs: [8]))
        #expect(DSPGraphValidator.validate(changed).valid)
        let left = (0..<256).map { Float(sin(Double($0) * 0.1) * 0.1) }
        let right = left.map { $0 * 0.9 }
        let outer: [Double] = [Double](repeating: 0, count: 80)
        var ordinary = GeneratedDSPContinuationState()
        var observed = GeneratedDSPContinuationState()
        let probe = PreparationWorkingStorageProbe()
        var ordinaryFingerprints: [String] = []
        var observedFingerprints: [String] = []
        for (bar, plan) in [safe, changed, changed, changed].enumerated() {
            let reference = GeneratedDSPGraphRenderer.process(left: left, right: right,
                sampleRate: sampleRate, plan: plan, state: &ordinary)
            let scope = PreparationStorageObservation(probe: probe, prefix: "graph", bar: bar) { inventory in
                inventory.register(outer, owner: "outer.borrow")
                withExtendedLifetime(outer) {}
            }
            let actual = GeneratedDSPGraphRenderer.process(left: left, right: right,
                sampleRate: sampleRate, plan: plan, state: &observed, storageObservation: scope)
            #expect(actual.0 == reference.0 && actual.1 == reference.1 && observed == ordinary)
            ordinaryFingerprints.append(ExactPCMFingerprint.stereo(left: reference.0, right: reference.1))
            observedFingerprints.append(ExactPCMFingerprint.stereo(left: actual.0, right: actual.1))
            #expect(observed.retiringBarsRemaining == (bar == 1 ? 1 : 0))
        }
        #expect(probe.valid && observed.retiringGraph == nil && observed.retiringStates.isEmpty)
        let phases = probe.snapshots.map(\.phase)
        #expect(phases == ["graph.current.branches", "graph.current.mixed", "graph.current.node-return",
            "graph.output", "graph.retiring.branches", "graph.retiring.mixed", "graph.retiring.node-return", "graph.split"])
        #expect(probe.snapshots.allSatisfy { $0.ownerRecords.contains { $0.owner == "outer.borrow" } })
        let retiring = try #require(probe.snapshots.first { $0.phase == "graph.retiring.node-return" })
        #expect(retiring.ownerRecords.contains { $0.owner.hasPrefix("graph.current-state.") && $0.capacityBytes > 0 })
        #expect(retiring.ownerRecords.contains { $0.owner.hasPrefix("branch.states.") && $0.capacityBytes > 0 })
        let node = try #require(probe.snapshots.first { $0.phase == "graph.current.node-return" })
        let newDelay = node.ownerRecords.filter { $0.owner.hasPrefix("branch.node-8.") &&
            $0.owner.hasSuffix(".delayLeft") && $0.capacityBytes > 0 }
        let oldDelay = node.ownerRecords.filter { $0.owner == "branch.states.8.delayLeft" && $0.capacityBytes > 0 }
        #expect(newDelay.count == 1 && oldDelay.count == 1)
        #expect(newDelay.first?.aliasOf == nil && oldDelay.first?.aliasOf == nil)
        let control: [String: Any] = [
            "schema": "autotechno-inner-graph-retirement-control.v1",
            "sampleRate": sampleRate, "framesPerCall": left.count, "calls": 4,
            "observations": probe.observationCount,
            "snapshots": try JSONSerialization.jsonObject(with: JSONEncoder().encode(probe.snapshots)),
            "ordinaryFingerprints": ordinaryFingerprints, "observedFingerprints": observedFingerprints,
            "ordinaryEndingState": AutonomousCandidateFingerprint.generatedDSPState(ordinary),
            "observedEndingState": AutonomousCandidateFingerprint.generatedDSPState(observed),
            "newAndOldDelayStorageIndependent": newDelay.first?.aliasOf == nil && oldDelay.first?.aliasOf == nil,
            "retirementClosed": observed.retiringGraph == nil && observed.retiringStates.isEmpty,
            "qualification": "mechanical-only-not-installed", "completeWorkingSetQualification": false,
        ]
        let controlJSON = try JSONSerialization.data(withJSONObject: control, options: [.sortedKeys])
        print("AUTOTECHNO_GRAPH_INNER_STORAGE_CONTROL " + String(decoding: controlJSON, as: UTF8.self))
        withExtendedLifetime((outer, left, right, ordinary, observed)) {}
    }

}
