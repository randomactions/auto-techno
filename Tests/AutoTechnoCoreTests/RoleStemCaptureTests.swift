import AutoTechnoCore
@testable import AutoTechnoDSP
import Foundation
import Testing

@Suite("Detached role-stem capture")
struct RoleStemCaptureTests {
    @Test("Capture is opt-in, bit-exact, aligned, finite, and reconstructable")
    func captureContract() throws {
        let director = AutonomousSessionDirector(rootSeed: 42)
        let state = director.initialState()
        let plan = director.plan(from: state)
        let graph = DSPGraphGenerator.safePlan(sessionSeed: state.rootSeed)
        var defaultRenderState = RenderState()
        var defaultGraphState = GeneratedDSPContinuationState()
        let production = try #require(
            AutonomousPhraseRenderer.renderProductIfNotCancelled(
                plan: plan,
                graph: graph,
                sampleRate: 8_000,
                state: &defaultRenderState,
                graphState: &defaultGraphState,
                cancellationRequested: { false }
            )
        )
        var capturedRenderState = RenderState()
        var capturedGraphState = GeneratedDSPContinuationState()
        let diagnostic = try #require(
            AutonomousPhraseRenderer.renderProductIfNotCancelled(
                plan: plan,
                graph: graph,
                sampleRate: 8_000,
                state: &capturedRenderState,
                graphState: &capturedGraphState,
                diagnosticRoleStemCapture: true,
                cancellationRequested: { false }
            )
        )

        #expect(production.diagnosticRoleStemCaptures.isEmpty)
        #expect(production.blocks == diagnostic.blocks)
        #expect(defaultRenderState == capturedRenderState)
        #expect(defaultGraphState == capturedGraphState)
        #expect(diagnostic.diagnosticRoleStemCaptures.count == plan.barCount)

        for (block, capture) in zip(
            diagnostic.blocks,
            diagnostic.diagnosticRoleStemCaptures
        ) {
            #expect(capture.bar == block.bar)
            #expect(capture.frameCount == block.left.count)
            #expect(capture.frameCountsAreAligned)
            #expect(capture.samplesAreFinite)
            #expect(capture.full.kick == capture.protectedRhythm.kick)
            #expect(capture.full.foundation == capture.protectedRhythm.foundation)
            #expect(capture.full.modalFoundation ==
                    capture.protectedRhythm.modalFoundation)
            #expect(capture.full.percussion == capture.protectedRhythm.percussion)
            #expect(capture.full.protectedFoundation ==
                    capture.protectedRhythm.protectedFoundation)
            #expect(capture.protectedRhythm.upperTonal.allSatisfy { $0 == 0 })
            #expect(capture.protectedRhythm.atmosphere.allSatisfy { $0 == 0 })

            #expect(maximumError(
                target: capture.full.protectedFoundation,
                first: capture.full.kick,
                second: capture.full.foundation
            ) < 0.000_001)
            #expect(maximumDryCenterError(capture.full) < 0.000_001)
            #expect(maximumError(
                target: capture.full.dryUpperReference,
                first: capture.full.upperTonal,
                second: capture.full.atmosphere
            ) < 0.000_001)
            #expect(maximumStereoError(
                targetLeft: capture.preClimaxMixLeft,
                targetRight: capture.preClimaxMixRight,
                firstLeft: capture.protectedRhythm.sourceLeft,
                firstRight: capture.protectedRhythm.sourceRight,
                secondLeft: capture.processedUpperLeft,
                secondRight: capture.processedUpperRight,
                residualLeft: capture.outputSafetyResidualLeft,
                residualRight: capture.outputSafetyResidualRight
            ) < 0.000_001)
            #expect(maximumStereoError(
                targetLeft: block.left,
                targetRight: block.right,
                firstLeft: capture.preClimaxMixLeft,
                firstRight: capture.preClimaxMixRight,
                residualLeft: capture.terminalProcessingResidualLeft,
                residualRight: capture.terminalProcessingResidualRight
            ) < 0.000_001)
        }
    }

    @Test("Diagnostic PCM is unreachable from hosts and realtime targets")
    func productionIsolation() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let forbidden = [
            "Sources/AutoTechnoApp",
            "Sources/AutoTechnoWindows",
            "Sources/CAutoTechnoRealtime",
        ]
        for relativePath in forbidden {
            let directory = root.appendingPathComponent(relativePath)
            let files = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey]
            )?.allObjects as? [URL] ?? []
            for file in files where
                (try? file.resourceValues(forKeys: [.isRegularFileKey])
                    .isRegularFile) == true {
                let source = try String(contentsOf: file, encoding: .utf8)
                #expect(!source.contains("diagnosticRoleStemCapture"))
                #expect(!source.contains("diagnosticRoleStemCaptures"))
            }
        }
    }

    private func maximumError(
        target: [Float],
        first: [Float],
        second: [Float]
    ) -> Float {
        zip(target, zip(first, second)).reduce(0) { maximum, values in
            max(maximum, abs(values.0 - (values.1.0 + values.1.1)))
        }
    }

    private func maximumDryCenterError(
        _ capture: VoiceRoleStemCapture
    ) -> Float {
        capture.dryCenterReference.indices.reduce(0) { maximum, index in
            let reconstructed = capture.protectedFoundation[index] +
                capture.percussion[index] - capture.modalFoundation[index]
            return max(
                maximum,
                abs(capture.dryCenterReference[index] - reconstructed)
            )
        }
    }

    private func maximumStereoError(
        targetLeft: [Float],
        targetRight: [Float],
        firstLeft: [Float],
        firstRight: [Float],
        secondLeft: [Float]? = nil,
        secondRight: [Float]? = nil,
        residualLeft: [Float],
        residualRight: [Float]
    ) -> Float {
        var maximum: Float = 0
        for index in targetLeft.indices {
            let left = firstLeft[index] + (secondLeft?[index] ?? 0) +
                residualLeft[index]
            let right = firstRight[index] + (secondRight?[index] ?? 0) +
                residualRight[index]
            maximum = max(
                maximum,
                abs(targetLeft[index] - left),
                abs(targetRight[index] - right)
            )
        }
        return maximum
    }
}
