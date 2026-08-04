import AVFoundation
import CoreGraphics
import Foundation
import Testing
@testable import Framelingo

/// End-to-end export verification through the real FFmpeg service (embedded
/// FFmpegKit in the app host): clip trimming, resolution/FPS targets, and
/// burned-in subtitle position parity with the preview's normalized anchor.
@Suite(.serialized)
struct VideoExportIntegrationTests {
    @Test
    func testClipExportHonorsClipsResolutionAndFrameRate() async throws {
        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let sourceURL = try makeSolidColorVideo(
            at: workspace.appendingPathComponent("source.mp4"),
            width: 1_920,
            height: 1_080,
            framesPerSecond: 60,
            durationSeconds: 4
        )
        let subtitlesURL = workspace.appendingPathComponent("subtitles.ass")
        var settings = VideoExportSettings()
        settings.resolution = .p720
        settings.frameRate = .fps30
        let ass = try ASSSubtitleExportService().generateASS(
            segments: [makeSegment(startMs: 0, endMs: 2_000, text: "SYNC CHECK")],
            settings: settings
        )
        try Data(ass.utf8).write(to: subtitlesURL, options: .atomic)

        let outputURL = workspace.appendingPathComponent("clipped.mp4")
        // The generated source has no audio stream, so the clip path must also
        // exercise the video-only retry after `[0:a]atrim` matches no streams.
        _ = try await makeFFmpegService().burnSubtitles(
            videoURL: sourceURL,
            subtitlesURL: subtitlesURL,
            outputURL: outputURL,
            settings: settings,
            sourceInfo: VideoSourceInfo(width: 1_920, height: 1_080, nominalFrameRate: 60),
            clips: [
                ExportClipRange(sourceStartMs: 500, sourceEndMs: 1_500),
                ExportClipRange(sourceStartMs: 2_500, sourceEndMs: 3_500)
            ],
            progressHandler: nil
        )

        let asset = AVURLAsset(url: outputURL)
        let durationSeconds = try await asset.load(.duration).seconds
        #expect(abs(durationSeconds - 2.0) < 0.15)

        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let naturalSize = try await track.load(.naturalSize)
        #expect(Int(naturalSize.width) == 1_280)
        #expect(Int(naturalSize.height) == 720)

        let frameRate = try await track.load(.nominalFrameRate)
        #expect(abs(frameRate - 30) < 0.5)
    }

    @Test
    func testBurnedSubtitleCenterMatchesNormalizedAnchorAcrossResolutions() async throws {
        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let sourceURL = try makeSolidColorVideo(
            at: workspace.appendingPathComponent("source.mp4"),
            width: 1_920,
            height: 1_080,
            framesPerSecond: 30,
            durationSeconds: 3
        )

        // Off-center anchor, an opaque white block on black video: the bright
        // pixel centroid of a frame is the block center.
        let anchor = CGPoint(x: 0.3, y: 0.7)
        var settings = makeWhiteBlockSettings(anchor: anchor)

        for resolution in [VideoExportResolution.original, .p720] {
            settings.resolution = resolution
            let centroid = try await burnAndMeasureCentroid(
                sourceURL: sourceURL,
                settings: settings,
                sourceInfo: VideoSourceInfo(width: 1_920, height: 1_080, nominalFrameRate: 30),
                workspace: workspace,
                outputName: "parity-\(resolution.rawValue).mp4"
            )

            #expect(abs(centroid.x - anchor.x) < 0.02, "x centroid at \(resolution.rawValue)")
            #expect(abs(centroid.y - anchor.y) < 0.02, "y centroid at \(resolution.rawValue)")
        }
    }

    @Test
    func testBurnedSubtitlePositionParityForNonWidescreenSource() async throws {
        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let sourceURL = try makeSolidColorVideo(
            at: workspace.appendingPathComponent("source43.mp4"),
            width: 1_440,
            height: 1_080,
            framesPerSecond: 30,
            durationSeconds: 3
        )

        let anchor = CGPoint(x: 0.5, y: 0.86)
        let settings = makeWhiteBlockSettings(anchor: anchor)
        let centroid = try await burnAndMeasureCentroid(
            sourceURL: sourceURL,
            settings: settings,
            sourceInfo: VideoSourceInfo(width: 1_440, height: 1_080, nominalFrameRate: 30),
            workspace: workspace,
            outputName: "parity-4x3.mp4"
        )

        #expect(abs(centroid.x - anchor.x) < 0.02)
        #expect(abs(centroid.y - anchor.y) < 0.02)
    }

