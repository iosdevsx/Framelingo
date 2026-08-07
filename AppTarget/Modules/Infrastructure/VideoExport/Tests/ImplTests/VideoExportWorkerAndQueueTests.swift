import Combine
import Foundation
import Media
import Project
import Shorts
import SpeakerAnalysis
import Subtitles
import Timeline
import VideoExport
import VideoRendering
import XCTest

@testable import VideoExportImpl

final class VideoExportWorkerTests: XCTestCase {
    func testFullProjectValidatesSubtitlesMediaAndEditedTimeline() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let worker = fixture.worker

        var noSubtitles = fixture.project
        noSubtitles.subtitles = []
        let subtitleResult = await worker.run(
            request: .fullProject(fixture.request(project: noSubtitles)),
            ffmpegService: fixture.ffmpeg,
            events: { _ in }
        )
        XCTAssertEqual(subtitleResult.failure?.code, .missingSubtitles)

        var missingMedia = fixture.project
        missingMedia.mediaFile.originalURL = fixture.directory.appendingPathComponent("missing.mov")
        let mediaResult = await worker.run(
            request: .fullProject(fixture.request(project: missingMedia)),
            ffmpegService: fixture.ffmpeg,
            events: { _ in }
        )
        XCTAssertEqual(mediaResult.failure?.code, .missingMedia)

        var edited = fixture.project
        edited.editTimeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 5_000,
                    sourceEndMs: 7_000,
                    timelineStartMs: 0,
                    timelineEndMs: 2_000
                ),
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 10_000,
                    sourceEndMs: 12_000,
                    timelineStartMs: 2_000,
                    timelineEndMs: 4_000
                )
            ],
            totalDurationMs: 4_000
        )
        let result = await worker.run(
            request: .fullProject(fixture.request(project: edited)),
            ffmpegService: fixture.ffmpeg,
            events: { _ in }
        )

        XCTAssertTrue(result.isSuccess)
        let burns = await fixture.ffmpeg.burns
        XCTAssertEqual(burns.last?.clips, [
            ExportClipRange(sourceStartMs: 5_000, sourceEndMs: 7_000),
            ExportClipRange(sourceStartMs: 10_000, sourceEndMs: 12_000)
        ])
        XCTAssertEqual(fixture.scripts.fullSegments, edited.subtitles)
    }

    func testShortUsesNormalizedPlanAllowsEmptyCuesWritesLocalizedSidecarAndCleansTemp() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let projectRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("Framelingo")
            .appendingPathComponent(fixture.project.id.uuidString)
        let plan = ShortExportPlan(
            clips: [ExportClipRange(sourceStartMs: 2_000, sourceEndMs: 5_000)],
            subtitles: [fixture.project.subtitles[0]],
            subtitleStyle: VideoExportSettings(),
            platform: .tiktok,
            reframe: VerticalReframePlan(
                mode: .crop,
                cropOffsetX: 0.2,
                cropKeyframes: [],
                sourceWidth: 1_920,
                sourceHeight: 1_080
            ),
            hookText: "Hook",
            hookFontSize: 70,
            durationMs: 3_000,
            burnSubtitlesIntoVideo: false,
            writeSRTSidecar: true
        )
        let request = ShortVideoExportRequest(
            projectID: fixture.project.id,
            projectName: "Project — Short",
            mediaURL: fixture.mediaURL,
            settings: VideoExportSettings(),
            sourceInfo: nil,
            outputURL: fixture.outputURL,
            plan: plan,
            speakerLabels: fixture.project.speakerLabels,
            speakerExportOptions: fixture.project.speakerExportOptions
        )
        let eventRecorder = WorkerEventRecorder()

        let result = await fixture.worker.run(
            request: .short(request),
            ffmpegService: fixture.ffmpeg,
            events: { event in
                await eventRecorder.record(event)
            }
        )

        XCTAssertTrue(result.isSuccess)
        let statuses = await eventRecorder.statuses
        XCTAssertEqual(statuses, [.preparing, .exporting, .writingSidecar])
        XCTAssertEqual(fixture.scripts.verticalRequest?.segments, [])
        XCTAssertEqual(fixture.scripts.verticalRequest?.hookText, "Hook")
        let export = await fixture.exporter.exports.last
        XCTAssertEqual(export?.request.segments, plan.subtitles)
        XCTAssertEqual(export?.destinationURL, fixture.outputURL.deletingPathExtension().appendingPathExtension("srt"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.outputURL.path))
        let children: [String]
        do {
            children = try FileManager.default.contentsOfDirectory(atPath: projectRoot.path)
        } catch CocoaError.fileReadNoSuchFile {
            children = []
        }
        XCTAssertFalse(children.contains { $0.hasPrefix("VideoExport-") })
    }

    func testFailureMappingPreservesActionableCapabilityMessagesAndStderr() {
        let ass = VideoExportWorker.failure(for: FFmpegServiceError.processFailed(
            exitCode: 1,
            standardOutput: "",
            standardError: "No such filter: 'ass'"
        ))
        XCTAssertEqual(ass.code, .missingASSFilter)
        XCTAssertEqual(ass.debugOutput, "No such filter: 'ass'")

        let encoder = VideoExportWorker.failure(for: FFmpegServiceError.processFailed(
            exitCode: 1,
            standardOutput: "",
            standardError: "Unknown encoder 'libx264'"
        ))
        XCTAssertEqual(encoder.code, .missingH264Encoder)

        let unavailable = VideoExportWorker.failure(for: FFmpegServiceError.notFound)
        XCTAssertEqual(unavailable.code, .ffmpegUnavailable)
    }

    func testEmptyTimelineAndASSFailureAreTypedAndTemporaryFilesAreRemoved() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        var emptyTimeline = fixture.project
        emptyTimeline.editTimeline = EditTimeline(clips: [], totalDurationMs: 0)
        let timelineResult = await fixture.worker.run(
            request: .fullProject(fixture.request(project: emptyTimeline)),
            ffmpegService: fixture.ffmpeg,
            events: { _ in }
        )
        XCTAssertEqual(timelineResult.failure?.code, .emptyTimeline)

        fixture.scripts.shouldFail = true
        let assResult = await fixture.worker.run(
            request: .fullProject(fixture.request()),
            ffmpegService: fixture.ffmpeg,
            events: { _ in }
        )
        XCTAssertEqual(assResult.failure?.code, .assGeneration)
        let projectRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("Framelingo")
            .appendingPathComponent(fixture.project.id.uuidString)
        let children: [String]
        do {
            children = try FileManager.default.contentsOfDirectory(atPath: projectRoot.path)
        } catch CocoaError.fileReadNoSuchFile {
            children = []
        }
        XCTAssertFalse(children.contains { $0.hasPrefix("VideoExport-") })
    }
}

