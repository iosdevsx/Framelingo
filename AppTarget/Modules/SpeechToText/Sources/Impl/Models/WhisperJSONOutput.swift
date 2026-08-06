struct WhisperJSONOutput: Decodable {
    let transcription: [WhisperJSONSegment]
}