    @Test
    func testSystemFFmpegBurnsDedicatedShortsStyleWhenAvailable() async throws {
        let executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        guard FileManager.default.isExecutableFile(atPath: executableURL.path),
              try systemFFmpegSupportsASS(at: executableURL) else {
            return
        }

        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let sourceURL = try makeSolidColorVideo(
            at: workspace.appendingPathComponent("system-shorts-source.mp4"),
            width: 960,
            height: 540,
            framesPerSecond: 30,
            durationSeconds: 2
        )
        let cue = makeSegment(
            startMs: 0,
            endMs: 2_000,
            text: "REGULAR ORIGINAL",
            translatedText: "SHORTS SYSTEM STYLE"
        )
        var shortsStyle = makeWhiteBlockSettings(anchor: CGPoint(x: 0.3, y: 0.58))
        shortsStyle.subtitleTextMode = .translated
        shortsStyle.fontSize = 86
        let layout = try #require(
            BurnedSubtitleLayoutHelper.makeVerticalCaptionLayout(
                for: cue,
                settings: shortsStyle,
                platform: .youtubeShorts
            )
        )
        let ass = ASSSubtitleExportService().generateVerticalShortsASS(
            segments: [cue],
            style: shortsStyle,
            platform: .youtubeShorts,
            hookText: "",
            hookFontSize: 72,
            shortDurationMs: 2_000
        )
        #expect(ass.contains(layout.wrappedText.replacingOccurrences(of: "\n", with: "\\N")))
        #expect(!ass.contains("REGULAR ORIGINAL"))

        let subtitlesURL = workspace.appendingPathComponent("system-shorts.ass")
        try Data(ass.utf8).write(to: subtitlesURL, options: .atomic)
        let outputURL = workspace.appendingPathComponent("system-shorts.mp4")
        var encodingSettings = VideoExportSettings()
        encodingSettings.quality = .smallFile
        encodingSettings.preset = .fast
        _ = try await ProcessFFmpegService(preferredExecutableURL: executableURL).burnSubtitles(
            videoURL: sourceURL,
            subtitlesURL: subtitlesURL,
            outputURL: outputURL,
            settings: encodingSettings,
            sourceInfo: VideoSourceInfo(width: 960, height: 540, nominalFrameRate: 30),
            clips: nil,
            verticalReframe: VerticalReframePlan(
                mode: .blurPad,
                cropOffsetX: 0.5,
                sourceWidth: 960,
                sourceHeight: 540
            ),
            progressHandler: nil
        )

