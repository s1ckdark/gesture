import AppKit
import Combine

/// Shared state for the live camera preview.
/// SocketClient pushes frames in, PreviewWindow renders them.
@MainActor
final class PreviewModel: ObservableObject {
    @Published var image: NSImage?
    @Published var isActive: Bool = false
    /// Live finger states [thumb, index, middle, ring, pinky] streamed from the engine.
    @Published var fingerStates: [Int] = []

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
        fingerStates = []
    }

    func ingest(jpegData: Data) {
        guard isActive else { return }
        if let img = NSImage(data: jpegData) {
            self.image = img
        }
    }

    func ingest(fingerStates: [Int]) {
        guard isActive, fingerStates.count == 5 else { return }
        self.fingerStates = fingerStates
    }
}
