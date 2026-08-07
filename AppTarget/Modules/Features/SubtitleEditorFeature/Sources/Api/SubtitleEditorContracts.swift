import Foundation
import SpeakerAnalysis
import Subtitles

public struct SubtitleEditorState: Equatable {
    public let subtitles: [SubtitleSegment]
    public let speakers: [Speaker]
    public let speakerLabels: [SpeakerLabel]
    public let selectedSegmentID: UUID?
    public let selectedCueIDs: Set<UUID>
    public let activeSegmentID: UUID?
    public let autosaveErrorMessage: String?

    public init(
        subtitles: [SubtitleSegment],
        speakers: [Speaker],
        speakerLabels: [SpeakerLabel],
        selectedSegmentID: UUID?,
        selectedCueIDs: Set<UUID>,
        activeSegmentID: UUID?,
        autosaveErrorMessage: String?
    ) {
        self.subtitles = subtitles
        self.speakers = speakers
        self.speakerLabels = speakerLabels
        self.selectedSegmentID = selectedSegmentID
        self.selectedCueIDs = selectedCueIDs
        self.activeSegmentID = activeSegmentID
        self.autosaveErrorMessage = autosaveErrorMessage
    }

    public func speaker(for segment: SubtitleSegment) -> Speaker? {
        guard let speakerID = segment.speaker else { return nil }
        return speakers.first(where: { $0.id == speakerID })
    }
}

public struct SubtitleEditorUpdateResult: Equatable {
    public let segment: SubtitleSegment?
    public let errorMessage: String?

    public init(segment: SubtitleSegment?, errorMessage: String?) {
        self.segment = segment
        self.errorMessage = errorMessage
    }
}

@MainActor
public struct SubtitleEditorActions {
    private let selectSegmentAction: (UUID?, Bool, Bool) -> Void
    private let updateSubtitleAction: (SubtitleSegment) -> SubtitleEditorUpdateResult
    private let addSegmentAfterAction: (UUID) -> UUID?
    private let splitSegmentAction: (UUID) -> UUID?
    private let mergeWithNextSegmentAction: (UUID) -> UUID?
    private let deleteSegmentAction: (UUID) -> UUID?
    private let createShortFromSelectedCuesAction: () -> Void
    private let beginTextEditAction: (UUID) -> Void
    private let endTextEditAction: () -> Void
    private let currentErrorMessageAction: () -> String?

    public init(
        selectSegment: @escaping (UUID?, Bool, Bool) -> Void,
        updateSubtitle: @escaping (SubtitleSegment) -> SubtitleEditorUpdateResult,
        addSegmentAfter: @escaping (UUID) -> UUID?,
        splitSegment: @escaping (UUID) -> UUID?,
        mergeWithNextSegment: @escaping (UUID) -> UUID?,
        deleteSegment: @escaping (UUID) -> UUID?,
        createShortFromSelectedCues: @escaping () -> Void,
        beginTextEdit: @escaping (UUID) -> Void,
        endTextEdit: @escaping () -> Void,
        currentErrorMessage: @escaping () -> String?
    ) {
        self.selectSegmentAction = selectSegment
        self.updateSubtitleAction = updateSubtitle
        self.addSegmentAfterAction = addSegmentAfter
        self.splitSegmentAction = splitSegment
        self.mergeWithNextSegmentAction = mergeWithNextSegment
        self.deleteSegmentAction = deleteSegment
        self.createShortFromSelectedCuesAction = createShortFromSelectedCues
        self.beginTextEditAction = beginTextEdit
        self.endTextEditAction = endTextEdit
        self.currentErrorMessageAction = currentErrorMessage
    }

    public func selectSegment(
        id: UUID?,
        extendingSelection: Bool = false,
        togglingSelection: Bool = false
    ) {
        selectSegmentAction(id, extendingSelection, togglingSelection)
    }

    @discardableResult
    public func updateSubtitle(_ segment: SubtitleSegment) -> SubtitleEditorUpdateResult {
        updateSubtitleAction(segment)
    }

    public func addSegmentAfter(id: UUID) -> UUID? {
        addSegmentAfterAction(id)
    }

    public func splitSegment(id: UUID) -> UUID? {
        splitSegmentAction(id)
    }

    public func mergeWithNextSegment(id: UUID) -> UUID? {
        mergeWithNextSegmentAction(id)
    }

    public func deleteSegment(id: UUID) -> UUID? {
        deleteSegmentAction(id)
    }

    public func createShortFromSelectedCues() {
        createShortFromSelectedCuesAction()
    }

    public func beginTextEdit(id: UUID) {
        beginTextEditAction(id)
    }

    public func endTextEdit() {
        endTextEditAction()
    }

    public var currentErrorMessage: String? {
        currentErrorMessageAction()
    }
}
