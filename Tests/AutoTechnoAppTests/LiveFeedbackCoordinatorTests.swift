import AutoTechnoApp
import Testing

@Suite("Live feedback scheduled-window coordinator")
struct LiveFeedbackCoordinatorTests {
    @Test("Stable integral probes map mixer samples into the player domain")
    func mapsIntegralMixerOffsetIntoPlayerDomain() {
        let first = MixerPlayerClockProbe(
            mixerSample: 1_024,
            playerSample: 4_096,
            mixerSampleRate: 44_100,
            playerSampleRate: 44_100
        )
        let second = MixerPlayerClockProbe(
            mixerSample: 2_048,
            playerSample: 5_120,
            mixerSampleRate: 44_100,
            playerSampleRate: 44_100
        )

        let map = MixerPlayerClockMap.stable(first: first, second: second)

        #expect(map?.sampleOffset == 3_072)
        #expect(map?.sampleRate == 44_100)
        #expect(map?.checkedPlayerSample(forMixerSample: 8_192) == 11_264)
    }

    @Test("Fractional, drifting, and rate-mismatched probes are unavailable")
    func rejectsFractionalOrDriftingClockMap() {
        let baseline = MixerPlayerClockProbe(
            mixerSample: 1_000,
            playerSample: 2_000,
            mixerSampleRate: 48_000,
            playerSampleRate: 48_000
        )
        let fractional = MixerPlayerClockProbe(
            mixerSample: 2_000,
            playerSample: 3_000.5,
            mixerSampleRate: 48_000,
            playerSampleRate: 48_000
        )
        let drifting = MixerPlayerClockProbe(
            mixerSample: 2_000,
            playerSample: 3_001,
            mixerSampleRate: 48_000,
            playerSampleRate: 48_000
        )
        let rateMismatch = MixerPlayerClockProbe(
            mixerSample: 2_000,
            playerSample: 3_000,
            mixerSampleRate: 44_100,
            playerSampleRate: 48_000
        )
        let nonadvancing = MixerPlayerClockProbe(
            mixerSample: 1_000,
            playerSample: 2_000,
            mixerSampleRate: 48_000,
            playerSampleRate: 48_000
        )

        #expect(MixerPlayerClockMap.stable(first: baseline, second: fractional) == nil)
        #expect(MixerPlayerClockMap.stable(first: baseline, second: drifting) == nil)
        #expect(MixerPlayerClockMap.stable(first: baseline, second: rateMismatch) == nil)
        #expect(MixerPlayerClockMap.stable(first: baseline, second: nonadvancing) == nil)

        let overflowing = MixerPlayerClockMap(
            sampleOffset: .max,
            sampleRate: 48_000
        )
        #expect(overflowing?.checkedPlayerSample(forMixerSample: 0) == Int64.max)
        #expect(overflowing?.checkedPlayerSample(forMixerSample: 1) == nil)
    }

