import AutoTechnoApp
import Testing

@Suite("Playing time presentation")
struct PlayingTimeTests {
    @Test("Elapsed time follows exact rendered sample time at supported rates")
    func followsRenderedSamples() {
        var clock = PlayingTimeClock()

        #expect(clock.observe(sampleTime: 44_100, sampleRate: 44_100) == 1)
        #expect(clock.observe(sampleTime: 144_000, sampleRate: 48_000) == 3)
        #expect(clock.elapsedWholeSeconds == 3)
    }

    @Test("Pause and timeline recovery preserve elapsed playing time")
    func preservesElapsedTimeAcrossTimelineReset() {
        var clock = PlayingTimeClock()

        #expect(clock.observe(sampleTime: 220_500, sampleRate: 44_100) == 5)
        clock.preserveForTimelineReset()
        #expect(clock.observe(sampleTime: 48_000, sampleRate: 48_000) == 6)
        #expect(clock.observe(sampleTime: 24_000, sampleRate: 48_000) == 6)
        #expect(clock.observe(sampleTime: 96_000, sampleRate: 48_000) == 7)

        clock.reset()
        #expect(clock.elapsedWholeSeconds == 0)
    }

    @Test("Invalid player times fail closed without moving the clock")
    func rejectsInvalidPlayerTimes() {
        var clock = PlayingTimeClock()
        #expect(clock.observe(sampleTime: 96_000, sampleRate: 48_000) == 2)

        #expect(clock.observe(sampleTime: -1, sampleRate: 48_000) == 2)
        #expect(clock.observe(sampleTime: 96_000, sampleRate: 0) == 2)
        #expect(clock.observe(sampleTime: 96_000, sampleRate: .nan) == 2)
    }

    @Test("Playing time uses compact clock notation")
    func formatsCompactClockNotation() {
        #expect(PlayingTimeFormatter.string(forWholeSeconds: 0) == "00:00")
        #expect(PlayingTimeFormatter.string(forWholeSeconds: 65) == "01:05")
        #expect(PlayingTimeFormatter.string(forWholeSeconds: 3_599) == "59:59")
        #expect(PlayingTimeFormatter.string(forWholeSeconds: 3_600) == "1:00:00")
        #expect(PlayingTimeFormatter.string(forWholeSeconds: 36_061) == "10:01:01")
        #expect(PlayingTimeFormatter.string(forWholeSeconds: -1) == "00:00")
    }
}
