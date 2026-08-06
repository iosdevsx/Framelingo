/// A source-time range of the original video that survives edit-timeline cuts.
public struct ExportClipRange: Equatable, Sendable {
    public var sourceStartMs: Int
    public var sourceEndMs: Int

    public init(sourceStartMs: Int, sourceEndMs: Int) {
        self.sourceStartMs = sourceStartMs
        self.sourceEndMs = sourceEndMs
    }

    public var durationMs: Int {
        max(0, sourceEndMs - sourceStartMs)
    }
}
