import AVFoundation
import CoreVideo
import Foundation
import Subtitles
import Testing
import VideoRendering
import VideoRenderingImpl

@Suite(.serialized)
struct VideoExportSmokeTests {
    @Test
    func embeddedRendererExtractsOnlyEditedTimelineAudio() async throws {
        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("VideoRenderingAudioSmoke-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: workspace,
            withIntermediateDirectories: true
        )

        let sourceURL = workspace.appendingPathComponent("source.wav")
        try makeSilentAudio(at: sourceURL, durationSeconds: 2)

        let outputURL = workspace.appendingPathComponent("edited.wav")
        let renderer = VideoRenderingAssembly.makeDefaultService()
        let result = try await renderer.extractAudio(
            from: sourceURL,
            to: outputURL,
            clips: [
                ExportClipRange(sourceStartMs: 0, sourceEndMs: 500),
                ExportClipRange(sourceStartMs: 1_500, sourceEndMs: 2_000),
            ]
        )

        #expect(result == outputURL)
        let audioFile = try AVAudioFile(forReading: outputURL)
        let duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
        #expect(abs(duration - 1) < 0.05)
        #expect(audioFile.fileFormat.sampleRate == 16_000)
        #expect(audioFile.fileFormat.channelCount == 1)

        try FileManager.default.removeItem(at: workspace)
    }

    @Test
    func embeddedRendererBurnsSubtitlesAndTrimsGenericClips() async throws {
        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("VideoRenderingSmoke-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: workspace,
            withIntermediateDirectories: true
        )

        let sourceURL = workspace.appendingPathComponent("source.mp4")
        try await makeBlackVideo(at: sourceURL)

        let segment = SubtitleSegment(
            id: UUID(),
            index: 1,
            startMs: 0,
            endMs: 1_000,
            originalText: "PACKAGE SMOKE",
            translatedText: ""
        )
        let script = try VideoRenderingAssembly.makeSubtitleScriptGenerator()
            .generateASS(segments: [segment], settings: VideoExportSettings())
        let subtitlesURL = workspace.appendingPathComponent("subtitles.ass")
        try Data(script.utf8).write(to: subtitlesURL, options: .atomic)

        let outputURL = workspace.appendingPathComponent("output.mp4")
        let renderer = VideoRenderingAssembly.makeDefaultService()
        let result = try await renderer.burnSubtitles(
            videoURL: sourceURL,
            subtitlesURL: subtitlesURL,
            outputURL: outputURL,
            settings: VideoExportSettings(quality: .smallFile, preset: .fast),
            sourceInfo: VideoSourceInfo(
                width: 640,
                height: 360,
                nominalFrameRate: 30
            ),
            clips: [
                ExportClipRange(sourceStartMs: 250, sourceEndMs: 1_250)
            ],
            verticalReframe: nil,
            progressHandler: nil
        )

        #expect(result == outputURL)
        #expect(FileManager.default.fileExists(atPath: outputURL.path))
        let asset = AVURLAsset(url: outputURL)
        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - 1) < 0.2)
        let track = try #require(
            try await asset.loadTracks(withMediaType: .video).first
        )
        let size = try await track.load(.naturalSize)
        #expect(Int(size.width) == 640)
        #expect(Int(size.height) == 360)

        try FileManager.default.removeItem(at: workspace)
    }

    private func makeBlackVideo(at url: URL) async throws {
        let width = 640
        let height = 360
        let framesPerSecond = 30
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
            ]
        )
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )
        writer.add(input)
        guard writer.startWriting() else {
            throw writer.error ?? CocoaError(.fileWriteUnknown)
        }
        writer.startSession(atSourceTime: .zero)

        guard let pool = adaptor.pixelBufferPool else {
            throw CocoaError(.coderInvalidValue)
        }
        var optionalBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optionalBuffer)
        guard let buffer = optionalBuffer else {
            throw CocoaError(.coderInvalidValue)
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            throw CocoaError(.coderInvalidValue)
        }
        memset(baseAddress, 0, CVPixelBufferGetDataSize(buffer))
        CVPixelBufferUnlockBaseAddress(buffer, [])

        for frame in 0..<(framesPerSecond * 2) {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(2))
            }
            let time = CMTime(
                value: CMTimeValue(frame),
                timescale: CMTimeScale(framesPerSecond)
            )
            guard adaptor.append(buffer, withPresentationTime: time) else {
                throw writer.error ?? CocoaError(.fileWriteUnknown)
            }
        }

        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw writer.error ?? CocoaError(.fileWriteUnknown)
        }
    }

    private func makeSilentAudio(at url: URL, durationSeconds: Int) throws {
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: 48_000,
            channels: 1
        ) else {
            throw CocoaError(.coderInvalidValue)
        }

        let frameCount = AVAudioFrameCount(durationSeconds * 48_000)
        guard
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: frameCount
            ),
            let channel = buffer.floatChannelData?.pointee
        else {
            throw CocoaError(.coderInvalidValue)
        }

        buffer.frameLength = frameCount
        channel.initialize(repeating: 0, count: Int(frameCount))
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }
}