@MainActor
final class VideoExportQueueTests: XCTestCase {
    func testQueueIsFIFOSequentialThrottlesProgressContinuesAfterFailureAndObserves() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        await fixture.ffmpeg.configureFailure(
            outputName: "second.mp4",
            error: .processFailed(exitCode: 1, standardOutput: "", standardError: "boom")
        )
        let queue = VideoExportQueueImpl(
            worker: fixture.worker,
            makeFFmpegService: { fixture.ffmpeg }
        )
        var observed: [[VideoExport.VideoExportJob]] = []
        let subscription = queue.jobSnapshots.sink { observed.append($0) }
        let first = fixture.request(outputName: "first.mp4")
        let second = fixture.request(outputName: "second.mp4")
        let third = fixture.request(outputName: "third.mp4")

        queue.enqueue(.fullProject(first))
        queue.enqueue(.fullProject(second))
        queue.enqueue(.fullProject(third))
        queue.removeFinishedJob(id: second.id)

        try await waitUntil { queue.jobs.first(where: { $0.id == first.id })?.progress == 0.01 }
        XCTAssertEqual(queue.jobs.first(where: { $0.id == first.id })?.progress, 0.01)
        try await waitUntil { queue.jobs.allSatisfy(\.isFinished) }

        let starts = await fixture.ffmpeg.starts
        let maxConcurrent = await fixture.ffmpeg.maxConcurrentBurns
        XCTAssertEqual(starts, ["first.mp4", "second.mp4", "third.mp4"])
        XCTAssertEqual(maxConcurrent, 1)
        XCTAssertEqual(queue.jobs.first(where: { $0.id == first.id })?.status, .succeeded)
        XCTAssertEqual(queue.jobs.first(where: { $0.id == second.id })?.status, .failed)
        XCTAssertEqual(queue.jobs.first(where: { $0.id == third.id })?.status, .succeeded)
        XCTAssertEqual(queue.jobs.first(where: { $0.id == second.id })?.debugOutput, "boom")
        XCTAssertGreaterThan(observed.count, 3)

