import Foundation

enum MockData {
    static let subtitles: [SubtitleSegment] = [
        SubtitleSegment(
            id: UUID(),
            index: 1,
            startMs: 1_000,
            endMs: 3_400,
            originalText: "Welcome to the product demo.",
            translatedText: "Добро пожаловать в демонстрацию продукта.",
            speaker: "Speaker 1",
            confidence: 0.98
        ),
        SubtitleSegment(
            id: UUID(),
            index: 2,
            startMs: 4_000,
            endMs: 6_700,
            originalText: "We will generate subtitles locally first.",
            translatedText: "Сначала мы локально создадим субтитры.",
            speaker: "Speaker 1",
            confidence: 0.95
        ),
        SubtitleSegment(
            id: UUID(),
            index: 3,
            startMs: 7_200,
            endMs: 10_300,
            originalText: "Then you can edit timings and export SRT.",
            translatedText: "Затем можно отредактировать тайминги и экспортировать SRT.",
            speaker: "Speaker 1",
            confidence: 0.96
        )
    ]

    static let project = Project(
        id: UUID(),
        name: "Mock Video Translation",
        createdAt: Date(),
        updatedAt: Date(),
        mediaFile: MediaFile(
            id: UUID(),
            originalURL: URL(fileURLWithPath: "/Users/example/Videos/mock-demo.mp4"),
            fileName: "mock-demo.mp4",
            fileExtension: "mp4",
            sizeBytes: 128_000_000,
            durationMs: 12_000
        ),
        sourceLanguage: "English",
        targetLanguage: "Russian",
        subtitles: subtitles,
        status: .ready
    )
}
