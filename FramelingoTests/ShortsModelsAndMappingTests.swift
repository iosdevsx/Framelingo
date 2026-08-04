import Foundation
import Testing
@testable import Framelingo

struct ShortsModelsTests {
    @Test
    func testProjectJSONWithoutShortsKeysDecodesWithDefaults() throws {
        var project = MockData.project
        project.shorts = [ShortDefinition(title: "Marked", startMs: 0, endMs: 5_000)]

        let encoded = try JSONEncoder().encode(project)
        var jsonObject = try #require(
            try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        jsonObject.removeValue(forKey: "shorts")
        jsonObject.removeValue(forKey: "shortsExportSettings")
        let legacyData = try JSONSerialization.data(withJSONObject: jsonObject)

        let decoded = try JSONDecoder().decode(Project.self, from: legacyData)

        #expect(decoded.shorts.isEmpty)
        #expect(decoded.shortsExportSettings == ShortsExportSettings())
    }

    @Test
    func testShortDefinitionRoundtripsThroughJSON() throws {
        let short = ShortDefinition(
            title: "Обгон Ферстаппена",
            startMs: 65_000,
            endMs: 118_000,
            reframing: .crop,
            cropOffsetX: 0.8,
            cropKeyframes: [
                ShortCropKeyframe(timeMs: 4_000, offsetX: 0.2),
                ShortCropKeyframe(timeMs: 9_000, offsetX: 0.75)
            ],
            hookText: "ЧТО ОН СДЕЛАЛ",
            platformOverride: .tiktok
        )

        let decoded = try JSONDecoder().decode(
            ShortDefinition.self,
            from: JSONEncoder().encode(short)
        )

        #expect(decoded == short)
    }

