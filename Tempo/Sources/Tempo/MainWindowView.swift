import SwiftUI

enum AppTab: String, CaseIterable {
    case insights = "insights"
    case history  = "history"
    case settings = "settings"

    var label: String {
        switch self {
        case .insights: return "Insights"
        case .history:  return "History"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .insights: return "chart.bar.fill"
        case .history:  return "clock.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

final class WindowState: ObservableObject {
    @Published var selectedTab: AppTab = .history
}

struct MainWindowView: View {
    @EnvironmentObject var store: TimeStore
    @EnvironmentObject var windowState: WindowState

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 680, minHeight: 480)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                tabButton(tab)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private func tabButton(_ tab: AppTab) -> some View {
        let isActive = windowState.selectedTab == tab
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                windowState.selectedTab = tab
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                Text(tab.label)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular, design: .rounded))
            }
            .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch windowState.selectedTab {
        case .insights: InsightsView().environmentObject(store)
        case .history:  HistoryView().environmentObject(store)
        case .settings: SettingsView(settings: store.settings).environmentObject(store)
        }
    }
}
