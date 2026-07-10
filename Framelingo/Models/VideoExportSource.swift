import CoreGraphics
import Foundation

struct VideoSourceInfo: Equatable, Sendable {
    var width: Int
    var height: Int
    var nominalFrameRate: Double

    var displaySize: CGSize {
        CGSize(width: CGFloat(width), height: CGFloat(height))
    }
}

struct VideoOutputSize: Equatable, Sendable {
    var width: Int
    var height: Int
}

struct VideoExportTargets: Equatable, Sendable {
    var size: VideoOutputSize?
    var framesPerSecond: Int?
}

enum VideoExportGeometry {
    private static let frameRateTolerance = 0.1

    static func displaySize(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform
    ) -> CGSize {
        let transformedRect = CGRect(origin: .zero, size: naturalSize)
            .applying(preferredTransform)

        return CGSize(
            width: abs(transformedRect.width),
            height: abs(transformedRect.height)
        )
    }

    static func availableResolutions(
        sourceWidth: Int,
        sourceHeight: Int
    ) -> [VideoExportResolution] {
        let shorterSide = min(sourceWidth, sourceHeight)
        guard shorterSide > 0 else {
            return [.original]
        }

        return VideoExportResolution.allCases.filter { resolution in
            guard let target = resolution.shortSideTarget else {
                return true
            }

            return target <= shorterSide
        }
    }

    static func availableFrameRates(
        nominalFrameRate: Double
    ) -> [VideoExportFrameRate] {
        guard nominalFrameRate.isFinite, nominalFrameRate > 0 else {
            return [.original]
        }

        return VideoExportFrameRate.allCases.filter { frameRate in
            guard let framesPerSecond = frameRate.framesPerSecond else {
                return true
            }

            return Double(framesPerSecond) <= nominalFrameRate + frameRateTolerance
        }
    }

    static func outputSize(
        sourceWidth: Int,
        sourceHeight: Int,
        resolution: VideoExportResolution
    ) -> VideoOutputSize? {
        guard sourceWidth > 0,
              sourceHeight > 0,
              let target = resolution.shortSideTarget,
              target <= min(sourceWidth, sourceHeight) else {
            return nil
        }

        if sourceWidth >= sourceHeight {
            let scaledWidth = Double(sourceWidth) * Double(target) / Double(sourceHeight)
            return VideoOutputSize(width: nearestEvenInteger(scaledWidth), height: target)
        }

        let scaledHeight = Double(sourceHeight) * Double(target) / Double(sourceWidth)
        return VideoOutputSize(width: target, height: nearestEvenInteger(scaledHeight))
    }

    static func targets(
        settings: VideoExportSettings,
        sourceInfo: VideoSourceInfo?
    ) -> VideoExportTargets {
        guard let sourceInfo else {
            return VideoExportTargets(size: nil, framesPerSecond: nil)
        }

        let size = outputSize(
            sourceWidth: sourceInfo.width,
            sourceHeight: sourceInfo.height,
            resolution: settings.resolution
        )
        let availableFrameRates = availableFrameRates(
            nominalFrameRate: sourceInfo.nominalFrameRate
        )
        let framesPerSecond = availableFrameRates.contains(settings.frameRate)
            ? settings.frameRate.framesPerSecond
            : nil

        return VideoExportTargets(size: size, framesPerSecond: framesPerSecond)
    }

    static func aspectFitRect(videoSize: CGSize, in bounds: CGRect) -> CGRect {
        guard videoSize.width > 0,
              videoSize.height > 0,
              bounds.width > 0,
              bounds.height > 0 else {
            return bounds
        }

        let scale = min(bounds.width / videoSize.width, bounds.height / videoSize.height)
        let fittedSize = CGSize(
            width: videoSize.width * scale,
            height: videoSize.height * scale
        )

        return CGRect(
            x: bounds.midX - fittedSize.width / 2,
            y: bounds.midY - fittedSize.height / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }

    private static func nearestEvenInteger(_ value: Double) -> Int {
        max(2, Int((value / 2).rounded()) * 2)
    }
}
