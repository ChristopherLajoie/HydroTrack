import SwiftUI
import SwiftData

struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Today", systemImage: "drop.fill")
                }
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "chart.bar.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: WaterEntry.self, inMemory: true)
}
