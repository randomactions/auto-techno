import Foundation
import Testing
@testable import AutoTechnoDSP

@Suite("PCM kick/foundation collision evidence")
struct PCMKickFoundationCollisionAnalyzerTests {
    @Test("Low-frequency overlap retains duration, attribution, and energy sign")
    func lowBandOverlap() throws {
        let fixture = makeFixture(sampleRate: 48_000, step: 4)
        var kick = fixture.silence
        var foundation = fixture.silence
        fillSine(
            &kick,
            range: fixture.onset..<fixture.analysisEnd,
            frequency: 60,
            amplitude: 0.20,
            sampleRate: fixture.sampleRate
        )
        fillSine(
            &foundation,
            range: fixture.onset..<fixture.analysisEnd,
            frequency: 60,
            amplitude: 0.13,
            sampleRate: fixture.sampleRate
        )

        let evidence = try available(analyze(
            kick: kick,
            foundation: foundation,
            fixture: fixture
        ))
        let event = try #require(evidence.events.first)
        #expect(event.collisionClass == .lowBandOverlap)
        #expect(event.responsibleSignals == ["kick", "foundation"])
        #expect(event.temporalOverlapWindowCount == 16)
        #expect(event.lowBandOverlapWindowCount == 16)
        #expect(event.temporalOverlapFrameCount == event.analysisFrameCount)
        #expect(event.lowBandOverlapFrameCount == event.analysisFrameCount)
        #expect((event.kickOverFoundationDB ?? 0) > 3)
        #expect(event.maximumSubBandSimilarity > 0.38)
        #expect(event.confidence ==
                PCMKickFoundationCollisionAnalyzer.confidence)
        #expect(event.finite)
    }

    @Test("High foundation content is temporal overlap without low-band match")
    func temporalWithoutLowBandOverlap() throws {
        let fixture = makeFixture(sampleRate: 48_000, step: 4)
        var kick = fixture.silence
        var foundation = fixture.silence
        fillSine(
            &kick,
            range: fixture.onset..<fixture.analysisEnd,
            frequency: 60,
            amplitude: 0.15,
            sampleRate: fixture.sampleRate
        )
        fillSine(
            &foundation,
            range: fixture.onset..<fixture.analysisEnd,
            frequency: 4_000,
            amplitude: 0.15,
            sampleRate: fixture.sampleRate
        )

        let event = try #require(try available(analyze(
            kick: kick,
            foundation: foundation,
            fixture: fixture
        )).events.first)
        #expect(event.collisionClass == .temporalOverlap)
        #expect(event.temporalOverlapWindowCount == 16)
        #expect(event.lowBandOverlapWindowCount == 0)
        #expect(event.lowBandOverlapFrameCount == 0)
    }

    @Test("Separated tails and valid silence states remain distinct")
    func separatedAndMissingRoles() throws {
        let fixture = makeFixture(sampleRate: 48_000, step: 4)
        let quarter = (fixture.analysisEnd - fixture.onset) / 4
        var kick = fixture.silence
        var foundation = fixture.silence
        fillSine(
            &kick,
            range: fixture.onset..<(fixture.onset + quarter),
            frequency: 80,
            amplitude: 0.2,
            sampleRate: fixture.sampleRate
        )
        fillSine(
            &foundation,
            range: (fixture.analysisEnd - quarter)..<fixture.analysisEnd,
            frequency: 80,
            amplitude: 0.2,
            sampleRate: fixture.sampleRate
        )
        let separated = try #require(try available(analyze(
            kick: kick,
            foundation: foundation,
            fixture: fixture
        )).events.first)
        #expect(separated.collisionClass == .separated)
        #expect(separated.temporalOverlapWindowCount == 0)
        #expect(separated.kickOverFoundationDB == nil)

        let kickOnly = try #require(try available(analyze(
            kick: kick,
            foundation: fixture.silence,
            fixture: fixture
        )).events.first)
        #expect(kickOnly.collisionClass == .kickOnly)

        let foundationOnly = try #require(try available(analyze(
            kick: fixture.silence,
            foundation: foundation,
            fixture: fixture
        )).events.first)
        #expect(foundationOnly.collisionClass == .foundationOnly)

        let silence = try #require(try available(analyze(
            kick: fixture.silence,
            foundation: fixture.silence,
            fixture: fixture
        )).events.first)
        #expect(silence.collisionClass == .mutualSilence)
        #expect(silence.finite)
    }

    @Test("Exact pre-kick pocket is independent from post-onset collision")
    func pocketBinding() throws {
        var fixture = makeFixture(sampleRate: 48_000, step: 4)
        fixture.event = PCMKickFoundationEventInput(
            id: fixture.event.id,
            bar: fixture.event.bar,
            step: fixture.event.step,
            barStartFrame: fixture.event.barStartFrame,
            barFrameCount: fixture.event.barFrameCount,
            onsetFrame: fixture.event.onsetFrame,
            authoredFoundationRolesInBar: ["bass"],
            pocket: PCMKickFoundationPocketInput(
                releaseStartFrame: fixture.onset - 800,
                releaseEndFrame: fixture.onset - 400,
                kickFrame: fixture.onset,
                silenceFrameCount: 400,
                silencePeak: 0,
                silenceRMS: 0,
                applied: true,
                finite: true
            )
        )
        var kick = fixture.silence
        var foundation = fixture.silence
        fillSine(
            &kick,
            range: fixture.onset..<fixture.analysisEnd,
            frequency: 60,
            amplitude: 0.15,
            sampleRate: fixture.sampleRate
        )
        fillSine(
            &foundation,
            range: fixture.onset..<fixture.analysisEnd,
            frequency: 60,
            amplitude: 0.12,
            sampleRate: fixture.sampleRate
        )

        let event = try #require(try available(analyze(
            kick: kick,
            foundation: foundation,
            fixture: fixture
        )).events.first)
        #expect(event.pocketState == .exactSilence)
        #expect(event.pocketSilenceFrameCount == 400)
        #expect(event.collisionClass == .lowBandOverlap)
        #expect(event.authoredFoundationRolesInBar == ["bass"])
    }

    @Test("Phase inversion does not invent a role-sum cancellation claim")
    func phaseVariant() throws {
        let fixture = makeFixture(sampleRate: 48_000, step: 4)
        var kick = fixture.silence
        var same = fixture.silence
        var inverse = fixture.silence
        fillSine(
            &kick,
            range: fixture.onset..<fixture.analysisEnd,
            frequency: 73,
            amplitude: 0.12,
            sampleRate: fixture.sampleRate
        )
        fillSine(
            &same,
            range: fixture.onset..<fixture.analysisEnd,
            frequency: 73,
            amplitude: 0.12,
            sampleRate: fixture.sampleRate
        )
        inverse = same.map { -$0 }
        let sameEvent = try #require(try available(analyze(
            kick: kick,
            foundation: same,
            fixture: fixture
        )).events.first)
        let inverseEvent = try #require(try available(analyze(
            kick: kick,
            foundation: inverse,
            fixture: fixture
        )).events.first)
        #expect(sameEvent.collisionClass == .lowBandOverlap)
        #expect(inverseEvent.collisionClass == .lowBandOverlap)
        #expect(sameEvent.temporalOverlapFrameCount ==
                inverseEvent.temporalOverlapFrameCount)
        #expect(sameEvent.lowBandOverlapFrameCount ==
                inverseEvent.lowBandOverlapFrameCount)
    }

    @Test("44.1 and 48 kHz use bounded score-relative geometry")
    func sampleRateGeometry() throws {
        for rate in [44_100, 48_000] {
            let fixture = makeFixture(sampleRate: rate, step: 12)
            var kick = fixture.silence
            fillSine(
                &kick,
                range: fixture.onset..<fixture.analysisEnd,
                frequency: 70,
                amplitude: 0.1,
                sampleRate: fixture.sampleRate
            )
            let evidence = try available(analyze(
                kick: kick,
                foundation: fixture.silence,
                fixture: fixture
            ))
            let event = try #require(evidence.events.first)
            #expect(evidence.sampleRate == rate)
            #expect(event.windows.count == 16)
            #expect(event.windows.reduce(0) { $0 + $1.frameCount } ==
                    event.analysisFrameCount)
            #expect(event.analysisFrameCount ==
                    Int((Double(fixture.barFrames) / 8.0).rounded()))
        }
    }

    @Test("Malformed geometry, PCM, and pockets fail with stable reasons")
    func unavailableReasons() {
        let fixture = makeFixture(sampleRate: 48_000, step: 4)
        #expect(PCMKickFoundationCollisionAnalyzer.analyze(
            kick: fixture.silence,
            foundation: fixture.silence,
            sampleRate: 96_000,
            events: [fixture.event]
        ) == .unavailable(.unsupportedSampleRate))
        #expect(PCMKickFoundationCollisionAnalyzer.analyze(
            kick: fixture.silence,
            foundation: Array(fixture.silence.dropLast()),
            sampleRate: fixture.sampleRate,
            events: [fixture.event]
        ) == .unavailable(.unalignedSignals))
        var invalidPCM = fixture.silence
        invalidPCM[10] = .nan
        #expect(PCMKickFoundationCollisionAnalyzer.analyze(
            kick: invalidPCM,
            foundation: fixture.silence,
            sampleRate: fixture.sampleRate,
            events: [fixture.event]
        ) == .unavailable(.nonFinitePCM))
        #expect(PCMKickFoundationCollisionAnalyzer.analyze(
            kick: fixture.silence,
            foundation: fixture.silence,
            sampleRate: fixture.sampleRate,
            events: [fixture.event, fixture.event]
        ) == .unavailable(.duplicateEvent))
        let invalidEvent = PCMKickFoundationEventInput(
            id: "invalid",
            bar: 0,
            step: 4,
            barStartFrame: 0,
            barFrameCount: fixture.barFrames,
            onsetFrame: fixture.onset + 1,
            authoredFoundationRolesInBar: []
        )
        #expect(PCMKickFoundationCollisionAnalyzer.analyze(
            kick: fixture.silence,
            foundation: fixture.silence,
            sampleRate: fixture.sampleRate,
            events: [invalidEvent]
        ) == .unavailable(.invalidEventGeometry))
        let invalidPocket = PCMKickFoundationEventInput(
            id: "invalid-pocket",
            bar: 0,
            step: 4,
            barStartFrame: 0,
            barFrameCount: fixture.barFrames,
            onsetFrame: fixture.onset,
            authoredFoundationRolesInBar: ["bass"],
            pocket: PCMKickFoundationPocketInput(
                releaseStartFrame: fixture.onset - 800,
                releaseEndFrame: fixture.onset - 400,
                kickFrame: fixture.onset,
                silenceFrameCount: 400,
                silencePeak: 0.001,
                silenceRMS: 0,
                applied: true,
                finite: true
            )
        )
        #expect(PCMKickFoundationCollisionAnalyzer.analyze(
            kick: fixture.silence,
            foundation: fixture.silence,
            sampleRate: fixture.sampleRate,
            events: [invalidPocket]
        ) == .unavailable(.invalidPocketBinding))
    }

    private struct Fixture {
        let sampleRate: Double
        let barFrames: Int
        let onset: Int
        let analysisEnd: Int
        let silence: [Float]
        var event: PCMKickFoundationEventInput
    }

    private func makeFixture(sampleRate: Int, step: Int) -> Fixture {
        let barFrames = Int((Double(sampleRate) * 240.0 / 130.0).rounded())
        let onset = Int((Double(step) * Double(barFrames) / 16.0).rounded())
        let analysisEnd = min(
            barFrames,
            onset + Int((Double(barFrames) / 8.0).rounded())
        )
        return Fixture(
            sampleRate: Double(sampleRate),
            barFrames: barFrames,
            onset: onset,
            analysisEnd: analysisEnd,
            silence: [Float](repeating: 0, count: barFrames),
            event: PCMKickFoundationEventInput(
                id: "bar-0-step-\(step)",
                bar: 0,
                step: step,
                barStartFrame: 0,
                barFrameCount: barFrames,
                onsetFrame: onset,
                authoredFoundationRolesInBar: ["rumble", "bass", "bass"]
            )
        )
    }

    private func analyze(
        kick: [Float],
        foundation: [Float],
        fixture: Fixture
    ) -> PCMKickFoundationCollisionAnalysisResult {
        PCMKickFoundationCollisionAnalyzer.analyze(
            kick: kick,
            foundation: foundation,
            sampleRate: fixture.sampleRate,
            events: [fixture.event]
        )
    }

    private func available(
        _ result: PCMKickFoundationCollisionAnalysisResult
    ) throws -> PCMKickFoundationCollisionEvidence {
        guard case let .available(evidence) = result else {
            Issue.record("expected available collision evidence, got \(result)")
            throw FixtureError.unavailable
        }
        return evidence
    }

    private func fillSine(
        _ samples: inout [Float],
        range: Range<Int>,
        frequency: Double,
        amplitude: Double,
        sampleRate: Double
    ) {
        for frame in range {
            samples[frame] = Float(amplitude * sin(
                2 * Double.pi * frequency * Double(frame - range.lowerBound) /
                    sampleRate
            ))
        }
    }

    private enum FixtureError: Error { case unavailable }
}
