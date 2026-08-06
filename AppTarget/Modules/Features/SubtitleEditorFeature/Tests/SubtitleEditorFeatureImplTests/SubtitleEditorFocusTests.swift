import Foundation
import SubtitleEditorFeature
import Testing

struct SubtitleEditorFocusTests {
    @Test
    func exposesTheFocusedTextSegmentWithoutDuplicatingEditorState() {
        let id = UUID()

        #expect(SubtitleEditorFocus.translation(id).textEditSegmentID == id)
        #expect(SubtitleEditorFocus.start(id).textEditSegmentID == nil)
    }
}
