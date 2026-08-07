import Combine
import ProjectSession
import Shorts
import SpeakerAnalysis
import Subtitles
import TimelineImpl
import XCTest

@testable import ProjectSessionImpl

@MainActor
final class ProjectSessionEditingTests: XCTestCase {
    func testGroupedTypingPublishesCanonicalSubtitlesAndCreatesOneUndoEntry() {
        let (session, _, _) = makeSessionFixture()
        let cue = makeCue(index: 1, start: 0, end: 900, text: "one")
        var project = makeSessionProject()
        project.subtitles = [cue]
        session.open(project)
        session.selectCue(id: cue.id, extending: false, toggling: false)
        session.seek(to: 200)
        var publications = 0
        let subscription = session.snapshots.dropFirst().sink { _ in publications += 1 }

        session.beginInteraction(named: "subtitle-text")
        XCTAssertTrue(session.updateTranslatedText(segmentID: cue.id, text: "два").didChange)
        XCTAssertTrue(session.updateTranslatedText(segmentID: cue.id, text: "три").didChange)
        session.endInteraction(named: "subtitle-text")

        XCTAssertEqual(session.snapshot.project?.subtitles.first?.translatedText, "три")
        XCTAssertEqual(session.snapshot.interaction.cueSelection.primaryCueID, cue.id)
        XCTAssertEqual(session.snapshot.interaction.playback.playheadMs, 200)
        XCTAssertEqual(publications, 3)
        session.undo()
        XCTAssertEqual(session.snapshot.project?.subtitles.first?.translatedText, "")
        XCTAssertEqual(session.snapshot.interaction.cueSelection.primaryCueID, cue.id)
        XCTAssertEqual(session.snapshot.interaction.playback.playheadMs, 200)
        XCTAssertFalse(session.snapshot.history.canUndo)
        withExtendedLifetime(subscription) {}
    }

    func testStructuralDeleteReconcilesSelectionBeforeSinglePublication() {
        let (session, _, _) = makeSessionFixture()
        let first = makeCue(index: 1, start: 0, end: 700, text: "one")
        let second = makeCue(index: 2, start: 800, end: 1_500, text: "two")
        var project = makeSessionProject()
        project.mediaFile.durationMs = 2_000
        project.subtitles = [first, second]
        session.open(project)
        session.selectCue(id: first.id, extending: false, toggling: false)
        var publications = 0
        let subscription = session.snapshots.dropFirst().sink { _ in publications += 1 }

        let result = session.deleteSegment(id: first.id)

        XCTAssertTrue(result.didChange)
        XCTAssertEqual(session.snapshot.project?.subtitles.map(\.id), [second.id])
        XCTAssertEqual(session.snapshot.interaction.cueSelection.primaryCueID, second.id)
        XCTAssertEqual(publications, 1)
        withExtendedLifetime(subscription) {}
    }

    func testInvalidEditDoesNotPublishCreateHistoryOrScheduleSave() async {
        let (session, repository, sleeper) = makeSessionFixture()
        let cue = makeCue(index: 1, start: 0, end: 900, text: "one")
        var project = makeSessionProject()
        project.subtitles = [cue]
        session.open(project)
        var publications = 0
        let subscription = session.snapshots.dropFirst().sink { _ in publications += 1 }
        var invalid = cue
        invalid.startMs = -1

        let result = session.updateSubtitle(invalid)
        await Task.yield()

        XCTAssertFalse(result.didChange)
        XCTAssertNotNil(result.message)
        XCTAssertEqual(publications, 0)
        XCTAssertFalse(session.snapshot.history.canUndo)
        XCTAssertEqual(sleeper.waitingCount, 0)
        let saves = await repository.saves()
        XCTAssertEqual(saves.count, 0)
        withExtendedLifetime(subscription) {}
    }

    func testSuggestionAcceptanceCreatesOneCanonicalShortAndRemovesSuggestion() {
        let (session, _, _) = makeSessionFixture()
        var project = makeSessionProject()
        project.mediaFile.durationMs = 60_000
        project.subtitles = [makeCue(index: 1, start: 0, end: 20_000, text: "A complete idea with useful context")]
        session.open(project)
        session.generateShortsSuggestions()
        guard let suggestion = session.snapshot.interaction.shorts.suggestions.first else {
            XCTFail("Expected suggestion")
            return
        }
        var documentPublications = 0
        let subscription = session.snapshots.dropFirst().sink {
            if $0.project?.shorts.isEmpty == false { documentPublications += 1 }
        }

        let result = session.acceptShortSuggestion(id: suggestion.id)

        XCTAssertTrue(result.didChange)
        XCTAssertEqual(session.snapshot.project?.shorts.count, 1)
        XCTAssertFalse(session.snapshot.interaction.shorts.suggestions.contains(where: { $0.id == suggestion.id }))
        XCTAssertEqual(documentPublications, 2) // document commit, then derived suggestion state
        XCTAssertTrue(session.snapshot.history.canUndo)
        withExtendedLifetime(subscription) {}
    }

    func testRippleDeleteCommitsTimelineCuesWordsSpeakersAndShortsAtomically() {
        let (session, _, _) = makeSessionFixture(
            editTimelineService: TimelineAssembly.makeEditService()
        )
        var project = makeSessionProject()
        project.mediaFile.durationMs = 10_000
        project.subtitles = [makeCue(index: 1, start: 4_000, end: 6_000, text: "crosses cut")]
        project.wordTimings = [WordTiming(text: "after", start: 6, end: 7)]
        project.speakerSegments = [SpeakerSegment(speakerId: 0, start: 1, end: 5)]
        project.shorts = [ShortDefinition(title: "Short", startMs: 5_000, endMs: 8_000)]
        session.open(project)
        XCTAssertTrue(session.ensureTimeline().didChange)
        session.setEditRange(startMs: 2_000, endMs: 4_000)

        let result = session.rippleDeleteSelectedRange()

        XCTAssertTrue(result.didChange)
        XCTAssertEqual(session.snapshot.project?.editTimeline?.totalDurationMs, 8_000)
        XCTAssertEqual(session.snapshot.project?.subtitles.first?.startMs, 2_000)
        XCTAssertEqual(session.snapshot.project?.wordTimings.first?.start, 4)
        XCTAssertEqual(session.snapshot.project?.speakerSegments.first?.end, 3)
        XCTAssertEqual(session.snapshot.project?.shorts.first?.startMs, 3_000)
        XCTAssertTrue(session.snapshot.history.canUndo)
        session.undo()
        XCTAssertEqual(session.snapshot.project?.wordTimings.first?.start, 6)
        XCTAssertEqual(session.snapshot.project?.shorts.first?.startMs, 5_000)
    }
}

private func makeCue(index: Int, start: Int, end: Int, text: String) -> SubtitleSegment {
    SubtitleSegment(
        id: UUID(),
        index: index,
        startMs: start,
        endMs: end,
        originalText: text,
        translatedText: ""
    )
}
