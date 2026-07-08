import Foundation

struct MockSpeechToTextProvider: SpeechToTextProvider {
    func transcribe(_ input: TranscriptionInput) async throws -> TranscriptionResult {
        await input.progressHandler?(0.2, "Preparing mock transcription...")
        try await Task.sleep(for: .milliseconds(350))
        await input.progressHandler?(1, "Mock transcription complete.")

        let isRussian = input.sourceLanguage?.localizedCaseInsensitiveContains("Russian") == true ||
            input.sourceLanguage?.localizedCaseInsensitiveContains("ru") == true

        let texts = isRussian ? russianTexts : englishTexts
        let segments = texts.enumerated().map { offset, text in
            let timing = timings[offset]
            return SubtitleSegment(
                id: UUID(),
                index: offset + 1,
                startMs: timing.start,
                endMs: timing.end,
                originalText: text,
                translatedText: "",
                speaker: nil,
                confidence: timing.confidence
            )
        }

        return TranscriptionResult(
            segments: segments,
            words: [],
            detectedLanguage: isRussian ? "Russian" : "English",
            durationMs: timings.last?.end
        )
    }

    private var englishTexts: [String] {
        [
            "Welcome to this short subtitle editing demo.",
            "First, we import a local video file into the project.",
            "The app keeps the original file in place.",
            "Next, speech recognition creates timed subtitle segments.",
            "Each segment can be reviewed and adjusted by hand.",
            "Translations appear in a separate editable column.",
            "You can correct timing when the speaker pauses or changes pace.",
            "When everything looks right, export the subtitles.",
            "The first version supports SRT, VTT, and plain text.",
            "Later, the same workflow can render subtitles into video."
        ]
    }

    private var russianTexts: [String] {
        [
            "Добро пожаловать в короткую демонстрацию редактора субтитров.",
            "Сначала мы добавляем локальный видеофайл в проект.",
            "Приложение оставляет исходный файл на месте.",
            "Затем распознавание речи создаёт сегменты с таймкодами.",
            "Каждый сегмент можно проверить и поправить вручную.",
            "Перевод отображается в отдельной редактируемой колонке.",
            "Тайминг можно уточнить, когда диктор делает паузу.",
            "Когда всё готово, экспортируйте субтитры.",
            "Первая версия поддерживает SRT, VTT и обычный текст.",
            "Позже этот процесс можно использовать для вшивания субтитров в видео."
        ]
    }

    private var timings: [(start: Int, end: Int, confidence: Double)] {
        [
            (900, 3_900, 0.96),
            (4_350, 7_900, 0.94),
            (8_300, 10_850, 0.95),
            (11_400, 15_300, 0.92),
            (15_850, 19_100, 0.97),
            (19_650, 22_950, 0.93),
            (23_500, 27_700, 0.91),
            (28_200, 31_100, 0.96),
            (31_650, 35_450, 0.94),
            (36_000, 40_800, 0.90)
        ]
    }
}
