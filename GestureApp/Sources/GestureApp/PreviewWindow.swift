import SwiftUI

struct PreviewWindow: View {
    @EnvironmentObject var preview: PreviewModel
    @AppStorage("heatmapVisible") private var heatmapVisible = false

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
                if heatmapVisible {
                    heatmapOverlay
                        .scaleEffect(x: -1, y: 1) // match mirrored frame
                        .allowsHitTesting(false)
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
                Toggle("Heatmap", isOn: $heatmapVisible)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                if heatmapVisible {
                    Button("Reset") { preview.resetHeatmap() }
                        .controlSize(.small)
                }
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

    private var heatmapOverlay: some View {
        GeometryReader { geo in
            let cellW = geo.size.width / CGFloat(PreviewModel.heatmapCols)
            let cellH = geo.size.height / CGFloat(PreviewModel.heatmapRows)
            let maxV = max(preview.heatmapMax, 1.0)

            ForEach(0..<PreviewModel.heatmapRows, id: \.self) { row in
                ForEach(0..<PreviewModel.heatmapCols, id: \.self) { col in
                    let intensity = preview.heatmap[row][col] / maxV
                    if intensity > 0 {
                        Rectangle()
                            .fill(Color.red.opacity(0.15 + intensity * 0.45))
                            .frame(width: cellW, height: cellH)
                            .position(x: cellW * (CGFloat(col) + 0.5),
                                      y: cellH * (CGFloat(row) + 0.5))
                    }
                }
            }
        }
    }
}
