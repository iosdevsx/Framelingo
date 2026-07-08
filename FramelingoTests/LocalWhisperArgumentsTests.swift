import XCTest
@testable import Framelingo

final class LocalWhisperArgumentsTests: XCTestCase {
    private let modelURL = URL(fileURLWithPath: "/models/ggml-small.bin")
    private let audioURL = URL(fileURLWithPath: "/audio/input file.wav")
    private let outputBaseURL = URL(fileURLWithPath: "/tmp/out/transcript")

    private var existingVADModelURL: URL!

    override func setUpWithError() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalWhisperArgumentsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        existingVADModelURL = directory.appendingPathComponent("ggml-silero-v5.1.2.bin")
        FileManager.default.createFile(atPath: existingVADModelURL.path, contents: Data([0x01]))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: existingVADModelURL.deletingLastPathComponent())
    }

    private func makeArguments(
        sourceLanguage: String? = nil,
        whisperModelName: String? = nil,
        vadEnabled: Bool = false,
        vadModelURL: URL? = nil
    ) -> [String] {
        LocalWhisperSpeechToTextProvider.makeArguments(
            modelURL: modelURL,
            audioURL: audioURL,
            outputBaseURL: outputBaseURL,
            sourceLanguage: sourceLanguage,
            whisperModelName: whisperModelName,
            vadEnabled: vadEnabled,
            vadModelURL: vadModelURL
        )
    }

    private func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }

    // MARK: - Baseline

    func testBaselineArgumentsUnchanged() {
        let arguments = makeArguments()

        XCTAssertEqual(value(after: "-m", in: arguments), modelURL.path)
        XCTAssertEqual(value(after: "-f", in: arguments), audioURL.path)
        XCTAssertEqual(value(after: "-of", in: arguments), outputBaseURL.path)
        XCTAssertTrue(arguments.contains("-osrt"))
        XCTAssertTrue(arguments.contains("-ojf"))
        XCTAssertTrue(arguments.contains("-pp"))
        XCTAssertTrue(arguments.contains("-nt"))
    }

    // MARK: - Language

    func testKnownLanguageMapsToCode() {
        XCTAssertEqual(value(after: "-l", in: makeArguments(sourceLanguage: "Russian")), "ru")
        XCTAssertEqual(value(after: "-l", in: makeArguments(sourceLanguage: "english")), "en")
        XCTAssertEqual(value(after: "-l", in: makeArguments(sourceLanguage: "JAPANESE")), "ja")
    }

    func testUnknownOrMissingLanguageFallsBackToAuto() {
        XCTAssertEqual(value(after: "-l", in: makeArguments(sourceLanguage: nil)), "auto")
        XCTAssertEqual(value(after: "-l", in: makeArguments(sourceLanguage: "")), "auto")
        XCTAssertEqual(value(after: "-l", in: makeArguments(sourceLanguage: "Klingon")), "auto")
    }

    // MARK: - DTW

    func testKnownModelNameAppendsDTWPreset() {
        XCTAssertEqual(value(after: "--dtw", in: makeArguments(whisperModelName: "small")), "small")
        XCTAssertEqual(
            value(after: "--dtw", in: makeArguments(whisperModelName: "large-v3-turbo-q5_0")),
            "large.v3.turbo"
        )
        XCTAssertEqual(
            value(after: "--dtw", in: makeArguments(whisperModelName: "large-v3-turbo")),
            "large.v3.turbo"
        )
    }

    func testUnknownModelNameOmitsDTW() {
        XCTAssertFalse(makeArguments(whisperModelName: "my-custom-model").contains("--dtw"))
        XCTAssertFalse(makeArguments(whisperModelName: nil).contains("--dtw"))
    }

    // MARK: - VAD

    func testVADEnabledWithExistingModelAppendsVADArguments() {
        let arguments = makeArguments(vadEnabled: true, vadModelURL: existingVADModelURL)

        XCTAssertTrue(arguments.contains("--vad"))
        XCTAssertEqual(value(after: "--vad-model", in: arguments), existingVADModelURL.path)
        XCTAssertEqual(value(after: "--vad-speech-pad-ms", in: arguments), "100")
    }

    func testVADDisabledOmitsVADArguments() {
        let arguments = makeArguments(vadEnabled: false, vadModelURL: existingVADModelURL)

        XCTAssertFalse(arguments.contains("--vad"))
        XCTAssertFalse(arguments.contains("--vad-model"))
    }

    func testVADEnabledWithMissingModelFileOmitsVADArguments() {
        let missingURL = URL(fileURLWithPath: "/nonexistent/ggml-silero-v5.1.2.bin")
        let arguments = makeArguments(vadEnabled: true, vadModelURL: missingURL)

        XCTAssertFalse(arguments.contains("--vad"))
        XCTAssertFalse(arguments.contains("--vad-model"))
    }

    func testVADEnabledWithNilModelURLOmitsVADArguments() {
        XCTAssertFalse(makeArguments(vadEnabled: true, vadModelURL: nil).contains("--vad"))
    }
}
