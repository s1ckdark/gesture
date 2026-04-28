import SwiftUI
import Charts

struct StatsWindow: View {
    @EnvironmentObject var stats: StatsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Gesture Stats").font(.title2).bold()
                Spacer()
                Text("\(stats.totalRecognized) total recognized")
                    .font(.caption).foregroundColor(.secondary)
                Button("Reset") { stats.reset() }
                    .controlSize(.small)
            }

            if stats.counts.isEmpty {
                emptyState
            } else {
                countsChart
                Divider()
                activityChart
            }
        }
        .padding(20)
        .frame(minWidth: 600, minHeight: 480)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "chart.bar")
                .resizable().scaledToFit().frame(width: 60, height: 60)
                .foregroundColor(.secondary)
            Text("No gestures recognized yet")
                .foregroundColor(.secondary)
            Text("Start the engine and make some gestures.")
                .font(.caption).foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var orderedCounts: [(name: String, count: Int)] {
        stats.counts
            .map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private var countsChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Lifetime counts").font(.subheadline).bold()
            Chart(orderedCounts, id: \.name) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Gesture", item.name)
                )
                .foregroundStyle(.blue.gradient)
                .annotation(position: .trailing) {
                    Text("\(item.count)").font(.caption2).foregroundColor(.secondary)
                }
            }
            .frame(height: max(120, CGFloat(orderedCounts.count * 28)))
        }
    }

    private var activityChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent activity (last \(stats.recentEvents.count) events)")
                .font(.subheadline).bold()
            if stats.recentEvents.isEmpty {
                Text("No activity yet this session.").font(.caption).foregroundColor(.secondary)
            } else {
                Chart(stats.recentEvents) { entry in
                    PointMark(
                        x: .value("Time", entry.time),
                        y: .value("Gesture", entry.name)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(36)
                }
                .frame(height: 200)
            }
        }
    }
}
