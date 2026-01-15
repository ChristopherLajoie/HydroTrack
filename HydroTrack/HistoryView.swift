import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 60))
                    .foregroundStyle(.gray)
                
                Text("History Coming Soon")
                    .font(.title2.bold())
                
                Text("We'll build this in Phase 3")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("History")
        }
    }
}

#Preview {
    HistoryView()
}
