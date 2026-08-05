import Foundation

public enum ShortsEditError: Error, Equatable {
    case shortNotFound
    case invalidRange
}

public struct ShortsEditResult: Equatable {
    public let shorts: [ShortDefinition]
    public let editedShortID: UUID
    public let didChange: Bool

    public init(shorts: [ShortDefinition], editedShortID: UUID, didChange: Bool) {
        self.shorts = shorts
        self.editedShortID = editedShortID
        self.didChange = didChange
    }
}

public struct ShortsEditingPolicy {
    public init() {}

    public func add(
        shorts: [ShortDefinition],
        title: String,
        startMs: Int,
        endMs: Int,
        id: UUID = UUID()
    ) throws -> ShortsEditResult {
        let clampedStartMs = max(0, startMs)
        guard endMs > clampedStartMs else {
            throw ShortsEditError.invalidRange
        }

        var updated = shorts
        updated.append(ShortDefinition(
            id: id,
            title: title,
            startMs: clampedStartMs,
            endMs: endMs
        ))
        return ShortsEditResult(
            shorts: sorted(updated),
            editedShortID: id,
            didChange: true
        )
    }

    public func update(
        shorts: [ShortDefinition],
        id: UUID,
        mutate: (inout ShortDefinition) -> Void
    ) throws -> ShortsEditResult {
        guard let index = shorts.firstIndex(where: { $0.id == id }) else {
            throw ShortsEditError.shortNotFound
        }

        var updatedShort = shorts[index]
        mutate(&updatedShort)
        guard updatedShort != shorts[index] else {
            return ShortsEditResult(shorts: shorts, editedShortID: id, didChange: false)
        }

        var updated = shorts
        updated[index] = updatedShort
        return ShortsEditResult(
            shorts: sorted(updated),
            editedShortID: id,
            didChange: true
        )
    }

    public func updateRange(
        shorts: [ShortDefinition],
        id: UUID,
        startMs: Int,
        endMs: Int
    ) throws -> ShortsEditResult {
        let clampedStartMs = max(0, startMs)
        guard endMs > clampedStartMs else {
            throw ShortsEditError.invalidRange
        }

        return try update(shorts: shorts, id: id) { short in
            let oldStartMs = short.startMs
            let updatedDurationMs = endMs - clampedStartMs
            short.cropKeyframes = short.cropKeyframes.compactMap { keyframe in
                let absoluteTimeMs = oldStartMs + keyframe.timeMs
                let updatedLocalTimeMs = absoluteTimeMs - clampedStartMs
                guard updatedLocalTimeMs >= 0, updatedLocalTimeMs <= updatedDurationMs else {
                    return nil
                }
                var updatedKeyframe = keyframe
                updatedKeyframe.timeMs = updatedLocalTimeMs
                return updatedKeyframe
            }
            short.startMs = clampedStartMs
            short.endMs = endMs
        }
    }

    public func upsertCropKeyframe(
        shorts: [ShortDefinition],
        id: UUID,
        timelineTimeMs: Int,
        offsetX: Double
    ) throws -> ShortsEditResult {
        try update(shorts: shorts, id: id) { short in
            short.upsertCropKeyframe(
                localTimeMs: timelineTimeMs - short.startMs,
                offsetX: offsetX
            )
        }
    }

    public func deleteCropKeyframe(
        shorts: [ShortDefinition],
        shortID: UUID,
        keyframeID: UUID
    ) throws -> ShortsEditResult {
        try update(shorts: shorts, id: shortID) { short in
            short.cropKeyframes.removeAll { $0.id == keyframeID }
        }
    }

    public func delete(
        shorts: [ShortDefinition],
        id: UUID
    ) throws -> ShortsEditResult {
        guard shorts.contains(where: { $0.id == id }) else {
            throw ShortsEditError.shortNotFound
        }
        return ShortsEditResult(
            shorts: shorts.filter { $0.id != id },
            editedShortID: id,
            didChange: true
        )
    }

    private func sorted(_ shorts: [ShortDefinition]) -> [ShortDefinition] {
        shorts.sorted { $0.startMs < $1.startMs }
    }
}