        queue.removeFinishedJob(id: second.id)
        XCTAssertNil(queue.jobs.first(where: { $0.id == second.id }))
        withExtendedLifetime(subscription) {}
    }

    func testInvalidShortIsImmediateFailureWhileValidSiblingRuns() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let queue = VideoExportQueueImpl(
            worker: fixture.worker,
            makeFFmpegService: { fixture.ffmpeg }
        )
        let validPlan = ShortExportPlan(
            clips: [ExportClipRange(sourceStartMs: 0, sourceEndMs: 1_000)],
            subtitles: [],
            subtitleStyle: VideoExportSettings(),
            platform: .youtubeShorts,
            reframe: VerticalReframePlan(mode: .blurPad, cropOffsetX: 0.5),
            hookText: "",
            hookFontSize: 70,
            durationMs: 1_000,
            burnSubtitlesIntoVideo: true,
            writeSRTSidecar: false
        )
        let valid = ShortExportBatchItem(
            shortID: UUID(),
            displayName: "Valid",
            outputURL: fixture.directory.appendingPathComponent("valid.mp4"),
            encodingSettings: VideoExportSettings(),
            sourceInfo: nil,
            outcome: .valid(validPlan)
        )
        let invalid = ShortExportBatchItem(
            shortID: UUID(),
            displayName: "Invalid",
            outputURL: fixture.directory.appendingPathComponent("invalid.mp4"),
            encodingSettings: VideoExportSettings(),
            sourceInfo: nil,
            outcome: .invalid(.emptyClipPlan)
        )

        queue.enqueue(ShortsVideoExportBatchRequest(
            projectID: fixture.project.id,
            mediaURL: fixture.mediaURL,
            speakerLabels: [],
            speakerExportOptions: SubtitleExportOptions(),
            items: [valid, invalid]
        ))
        XCTAssertEqual(queue.jobs.first(where: { $0.id == invalid.id })?.status, .failed)
        try await waitUntil { queue.jobs.first(where: { $0.id == valid.id })?.isFinished == true }
        XCTAssertEqual(queue.jobs.first(where: { $0.id == valid.id })?.status, .succeeded)
    }

    func testQueueTeardownCancelsOwnedTaskWithoutBeingRetainedByRequestingView() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        var queue: VideoExportQueueImpl? = VideoExportQueueImpl(
            worker: fixture.worker,
            makeFFmpegService: { fixture.ffmpeg }
        )
        weak let weakQueue = queue

        func submitFromTemporaryViewScope() {
            queue?.enqueue(.fullProject(fixture.request(outputName: "view-owned.mp4")))
        }
        submitFromTemporaryViewScope()
        try await waitUntil { !queue!.jobs.isEmpty }
        queue = nil

        XCTAssertNil(weakQueue)
    }

    func testMissingRequestPayloadFailsDefensivelyAndQueueContinues() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let queue = VideoExportQueueImpl(
            worker: fixture.worker,
            makeFFmpegService: { fixture.ffmpeg }
        )
        let lostID = UUID()
        queue.accept(
            VideoExport.VideoExportJob(
                id: lostID,
                projectName: "Lost request",
                outputURL: fixture.directory.appendingPathComponent("lost.mp4"),
                status: .queued,
                statusText: "Queued",
                progress: nil
            ),
            request: nil
        )

        XCTAssertEqual(queue.jobs.first(where: { $0.id == lostID })?.status, .failed)
        XCTAssertEqual(queue.jobs.first(where: { $0.id == lostID })?.failure?.code, .lostRequest)

        let valid = fixture.request(outputName: "after-lost.mp4")
        queue.enqueue(.fullProject(valid))
        try await waitUntil { queue.jobs.first(where: { $0.id == valid.id })?.isFinished == true }
        XCTAssertEqual(queue.jobs.first(where: { $0.id == valid.id })?.status, .succeeded)
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            if clock.now >= deadline { throw QueueTestError.timeout }
            try await Task.sleep(for: .milliseconds(5))
        }
    }
}

private enum QueueTestError: Error { case timeout }

private actor WorkerEventRecorder {
    private(set) var statuses: [VideoExport.VideoExportJobStatus] = []

    func record(_ event: VideoExportWorkerEvent) {
        if case .status(let status, _) = event {
            statuses.append(status)
        }
    }
}

