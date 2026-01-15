import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \WaterEntry.timestamp, order: .reverse) private var allEntries: [WaterEntry]
    @AppStorage("dailyGoalML") private var dailyGoalML = 2000
    
    // Group entries by day
    private var dailyData: [(date: Date, total: Int, goalMet: Bool)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: allEntries) { entry in
            calendar.startOfDay(for: entry.timestamp)
        }
        
        return grouped.map { date, entries in
            let total = entries.reduce(0) { $0 + $1.amountML }
            let goalMet = total >= dailyGoalML
            return (date: date, total: total, goalMet: goalMet)
        }
        .sorted { $0.date > $1.date }
    }
    
    // Calculate 7-day average
    private var sevenDayAverage: Int {
        let last7Days = dailyData.prefix(7)
        guard !last7Days.isEmpty else { return 0 }
        let total = last7Days.reduce(0) { $0 + $1.total }
        return total / last7Days.count
    }
    
    // Calculate current streak
    private var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        
        let sortedDays = dailyData.sorted { $0.date > $1.date }
        
        for (index, day) in sortedDays.enumerated() {
            let expectedDate = calendar.date(byAdding: .day, value: -index, to: today) ?? today
            
            if calendar.isDate(day.date, inSameDayAs: expectedDate) && day.goalMet {
                streak += 1
            } else {
                break
            }
        }
        
        return streak
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats Cards
                    HStack(spacing: 16) {
                        StatCard(
                            title: "Streak",
                            value: "\(currentStreak)",
                            unit: currentStreak == 1 ? "day" : "days",
                            icon: "flame.fill",
                            color: .orange
                        )
                        
                        StatCard(
                            title: "7-Day Avg",
                            value: "\(sevenDayAverage)",
                            unit: "mL",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .blue
                        )
                    }
                    .padding(.horizontal)
                    
                    // Daily History
                    if dailyData.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                                .padding(.top, 60)
                            
                            Text("No History Yet")
                                .font(.title2.bold())
                            
                            Text("Start tracking your water intake to see your history here")
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    } else {
                        VStack(spacing: 0) {
                            ForEach(dailyData, id: \.date) { day in
                                DayRow(
                                    date: day.date,
                                    total: day.total,
                                    goal: dailyGoalML,
                                    goalMet: day.goalMet
                                )
                                
                                if day.date != dailyData.last?.date {
                                    Divider()
                                        .padding(.leading, 70)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 28)
                .padding(.bottom, 20)
            }
        }
    }
}

// Stat Card Component
struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 32, weight: .bold))
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}

// Day Row Component
struct DayRow: View {
    let date: Date
    let total: Int
    let goal: Int
    let goalMet: Bool
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private var percentage: Int {
        guard goal > 0 else { return 0 }
        return Int((Double(total) / Double(goal)) * 100)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }
    
    private var weekdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Date circle
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.title2.bold())
                    .foregroundStyle(isToday ? .blue : .primary)
                
                Text(String(weekdayFormatter.string(from: date).prefix(3)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 50)
            
            // Progress info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(isToday ? "Today" : dateFormatter.string(from: date))
                        .font(.headline)
                    
                    Spacer()
                    
                    if goalMet {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    
                    Text("\(total) mL")
                        .font(.subheadline.bold())
                        .foregroundStyle(goalMet ? .green : .primary)
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(goalMet ? Color.green : Color.blue)
                            .frame(width: geometry.size.width * min(Double(total) / Double(max(goal, 1)), 1.0))
                    }
                }
                .frame(height: 8)
                
                Text("\(percentage)% of goal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: WaterEntry.self, inMemory: true)
}
