import Foundation
import Media

enum WaveformPeakAnalyzer {
    static func peaks(fromWAVFile url: URL, targetPeakCount: Int) throws -> [Double] {
        let data = try Data(contentsOf: url)
        let wav = try wavPCMData(in: data)
        let bytesPerSample = wav.bitsPerSample / 8
        let bytesPerFrame = bytesPerSample * wav.channelCount
        let frameCount = wav.audioData.count / bytesPerFrame
        guard frameCount > 0 else {
            throw WaveformServiceError.emptyAudio
        }

        let peakCount = min(max(targetPeakCount, 1), frameCount)
        let framesPerPeak = max(1, frameCount / peakCount)
        var peaks: [Double] = []
        peaks.reserveCapacity(peakCount)

        var frameIndex = 0
        while frameIndex < frameCount {
            let endIndex = min(frameIndex + framesPerPeak, frameCount)
            var maxAmplitude: Int32 = 0

            var index = frameIndex
            while index < endIndex {
                let frameOffset = wav.audioData.startIndex + index * bytesPerFrame
                for channel in 0..<wav.channelCount {
                    let byteOffset = frameOffset + channel * bytesPerSample
                    let raw = int16(in: wav.audioData, offset: byteOffset)
                    maxAmplitude = max(maxAmplitude, Int32(abs(Int(raw))))
                }
                index += 1
            }

            peaks.append(min(1.0, Double(maxAmplitude) / 32_768.0))
            frameIndex = endIndex
        }

        return peaks
    }

    private static func wavPCMData(in data: Data) throws -> WAVPCMData {
        guard data.count >= 12,
              asciiString(in: data, offset: 0, length: 4) == "RIFF",
              asciiString(in: data, offset: 8, length: 4) == "WAVE" else {
            throw WaveformServiceError.unsupportedAudio
        }

        var offset = 12
        var format: WAVFormat?
        var audioData: Data?

        while offset + 8 <= data.count {
            let chunkID = asciiString(in: data, offset: offset, length: 4)
            let chunkSize = Int(littleEndianUInt32(in: data, offset: offset + 4))
            let dataOffset = offset + 8
            let chunkEnd = dataOffset + chunkSize

            guard chunkEnd <= data.count else {
                throw WaveformServiceError.unsupportedAudio
            }

            if chunkID == "fmt " {
                format = try wavFormat(in: data, offset: dataOffset, size: chunkSize)
            } else if chunkID == "data" {
                audioData = data.subdata(in: dataOffset..<chunkEnd)
            }

            offset = chunkEnd + (chunkSize % 2)
        }

        guard let format,
              format.audioFormat == 1,
              format.bitsPerSample == 16,
              format.channelCount > 0 else {
            throw WaveformServiceError.unsupportedAudio
        }

        guard let audioData, !audioData.isEmpty else {
            throw WaveformServiceError.emptyAudio
        }

        return WAVPCMData(
            audioData: audioData,
            channelCount: format.channelCount,
            bitsPerSample: format.bitsPerSample
        )
    }

    private static func wavFormat(in data: Data, offset: Int, size: Int) throws -> WAVFormat {
        guard size >= 16, offset + 16 <= data.count else {
            throw WaveformServiceError.unsupportedAudio
        }

        return WAVFormat(
            audioFormat: Int(littleEndianUInt16(in: data, offset: offset)),
            channelCount: Int(littleEndianUInt16(in: data, offset: offset + 2)),
            bitsPerSample: Int(littleEndianUInt16(in: data, offset: offset + 14))
        )
    }

    private static func int16(in data: Data, offset: Int) -> Int16 {
        let low = UInt16(data[offset])
        let high = UInt16(data[offset + 1])
        return Int16(bitPattern: high << 8 | low)
    }

    private static func littleEndianUInt16(in data: Data, offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func littleEndianUInt32(in data: Data, offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }

    private static func asciiString(in data: Data, offset: Int, length: Int) -> String {
        guard offset + length <= data.count else {
            return ""
        }

        return String(
            data: data.subdata(in: offset..<(offset + length)),
            encoding: .ascii
        ) ?? ""
    }
}
