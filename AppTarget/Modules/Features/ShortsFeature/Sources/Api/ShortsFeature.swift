import Foundation
import Shorts
import Subtitles
import VideoRendering

public enum ShortsFeature {}

/// Minimal speaker info the shorts workspace needs for the on-frame speaker
/// chip, kept local to the feature so it does not depend on SpeakerAnalysis.
public struct ShortsSpeakerBadge: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let colorHex: String

    public init(id: String, name: String, colorHex: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}

public struct ShortsWorkspaceState: Equatable {
    public let subtitles: [SubtitleSegment]
    public let shorts: [ShortDefinition]
    public let exportSettings: ShortsExportSettings
    public let currentTimeMs: Int
    public let selectedShortID: UUID?
    public let suggestions: [ShortSuggestion]
    public let suggestionMessage: String?
    public let videoSourceInfo: VideoSourceInfo?
    public let speakers: [ShortsSpeakerBadge]

    public init(
        subtitles: [SubtitleSegment],
        shorts: [ShortDefinition],
        exportSettings: ShortsExportSettings,
        currentTimeMs: Int,
        selectedShortID: UUID?,
        suggestions: [ShortSuggestion],
        suggestionMessage: String?,
        videoSourceInfo: VideoSourceInfo?,
        speakers: [ShortsSpeakerBadge] = []
    ) {
        self.subtitles = subtitles
        self.shorts = shorts
        self.exportSettings = exportSettings
        self.currentTimeMs = currentTimeMs
        self.selectedShortID = selectedShortID
        self.suggestions = suggestions
        self.suggestionMessage = suggestionMessage
        self.videoSourceInfo = videoSourceInfo
        self.speakers = speakers
    }

    public var selectedShort: ShortDefinition? {
        guard let selectedShortID else { return nil }
        return shorts.first(where: { $0.id == selectedShortID })
    }
}

@MainActor
public struct ShortsWorkspaceActions {
    private let selectShortAction: (UUID?) -> Void
    private let addShortAtPlayheadAction: () -> Void
    private let deleteShortAction: (UUID) -> Void
    private let duplicateShortAction: (UUID) -> Void
    private let updateShortAction: (UUID, String?, (inout ShortDefinition) -> Void) -> Void
    private let beginInteractiveShortEditAction: () -> Void
    private let endInteractiveShortEditAction: (String) -> Void
    private let addCropPointAtPlayheadAction: (UUID) -> Void
    private let updateShortCropOffsetAction: (UUID, Int, Double) -> Void
    private let deleteShortCropKeyframeAction: (UUID, UUID) -> Void
    private let updateExportSettingsAction: (ShortsExportSettings) -> Void
    private let updateSubtitleStyleAction: (VideoExportSettings, Bool) -> Void
    private let beginInteractiveSubtitleStyleEditAction: () -> Void
    private let endInteractiveSubtitleStyleEditAction: (String) -> Void
    private let generateSuggestionsAction: () -> Void
    private let acceptSuggestionAction: (ShortSuggestion) -> Void
    private let dismissSuggestionAction: (ShortSuggestion) -> Void
    private let exportShortsAction: ([ShortDefinition], URL) -> Void