private final class Fixture {
    let directory: URL
    let mediaURL: URL
    let outputURL: URL
    let project: Project
    let ffmpeg = RecordingFFmpegService()
    let scripts = RecordingScriptGenerator()
    let exporter = RecordingSubtitleExportService()
    let worker: VideoExportWorker

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VideoExportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        mediaURL = directory.appendingPathComponent("source.mov")
        outputURL = directory.appendingPathComponent("output.mp4")
        try Data("video".utf8).write(to: mediaURL)
        let cue = SubtitleSegment(
            id: UUID(),
            index: 1,
            startMs: 0,
            endMs: 10_000,
            originalText: "Hello",
            translatedText: "Привет"
        )
        project = Project(
            id: UUID(),
            name: "Project",
            createdAt: Date(),
            updatedAt: Date(),
            mediaFile: MediaFile(
                id: UUID(),
                originalURL: mediaURL,
                fileName: "source.mov",
                fileExtension: "mov",
                sizeBytes: 5,
                durationMs: 10_000
            ),
            sourceLanguage: "en",
            targetLanguage: "ru",
            subtitles: [cue],
            status: .ready
        )
        worker = VideoExportWorker(
            subtitleScriptGenerator: scripts,
            subtitleExportService: exporter,
            fileManager: .default
        )
    }

    func request(project: Project? = nil, outputName: String = "output.mp4") -> FullProjectVideoExportRequest {
        FullProjectVideoExportRequest(
            project: project ?? self.project,
            settings: VideoExportSettings(),
            sourceInfo: nil,
            outputURL: directory.appendingPathComponent(outputName)
        )
    }

    func cleanup() {
        do {
            if FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
        } catch {
            XCTFail("Fixture cleanup failed: \(error)")
        }
    }
}

private final class RecordingScriptGenerator: SubtitleScriptGenerating {
    var fullSegments: [SubtitleSegment] = []
    var verticalRequest: VerticalSubtitleScriptRequest?
    var shouldFail = false

    func generateASS(segments: [SubtitleSegment], settings: VideoExportSettings) throws -> String {
        if shouldFail { throw QueueTestError.timeout }
        fullSegments = segments
        return "[Script Info]"
    }

    func generateVerticalASS(_ request: VerticalSubtitleScriptRequest) -> String {
        verticalRequest = request
        return "[Script Info]"
    }
}

private actor RecordingSubtitleExportService: SubtitleExportService {
    struct Export {
        let request: SubtitleExportRequest
        let destinationURL: URL
    }
    private(set) var exports: [Export] = []

    func export(request: SubtitleExportRequest, kind: SubtitleExportKind, destinationURL: URL) async throws {}

    func exportSRT(
        request: SubtitleExportRequest,
        textMode: SubtitleTextMode,
        destinationURL: URL
    ) async throws {
        exports.append(Export(request: request, destinationURL: destinationURL))
        try Data("sidecar".utf8).write(to: destinationURL)
    }
}

private actor RecordingFFmpegService: FFmpegService {
    struct Burn {
        let outputName: String
        let clips: [ExportClipRange]?
        let reframe: VerticalReframePlan?
    }

    private(set) var burns: [Burn] = []
    private(set) var starts: [String] = []
    private(set) var maxConcurrentBurns = 0
    private var activeBurns = 0
    private var failures: [String: FFmpegServiceError] = [:]

    func configureFailure(outputName: String, error: FFmpegServiceError) {
        failures[outputName] = error
    }

    func checkAvailability() async throws -> FFmpegInfo {
        FFmpegInfo(executableURL: URL(fileURLWithPath: "/usr/bin/true"), version: "test")
    }

    func extractAudio(from videoURL: URL, to outputURL: URL, clips: [ExportClipRange]?) async throws -> URL {
        outputURL
    }

    func burnSubtitles(
        videoURL: URL,
        subtitlesURL: URL,
        outputURL: URL,
        settings: VideoExportSettings,
        sourceInfo: VideoSourceInfo?,
        clips: [ExportClipRange]?,
        verticalReframe: VerticalReframePlan?,
        progressHandler: FFmpegProgressHandler?
    ) async throws -> URL {
        let outputName = outputURL.lastPathComponent
        starts.append(outputName)
        activeBurns += 1
        maxConcurrentBurns = max(maxConcurrentBurns, activeBurns)
        burns.append(Burn(outputName: outputName, clips: clips, reframe: verticalReframe))
        if let progressHandler {
            await progressHandler(100)
            await progressHandler(101)
            await progressHandler(50)
        }
        try await Task.sleep(for: .milliseconds(35))
        activeBurns -= 1
        if let failure = failures[outputName] { throw failure }
        try Data("rendered".utf8).write(to: outputURL)
        return outputURL
    }
}

private extension Result where Success == Void, Failure == VideoExportFailure {
    var failure: VideoExportFailure? {
        guard case .failure(let failure) = self else { return nil }
        return failure
    }

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
