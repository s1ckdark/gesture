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
    /// Heatmap grid (rows × cols) of palm-position visit counts.
    @Published var heatmap: [[Double]] = Array(
        repeating: Array(repeating: 0.0, count: PreviewModel.heatmapCols),
        count: PreviewModel.heatmapRows
    )
    @Published var heatmapMax: Double = 0

    static let heatmapCols = 16
    static let heatmapRows = 12

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
            // Accumulate heatmap cell visit
            let col = min(Self.heatmapCols - 1, max(0, Int(palm[0] * Double(Self.heatmapCols))))
            let row = min(Self.heatmapRows - 1, max(0, Int(palm[1] * Double(Self.heatmapRows))))
            heatmap[row][col] += 1
            if heatmap[row][col] > heatmapMax {
                heatmapMax = heatmap[row][col]
            }
        }
    }

    func resetHeatmap() {
        heatmap = Array(
            repeating: Array(repeating: 0.0, count: Self.heatmapCols),
            count: Self.heatmapRows
        )
        heatmapMax = 0
    }
}
