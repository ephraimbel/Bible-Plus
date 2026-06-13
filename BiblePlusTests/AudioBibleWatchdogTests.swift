import Testing
// The app target's PRODUCT_NAME is "Bible Plus", so its Swift module name
// sanitizes to `Bible_Plus` (not `BiblePlus`).
@testable import Bible_Plus

/// Regression coverage for the audio-Bible playback watchdog's recovery
/// decisions — the logic that fixes "audio randomly stops after a couple of
/// verses." The decision is extracted as the pure function
/// `AudioBibleService.watchdogAction(_:)` so we can exercise every failure mode
/// deterministically, without driving a real `AVQueuePlayer` over the network.
///
/// The headline guarantees:
///   1. A verse that has genuinely `.failed` (a corrupt/truncated MP3 that can
///      never play) is *skipped* so it can't wedge the chapter in silence.
///   2. A verse that is merely slow to buffer, or briefly frozen, is NEVER
///      skipped — it's nudged/left to recover and play, so audio doesn't drop
///      verses the listener never heard.
///   3. The final verse freezing at its end completes the chapter (covering a
///      missed end-of-item notification) without dropping heard audio.
struct AudioBibleWatchdogTests {

    typealias Input = AudioBibleService.WatchdogInput

    /// A current item that is genuinely playing with an advancing clock.
    private func healthyPlaying() -> Input {
        Input(
            hasCurrentItem: true,
            isPlaying: true,
            itemFailed: false,
            clockFrozen: false,
            frozenFor: 0,
            notPlayingFor: 0,
            isLastQueuedItem: false,
            atEnd: false,
            hasQueuedAllVerses: false,
            didCompleteChapter: false,
            reachedLastVerse: false
        )
    }

    // MARK: - Healthy playback

    @Test("Playing with an advancing clock is left alone")
    func healthyPlaybackIsIdle() {
        #expect(AudioBibleService.watchdogAction(healthyPlaying()) == .idle)
    }

    @Test("A frozen clock below the stall threshold is not acted on yet")
    func briefFreezeIsIdle() {
        var s = healthyPlaying()
        s.clockFrozen = true
        s.frozenFor = AudioBibleService.watchdogStallSeconds - 0.5
        #expect(AudioBibleService.watchdogAction(s) == .idle)
    }

    @Test("Playing at the end of the last item is NOT completed while the clock still moves")
    func lastItemAtEndButProgressingIsIdle() {
        var s = healthyPlaying()
        s.isLastQueuedItem = true
        s.atEnd = true
        s.hasQueuedAllVerses = true
        // clockFrozen == false → still making progress → don't complete early.
        #expect(AudioBibleService.watchdogAction(s) == .idle)
    }

    // MARK: - Corrupt / failed verse  (primary regression)

    @Test("A failed item is skipped, not nudged — one bad verse can't wedge the chapter")
    func failedItemIsSkipped() {
        var s = healthyPlaying()
        s.isPlaying = false
        s.itemFailed = true
        s.notPlayingFor = 0 // skip is immediate, regardless of grace window
        #expect(AudioBibleService.watchdogAction(s) == .skipStalled)
    }

    @Test("A frozen MIDDLE verse is left to recover, NOT skipped — skipping dropped good verses")
    func frozenMiddleItemIsNotSkipped() {
        var s = healthyPlaying()
        s.clockFrozen = true
        s.frozenFor = AudioBibleService.watchdogStallSeconds + 0.1
        s.isLastQueuedItem = false // a verse mid-chapter
        #expect(AudioBibleService.watchdogAction(s) == .idle)
    }

    @Test("A frozen last verse that is NOT at its end is left to recover, not skipped")
    func frozenLastItemNotAtEndIsNotSkipped() {
        var s = healthyPlaying()
        s.clockFrozen = true
        s.frozenFor = AudioBibleService.watchdogStallSeconds + 0.1
        s.isLastQueuedItem = true
        s.hasQueuedAllVerses = true
        s.atEnd = false // stalled partway through the final verse
        #expect(AudioBibleService.watchdogAction(s) == .idle)
    }

