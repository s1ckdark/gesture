import AppKit
import Combine

/// Shared state for the live camera preview.
/// SocketClient pushes frames in, PreviewWindow renders them.
@MainActor
final class PreviewModel: ObservableObject {
    @Published var image: NSImage?
    @Published var isActive: Bool = false

    /// Set by GestureApp once a SocketClient is connected.
    var sendCommand: ((String) -> Void)?

    func activate() {
        isActive = true
        sendCommand?("preview_on")
    }

    func deactivate() {
        isActive = false
        sendCommand?("preview_off")
        image = nil
    }

    func ingest(jpegData: Data) {
        guard isActive else { return }
        if let img = NSImage(data: jpegData) {
            self.image = img
        }
    }
}
