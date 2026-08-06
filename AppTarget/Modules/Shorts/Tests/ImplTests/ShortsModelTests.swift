import Foundation
import Shorts
import Subtitles
import Testing

struct ShortsModelTests {
    @Test
    func shortDefinitionRoundtripsThroughJSON() throws {
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
    func legacyShortAndSettingsDecodeNewFieldsWithSafeDefaults() throws {
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
    func persistedSubtitleAppearanceRoundTripsThroughJSON() throws {
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

    @Test
    func cropPointsSwitchAtTheirLocalTimesWithoutInterpolation() {
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
    func effectivePlatformAndReframingFallBackToDefaults() {
        let short = ShortDefinition(title: "Plain", startMs: 0, endMs: 1_000)

        #expect(short.effectivePlatform(default: .instagramReels) == .instagramReels)
        #expect(short.effectiveReframing(default: .blurPad) == .blurPad)

        var overridden = short
        overridden.platformOverride = .tiktok
        overridden.reframing = .crop
        #expect(overridden.effectivePlatform(default: .instagramReels) == .tiktok)
        #expect(overridden.effectiveReframing(default: .blurPad) == .crop)
    }
}
