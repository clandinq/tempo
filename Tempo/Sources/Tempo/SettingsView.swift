import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)

            Divider()

            VStack(spacing: 0) {
                reminderRow(
                    icon: "cup.and.saucer",
                    title: "Break reminder",
                    detail: "Notify after this many minutes of continuous tracking",
                    value: $settings.breakReminderMinutes,
                    range: 1...240
                )

                Divider().padding(.leading, 56)

                reminderRow(
                    icon: "arrow.clockwise",
                    title: "Resume reminder",
                    detail: "Notify after this many minutes of being stopped",
                    value: $settings.resumeReminderMinutes,
                    range: 1...120
                )
            }
            .padding(.vertical, 8)

            Divider()

            // Footer note
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("Changes take effect on the next tracking session.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 380, maxWidth: .infinity)
    }

    // MARK: Row

    @ViewBuilder
    private func reminderRow(
        icon: String,
        title: String,
        detail: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                Text(detail)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Stepper with explicit text field so the user can also type a value
            HStack(spacing: 4) {
                TextField("", value: value, formatter: minuteFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 52)
                    .multilineTextAlignment(.trailing)
                Stepper("", value: value, in: range)
                    .labelsHidden()
                Text("min")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var minuteFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .none
        f.minimum = 1
        f.maximum = 240
        return f
    }
}
