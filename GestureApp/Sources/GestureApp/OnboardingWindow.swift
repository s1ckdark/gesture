import SwiftUI

struct OnboardingWindow: View {
    @EnvironmentObject var model: OnboardingModel
    @EnvironmentObject var preview: PreviewModel
    let isEngineRunning: Bool
    let hasAccessibility: Bool
    let onStartEngine: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                ForEach(0..<model.totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i <= model.step.rawValue ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }

            switch model.step {
            case .welcome: welcomeStep
            case .camera: cameraStep
            case .accessibility: accessibilityStep
            case .demo: demoStep
            case .done: doneStep
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 420)
    }

    private var welcomeStep: some View {
        VStack(spacing: 14) {
            Image(systemName: "hand.raised.fill")
                .resizable().scaledToFit().frame(width: 72, height: 72)
                .foregroundColor(.blue)
            Text("Welcome to Gesture")
                .font(.title).bold()
            Text("Recognize hand gestures from your webcam and trigger keyboard shortcuts or shell commands. This quick tour will set you up.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Get Started") { model.advance() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
    }

    private var cameraStep: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .resizable().scaledToFit().frame(width: 56, height: 56)
                .foregroundColor(.blue)
            Text("Camera Access").font(.title2).bold()
            Text("Gesture's Python engine reads webcam frames to find your hand. The first time you click Start, macOS will ask permission — allow it.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Continue") { model.advance() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
    }

    private var accessibilityStep: some View {
        VStack(spacing: 14) {
            Image(systemName: hasAccessibility ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .resizable().scaledToFit().frame(width: 56, height: 56)
                .foregroundColor(hasAccessibility ? .green : .orange)
            Text("Accessibility Access").font(.title2).bold()
            if hasAccessibility {
                Text("Already granted ✓ — Gesture can post keyboard events and run hotkey actions.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            } else {
                Text("Hotkey actions (like ⌘C from a thumbs-up) need Accessibility permission. Click below to open the System Settings pane and toggle GestureApp on.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Button("Open Permission Settings") {
                    Permissions.requestAccessibility()
                }
            }
            Button("Continue") { model.advance() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
    }

    private var demoStep: some View {
        VStack(spacing: 14) {
            Image(systemName: "hand.thumbsup.fill")
                .resizable().scaledToFit().frame(width: 56, height: 56)
                .foregroundColor(.blue)
            Text("Try a Gesture").font(.title2).bold()

            if !isEngineRunning {
                Text("Click below to start the engine, then show the camera a 👍 (thumbs up).")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Button("Start Engine") { onStartEngine() }
                    .buttonStyle(.borderedProminent)
            } else if let seen = model.demoGestureSeen {
                Image(systemName: "checkmark.circle.fill")
                    .resizable().scaledToFit().frame(width: 60, height: 60)
                    .foregroundColor(.green)
                Text("Got it: \(seen)")
                    .font(.title3)
                Text("That's all there is to it — the gesture is mapped to its action via your config.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Button("Continue") { model.advance() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            } else {
                ZStack {
                    Color.black
                    if let img = preview.image {
                        Image(nsImage: img)
                            .resizable().aspectRatio(contentMode: .fit)
                            .scaleEffect(x: -1, y: 1)
                    } else {
                        Text("Waiting for engine frames…").foregroundColor(.gray)
                    }
                }
                .frame(minHeight: 200)
                .cornerRadius(6)
                Text("Show the camera any gesture (👍 ✌️ ✊ 🖐️ 👌). I'll catch the first one you make.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Button("Skip") { model.advance() }
            }
        }
        .onAppear { preview.activate() }
        .onDisappear { preview.deactivate() }
    }

    private var doneStep: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .resizable().scaledToFit().frame(width: 60, height: 60)
                .foregroundColor(.blue)
            Text("You're all set!").font(.title).bold()
            Text("Find Gesture in the menu bar. Open Settings to remap, browse presets, record motions, or run the self-test. Have fun!")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Done") { onComplete() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
    }
}
