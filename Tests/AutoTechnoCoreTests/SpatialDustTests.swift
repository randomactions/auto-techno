import AutoTechnoCore
import Foundation
import Testing

@testable import AutoTechnoDSP

@Suite("Held asymmetric spatial dust")
struct SpatialDustTests {
    @Test("World cadence is exactly three active bars, one gap, and alternating dominance")
    func worldCadence() throws {
        let intent = LongHorizonMaterialWorldResolver.make(
            rootSeed: 48_291,
            episodeID: 7,
            operatorKind: .maintain,
            parent: nil,
            recallSource: nil,
            recentFingerprints: [],
            activationBar: 64
        )
        let world = LongHorizonMaterialWorldPlan(
            worldID: intent.id,
            worldFingerprint: intent.fingerprint,
            parentFingerprint: intent.parentFingerprint,
            generation: intent.generation,
            handoff: intent.handoff,
            sourceAxes: intent.parentAxes ?? intent.axes,
            axes: intent.axes,
            polymetricGrammar: intent.polymetricGrammar,
            progress: 0
        )
        let ensemble = EnsembleContext(
            focusRole: .percussion,
            events: [EnsembleResolvedEvent(
                voice: .percussion,
                step: 3,
                intensity: 0.7,
                relocated: false
            )],
            kickAnchors: [0, 4, 8, 12],
            intentionalPileup: false
        )
        let cadences = (64..<72).map {
            PercussionEchoTextureResolver.spatialDustCadence(
                materialWorld: world,
                absoluteBar: $0
            )
        }
        #expect(cadences.compactMap { $0 }.count == 8)
        let resolvedCadences = cadences.compactMap { $0 }
        #expect(resolvedCadences.prefix(4).filter { $0.active }.count == 3)
        #expect(resolvedCadences.suffix(4).filter { $0.active }.count == 3)
        #expect(Set(cadences.compactMap { $0?.gapPhase }).count == 1)

        let articulations = (64..<72).compactMap { bar in
            PercussionEchoTextureResolver.articulation(
                ensemble: ensemble,
                kind: .lock,
                character: .hypnoticLock,
                gesture: .steady,
                absoluteBar: bar,
                materialWorld: world
            )
        }
        #expect(articulations.count == 6)
        #expect(articulations.allSatisfy {
            $0.relation == PercussionEchoTextureRelation.spatialDust
        })
        let alternating = zip(articulations, articulations.dropFirst())
            .allSatisfy { pair in
                pair.0.dominantSide != pair.1.dominantSide
            }
        #expect(alternating)
        let bounded = articulations.allSatisfy { articulation in
            articulation.worldID == world.worldID &&
                articulation.outputStartStep == 0 &&
                articulation.outputEndStep == 16
        }
        #expect(bounded)

        let noSource = EnsembleContext(
            focusRole: .foundation,
            events: [EnsembleResolvedEvent(
                voice: .kick,
                step: 0,
                intensity: 1,
                relocated: false
            )],
            kickAnchors: [0],
            intentionalPileup: false
        )
        #expect(PercussionEchoTextureResolver.articulation(
            ensemble: noSource,
            kind: .lock,
            character: .hypnoticLock,
            gesture: .steady,
            absoluteBar: 65,
            materialWorld: world
        ) == nil)
    }

    @Test("Stereo dust is deterministic, asymmetric, band limited, and clears every boundary")
    func stereoDSP() throws {
        for sampleRate in [44_100.0, 48_000.0] {
            let frameCount = Int((240 / 130.0 * sampleRate).rounded())
            var source = [Float](repeating: 0, count: frameCount)
            let stepFrames = Double(frameCount) / 16
            for step in [1, 3, 6, 9, 11, 14] {
                let start = Int((Double(step) * stepFrames).rounded())
                for offset in 0..<min(128, frameCount - start) {
                    source[start + offset] += Float(
                        sin(Double(offset) * 0.71) *
                            exp(-Double(offset) / 34) * 0.18
                    )
                }
            }
            let articulation = PercussionEchoTextureArticulation(
                relation: .spatialDust,
                inputStep: 1,
                outputStartStep: 0,
                outputEndStep: 16,
                worldID: 91,
                cadencePhase: 1,
                gapPhase: 3,
                dominantSide: .left
            )
            var firstLeft = [Float](repeating: 0, count: frameCount)
            var firstRight = [Float](repeating: 0, count: frameCount)
            let first = PercussionEchoTextureVoice.renderSpatialDust(
                source: source,
                leftReturn: &firstLeft,
                rightReturn: &firstRight,
                articulation: articulation,
                sampleRate: sampleRate
            )
            var replayLeft = [Float](repeating: 0, count: frameCount)
            var replayRight = [Float](repeating: 0, count: frameCount)
            let replay = PercussionEchoTextureVoice.renderSpatialDust(
                source: source,
                leftReturn: &replayLeft,
                rightReturn: &replayRight,
                articulation: articulation,
                sampleRate: sampleRate
            )
            #expect(first == replay)
            #expect(firstLeft == replayLeft)
            #expect(firstRight == replayRight)
            #expect(first.active && first.finite && first.terminalCleared)
            #expect(first.left.returnSampleHash != first.right.returnSampleHash)
            #expect(first.left.returnRMS != first.right.returnRMS)
            #expect(first.left.delayFrameCount != first.right.delayFrameCount)
            #expect(first.left.pan == -0.75 && first.right.pan == 0.75)
            #expect(first.lowBandEnergyRatio < 0.25)
            #expect(first.stereoCorrelation > -1 && first.stereoCorrelation < 1)
            #expect(first.outOfWindowNonzeroSampleCount == 0)
            #expect((firstLeft.first?.bitPattern ?? 1) == 0)
            #expect((firstRight.first?.bitPattern ?? 1) == 0)
            #expect((firstLeft.last?.bitPattern ?? 1) == 0)
            #expect((firstRight.last?.bitPattern ?? 1) == 0)

            let candidate = AutonomousSpatialDustBarEvidence(
                bar: 65,
                cadence: SpatialDustCadence(
                    worldID: 91,
                    absoluteBar: 65,
                    cadencePhase: 1,
                    gapPhase: 3,
                    active: true,
                    dominantSide: .left
                ),
                eligibleSourceStepMask: UInt16(1 << 1),
                scoreRelation: .spatialDust,
                render: first,
                renderPassesMatch: true,
                bindingValid: true
            )
            #expect(candidate.isComplete(sampleRate: sampleRate))
        }
    }

    @Test("Gap and malformed paths render exact neutral PCM")
    func neutralFallback() {
        let frameCount = 8_000
        let source = [Float](repeating: 0.2, count: frameCount)
        for articulation in [
            Optional<PercussionEchoTextureArticulation>.none,
            PercussionEchoTextureArticulation(
                relation: .spatialDust,
                inputStep: 1,
                outputStartStep: 0,
                outputEndStep: 16,
                worldID: 0,
                cadencePhase: 1,
                gapPhase: 3,
                dominantSide: .left
            ),
        ] {
            var left = [Float](repeating: 0, count: frameCount)
            var right = [Float](repeating: 0, count: frameCount)
            let evidence = PercussionEchoTextureVoice.renderSpatialDust(
                source: source,
                leftReturn: &left,
                rightReturn: &right,
                articulation: articulation,
                sampleRate: 44_100
            )
            #expect(!evidence.active)
            #expect(evidence.terminalCleared)
            #expect(left.allSatisfy { $0.bitPattern & 0x7fff_ffff == 0 })
            #expect(right.allSatisfy { $0.bitPattern & 0x7fff_ffff == 0 })
        }
    }
}
