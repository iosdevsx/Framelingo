import FluidAudio
import XCTest
@testable import Framelingo

final class ParakeetLanguageSupportTests: XCTestCase {
    func testSupportedLanguageCodeIsCaseInsensitive() {
        XCTAssertTrue(ParakeetLanguageSupport.isSupported("en"))
        XCTAssertTrue(ParakeetLanguageSupport.isSupported("RU"))
        XCTAssertEqual(ParakeetLanguageSupport.fluidAudioLanguageHint(for: "ru"), .russian)
    }

    func testUnsupportedLanguageCode() {
        XCTAssertFalse(ParakeetLanguageSupport.isSupported("ja"))
        XCTAssertNil(ParakeetLanguageSupport.fluidAudioLanguageHint(for: "ja"))
    }

    func testRegionSubtagUsesPrimaryLanguageCode() {
        XCTAssertTrue(ParakeetLanguageSupport.isSupported("en-US"))
        XCTAssertTrue(ParakeetLanguageSupport.isSupported("pt_BR"))
        XCTAssertEqual(ParakeetLanguageSupport.fluidAudioLanguageHint(for: "en-US"), .english)
    }

    func testDisplayLanguageNameMapsToSupportedCode() {
        XCTAssertTrue(ParakeetLanguageSupport.isSupported("English"))
        XCTAssertTrue(ParakeetLanguageSupport.isSupported("Russian"))
        XCTAssertEqual(ParakeetLanguageSupport.fluidAudioLanguageHint(for: "English"), .english)
    }

    func testNilSourceLanguageCallSiteTreatsLanguageAsAutomatic() {
        let sourceLanguage: String? = nil
        let shouldUseFallback = sourceLanguage.map { !ParakeetLanguageSupport.isSupported($0) } ?? false
        let languageHint = ParakeetLanguageSupport.fluidAudioLanguageHint(for: sourceLanguage)

        XCTAssertFalse(shouldUseFallback)
        XCTAssertNil(languageHint)
    }
}
