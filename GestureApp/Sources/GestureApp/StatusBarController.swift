import SwiftUI

enum AppStatus {
    case stopped
    case running
    case handDetected

    var icon: String {
        switch self {
        case .stopped: return "hand.raised.slash"
        case .running: return "hand.raised"
        case .handDetected: return "hand.raised.fill"
        }
    }

    var label: String {
        switch self {
        case .stopped: return "Stopped"
        case .running: return "Running"
        case .handDetected: return "Hand Detected"
        }
    }
}

class StatusBarController: ObservableObject {
    @Published var status: AppStatus = .stopped
    @Published var fps: Double = 0
    @Published var lastGesture: String = ""
    @Published var isEngineRunning = false

    func updateStatus(_ event: GestureEvent) {
        if event.type == "status" {
            fps = event.fps ?? 0
            status = (event.handsDetected ?? 0) > 0 ? .handDetected : .running
        }
    }

    func gestureRecognized(_ name: String) {
        lastGesture = name
        // Clear after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.lastGesture == name {
                self?.lastGesture = ""
            }
        }
    }
}
