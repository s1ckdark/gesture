import SwiftUI
import Combine

private enum RecorderState: Equatable {
    case idle
    case countdown(Int)
    case recording(Double)  // seconds left
    case done(Int)          // captured count
}

struct MotionRecordSheet: View {
    let existingNames: Set<String>
    let onAdd: (String, GestureConfig) -> Void
    let onCancel: () -> Void

    @EnvironmentObject var preview: PreviewModel
    @State private var name: String = ""
    @State private var capturedPoints: [[Double]] = []
    @State private var state: RecorderState = .idle
    @State private var actionConfig: ActionConfig = ActionConfig(
        type: .hotkey, keys: [], command: nil, script: nil,
        button: nil, clickCount: nil, dx: nil, dy: nil, text: nil
    )
    @State private var subscription: AnyCancellable?

    private let recordSeconds: Double = 3.0

    private var nameError: String? {
        if name.isEmpty { return nil }
        if !name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
            return "Use letters, digits, or underscore only."
        }
        if existingNames.contains(name) {
            return "A gesture with this name already exists."
        }
        return nil
    }

    private var canSubmit: Bool {
        !name.isEmpty && nameError == nil && capturedPoints.count >= 5 &&
            ActionEditorView.isValid(actionConfig)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Record Motion Gesture").font(.title2).bold()

            VStack(alignment: .leading, spacing: 4) {
                Text("Name").font(.subheadline)
                TextField("e.g. circle, swipe_diag", text: $name)
                    .textFieldStyle(.roundedBorder)
                if let err = nameError {
                    Text(err).font(.caption).foregroundColor(.red)
                }
            }

            recorderArea

            ActionEditorView(config: $actionConfig)

            Divider()
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSubmit)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(minWidth: 520)
        .onAppear { preview.activate() }
        .onDisappear {
            preview.deactivate()
            subscription?.cancel()
        }
    }

    @ViewBuilder
    private var recorderArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trace your motion").font(.subheadline)
            if !preview.isActive || preview.palmCenter == nil {
                Text("Engine must be running and the camera preview active. Showing your hand to the camera will enable recording.")
                    .font(.caption).foregroundColor(.secondary)
            }
            HStack {
                switch state {
                case .idle:
                    Button("Start Recording (3s)") { startRecording() }
                        .disabled(preview.palmCenter == nil)
                case .countdown(let n):
                    Text("Recording in \(n)…").font(.title3)
                case .recording(let secs):
                    HStack(spacing: 8) {
                        Image(systemName: "record.circle.fill").foregroundColor(.red)
                        Text("Recording… \(String(format: "%.1f", secs))s left")
                            .font(.title3)
                    }
                case .done(let count):
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text("Captured \(count) points")
                        Button("Re-record") {
                            capturedPoints = []
                            state = .idle
                        }
                        .controlSize(.small)
                    }
                }
                Spacer()
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(6)
    }

    private func startRecording() {
        capturedPoints = []
        state = .countdown(3)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { state = .countdown(2) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { state = .countdown(1) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { beginCapture() }
    }

    private func beginCapture() {
        // Subscribe to live palmCenter; capture every value while recording
        subscription = preview.$palmCenter
            .compactMap { $0 }
            .sink { palm in
                capturedPoints.append([palm.0, palm.1])
            }
        let start = Date()
        // Tick the countdown UI
        var deadline: Date = start.addingTimeInterval(recordSeconds)
        state = .recording(recordSeconds)
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            let now = Date()
            if now >= deadline {
                timer.invalidate()
                subscription?.cancel()
                subscription = nil
                state = .done(capturedPoints.count)
            } else {
                state = .recording(deadline.timeIntervalSince(now))
            }
            _ = start  // silence unused
            _ = deadline
        }
    }

    private func submit() {
        let action = actionConfig
        let cfg = GestureConfig(
            type: "motion_custom",
            emoji: nil,
            pattern: nil,
            patternLeft: nil, patternRight: nil,
            proximity: nil,
            motionTemplate: capturedPoints,
            action: action
        )
        onAdd(name, cfg)
    }

}