        let track = try #require(
            try await AVURLAsset(url: outputURL).loadTracks(withMediaType: .video).first
        )
        let size = try await track.load(.naturalSize)
        #expect(Int(size.width) == 1_080)
        #expect(Int(size.height) == 1_920)

        let centroid = try brightPixelCentroid(
            of: try await copyFrame(from: outputURL, atSeconds: 1)
        )
        let expected = BurnedSubtitleLayoutHelper.normalizedPosition(for: layout)
        #expect(abs(centroid.x - expected.x) < 0.02)
        #expect(abs(centroid.y - expected.y) < 0.02)
    }

    @MainActor
    @Test
    func testBatchShortsExportEndToEnd() async throws {
        let workspace = try makeWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let sourceURL = try makeSolidColorVideo(
            at: workspace.appendingPathComponent("shorts-source.mp4"),
            width: 960,
            height: 540,
            framesPerSecond: 30,
            durationSeconds: 6,
            horizontalSplitColors: true
        )
        let destination = workspace.appendingPathComponent("exports", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let cropShort = ShortDefinition(
            title: "Crop Switch",
            startMs: 0,
            endMs: 1_500,
            reframing: .crop,
            cropOffsetX: 0.2,
            cropKeyframes: [ShortCropKeyframe(timeMs: 750, offsetX: 0.8)]
        )
        let cutShort = ShortDefinition(
            title: "Across Cut",
            startMs: 1_000,
            endMs: 3_000
        )
        let hookShort = ShortDefinition(
            title: "With Hook",
            startMs: 2_000,
            endMs: 4_000,
            hookText: "HOOK CHECK"
        )

        var project = MockData.project
        project.name = "Shorts E2E"
        project.mediaFile = MediaFile(
            id: UUID(),
            originalURL: sourceURL,
            fileName: sourceURL.lastPathComponent,
            fileExtension: sourceURL.pathExtension,
            sizeBytes: Int64((try FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? NSNumber)?.int64Value ?? 0),
            durationMs: 6_000
        )
        project.subtitles = [
            makeSegment(
                startMs: 500,
                endMs: 1_400,
                text: "FIRST CUE",
                translatedText: "SHORTS TRANSLATED FIRST"
            ),
            makeSegment(
                startMs: 1_800,
                endMs: 2_600,
                text: "SECOND CUE",
                translatedText: "SHORTS TRANSLATED SECOND"
            ),
            makeSegment(
                startMs: 2_700,
                endMs: 3_700,
                text: "THIRD CUE",
                translatedText: "SHORTS TRANSLATED THIRD"
            ),
        ]
        project.editTimeline = EditTimeline(
            clips: [
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 0,
                    sourceEndMs: 2_000,
                    timelineStartMs: 0,
                    timelineEndMs: 2_000
                ),
                TimelineClip(
                    id: UUID(),
                    sourceStartMs: 4_000,
                    sourceEndMs: 6_000,
                    timelineStartMs: 2_000,
                    timelineEndMs: 4_000
                )
            ],
            totalDurationMs: 4_000
        )
        project.shorts = [cutShort, cropShort, hookShort]
        project.videoExportSettings = VideoExportSettings(
            quality: .smallFile,
            preset: .fast
        )
        project.videoExportSettings.subtitleTextMode = .original
        project.videoExportSettings.fontSize = 30
        project.videoExportSettings.subtitlePositionY = 0.86
        var shortsSettings = ShortsExportSettings()
        shortsSettings.subtitleStyle.subtitleTextMode = .translated
        shortsSettings.subtitleStyle.fontSize = 82
        shortsSettings.subtitleStyle.subtitlePositionY = 0.55
        project.shortsExportSettings = shortsSettings
        let persistedSubtitles = project.subtitles

        let appState = AppState()
        appState.enqueueShortsExport(
            project: project,
            shorts: project.shorts,
            sourceInfo: VideoSourceInfo(width: 960, height: 540, nominalFrameRate: 30),
            destinationDirectory: destination
        )
        try await waitForShortsExports(in: appState, expectedCount: 3)

        let jobs = appState.videoExportJobs
        try #require(jobs.count == 3)
        for job in jobs {
            try #require(
                job.status == .succeeded,
                "\(job.outputURL.lastPathComponent): \(job.errorMessage ?? "unknown export error")"
            )
        }

        let expectedDurations: [String: Double] = [
            "Shorts E2E — 01 Crop Switch.mp4": 1.5,
            "Shorts E2E — 02 Across Cut.mp4": 2.0,
            "Shorts E2E — 03 With Hook.mp4": 2.0
        ]
        #expect(Set(jobs.map { $0.outputURL.lastPathComponent }) == Set(expectedDurations.keys))

        for job in jobs {
            let expectedDuration = try #require(expectedDurations[job.outputURL.lastPathComponent])
            let asset = AVURLAsset(url: job.outputURL)
            let duration = try await asset.load(.duration).seconds
            #expect(abs(duration - expectedDuration) < 0.2)

            let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
            let size = try await track.load(.naturalSize)
            #expect(Int(size.width) == 1_080)
            #expect(Int(size.height) == 1_920)

            let sidecarURL = job.outputURL.deletingPathExtension().appendingPathExtension("srt")
            #expect(FileManager.default.fileExists(atPath: sidecarURL.path))
        }

        let cutOutput = try #require(jobs.first {
            $0.outputURL.lastPathComponent.contains("Across Cut")
        }?.outputURL)
        let cutSRT = try String(
            contentsOf: cutOutput.deletingPathExtension().appendingPathExtension("srt"),
            encoding: .utf8
        )
        #expect(cutSRT.contains("00:00:00,000 --> 00:00:00,400"))
        #expect(cutSRT.contains("00:00:00,800 --> 00:00:01,600"))
        #expect(cutSRT.contains("SHORTS TRANSLATED FIRST"))
        #expect(cutSRT.contains("SHORTS TRANSLATED SECOND"))
        #expect(!cutSRT.contains("FIRST CUE"))
        #expect(!cutSRT.contains("SECOND CUE"))
        #expect(project.subtitles == persistedSubtitles)

        let cropOutput = try #require(jobs.first {
            $0.outputURL.lastPathComponent.contains("Crop Switch")
        }?.outputURL)
        let cropBeforeImage = try await copyFrame(from: cropOutput, atSeconds: 0.25)
        let cropAfterImage = try await copyFrame(from: cropOutput, atSeconds: 1.0)
        let cropBeforePoint = try averageRGB(of: cropBeforeImage)
        let cropAfterPoint = try averageRGB(of: cropAfterImage)
        #expect(cropBeforePoint.red > cropBeforePoint.blue * 1.5)
        #expect(cropAfterPoint.blue > cropAfterPoint.red * 1.5)

        let hookOutput = try #require(jobs.first {
            $0.outputURL.lastPathComponent.contains("With Hook")
        }?.outputURL)
        let hookFrame = try await copyFrame(from: hookOutput, atSeconds: 0.5)
        #expect(try brightPixelCount(of: hookFrame, normalizedY: 0.10...0.35) > 20)
        #expect(try brightPixelCount(of: hookFrame, normalizedY: 0.45...0.65) > 20)
        // The regular export style is deliberately at 0.86; Shorts must not
        // burn its cue there.
        #expect(try brightPixelCount(of: hookFrame, normalizedY: 0.78...0.92) == 0)
    }

    // MARK: - Export + measurement helpers

    private func makeFFmpegService() -> FFmpegService {
        FFmpegServiceFactory.makeDefaultService(settings: .default)
    }

    private func systemFFmpegSupportsASS(at executableURL: URL) throws -> Bool {
        let process = Process()
        let standardOutput = Pipe()
        process.executableURL = executableURL
        process.arguments = ["-hide_banner", "-filters"]
        process.standardOutput = standardOutput
        process.standardError = Pipe()
        try process.run()
        let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(
            data: outputData,
            encoding: .utf8
        ) ?? ""
        return process.terminationStatus == 0 && output.contains(" ass ")
    }

    private func makeWorkspace() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("VideoExportIntegrationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeSegment(
        startMs: Int,
        endMs: Int,
        text: String,
        translatedText: String = ""
    ) -> SubtitleSegment {
        SubtitleSegment(
            id: UUID(),
            index: 1,
            startMs: startMs,
            endMs: endMs,
            originalText: text,
            translatedText: translatedText
        )
    }

    private func makeWhiteBlockSettings(anchor: CGPoint) -> VideoExportSettings {
        var settings = VideoExportSettings()
        settings.subtitlePositionX = anchor.x
        settings.subtitlePositionY = anchor.y
        settings.backgroundEnabled = true
        settings.backgroundColorRed = 1
        settings.backgroundColorGreen = 1
        settings.backgroundColorBlue = 1
        settings.backgroundOpacity = 1
        settings.backgroundCornerRadius = 0
        settings.borderEnabled = false
        return settings
    }

    private func burnAndMeasureCentroid(
        sourceURL: URL,
        settings: VideoExportSettings,
        sourceInfo: VideoSourceInfo,
        workspace: URL,
        outputName: String
    ) async throws -> CGPoint {
        let subtitlesURL = workspace.appendingPathComponent("\(outputName).ass")
        let ass = try ASSSubtitleExportService().generateASS(
            segments: [makeSegment(startMs: 0, endMs: 3_000, text: "HHHH HHHH")],
            settings: settings
        )
        try Data(ass.utf8).write(to: subtitlesURL, options: .atomic)

        let outputURL = workspace.appendingPathComponent(outputName)
        _ = try await makeFFmpegService().burnSubtitles(
            videoURL: sourceURL,
            subtitlesURL: subtitlesURL,
            outputURL: outputURL,
            settings: settings,
            sourceInfo: sourceInfo,
            clips: nil,
            progressHandler: nil
        )

        let image = try await copyFrame(from: outputURL, atSeconds: 1.5)
        return try brightPixelCentroid(of: image)
    }

    private func copyFrame(from url: URL, atSeconds seconds: Double) async throws -> CGImage {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        return try await generator.image(at: time).image
    }

    private func brightPixelCentroid(of image: CGImage) throws -> CGPoint {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        let context = try #require(
            CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            )
        )
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var sumX = 0.0
        var sumY = 0.0
        var count = 0.0
        for y in 0..<height {
            let rowStart = y * width
            for x in 0..<width where pixels[rowStart + x] > 128 {
                sumX += Double(x)
                sumY += Double(y)
                count += 1
            }
        }

        try #require(count > 0, "no bright pixels found in the exported frame")
        // CGContext rows are top-down, matching ASS/preview coordinates.
        return CGPoint(
            x: sumX / count / Double(width),
            y: sumY / count / Double(height)
        )
    }

    @MainActor
    private func waitForShortsExports(
        in appState: AppState,
        expectedCount: Int
    ) async throws {
        for _ in 0..<600 {
            if appState.videoExportJobs.count == expectedCount,
               appState.videoExportJobs.allSatisfy(\.isFinished) {
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        throw ShortsExportIntegrationError.timedOut
    }

    private func brightPixelCount(
        of image: CGImage,
        normalizedY range: ClosedRange<Double>
    ) throws -> Int {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        let context = try #require(CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let startY = min(max(0, Int((range.lowerBound * Double(height)).rounded(.down))), height - 1)
        let endY = min(max(startY, Int((range.upperBound * Double(height)).rounded(.up))), height)
        var count = 0
        for y in startY..<endY {
            let rowStart = y * width
            for x in 0..<width where pixels[rowStart + x] > 220 {
                count += 1
            }
        }
        return count
    }

    private func averageRGB(of image: CGImage) throws -> (red: Double, green: Double, blue: Double) {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
            | CGImageAlphaInfo.premultipliedLast.rawValue
        let context = try #require(CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var red = 0.0
        var green = 0.0
        var blue = 0.0
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            red += Double(pixels[offset])
            green += Double(pixels[offset + 1])
            blue += Double(pixels[offset + 2])
        }
        let count = Double(width * height) * 255
        return (red / count, green / count, blue / count)
    }

    // MARK: - Source video synthesis

    private func makeSolidColorVideo(
        at url: URL,
        width: Int,
        height: Int,
        framesPerSecond: Int,
        durationSeconds: Int,
        horizontalSplitColors: Bool = false
    ) throws -> URL {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height
            ]
        )
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )
        writer.add(input)
        guard writer.startWriting() else {
            throw writer.error ?? CocoaError(.fileWriteUnknown)
        }
        writer.startSession(atSourceTime: .zero)

        let pool = try #require(adaptor.pixelBufferPool)
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        let buffer = try #require(pixelBuffer)
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            if horizontalSplitColors {
                let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
                let bytes = base.assumingMemoryBound(to: UInt8.self)
                for y in 0..<height {
                    let row = bytes.advanced(by: y * bytesPerRow)
                    for x in 0..<width {
                        let pixel = row.advanced(by: x * 4)
                        let isRightHalf = x >= width / 2
                        pixel[0] = isRightHalf ? 255 : 0
                        pixel[1] = 0
                        pixel[2] = isRightHalf ? 0 : 255
                        pixel[3] = 255
                    }
                }
            } else {
                memset(base, 0, CVPixelBufferGetDataSize(buffer))
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])

        let frameCount = framesPerSecond * durationSeconds
        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.01)
            }
            let time = CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(framesPerSecond))
            adaptor.append(buffer, withPresentationTime: time)
        }

        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        semaphore.wait()
        guard writer.status == .completed else {
            throw writer.error ?? CocoaError(.fileWriteUnknown)
        }
        return url
    }
}

private enum ShortsExportIntegrationError: Error {
    case timedOut
}
