import SwiftUI

struct SelfTestWindow: View {
    @EnvironmentObject var selfTest: SelfTestModel
    @EnvironmentObject var preview: PreviewModel
    let availableGestures: [String]
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            switch selfTest.state {
            case .idle:
                idleScreen
            case .running:
                runningScreen
            case .complete:
                summaryScreen
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 420)
        .onAppear {
            preview.activate()
        }
        .onDisappear {
            preview.deactivate()
            selfTest.reset()
        }
    }

    private var idleScreen: some View {
        VStack(spacing: 14) {
            Text("Self Test")
                .font(.title)
                .bold()
            Text("Walk through every gesture you've configured. The test passes a gesture once it's recognized; click Skip if you can't get it to fire.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Text("\(availableGestures.count) gestures will be tested")
                .font(.caption)
            HStack {
                Button("Cancel") { onClose() }
                Button("Start") {
                    selfTest.start(gestures: availableGestures)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var runningScreen: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Test \(selfTest.currentIndex + 1) of \(selfTest.gesturesToTest.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                ProgressView(value: Double(selfTest.currentIndex), total: Double(selfTest.gesturesToTest.count))
                    .frame(width: 140)
            }

            Text("Make this gesture:")
                .font(.callout)
                .foregroundColor(.secondary)
            Text(selfTest.current ?? "—")
                .font(.system(size: 36, weight: .bold, design: .rounded))

            ZStack {
                Color.black
                if let img = preview.image {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(x: -1, y: 1)
                } else {
                    Text("Waiting for camera frames…")
                        .foregroundColor(.gray)
                }
            }
            .frame(minHeight: 220)
            .cornerRadius(6)

            HStack {
                Button("Skip") { selfTest.skip() }
                Spacer()
                Button("Cancel") {
                    selfTest.reset()
                    onClose()
                }
            }
        }
    }

    private var summaryScreen: some View {
        VStack(spacing: 14) {
            Text("Test Complete")
                .font(.title)
                .bold()
            HStack(spacing: 16) {
                Label("\(selfTest.passedCount) passed", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Label("\(selfTest.failedCount) skipped", systemImage: "xmark.circle.fill")
                    .foregroundColor(.orange)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(selfTest.gesturesToTest, id: \.self) { name in
                        HStack {
                            Image(systemName: selfTest.results[name] == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(selfTest.results[name] == true ? .green : .orange)
                            Text(name).font(.system(.body, design: .monospaced))
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Button("Run Again") {
                    selfTest.start(gestures: availableGestures)
                }
                Spacer()
                Button("Done") { onClose() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
