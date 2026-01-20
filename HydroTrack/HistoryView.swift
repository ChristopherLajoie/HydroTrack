import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WaterEntry.timestamp, order: .reverse) private var allEntries: [WaterEntry]
    @AppStorage("dailyGoalML") private var dailyGoalML = 2000
    @AppStorage("containers") private var containersJSON = Container.defaults.toJSON()
    
    @State private var selectedMonth = Date()
    @State private var selectedDate: Date? = Calendar.current.startOfDay(for: Date())
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    private var containers: [Container] {
        Array<Container>.fromJSON(containersJSON)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Monthly stats at top
                    MonthStatsView(
                        entries: entriesForMonth(selectedMonth),
                        goal: dailyGoalML
                    )
                    .padding(.horizontal)
                    .padding(.top, 30)
                    .padding(.bottom, 20)
                    
                    // Month selector
                    HStack {
                        Button(action: previousMonth) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundStyle(.blue)
                        }
                        
                        Spacer()
                        
                        Text(monthYearString(selectedMonth))
                            .font(.title2.bold())
                        
                        Spacer()
                        
                        Button(action: nextMonth) {
                            Image(systemName: "chevron.right")
                                .font(.title3)
                                .foregroundStyle(.blue)
                        }
                        .disabled(isCurrentMonth)
                    }
                    .padding(.horizontal)
                    
                    // Days of week header
                    HStack(spacing: 0) {
                        ForEach(daysOfWeek, id: \.self) { day in
                            Text(day)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Calendar grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                        ForEach(daysInMonth, id: \.self) { date in
                            if let date = date {
                                DayCell(
                                    date: date,
                                    total: totalForDate(date),
                                    goal: dailyGoalML,
                                    isToday: calendar.isDateInToday(date),
                                    isSelected: selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!)
                                )
                                .onTapGesture {
                                    withAnimation {
                                        if let selected = selectedDate, calendar.isDate(date, inSameDayAs: selected) {
                                            // Clicking same day - close it
                                            selectedDate = nil
                                        } else {
                                            // Clicking different day - open it
                                            selectedDate = date
                                        }
                                    }
                                }
                            } else {
                                Color.clear
                                    .frame(height: 60)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Selected day detail
                    if let selected = selectedDate {
                        DayDetailView(
                            date: selected,
                            entries: entriesForDate(selected),
                            goal: dailyGoalML,
                            containers: containers,
                            onDelete: deleteEntry
                        )
                        .padding(.horizontal)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                    
                    Spacer(minLength: 50)
                }
            }
            .scrollIndicators(.hidden)
        }
    }
    
    // MARK: - Calendar Logic
    
    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }
        
        let monthLastDay = calendar.date(byAdding: DateComponents(day: -1), to: monthInterval.end)!
        
        var days: [Date?] = []
        var currentDate = monthFirstWeek.start
        
        while currentDate <= monthLastDay {
            if calendar.isDate(currentDate, equalTo: selectedMonth, toGranularity: .month) {
                days.append(currentDate)
            } else if days.isEmpty || days.last != nil {
                days.append(nil)
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // Fill remaining cells to complete the grid
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    private var isCurrentMonth: Bool {
        calendar.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }
    
    private func previousMonth() {
        selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
        selectedDate = nil
    }
    
    private func nextMonth() {
        guard !isCurrentMonth else { return }
        selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
        selectedDate = nil
    }
    
    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    // MARK: - Data Logic
    
    private func totalForDate(_ date: Date) -> Int {
        entriesForDate(date).reduce(0) { $0 + $1.amountML }
    }
    
    private func entriesForDate(_ date: Date) -> [WaterEntry] {
        allEntries.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
    }
    
    private func entriesForMonth(_ date: Date) -> [WaterEntry] {
        allEntries.filter { calendar.isDate($0.timestamp, equalTo: date, toGranularity: .month) }
    }
    
    private func deleteEntry(_ entry: WaterEntry) {
        withAnimation {
            modelContext.delete(entry)
            HapticManager.shared.impact(style: .medium)
        }
    }
}

// MARK: - Day Cell
struct DayCell: View {
    let date: Date
    let total: Int
    let goal: Int
    let isToday: Bool
    let isSelected: Bool
    
    private var progress: Double {
        min(Double(total) / Double(goal), 1.0)
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Text(dayNumber)
                .font(.headline)
                .foregroundStyle(isToday ? .white : (total > 0 ? .primary : .secondary))
            
            if total > 0 {
                Circle()
                    .fill(progress >= 1.0 ? Color.green : Color.blue)
                    .frame(width: 8, height: 8)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isToday ? Color.blue : (isSelected ? Color.blue.opacity(0.2) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Month Stats View
struct MonthStatsView: View {
    let entries: [WaterEntry]
    let goal: Int
    
    private var averageML: Int {
        guard !entries.isEmpty else { return 0 }
        let days = Set(entries.map { Calendar.current.startOfDay(for: $0.timestamp) }).count
        let totalML = entries.reduce(0) { $0 + $1.amountML }
        return days > 0 ? totalML / days : 0
    }
    
    private var currentStreak: Int {
        let calendar = Calendar.current
        var dailyTotals: [Date: Int] = [:]
        
        for entry in entries {
            let day = calendar.startOfDay(for: entry.timestamp)
            dailyTotals[day, default: 0] += entry.amountML
        }
        
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        while true {
            if let total = dailyTotals[currentDate], total >= goal {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
                currentDate = previousDay
            } else {
                break
            }
        }
        
        return streak
    }
    
    var body: some View {
        HStack(spacing: 30) {
            StatBox(title: "Avg/Day", value: "\(averageML) mL", icon: "chart.line.uptrend.xyaxis", color: .blue)
            StatBox(title: "Streak", value: "\(currentStreak) days", icon: "flame.fill", color: .orange)
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.headline)
            
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Day Detail View
struct DayDetailView: View {
    let date: Date
    let entries: [WaterEntry]
    let goal: Int
    let containers: [Container]
    let onDelete: (WaterEntry) -> Void

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }

    private var total: Int {
        entries.reduce(0) { $0 + $1.amountML }
    }

    private var progress: Double {
        Double(total) / Double(goal)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateString)
                        .font(.headline)
                    Text("\(Int(progress * 100))%")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: progress >= 1.0 ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(progress >= 1.0 ? .green : .secondary)
            }

            Divider()

            if entries.isEmpty {
                Text("No entries for this day")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                ForEach(entries.sorted { $0.timestamp > $1.timestamp }) { entry in
                    HStack(spacing: 12) {
                        Text(timeString(entry.timestamp))
                            .font(.subheadline)
                            .frame(width: 90, alignment: .leading)

                        if let display = displayForEntry(entry) {
                            ContainerIconView(container: display.container, size: 24)

                            Text(display.text)
                                .font(.subheadline)
                        } else {
                            Text("Custom")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            onDelete(entry)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func displayForEntry(_ entry: WaterEntry) -> (container: Container, text: String)? {
        // 1) New entries (fraction logging): use containerID
        if let cid = entry.containerID,
           let container = containers.first(where: { $0.id == cid }) {

            if let n = entry.fractionNumerator, let d = entry.fractionDenominator {
                let label = (n == 1 && d == 1) ? "Full" : "\(n)/\(d)"
                return (container, "\(container.name) • \(label)")
            } else {
                // Full container but no fraction stored (still show container)
                return (container, container.name)
            }
        }

        // 2) Backward compatibility for old entries: try match by full volume
        if let container = containers.first(where: { $0.volumeML == entry.amountML }) {
            return (container, "\(container.name) • Full")
        }

        return nil
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: WaterEntry.self, inMemory: true)
}
