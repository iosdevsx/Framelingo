import CoreGraphics
import Testing
@testable import Framelingo

struct VideoExportSourceTests {
    @Test
    func testDisplaySizeAppliesPortraitRotationTransform() {
        let transform = CGAffineTransform(
            a: 0,
            b: 1,
            c: -1,
            d: 0,
            tx: 1_080,
            ty: 0
        )

        let size = VideoExportGeometry.displaySize(
            naturalSize: CGSize(width: 1_920, height: 1_080),
            preferredTransform: transform
        )

        #expect(size.width == 1_080)
        #expect(size.height == 1_920)
    }

    @Test
    func testAvailableResolutionsUseShorterSideWithoutUpscaling() {
        let options = VideoExportGeometry.availableResolutions(
            sourceWidth: 1_920,
            sourceHeight: 1_080
        )

        #expect(options == [.original, .p1080, .p720])
        #expect(
            VideoExportGeometry.availableResolutions(sourceWidth: 0, sourceHeight: 0)
                == [.original]
        )
    }

    @Test
    func testAvailableFrameRatesAllowNearIntegerNTSCValues() {
        #expect(
            VideoExportGeometry.availableFrameRates(nominalFrameRate: 29.97)
                == [.original, .fps24, .fps25, .fps30]
        )
        #expect(
            VideoExportGeometry.availableFrameRates(nominalFrameRate: 59.94)
                == [.original, .fps24, .fps25, .fps30, .fps50, .fps60]
        )
        #expect(
            VideoExportGeometry.availableFrameRates(nominalFrameRate: 0)
                == [.original]
        )
    }

    @Test
    func testOutputSizePreservesLandscapeAndPortraitAspectRatios() {
        #expect(
            VideoExportGeometry.outputSize(
                sourceWidth: 3_840,
                sourceHeight: 2_160,
                resolution: .p1080
            ) == VideoOutputSize(width: 1_920, height: 1_080)
        )
        #expect(
            VideoExportGeometry.outputSize(
                sourceWidth: 1_080,
                sourceHeight: 1_920,
                resolution: .p720
            ) == VideoOutputSize(width: 720, height: 1_280)
        )
    }

    @Test
    func testOutputSizeRoundsOddSourceRatioToEvenDimensions() {
        let output = VideoExportGeometry.outputSize(
            sourceWidth: 1_919,
            sourceHeight: 1_079,
            resolution: .p720
        )

        #expect(output == VideoOutputSize(width: 1_280, height: 720))
        #expect(output?.width.isMultiple(of: 2) == true)
        #expect(output?.height.isMultiple(of: 2) == true)
        #expect(
            VideoExportGeometry.outputSize(
                sourceWidth: 1_280,
                sourceHeight: 720,
                resolution: .p1080
            ) == nil
        )
    }

    @Test
    func testTargetsClampUnavailableSavedOptions() {
        var settings = VideoExportSettings()
        settings.resolution = .p2160
        settings.frameRate = .fps60

        let targets = VideoExportGeometry.targets(
            settings: settings,
            sourceInfo: VideoSourceInfo(
                width: 1_920,
                height: 1_080,
                nominalFrameRate: 29.97
            )
        )

        #expect(targets == VideoExportTargets(size: nil, framesPerSecond: nil))
        #expect(
            VideoExportGeometry.targets(settings: settings, sourceInfo: nil)
                == VideoExportTargets(size: nil, framesPerSecond: nil)
        )
    }

    @Test
    func testAspectFitRectUsesActualVideoAspect() {
        let rect = VideoExportGeometry.aspectFitRect(
            videoSize: CGSize(width: 1_080, height: 1_920),
            in: CGRect(x: 0, y: 0, width: 1_600, height: 900)
        )

        #expect(abs(rect.width - 506.25) < 0.001)
        #expect(abs(rect.height - 900) < 0.001)
        #expect(abs(rect.midX - 800) < 0.001)
        #expect(abs(rect.midY - 450) < 0.001)
    }
}
