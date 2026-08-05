actor ProgressRecorder {
    private(set) var statuses: [String] = []

    func record(_ status: String) {
        statuses.append(status)
    }
}