    // MARK: - Loaded-but-not-playing recovery

    @Test("A loaded item that just paused is nudged back to life within the grace window")
    func recentlyStalledItemIsNudged() {
        var s = healthyPlaying()
        s.isPlaying = false
        s.notPlayingFor = AudioBibleService.watchdogNotPlayingGraceSeconds - 1
        #expect(AudioBibleService.watchdogAction(s) == .nudge)
    }

    @Test("A non-failed item that stays un-played is nudged, NOT skipped — buffering must not drop verses")
    func chronicallyStalledNonFailedItemIsNudged() {
        var s = healthyPlaying()
        s.isPlaying = false
        s.notPlayingFor = AudioBibleService.watchdogNotPlayingGraceSeconds + 0.1
        // Not failed — it's still buffering. Keep nudging; never skip a verse
        // just because it's slow to start.
        #expect(AudioBibleService.watchdogAction(s) == .nudge)
    }

    // MARK: - Chapter completion at the end

    @Test("A frozen final verse at its end completes the chapter (missed end-of-item)")
    func frozenLastItemAtEndCompletes() {
        var s = healthyPlaying()
        s.clockFrozen = true
        s.frozenFor = AudioBibleService.watchdogStallSeconds + 0.1
        s.isLastQueuedItem = true
        s.hasQueuedAllVerses = true
        s.atEnd = true
        #expect(AudioBibleService.watchdogAction(s) == .completeChapter)
    }

    @Test("Completion does not re-fire once the chapter is already latched complete")
    func completionLatchPreventsDoubleFire() {
        var s = healthyPlaying()
        s.clockFrozen = true
        s.frozenFor = AudioBibleService.watchdogStallSeconds + 0.1
        s.isLastQueuedItem = true
        s.hasQueuedAllVerses = true
        s.atEnd = true
        s.didCompleteChapter = true
        #expect(AudioBibleService.watchdogAction(s) == .idle)
    }

    // MARK: - Empty queue

    @Test("Empty queue after reaching the last verse completes the chapter")
    func emptyQueueAllPlayedCompletes() {
        var s = healthyPlaying()
        s.hasCurrentItem = false
        s.hasQueuedAllVerses = true
        s.reachedLastVerse = true
        s.didCompleteChapter = false
        #expect(AudioBibleService.watchdogAction(s) == .completeChapter)
    }

    @Test("Empty queue already completed is idle (no double completion)")
    func emptyQueueAlreadyCompletedIsIdle() {
        var s = healthyPlaying()
        s.hasCurrentItem = false
        s.hasQueuedAllVerses = true
        s.reachedLastVerse = true
        s.didCompleteChapter = true
        #expect(AudioBibleService.watchdogAction(s) == .idle)
    }

    @Test("Empty queue mid-stream is buffering, NOT chapter-complete — the original cut-after-a-few-verses bug")
    func emptyQueueMidStreamBuffers() {
        var s = healthyPlaying()
        s.hasCurrentItem = false
        s.hasQueuedAllVerses = false // more verses still generating
        #expect(AudioBibleService.watchdogAction(s) == .startBuffering)
    }

    @Test("Empty queue with all verses queued but NOT at the last verse rebuilds — the queue-collapse skip bug")
    func emptyQueueBeforeLastVerseRecovers() {
        var s = healthyPlaying()
        s.hasCurrentItem = false
        s.hasQueuedAllVerses = true   // every verse WAS queued...
        s.reachedLastVerse = false    // ...but AVQueuePlayer dropped the rest mid-chapter
        s.didCompleteChapter = false
        // Must NOT complete (that would skip the remaining verses) — rebuild instead.
        #expect(AudioBibleService.watchdogAction(s) == .recoverDrain)
    }
}