    public init(
        selectShort: @escaping (UUID?) -> Void,
        addShortAtPlayhead: @escaping () -> Void,
        deleteShort: @escaping (UUID) -> Void,
        duplicateShort: @escaping (UUID) -> Void = { _ in },
        updateShort: @escaping (UUID, String?, (inout ShortDefinition) -> Void) -> Void,
        beginInteractiveShortEdit: @escaping () -> Void,
        endInteractiveShortEdit: @escaping (String) -> Void,
        addCropPointAtPlayhead: @escaping (UUID) -> Void,
        updateShortCropOffset: @escaping (UUID, Int, Double) -> Void,
        deleteShortCropKeyframe: @escaping (UUID, UUID) -> Void,
        updateExportSettings: @escaping (ShortsExportSettings) -> Void,
        updateSubtitleStyle: @escaping (VideoExportSettings, Bool) -> Void,
        beginInteractiveSubtitleStyleEdit: @escaping () -> Void,
        endInteractiveSubtitleStyleEdit: @escaping (String) -> Void,
        generateSuggestions: @escaping () -> Void,
        acceptSuggestion: @escaping (ShortSuggestion) -> Void,
        dismissSuggestion: @escaping (ShortSuggestion) -> Void,
        exportShorts: @escaping ([ShortDefinition], URL) -> Void
    ) {
        self.selectShortAction = selectShort
        self.addShortAtPlayheadAction = addShortAtPlayhead
        self.deleteShortAction = deleteShort
        self.duplicateShortAction = duplicateShort
        self.updateShortAction = updateShort
        self.beginInteractiveShortEditAction = beginInteractiveShortEdit
        self.endInteractiveShortEditAction = endInteractiveShortEdit
        self.addCropPointAtPlayheadAction = addCropPointAtPlayhead
        self.updateShortCropOffsetAction = updateShortCropOffset
        self.deleteShortCropKeyframeAction = deleteShortCropKeyframe
        self.updateExportSettingsAction = updateExportSettings
        self.updateSubtitleStyleAction = updateSubtitleStyle
        self.beginInteractiveSubtitleStyleEditAction = beginInteractiveSubtitleStyleEdit
        self.endInteractiveSubtitleStyleEditAction = endInteractiveSubtitleStyleEdit
        self.generateSuggestionsAction = generateSuggestions
        self.acceptSuggestionAction = acceptSuggestion
        self.dismissSuggestionAction = dismissSuggestion
        self.exportShortsAction = exportShorts
    }

    public func selectShort(id: UUID?) { selectShortAction(id) }
    public func addShortAtPlayhead() { addShortAtPlayheadAction() }
    public func deleteShort(id: UUID) { deleteShortAction(id) }
    public func duplicateShort(id: UUID) { duplicateShortAction(id) }

    public func updateShort(
        id: UUID,
        undoActionName: String? = nil,
        mutate: (inout ShortDefinition) -> Void
    ) {
        updateShortAction(id, undoActionName, mutate)
    }

    public func beginInteractiveShortEdit() { beginInteractiveShortEditAction() }
    public func endInteractiveShortEdit(undoActionName: String) {
        endInteractiveShortEditAction(undoActionName)
    }
    public func addCropPointAtPlayhead(shortID: UUID) { addCropPointAtPlayheadAction(shortID) }
    public func updateShortCropOffset(id: UUID, timelineTimeMs: Int, offsetX: Double) {
        updateShortCropOffsetAction(id, timelineTimeMs, offsetX)
    }
    public func deleteShortCropKeyframe(shortID: UUID, keyframeID: UUID) {
        deleteShortCropKeyframeAction(shortID, keyframeID)
    }
    public func updateExportSettings(_ settings: ShortsExportSettings) {
        updateExportSettingsAction(settings)
    }
    public func updateSubtitleStyle(_ style: VideoExportSettings, registerUndo: Bool = true) {
        updateSubtitleStyleAction(style, registerUndo)
    }
    public func beginInteractiveSubtitleStyleEdit() {
        beginInteractiveSubtitleStyleEditAction()
    }
    public func endInteractiveSubtitleStyleEdit(
        undoActionName: String = "Edit Shorts Subtitle Style"
    ) {
        endInteractiveSubtitleStyleEditAction(undoActionName)
    }
    public func generateSuggestions() { generateSuggestionsAction() }
    public func acceptSuggestion(_ suggestion: ShortSuggestion) { acceptSuggestionAction(suggestion) }
    public func dismissSuggestion(_ suggestion: ShortSuggestion) { dismissSuggestionAction(suggestion) }
    public func exportShorts(_ shorts: [ShortDefinition], to directory: URL) {
        exportShortsAction(shorts, directory)
    }
}