    @Test("Only exact product sample rates can define clock and window geometry")
    func rejectsUnsupportedAndPathologicalRates() {
        let unsupportedRates = [
            0,
            32_000,
            44_100.5,
            96_000,
            Double.greatestFiniteMagnitude,
            Double.nan,
            Double.infinity,
            -Double.infinity,
        ]
        let supportedMap = MixerPlayerClockMap(sampleOffset: 0, sampleRate: 44_100)
        #expect(supportedMap != nil)
        if let supportedMap {
            #expect(LivePhraseWindowAssembler(
                sampleRate: 48_000,
                clockMap: supportedMap,
                initialCounters: .zero
            ) == nil)
        }

        for sampleRate in unsupportedRates {
            #expect(MixerPlayerClockMap(sampleOffset: 0, sampleRate: sampleRate) == nil)
            guard let supportedMap else { continue }
            let assembler = LivePhraseWindowAssembler(
                sampleRate: sampleRate,
                clockMap: supportedMap,
                initialCounters: .zero
            )
            #expect(assembler == nil)
        }

        for sampleRate in [44_100.0, 48_000.0] {
            let first = MixerPlayerClockProbe(
                mixerSample: 0,
                playerSample: 512,
                mixerSampleRate: sampleRate,
                playerSampleRate: sampleRate
            )
            let second = MixerPlayerClockProbe(
                mixerSample: 1_024,
                playerSample: 1_536,
                mixerSampleRate: sampleRate,
                playerSampleRate: sampleRate
            )
            #expect(MixerPlayerClockMap.stable(first: first, second: second) != nil)
        }
    }

    @Test("The first exact three seconds are assembled at each supported route rate")
    func assemblesFirstExactThreeSeconds() {
        for sampleRate in [44_100.0, 48_000.0] {
            let expectedFrameCount = sampleRate == 44_100 ? 132_300 : 144_000
            let range = makeRange(
                phraseIndex: Int(sampleRate),
                startSample: 20_000,
                frameCount: expectedFrameCount + 2_048
            )
            var ledger = ScheduledPhraseLedger()
            ledger.setPlaying(range)
            var assembler = makeAssembler(sampleRate: sampleRate)
            let windows = feed(
                frameCount: expectedFrameCount,
                range: range,
                ledger: ledger,
                assembler: &assembler,
                leadingFrames: 512
            )

            #expect(windows.count == 1)
            #expect(windows.first?.phraseIndex == range.phraseIndex)
            #expect(windows.first?.planFingerprint == range.planFingerprint)
            #expect(windows.first?.playerSampleRange ==
                    range.playerSampleRange.lowerBound..<(range.playerSampleRange.lowerBound + Int64(expectedFrameCount)))
            #expect(windows.first?.left.count == expectedFrameCount)
            #expect(windows.first?.right.count == expectedFrameCount)
            #expect(windows.first?.left.first == 512)
            #expect(windows.first?.right.first == -512)
            #expect(windows.first?.left.last == Float((expectedFrameCount + 511) % 1_024))
            #expect(windows.first?.right.last == -Float((expectedFrameCount + 511) % 1_024))
            #expect(assembler.unavailability(for: range) == nil)
        }
    }

    @Test("Gaps, duplicates, counter changes, generation changes, and non-finite PCM reject")
    func rejectsGapDuplicateAndGenerationChange() {
        let range = makeRange(phraseIndex: 7, startSample: 10_000, frameCount: 160_000)
        let ledger = ledger(playing: range)

        assertRejected(
            range: range,
            ledger: ledger,
            first: packet(sequence: 0, firstPlayerSample: 10_000),
            second: packet(sequence: 2, firstPlayerSample: 11_024),
            reason: .packetSequenceDiscontinuity
        )
        assertRejected(
            range: range,
            ledger: ledger,
            first: packet(sequence: 0, firstPlayerSample: 10_000),
            second: packet(sequence: 0, firstPlayerSample: 11_024),
            reason: .packetSequenceDiscontinuity
        )
        assertRejected(
            range: range,
            ledger: ledger,
            first: packet(sequence: 0, firstPlayerSample: 10_000),
            second: packet(sequence: 1, firstPlayerSample: 11_025),
            reason: .sampleGap
        )
        assertRejected(
            range: range,
            ledger: ledger,
            first: packet(sequence: 0, firstPlayerSample: 10_000),
            second: packet(sequence: 1, firstPlayerSample: 11_023),
            reason: .sampleOverlap
        )
        assertRejected(
            range: range,
            ledger: ledger,
            first: packet(sequence: 0, firstPlayerSample: 10_000),
            second: packet(
                sequence: 1,
                firstPlayerSample: 11_024,
                counters: LivePCMQueueCounterSnapshot(droppedPackets: 1, rejectedPackets: 0)
            ),
            reason: .queueDropDelta
        )
        assertRejected(
            range: range,
            ledger: ledger,
            first: packet(sequence: 0, firstPlayerSample: 10_000),
            second: packet(
                sequence: 1,
                firstPlayerSample: 11_024,
                counters: LivePCMQueueCounterSnapshot(droppedPackets: 0, rejectedPackets: 1)
            ),
            reason: .rejectedPacketDelta
        )
        assertRejected(
            range: range,
            ledger: ledger,
            first: packet(sequence: 0, firstPlayerSample: 10_000),
            second: packet(sequence: 1, firstPlayerSample: 11_024, routeGeneration: 4),
            reason: .routeGenerationMismatch
        )
        assertRejected(
            range: range,
            ledger: ledger,
            first: packet(sequence: 0, firstPlayerSample: 10_000),
            second: packet(sequence: 1, firstPlayerSample: 11_024, controllerRevision: 10),
            reason: .controllerRevisionMismatch
        )
        assertRejected(
            range: range,
            ledger: ledger,
            first: packet(sequence: 0, firstPlayerSample: 10_000),
            second: packet(
                sequence: 1,
                firstPlayerSample: 11_024,
                replacingFirstLeftSample: .nan
            ),
            reason: .nonFiniteSample
        )

        var evictionLedger = ledger
        var evictionAssembler = makeAssembler(sampleRate: 48_000)
        _ = evictionAssembler.consume(
            packet(sequence: 0, firstPlayerSample: 10_000),
            ledger: evictionLedger
        )
        for phrase in 8...12 {
            evictionLedger.setPlaying(makeRange(
                phraseIndex: phrase,
                startSample: Int64(phrase * 200_000),
                frameCount: 160_000
            ))
        }
        evictionAssembler.reconcile(with: evictionLedger)
        #expect(evictionAssembler.lastUnavailabilityReason == .ledgerEviction)
        #expect(evictionAssembler.unavailability(for: range) == nil)
        #expect(evictionAssembler.bookkeepingIdentityCount <= 4)
    }

    @Test("Historical off-window sequence and counters baseline at phrase onset")
    func phraseOnsetBaselinesHistoricalFaults() {
        let frameCount = 132_300
        let range = makeRange(phraseIndex: 23, startSample: 30_000, frameCount: 150_000)
        let ledger = ledger(playing: range)
        var assembler = makeAssembler(sampleRate: 44_100)

        #expect(assembler.consume(
            packet(
                sequence: 41,
                firstPlayerSample: 20_000,
                counters: LivePCMQueueCounterSnapshot(
                    droppedPackets: 7,
                    rejectedPackets: 11
                )
            ),
            ledger: ledger
        ) == nil)

        let windows = feed(
            frameCount: frameCount,
            range: range,
            ledger: ledger,
            assembler: &assembler,
            startingSequence: 100,
            leadingFrames: 512,
            counters: LivePCMQueueCounterSnapshot(
                droppedPackets: 13,
                rejectedPackets: 17
            )
        )

        #expect(windows.count == 1)
        #expect(windows.first?.left.count == frameCount)
        #expect(assembler.unavailability(for: range) == nil)
    }

    @Test("Assembler bookkeeping remains bounded by the four-record ledger")
    func assemblerBookkeepingRemainsBounded() {
        var ledger = ScheduledPhraseLedger()
        var assembler = makeAssembler(sampleRate: 44_100)
        var firstEmitted: ScheduledPhraseRange?
        var firstRejected: ScheduledPhraseRange?
        var emittedWindowCount = 0

        for phraseIndex in 0..<12 {
            let range = makeRange(
                phraseIndex: phraseIndex,
                startSample: Int64(phraseIndex * 200_000),
                frameCount: 150_000
            )
            ledger.setPlaying(range)

            if phraseIndex % 4 == 1 {
                firstRejected = firstRejected ?? range
                #expect(assembler.consume(
                    packet(
                        sequence: 0,
                        firstPlayerSample: range.playerSampleRange.lowerBound,
                        replacingFirstLeftSample: .nan
                    ),
                    ledger: ledger
                ) == nil)
                #expect(assembler.unavailability(for: range) == .nonFiniteSample)
            } else {
                firstEmitted = firstEmitted ?? range
                let windows = feed(
                    frameCount: 132_300,
                    range: range,
                    ledger: ledger,
                    assembler: &assembler
                )
                emittedWindowCount += windows.count
                #expect(windows.count == 1)
            }

            assembler.reconcile(with: ledger)
            #expect(assembler.trackedEmissionCount <= ledger.retainedRanges.count)
            #expect(assembler.trackedUnavailabilityCount <= ledger.retainedRanges.count)
            #expect(assembler.bookkeepingIdentityCount <= 4)
        }

        #expect(emittedWindowCount == 9)
        if let firstEmitted {
            #expect(!assembler.hasEmitted(firstEmitted))
            ledger.setPlaying(firstEmitted)
            #expect(feed(
                frameCount: 132_300,
                range: firstEmitted,
                ledger: ledger,
                assembler: &assembler
            ).isEmpty)
            #expect(assembler.unavailability(for: firstEmitted) ==
                    .staleScheduledOccurrence)
        }
        if let firstRejected {
            ledger.setPlaying(firstRejected)
            #expect(feed(
                frameCount: 132_300,
                range: firstRejected,
                ledger: ledger,
                assembler: &assembler
            ).isEmpty)
            #expect(assembler.unavailability(for: firstRejected) ==
                    .staleScheduledOccurrence)
        }
        if let firstEmitted {
            let laterOccurrence = ScheduledPhraseRange(
                phraseIndex: firstEmitted.phraseIndex,
                planFingerprint: firstEmitted.planFingerprint,
                playerSampleRange: 3_000_000..<3_150_000,
                routeGeneration: firstEmitted.routeGeneration,
                controllerRevision: firstEmitted.controllerRevision
            )
            ledger.setPlaying(laterOccurrence)
            #expect(feed(
                frameCount: 132_300,
                range: laterOccurrence,
                ledger: ledger,
                assembler: &assembler
            ).count == 1)
        }
        #expect(assembler.bookkeepingIdentityCount <= 4)
    }

    @Test("A newer route resets only its sample watermark and older routes stay stale")
    func routeGenerationRetirementIsMonotonicAndBounded() {
        var ledger = ScheduledPhraseLedger()
        var assembler = makeAssembler(sampleRate: 44_100)

        for phraseIndex in 0..<5 {
            let range = makeRange(
                phraseIndex: phraseIndex,
                startSample: Int64(phraseIndex * 200_000),
                frameCount: 150_000,
                routeGeneration: 3
            )
            ledger.setPlaying(range)
            #expect(feed(
                frameCount: 132_300,
                range: range,
                ledger: ledger,
                assembler: &assembler
            ).count == 1)
        }

        #expect(assembler.retirementRouteGeneration == 3)
        #expect(assembler.retiredThroughPlayerSample == 349_999)

        let restartedRoute = makeRange(
            phraseIndex: 5,
            startSample: 0,
            frameCount: 150_000,
            routeGeneration: 4
        )
        ledger.setPlaying(restartedRoute)
        #expect(feed(
            frameCount: 132_300,
            range: restartedRoute,
            ledger: ledger,
            assembler: &assembler
        ).count == 1)
        #expect(assembler.retirementRouteGeneration == 4)
        #expect(assembler.retiredThroughPlayerSample == nil)

        let oldRouteAtLaterSamples = makeRange(
            phraseIndex: 6,
            startSample: 10_000_000,
            frameCount: 150_000,
            routeGeneration: 3
        )
        ledger.setPlaying(oldRouteAtLaterSamples)
        #expect(feed(
            frameCount: 132_300,
            range: oldRouteAtLaterSamples,
            ledger: ledger,
            assembler: &assembler
        ).isEmpty)
        #expect(assembler.unavailability(for: oldRouteAtLaterSamples) ==
                .staleScheduledOccurrence)

        let nextRestart = makeRange(
            phraseIndex: 7,
            startSample: 0,
            frameCount: 150_000,
            routeGeneration: 5
        )
        ledger.setPlaying(nextRestart)
        #expect(feed(
            frameCount: 132_300,
            range: nextRestart,
            ledger: ledger,
            assembler: &assembler
        ).count == 1)
        #expect(assembler.retirementRouteGeneration == 5)
        #expect(assembler.retiredThroughPlayerSample == nil)
        #expect(assembler.bookkeepingIdentityCount <= 4)
    }

    @Test("The ledger retains playing, successor, and exactly two recent ranges")
    func retainsPlayingSuccessorAndTwoRecentRanges() {
        var ledger = ScheduledPhraseLedger()
        let phrases = (1...5).map {
            makeRange(
                phraseIndex: $0,
                startSample: Int64($0 * 200_000),
                frameCount: 160_000
            )
        }

        ledger.setPlaying(phrases[0])
        ledger.setScheduledSuccessor(phrases[1])
        ledger.setPlaying(phrases[1])
        ledger.setScheduledSuccessor(phrases[2])
        ledger.setPlaying(phrases[2])
        ledger.setScheduledSuccessor(phrases[3])
        ledger.setPlaying(phrases[3])
        ledger.setScheduledSuccessor(phrases[4])

        #expect(ledger.playing == phrases[3])
        #expect(ledger.scheduledSuccessor == phrases[4])
        #expect(ledger.recent == [phrases[2], phrases[1]])
        #expect(ledger.retainedRanges.count == 4)
        #expect(!ledger.contains(phrases[0]))
        #expect(ledger.contains(phrases[1]))
    }

    @Test("A phrase window is emitted at most once")
    func doesNotEmitTwiceForOnePhrase() {
        let frameCount = 132_300
        let range = makeRange(phraseIndex: 19, startSample: 30_000, frameCount: 150_000)
        let ledger = ledger(playing: range)
        var assembler = makeAssembler(sampleRate: 44_100)

        let firstPass = feed(
            frameCount: frameCount,
            range: range,
            ledger: ledger,
            assembler: &assembler
        )
        let secondPass = feed(
            frameCount: frameCount,
            range: range,
            ledger: ledger,
            assembler: &assembler,
            startingSequence: 1_000
        )

        #expect(firstPass.count == 1)
        #expect(secondPass.isEmpty)
        #expect(assembler.hasEmitted(range))
    }

    private func makeAssembler(sampleRate: Double) -> LivePhraseWindowAssembler {
        LivePhraseWindowAssembler(
            sampleRate: sampleRate,
            clockMap: MixerPlayerClockMap(sampleOffset: 512, sampleRate: sampleRate)!,
            initialCounters: .zero
        )!
    }

    private func makeRange(
        phraseIndex: Int,
        startSample: Int64,
        frameCount: Int,
        routeGeneration: Int = 3,
        controllerRevision: Int = 9
    ) -> ScheduledPhraseRange {
        ScheduledPhraseRange(
            phraseIndex: phraseIndex,
            planFingerprint: "plan-\(phraseIndex)",
            playerSampleRange: startSample..<(startSample + Int64(frameCount)),
            routeGeneration: routeGeneration,
            controllerRevision: controllerRevision
        )
    }

    private func ledger(playing: ScheduledPhraseRange) -> ScheduledPhraseLedger {
        var ledger = ScheduledPhraseLedger()
        ledger.setPlaying(playing)
        return ledger
    }

    private func packet(
        sequence: UInt64,
        firstPlayerSample: Int64,
        frameCount: Int = 1_024,
        routeGeneration: Int = 3,
        controllerRevision: Int = 9,
        counters: LivePCMQueueCounterSnapshot = .zero,
        replacingFirstLeftSample: Float? = nil
    ) -> ConsumedLivePCMPacket {
        var left = (0..<frameCount).map { Float($0) }
        if let replacingFirstLeftSample {
            left[0] = replacingFirstLeftSample
        }
        return ConsumedLivePCMPacket(
            packetSequence: sequence,
            firstMixerSample: firstPlayerSample - 512,
            routeGeneration: routeGeneration,
            controllerRevision: controllerRevision,
            counters: counters,
            left: left,
            right: (0..<frameCount).map { -Float($0) }
        )
    }

    private func feed(
        frameCount: Int,
        range: ScheduledPhraseRange,
        ledger: ScheduledPhraseLedger,
        assembler: inout LivePhraseWindowAssembler,
        startingSequence: UInt64 = 0,
        leadingFrames: Int = 0,
        counters: LivePCMQueueCounterSnapshot = .zero
    ) -> [LivePhrasePCMWindow] {
        var windows: [LivePhrasePCMWindow] = []
        var consumedFrames = -leadingFrames
        var sequence = startingSequence
        while consumedFrames < frameCount {
            let count = min(1_024, frameCount - consumedFrames)
            if let window = assembler.consume(
                packet(
                    sequence: sequence,
                    firstPlayerSample: range.playerSampleRange.lowerBound + Int64(consumedFrames),
                    frameCount: count,
                    routeGeneration: range.routeGeneration,
                    controllerRevision: range.controllerRevision,
                    counters: counters
                ),
                ledger: ledger
            ) {
                windows.append(window)
            }
            consumedFrames += count
            sequence += 1
        }
        return windows
    }

    private func assertRejected(
        range: ScheduledPhraseRange,
        ledger: ScheduledPhraseLedger,
        first: ConsumedLivePCMPacket,
        second: ConsumedLivePCMPacket,
        reason: LivePhraseWindowUnavailabilityReason
    ) {
        var assembler = makeAssembler(sampleRate: 48_000)
        #expect(assembler.consume(first, ledger: ledger) == nil)
        #expect(assembler.consume(second, ledger: ledger) == nil)
        #expect(assembler.unavailability(for: range) == reason)
        #expect(!assembler.hasEmitted(range))
    }
}
