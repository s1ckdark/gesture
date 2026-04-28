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
