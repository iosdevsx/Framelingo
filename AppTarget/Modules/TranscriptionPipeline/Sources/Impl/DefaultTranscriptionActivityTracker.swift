import Combine
import TranscriptionPipeline

@MainActor
final class DefaultTranscriptionActivityTracker: TranscriptionActivityTracking {
    private let subject = CurrentValueSubject<TranscriptionActivity?, Never>(nil)

    private(set) var activity: TranscriptionActivity? {
        didSet { subject.send(activity) }
    }

    var activitySnapshots: AnyPublisher<TranscriptionActivity?, Never> {
        subject.eraseToAnyPublisher()
    }

    func start(projectName: String) {
        activity = TranscriptionActivity(
            projectName: projectName,
            statusText: "Extracting audio...",
            progress: 0,
            status: .running
        )
    }

    func update(statusText: String, progress: Double?) {
        guard activity != nil else { return }
        activity?.statusText = statusText
        if let progress {
            activity?.progress = min(max(progress, 0), 1)
        }
    }

    func finish(success: Bool, message: String?) {
        guard activity != nil else { return }
        activity?.status = success ? .succeeded : .failed
        if success { activity?.progress = 1 }
        activity?.statusText = message ?? (success ? "Transcription complete" : "Transcription failed")
    }

    func dismiss() {
        activity = nil
    }
}
