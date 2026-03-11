import SwiftUI
import Charts

// MARK: - Period

enum Period: String, CaseIterable, Identifiable {
    case today   = "Today"
    case week    = "This Week"
    case month   = "This Month"

    var id: String { rawValue }
}

// MARK: - ProjectStat

struct ProjectStat: Identifiable {
    let id: UUID
    let name: String
    let color: ProjectColor
    let seconds: TimeInterval

    var hours: Double { seconds / 3600 }
}

// MARK: - InsightsView

struct InsightsView: View {
    @EnvironmentObject var store: TimeStore
    @State private var period: Period = .today

    var stats: [ProjectStat] {
        let range: DateInterval
        switch period {
        case .today:  range = store.todayRange()
        case .week:   range = store.weekRange()
        case .month:  range = store.monthRange()
        }
        return store.projects.map { project in
            ProjectStat(
                id: project.id,
                name: project.name,
                color: project.color,
                seconds: store.totalTime(for: project.id, in: range)
            )
        }
        .filter { $0.seconds > 0 }
        .sorted { $0.seconds > $1.seconds }
    }

    var totalSeconds: TimeInterval { stats.reduce(0) { $0 + $1.seconds } }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Insights")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    HStack(spacing: 4) {
                        Text(Formatters.shortDuration(totalSeconds))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("total")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Picker("Period", selection: $period) {
                    ForEach(Period.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if stats.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        barChartSection
                        tableSection
                    }
                    .padding(24)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 460)
    }

    // MARK: Sub-views

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No time tracked for this period")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Text("Start a project from the menu bar to begin.")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var barChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time per Project")
                .font(.system(size: 15, weight: .semibold, design: .rounded))

            Chart(stats) { stat in
                BarMark(
                    x: .value("Hours", stat.hours),
                    y: .value("Project", stat.name)
                )
                // Each bar uses the project's own chosen color
                .foregroundStyle(stat.color.color)
                .cornerRadius(5)
                .annotation(position: .trailing, alignment: .leading) {
                    Text(Formatters.shortDuration(stat.seconds))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    if let h = value.as(Double.self) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            Text(h == 1 ? "1h" : String(format: "%.0fh", h))
                                .font(.system(size: 10, design: .rounded))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let name = value.as(String.self) {
                            Text(name)
                                .font(.system(size: 12, design: .rounded))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .chartLegend(.hidden)
            .frame(height: max(60, CGFloat(stats.count) * 44 + 16))
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
    }

    private var tableSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Breakdown")
                .font(.system(size: 15, weight: .semibold, design: .rounded))

            VStack(spacing: 0) {
                HStack {
                    Text("Project")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Duration")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("Share")
                        .frame(width: 60, alignment: .trailing)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                ForEach(Array(stats.enumerated()), id: \.element.id) { idx, stat in
                    HStack {
                        Circle()
                            .fill(stat.color.color)
                            .frame(width: 8, height: 8)
                        Text(stat.name)
                            .font(.system(size: 13, design: .rounded))
                        Spacer()
                        Text(Formatters.shortDuration(stat.seconds))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                        Text(shareLabel(stat))
                            .frame(width: 60, alignment: .trailing)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(idx % 2 == 0 ? Color.clear : Color(NSColor.alternatingContentBackgroundColors[1]))

                    if idx < stats.count - 1 { Divider() }
                }
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
        }
    }

    // MARK: Helpers

    private func shareLabel(_ stat: ProjectStat) -> String {
        guard totalSeconds > 0 else { return "0%" }
        let pct = (stat.seconds / totalSeconds) * 100
        return String(format: "%.0f%%", pct)
    }
}
