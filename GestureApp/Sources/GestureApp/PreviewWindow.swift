import SwiftUI

struct PreviewWindow: View {
    @EnvironmentObject var preview: PreviewModel

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Color.black
                if let img = preview.image {
                    Image(nsImage: img)
                        .resizable()
                        .interpolation(.low)
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(x: -1, y: 1) // mirror like a selfie
                } else {
                    VStack(spacing: 6) {
                        ProgressView()
                        Text("Waiting for engine frames…")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(minWidth: 480, minHeight: 360)
            .cornerRadius(6)

            HStack {
                Circle()
                    .fill(preview.isActive ? .green : .gray)
                    .frame(width: 8, height: 8)
                Text(preview.isActive ? "Streaming" : "Inactive")
                    .font(.caption)
                Spacer()
                Text("Close window to stop the stream.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !preview.fingerStates.isEmpty {
                HStack(spacing: 4) {
                    Text("Live fingers:").font(.caption2).foregroundColor(.secondary)
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(preview.fingerStates[i] == 1 ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 14, height: 14)
                            .overlay(
                                Text(["T", "I", "M", "R", "P"][i])
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                    }
                    Text("[\(preview.fingerStates.map(String.init).joined(separator: ","))]")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .frame(minWidth: 504, minHeight: 400)
        .onAppear {
            preview.activate()
        }
        .onDisappear {
            preview.deactivate()
        }
    }
}
