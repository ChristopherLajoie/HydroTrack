import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WaterEntry.timestamp, order: .reverse) private var allEntries: [WaterEntry]
    @AppStorage("dailyGoalML") private var dailyGoalML = 2000
    @AppStorage("trainingDayGoalML") private var trainingDayGoalML = 3000
    @AppStorage("isTrainingDay") private var isTrainingDay = false  // For today's status
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
                        dailyGoal: dailyGoalML,
                        trainingDayGoal: trainingDayGoalML
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
                        ForEach(Array(daysInMonth.enumerated()), id: \.offset) { index, date in
                            if let date = date {
                                DayCell(
                                    date: date,
                                    total: totalForDate(date),
                                    goal: goalForDate(date),
                                    isTrainingDay: isTrainingDayForDate(date),
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
                            goal: goalForDate(selected),
                            isTrainingDay: isTrainingDayForDate(selected),
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
        guard let newMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) else { return }
        selectedMonth = newMonth
        
        // If navigating back to current month, auto-select today
        if calendar.isDate(newMonth, equalTo: Date(), toGranularity: .month) {
            withAnimation {
                selectedDate = calendar.startOfDay(for: Date())
            }
        } else {
            selectedDate = nil
        }
    }
    
    private func nextMonth() {
        guard !isCurrentMonth else { return }
        guard let newMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) else { return }
        selectedMonth = newMonth
        
        // If navigating back to current month, auto-select today
        if calendar.isDate(newMonth, equalTo: Date(), toGranularity: .month) {
            withAnimation {
                selectedDate = calendar.startOfDay(for: Date())
            }
        } else {
            selectedDate = nil
        }
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
    
    // Determine if a specific date was a training day
    private func isTrainingDayForDate(_ date: Date) -> Bool {
        // For today: use AppStorage value even if no entries
        if calendar.isDateInToday(date) {
            return isTrainingDay
        }
        
        // For past days: check entries
        let dayEntries = entriesForDate(date)
        return dayEntries.contains { $0.isTrainingDay }
    }
    
    // Get the correct goal for a specific date
    private func goalForDate(_ date: Date) -> Int {
        isTrainingDayForDate(date) ? trainingDayGoalML : dailyGoalML
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
    let isTrainingDay: Bool
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
    
    private var textColor: Color {
        if isToday {
            return .white
        } else if total == 0 {
            return .secondary  // Grey for no entries
        } else if progress >= 1.0 {
            return .green  // Green for goal reached
        } else {
            return .primary  // White/primary for entries but goal not reached
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Day number - fixed position
            Text(dayNumber)
                .font(.body)  // Regular font, not bold
                .foregroundStyle(textColor)
                .frame(height: 24)
            
            // Training day indicator - fixed position below number
            Group {
                if isTrainingDay {
                    Image(systemName: "figure.run")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                } else {
                    Color.clear
                }
            }
            .frame(height: 12)
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
    let dailyGoal: Int
    let trainingDayGoal: Int
    
    private var averagePercentage: Int {
        guard !entries.isEmpty else { return 0 }
        
        // Group entries by day with training day status
        let calendar = Calendar.current
        var dailyData: [Date: (total: Int, isTrainingDay: Bool)] = [:]
        
        for entry in entries {
            let day = calendar.startOfDay(for: entry.timestamp)
            let existing = dailyData[day] ?? (total: 0, isTrainingDay: false)
            dailyData[day] = (
                total: existing.total + entry.amountML,
                isTrainingDay: existing.isTrainingDay || entry.isTrainingDay
            )
        }
        
        guard !dailyData.isEmpty else { return 0 }
        
        // Calculate average consumption and average goal
        var totalConsumption = 0
        var totalGoal = 0
        
        for (_, data) in dailyData {
            totalConsumption += data.total
            totalGoal += data.isTrainingDay ? trainingDayGoal : dailyGoal
        }
        
        let avgConsumption = totalConsumption / dailyData.count
        let avgGoal = totalGoal / dailyData.count
        
        return avgGoal > 0 ? Int((Double(avgConsumption) / Double(avgGoal)) * 100) : 0
    }
    
    private var currentStreak: Int {
        let calendar = Calendar.current
        var dailyData: [Date: (total: Int, isTrainingDay: Bool)] = [:]
        
        // Group by day with training status
        for entry in entries {
            let day = calendar.startOfDay(for: entry.timestamp)
            let existing = dailyData[day] ?? (total: 0, isTrainingDay: false)
            dailyData[day] = (
                total: existing.total + entry.amountML,
                isTrainingDay: existing.isTrainingDay || entry.isTrainingDay
            )
        }
        
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        while true {
            if let dayData = dailyData[currentDate] {
                let goal = dayData.isTrainingDay ? trainingDayGoal : dailyGoal
                if dayData.total >= goal {
                    streak += 1
                    guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
                    currentDate = previousDay
                } else {
                    break
                }
            } else {
                break
            }
        }
        
        return streak
    }
    
    var body: some View {
        HStack(spacing: 30) {
            StatBox(title: "Avg/Day", value: "\(averagePercentage)%", icon: "chart.line.uptrend.xyaxis", color: .blue)
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
    let isTrainingDay: Bool
    let containers: [Container]
    let onDelete: (WaterEntry) -> Void

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private var total: Int {
        entries.reduce(0) { $0 + $1.amountML }
    }

    private var progress: Double {
        Double(total) / Double(goal)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with date and training indicator
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateString)
                        .font(.headline)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Training day indicator moved to top right
                if isTrainingDay {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.run")
                            .font(.caption)
                        Text("Training Day")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .clipShape(Capsule())
                }
            }
            .padding()

            Divider()

            if entries.isEmpty {
                Text("No entries for this day")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                List {
                    ForEach(entries.sorted { $0.timestamp > $1.timestamp }) { entry in
                        HStack(spacing: 12) {
                            // Time in 24-hour format
                            Text(timeString(entry.timestamp))
                                .font(.subheadline)
                                .frame(width: 50, alignment: .leading)

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
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                onDelete(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: CGFloat(entries.count) * 56)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"  // 24-hour format
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
