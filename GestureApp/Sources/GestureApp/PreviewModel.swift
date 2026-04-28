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
    /// Latest palm center [x, y] in normalized image coords.
    @Published var palmCenter: (Double, Double)?

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
        palmCenter = nil
    }

    func ingest(jpegData: Data) {
        guard isActive else { return }
        if let img = NSImage(data: jpegData) {
            self.image = img
        }
    }

    func ingest(fingerStates: [Int], palm: [Double]? = nil) {
        guard isActive, fingerStates.count == 5 else { return }
        self.fingerStates = fingerStates
        if let palm, palm.count >= 2 {
            self.palmCenter = (palm[0], palm[1])
        }
    }
}