    @Test
    func testLegacyShortAndSettingsDecodeNewFieldsWithSafeDefaults() throws {
        let shortJSON = Data(#"""
        {
          "id":"D6C33742-D7C7-4CCB-B5CB-0C5A58DB8A20",
          "title":"Legacy",
          "startMs":1000,
          "endMs":5000,
          "cropOffsetX":0.7
        }
        """#.utf8)
        let short = try JSONDecoder().decode(ShortDefinition.self, from: shortJSON)
        let settings = try JSONDecoder().decode(ShortsExportSettings.self, from: Data("{}".utf8))

        #expect(short.cropKeyframes.isEmpty)
        #expect(short.cropOffset(atTimelineTimeMs: 3_000) == 0.7)
        #expect(settings.burnSubtitlesIntoVideo)
        #expect(settings.subtitleStyle.fontSize == 64)
        #expect(settings.subtitleStyle.maxLines == 3)
        #expect(settings.subtitleStyle.subtitlePositionX == 0.5)
        #expect(settings.subtitleStyle.subtitlePositionY == 0.68)
    }

    @Test
    func testPersistedShortsSubtitleStyleRoundTripsThroughJSON() throws {
        var settings = ShortsExportSettings()
        settings.subtitleStyle.fontName = "Helvetica Neue"
        settings.subtitleStyle.fontSize = 82
        settings.subtitleStyle.subtitleTextMode = .translated
        settings.subtitleStyle.textColorRed = 0.2
        settings.subtitleStyle.subtitlePositionX = 0.27
        settings.subtitleStyle.subtitlePositionY = 0.44

        let decoded = try JSONDecoder().decode(
            ShortsExportSettings.self,
            from: JSONEncoder().encode(settings)
        )

        #expect(decoded == settings)
    }

    @MainActor
    @Test
    func testRegularAndShortsAppearanceMutationsStayIsolatedAndRoundTrip() throws {
        var project = MockData.project
        project.videoExportSettings.fontName = "Arial"
        project.videoExportSettings.fontSize = 32
        project.shortsExportSettings.subtitleStyle.fontName = "Avenir Next"
        project.shortsExportSettings.subtitleStyle.fontSize = 70
        let subtitles = project.subtitles

        let appState = AppState()
        appState.selectedProject = project
        let viewModel = ProjectViewModel(appState: appState)

        var shortsStyle = try #require(viewModel.project?.shortsExportSettings.subtitleStyle)
        shortsStyle.fontSize = 88
        shortsStyle.subtitleTextMode = .translated
        viewModel.updateShortsSubtitleStyle(shortsStyle)

        let updated = try #require(viewModel.project)
        #expect(updated.videoExportSettings.fontName == "Arial")
        #expect(updated.videoExportSettings.fontSize == 32)
        #expect(updated.shortsExportSettings.subtitleStyle.fontName == "Avenir Next")
        #expect(updated.shortsExportSettings.subtitleStyle.fontSize == 88)
        #expect(updated.shortsExportSettings.subtitleStyle.subtitleTextMode == .translated)
        #expect(updated.subtitles == subtitles)
        #expect(viewModel.canUndo)

        let decoded = try JSONDecoder().decode(
            Project.self,
            from: JSONEncoder().encode(updated)
        )
        #expect(decoded.videoExportSettings == updated.videoExportSettings)
        #expect(decoded.shortsExportSettings.subtitleStyle == updated.shortsExportSettings.subtitleStyle)

        viewModel.undo()
        #expect(viewModel.project?.videoExportSettings.fontSize == 32)
        #expect(viewModel.project?.shortsExportSettings.subtitleStyle.fontSize == 70)
        #expect(viewModel.project?.subtitles == subtitles)
    }

    @MainActor
    @Test
    func testInteractiveShortsSubtitlePositionEditRegistersSingleUndoSnapshot() throws {
        var project = MockData.project
        project.shortsExportSettings.subtitleStyle.subtitlePositionX = 0.5
        project.shortsExportSettings.subtitleStyle.subtitlePositionY = 0.68

        let appState = AppState()
        appState.selectedProject = project
        let viewModel = ProjectViewModel(appState: appState)
        viewModel.beginInteractiveShortsSubtitleStyleEdit()

        var style = project.shortsExportSettings.subtitleStyle
        style.subtitlePositionX = 0.4
        viewModel.updateShortsSubtitleStyle(style, registerUndo: false)
        style.subtitlePositionX = 0.3
        style.subtitlePositionY = 0.5
        viewModel.updateShortsSubtitleStyle(style, registerUndo: false)
        viewModel.endInteractiveShortsSubtitleStyleEdit()

        #expect(viewModel.canUndo)
        #expect(viewModel.project?.shortsExportSettings.subtitleStyle.subtitlePositionX == 0.3)
        #expect(viewModel.project?.shortsExportSettings.subtitleStyle.subtitlePositionY == 0.5)

        viewModel.undo()
        #expect(viewModel.project?.shortsExportSettings.subtitleStyle.subtitlePositionX == 0.5)
        #expect(viewModel.project?.shortsExportSettings.subtitleStyle.subtitlePositionY == 0.68)
    }

    @Test
    func testCropPointsSwitchAtTheirLocalTimesWithoutInterpolation() {
        let short = ShortDefinition(
            title: "Interview",
            startMs: 10_000,
            endMs: 30_000,
            cropOffsetX: 0.5,
            cropKeyframes: [
                ShortCropKeyframe(timeMs: 2_000, offsetX: 0.15),
                ShortCropKeyframe(timeMs: 8_000, offsetX: 0.85)
            ]
        )

        #expect(short.cropOffset(atTimelineTimeMs: 11_999) == 0.5)
        #expect(short.cropOffset(atTimelineTimeMs: 12_000) == 0.15)
        #expect(short.cropOffset(atTimelineTimeMs: 17_999) == 0.15)
        #expect(short.cropOffset(atTimelineTimeMs: 18_000) == 0.85)
    }

    @Test
    func testEffectivePlatformAndReframingFallBackToDefaults() {
        let short = ShortDefinition(title: "Plain", startMs: 0, endMs: 1_000)

        #expect(short.effectivePlatform(default: .instagramReels) == .instagramReels)
        #expect(short.effectiveReframing(default: .blurPad) == .blurPad)

        var overridden = short
        overridden.platformOverride = .tiktok
        overridden.reframing = .crop
        #expect(overridden.effectivePlatform(default: .instagramReels) == .tiktok)
        #expect(overridden.effectiveReframing(default: .blurPad) == .crop)
    }

    @MainActor
    @Test
    func testCreateShortFromMultiCueSelectionAndUndo() throws {
        var project = MockData.project
        project.shorts = []
        project.subtitles = [
            makeCue(index: 1, startMs: 10_000, endMs: 12_000),
            makeCue(index: 2, startMs: 13_000, endMs: 15_000),
            makeCue(index: 3, startMs: 16_000, endMs: 19_000)
        ]

        let appState = AppState()
        appState.selectedProject = project
        let viewModel = ProjectViewModel(appState: appState)
        viewModel.selectSegment(id: project.subtitles[0].id)
        viewModel.selectSegment(
            id: project.subtitles[2].id,
            extendingSelection: true
        )
        viewModel.createShortFromSelectedCues()

        let short = try #require(viewModel.project?.shorts.first)
        #expect(viewModel.selectedCueIDs.count == 3)
        #expect(short.startMs == 10_000)
        #expect(short.endMs == 19_000)

        viewModel.undo()
        #expect(viewModel.project?.shorts.isEmpty == true)
    }

    @MainActor
    @Test
    func testInteractiveCropEditRegistersSingleUndoSnapshot() throws {
        var project = MockData.project
        let short = ShortDefinition(
            title: "Crop",
            startMs: 0,
            endMs: 5_000,
            reframing: .crop,
            cropOffsetX: 0.5
        )
        project.shorts = [short]

        let appState = AppState()
        appState.selectedProject = project
        let viewModel = ProjectViewModel(appState: appState)
        viewModel.beginInteractiveShortEdit()
        viewModel.updateShort(id: short.id) { $0.cropOffsetX = 0.7 }
        viewModel.updateShort(id: short.id) { $0.cropOffsetX = 0.8 }
        viewModel.endInteractiveShortEdit(undoActionName: "Adjust Crop Framing")

        #expect(viewModel.canUndo)
        #expect(viewModel.project?.shorts.first?.cropOffsetX == 0.8)
        viewModel.undo()
        #expect(viewModel.project?.shorts.first?.cropOffsetX == 0.5)
    }

    @MainActor
    @Test
    func testSetShortEdgesToPlayheadAndDeleteSelectedShort() throws {
        var project = MockData.project
        let short = ShortDefinition(title: "Range", startMs: 10_000, endMs: 30_000)
        project.shorts = [short]

        let appState = AppState()
        appState.selectedProject = project
        let viewModel = ProjectViewModel(appState: appState)
        viewModel.shortsSelectedShortID = short.id
        viewModel.currentTimeMs = 14_000
        viewModel.setSelectedShortStartToPlayhead()
        #expect(viewModel.selectedShort?.startMs == 14_000)

        viewModel.currentTimeMs = 24_000
        viewModel.setSelectedShortEndToPlayhead()
        #expect(viewModel.selectedShort?.endMs == 24_000)

        viewModel.deleteSelectedShort()
        #expect(viewModel.project?.shorts.isEmpty == true)
    }

    @MainActor
    @Test
    func testSetStartOutsideSelectionCreatesNewPlayheadRange() throws {
        var project = MockData.project
        let existing = ShortDefinition(title: "Existing", startMs: 10_000, endMs: 20_000)
        project.shorts = [existing]

        let appState = AppState()
        appState.selectedProject = project
        let viewModel = ProjectViewModel(appState: appState)
        viewModel.shortsSelectedShortID = existing.id
        viewModel.currentTimeMs = 25_000
        viewModel.setShortStartFromPlayhead()

        #expect(viewModel.pendingShortStartMs == 25_000)
        #expect(viewModel.project?.shorts.count == 1)

        viewModel.currentTimeMs = 30_000
        viewModel.setShortEndFromPlayhead()

        #expect(viewModel.pendingShortStartMs == nil)
        #expect(viewModel.project?.shorts.count == 2)
        #expect(viewModel.selectedShort?.startMs == 25_000)
        #expect(viewModel.selectedShort?.endMs == 30_000)
    }

    @MainActor
    @Test
    func testSetStartInsideSelectionEditsExistingShort() throws {
        var project = MockData.project
        let existing = ShortDefinition(title: "Existing", startMs: 10_000, endMs: 20_000)
        project.shorts = [existing]

        let appState = AppState()
        appState.selectedProject = project
        let viewModel = ProjectViewModel(appState: appState)
        viewModel.shortsSelectedShortID = existing.id
        viewModel.currentTimeMs = 12_000
        viewModel.setShortStartFromPlayhead()

        #expect(viewModel.pendingShortStartMs == nil)
        #expect(viewModel.selectedShort?.startMs == 12_000)
        #expect(viewModel.project?.shorts.count == 1)
    }

    private func makeCue(index: Int, startMs: Int, endMs: Int) -> SubtitleSegment {
        SubtitleSegment(
            id: UUID(),
            index: index,
            startMs: startMs,
            endMs: endMs,
            originalText: "Cue \(index)",
            translatedText: ""
        )
    }
}

struct ShortsTimelineSnapperTests {
    private let cues = [
        SubtitleSegment(
            id: UUID(),
            index: 1,
            startMs: 5_000,
            endMs: 7_000,
            originalText: "Cue",
            translatedText: ""
        )
    ]

    @Test
    func testSnapThresholdDependsOnZoom() {
        let zoomedOut = ShortsTimelineSnapper.snapped(
            4_200,
            to: cues,
            enabled: true,
            thresholdPx: 10,
            pxPerMs: 0.01
        )
        let zoomedIn = ShortsTimelineSnapper.snapped(
            4_200,
            to: cues,
            enabled: true,
            thresholdPx: 10,
            pxPerMs: 0.1
        )

        #expect(zoomedOut == 5_000)
        #expect(zoomedIn == 4_200)
    }

    @Test
    func testDisabledSnapKeepsReleasedPosition() {
        #expect(ShortsTimelineSnapper.snapped(
            4_950,
            to: cues,
            enabled: false,
            thresholdPx: 10,
            pxPerMs: 0.1
        ) == 4_950)
    }
}

struct ShortsRangeHitTestTests {
    @Test
    func testWideShortUsesEdgesForResizeAndCenterForMove() {
        #expect(ShortsRangeHitTest.target(at: 10, width: 200) == .leading)
        #expect(ShortsRangeHitTest.target(at: 100, width: 200) == .body)
        #expect(ShortsRangeHitTest.target(at: 190, width: 200) == .trailing)
    }

    @Test
    func testNarrowShortStillKeepsMovableCenter() {
        #expect(ShortsRangeHitTest.target(at: 1, width: 14) == .leading)
        #expect(ShortsRangeHitTest.target(at: 7, width: 14) == .body)
        #expect(ShortsRangeHitTest.target(at: 13, width: 14) == .trailing)
    }
}

struct ShortsTimelineMappingTests {
    private let service = SubtitleTimelineMappingService()

    @Test
    func testShortBeforeCutIsUnchanged() {
        let shorts = [ShortDefinition(title: "A", startMs: 0, endMs: 10_000)]

        let updated = service.rippleDeleteShorts(
            shorts: shorts,
            range: VideoCutRange(startMs: 20_000, endMs: 30_000)
        )

        #expect(updated == shorts)
    }

    @Test
    func testShortAfterCutShiftsLeft() {
        let shorts = [ShortDefinition(id: UUID(), title: "B", startMs: 300_000, endMs: 340_000)]

        let updated = service.rippleDeleteShorts(
            shorts: shorts,
            range: VideoCutRange(startMs: 20_000, endMs: 30_000)
        )

        #expect(updated.count == 1)
        #expect(updated[0].startMs == 290_000)
        #expect(updated[0].endMs == 330_000)
        #expect(updated[0].id == shorts[0].id)
    }

    @Test
    func testShortContainingCutShrinks() {
        let shorts = [ShortDefinition(title: "C", startMs: 10_000, endMs: 50_000)]

        let updated = service.rippleDeleteShorts(
            shorts: shorts,
            range: VideoCutRange(startMs: 20_000, endMs: 30_000)
        )

        #expect(updated.count == 1)
        #expect(updated[0].startMs == 10_000)
        #expect(updated[0].endMs == 40_000)
    }

    @Test
    func testRippleDeleteRetimesAndDropsCropPoints() throws {
        let short = ShortDefinition(
            title: "Interview",
            startMs: 10_000,
            endMs: 50_000,
            cropKeyframes: [
                ShortCropKeyframe(timeMs: 5_000, offsetX: 0.1),
                ShortCropKeyframe(timeMs: 15_000, offsetX: 0.5),
                ShortCropKeyframe(timeMs: 30_000, offsetX: 0.9)
            ]
        )

        let updated = try #require(service.rippleDeleteShorts(
            shorts: [short],
            range: VideoCutRange(startMs: 20_000, endMs: 30_000)
        ).first)

        #expect(updated.cropKeyframes.map(\.timeMs) == [5_000, 20_000])
        #expect(updated.cropKeyframes.map(\.offsetX) == [0.1, 0.9])
    }

    @Test
    func testShortInsideCutIsDropped() {
        let shorts = [
            ShortDefinition(title: "Gone", startMs: 22_000, endMs: 28_000),
            ShortDefinition(title: "Kept", startMs: 40_000, endMs: 45_000)
        ]

        let updated = service.rippleDeleteShorts(
            shorts: shorts,
            range: VideoCutRange(startMs: 20_000, endMs: 30_000)
        )

        #expect(updated.count == 1)
        #expect(updated[0].title == "Kept")
        #expect(updated[0].startMs == 30_000)
        #expect(updated[0].endMs == 35_000)
    }

    @Test
    func testShortOverlappingCutEdgesIsTrimmed() {
        let shorts = [
            ShortDefinition(title: "Head", startMs: 15_000, endMs: 25_000),
            ShortDefinition(title: "Tail", startMs: 25_000, endMs: 35_000)
        ]

        let updated = service.rippleDeleteShorts(
            shorts: shorts,
            range: VideoCutRange(startMs: 20_000, endMs: 30_000)
        )

        #expect(updated.count == 2)
        #expect(updated[0].startMs == 15_000)
        #expect(updated[0].endMs == 20_000)
        #expect(updated[1].startMs == 20_000)
        #expect(updated[1].endMs == 25_000)
    }
}

struct ShortsFilenameTemplateTests {
    @Test
    func testTemplateExpansionWithCyrillicTitleAndPaddedIndex() {
        let name = ShortsFilenameTemplate.baseName(
            template: "{project} — {index} {title}",
            projectName: "F1 GP",
            index: 2,
            totalCount: 8,
            shortTitle: "Питстоп"
        )

        #expect(name == "F1 GP — 02 Питстоп")
    }

    @Test
    func testIllegalCharactersAreReplaced() {
        let name = ShortsFilenameTemplate.baseName(
            template: "{title}",
            projectName: "P",
            index: 1,
            totalCount: 1,
            shortTitle: "AB/CD:EF?"
        )

        #expect(name == "AB CD EF")
    }

    @Test
    func testEmptyExpansionFallsBackToNumberedDefault() {
        let name = ShortsFilenameTemplate.baseName(
            template: "{title}",
            projectName: "P",
            index: 3,
            totalCount: 12,
            shortTitle: "   "
        )

        #expect(name == "Short 03")
    }

    @Test
    func testCollisionSuffixingAgainstDiskAndReservedPaths() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShortsNames-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let existing = directory.appendingPathComponent("Clip.mp4")
        try Data().write(to: existing)

        let second = ShortsFilenameTemplate.availableURL(
            in: directory,
            baseName: "Clip",
            fileExtension: "mp4"
        )
        #expect(second.lastPathComponent == "Clip 2.mp4")

        let third = ShortsFilenameTemplate.availableURL(
            in: directory,
            baseName: "Clip",
            fileExtension: "mp4",
            reservedPaths: [second.path]
        )
        #expect(third.lastPathComponent == "Clip 3.mp4")
    }
}

struct ShortsSuggestionServiceTests {
    private let service = ShortsSuggestionService()

    @Test
    func testSuggestionsSplitAtSilenceGaps() {
        var cues: [SubtitleSegment] = []
        // Three 60s speech blocks separated by 2s pauses.
        for block in 0..<3 {
            let blockStart = block * 62_000
            for cueIndex in 0..<6 {
                let start = blockStart + cueIndex * 10_000
                cues.append(makeCue(index: cues.count + 1, startMs: start, endMs: start + 9_900))
            }
        }

        let suggestions = service.suggestions(cues: cues, platform: .youtubeShorts)

        #expect(suggestions.count == 2)
        #expect(suggestions[0].reason == .pause)
        #expect(suggestions[0].startMs == 0)
        #expect(suggestions[0].endMs == 121_900)
        #expect(suggestions[1].reason == .endOfVideo)
        #expect(suggestions[1].startMs == 124_000)
    }

    @Test
    func testSuggestionsSplitAtSpeakerChanges() {
        let cues = [
            makeCue(index: 1, startMs: 0, endMs: 50_000, speakerId: 1),
            makeCue(index: 2, startMs: 50_100, endMs: 100_000, speakerId: 1),
            makeCue(index: 3, startMs: 100_200, endMs: 150_000, speakerId: 2)
        ]

        let suggestions = service.suggestions(cues: cues, platform: .youtubeShorts)

        #expect(suggestions.count == 2)
        #expect(suggestions[0].reason == .speakerChange)
        #expect(suggestions[0].endMs == 100_000)
        #expect(suggestions[1].startMs == 100_200)
    }

    @Test
    func testNoCuesYieldNoSuggestions() {
        #expect(service.suggestions(cues: [], platform: .tiktok).isEmpty)
    }

    @Test
    func testCandidateClosesBeforeExceedingPlatformLimit() {
        let cues = [
            makeCue(index: 1, startMs: 0, endMs: 100_000),
            makeCue(index: 2, startMs: 100_050, endMs: 200_000)
        ]

        let suggestions = service.suggestions(cues: cues, platform: .youtubeShorts)

        #expect(suggestions.count == 2)
        #expect(suggestions[0].reason == .durationLimit)
        #expect(suggestions[0].endMs == 100_000)
        #expect(suggestions[0].durationMs <= ShortsPlatform.youtubeShorts.durationLimitMs)
    }

    @Test
    func testSuggestionsOverlappingExistingShortsAreFiltered() {
        let cues = [
            makeCue(index: 1, startMs: 0, endMs: 100_000),
            makeCue(index: 2, startMs: 105_000, endMs: 170_000)
        ]
        let existing = [ShortDefinition(title: "Done", startMs: 0, endMs: 60_000)]

        let suggestions = service.suggestions(
            cues: cues,
            platform: .youtubeShorts,
            existingShorts: existing
        )

        #expect(suggestions.allSatisfy { $0.startMs >= 60_000 })
    }

    private func makeCue(
        index: Int,
        startMs: Int,
        endMs: Int,
        speakerId: Int? = nil
    ) -> SubtitleSegment {
        SubtitleSegment(
            id: UUID(),
            index: index,
            startMs: startMs,
            endMs: endMs,
            originalText: "cue \(index)",
            translatedText: "",
            speakerId: speakerId
        )
    }
}
