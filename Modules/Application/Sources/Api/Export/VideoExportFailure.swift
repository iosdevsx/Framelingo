struct VideoExportFailure: Error, Equatable {
    var message: String
    var debugOutput: String?
}
