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

    var label: LocalizedStringKey {
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
    @Published var hasAccessibility: Bool = Permissions.isAccessibilityGranted()
    /// Set briefly when a gesture fires; nil otherwise. Drives a transient menu-bar icon flash.
    @Published var flashIcon: String? = nil

    private var flashWorkItem: DispatchWorkItem?

    func refreshPermissions() {
        hasAccessibility = Permissions.isAccessibilityGranted()
    }

    func updateStatus(_ event: GestureEvent) {
        if event.type == "status" {
            fps = event.fps ?? 0
            status = (event.handsDetected ?? 0) > 0 ? .handDetected : .running
        }
    }

    func gestureRecognized(_ name: String) {
        lastGesture = name
        // Flash the menu-bar icon for 1s
        flashIcon = "checkmark.seal.fill"
        flashWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.flashIcon = nil
        }
        flashWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)

        // Clear "last gesture" text after 2s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.lastGesture == name {
                self?.lastGesture = ""
            }
        }
    }
}
