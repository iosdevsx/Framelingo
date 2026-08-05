import Foundation
import Project
import Timeline
import VideoRendering
import XCTest

final class ExportClipPlanResolverTests: XCTestCase {
    func testResolverReturnsNilWithoutEditTimeline() throws {
        XCTAssertNil(try ExportClipPlanResolver.clips(for: makeProject(editTimeline: nil)))
    }

    func testResolverReturnsNilForFullLengthSingleClip() throws {
        let timeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 0,
                    sourceEndMs: 10_000,
                    timelineStartMs: 0,
                    timelineEndMs: 10_000
                )
            ],
            totalDurationMs: 10_000
        )

        XCTAssertNil(try ExportClipPlanResolver.clips(for: makeProject(editTimeline: timeline)))
    }

    func testResolverDetectsTailTrimAgainstSourceDuration() throws {
        let timeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 0,
                    sourceEndMs: 10_000,
                    timelineStartMs: 0,
                    timelineEndMs: 10_000
                )
            ],
            totalDurationMs: 10_000
        )

        let clips = try XCTUnwrap(
            ExportClipPlanResolver.clips(
                for: makeProject(editTimeline: timeline, mediaDurationMs: 60_000)
            )
        )

        XCTAssertEqual(clips, [ExportClipRange(sourceStartMs: 0, sourceEndMs: 10_000)])
    }

    func testResolverReturnsClipsSortedByTimelineStart() throws {
        let timeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 5_000,
                    sourceEndMs: 10_000,
                    timelineStartMs: 3_000,
                    timelineEndMs: 8_000
                ),
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 0,
                    sourceEndMs: 3_000,
                    timelineStartMs: 0,
                    timelineEndMs: 3_000
                )
            ],
            totalDurationMs: 8_000
        )

        let clips = try XCTUnwrap(
            ExportClipPlanResolver.clips(for: makeProject(editTimeline: timeline))
        )

        XCTAssertEqual(clips, [
            ExportClipRange(sourceStartMs: 0, sourceEndMs: 3_000),
            ExportClipRange(sourceStartMs: 5_000, sourceEndMs: 10_000)
        ])
    }

    func testResolverFiltersDegenerateClips() throws {
        let timeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 4_000,
                    sourceEndMs: 4_000,
                    timelineStartMs: 0,
                    timelineEndMs: 0
                ),
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 6_000,
                    sourceEndMs: 9_000,
                    timelineStartMs: 0,
                    timelineEndMs: 3_000
                )
            ],
            totalDurationMs: 3_000
        )

        let clips = try XCTUnwrap(
            ExportClipPlanResolver.clips(for: makeProject(editTimeline: timeline))
        )

        XCTAssertEqual(clips, [ExportClipRange(sourceStartMs: 6_000, sourceEndMs: 9_000)])
    }

    func testResolverThrowsWhenPlanIsEmpty() {
        let timeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 4_000,
                    sourceEndMs: 4_000,
                    timelineStartMs: 0,
                    timelineEndMs: 0
                )
            ],
            totalDurationMs: 0
        )

        XCTAssertThrowsError(
            try ExportClipPlanResolver.clips(for: makeProject(editTimeline: timeline))
        ) { error in
            XCTAssertEqual(error as? ExportClipPlanError, .emptyPlan)
        }
    }

    private func makeProject(
        editTimeline: EditTimeline?,
        mediaDurationMs: Int = 10_000
    ) -> Project {
        Project(
            id: UUID(),
            name: "Test",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            mediaFile: MediaFile(
                id: UUID(),
                originalURL: URL(fileURLWithPath: "/tmp/video.mp4"),
                fileName: "video.mp4",
                fileExtension: "mp4",
                sizeBytes: 1,
                durationMs: mediaDurationMs
            ),
            sourceLanguage: "en",
            targetLanguage: "ru",
            subtitles: [],
            status: .ready,
            editTimeline: editTimeline
        )
    }
}
