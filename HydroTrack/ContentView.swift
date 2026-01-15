import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [WaterEntry]
    
    // State for celebration
    @State private var confettiCounter = 0
    @State private var previousProgress: Double = 0
    
    // State for custom amount
    @State private var customAmount = ""
    @FocusState private var isCustomFieldFocused: Bool
    
    // State for reset confirmation
    @State private var showResetAlert = false
    
    // Dynamic goal from AppStorage
    @AppStorage("dailyGoalML") private var dailyGoalML = 2000
    
    // Calculate today's total
    private var todayTotal: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let todayEntries = allEntries.filter { entry in
            Calendar.current.isDate(entry.timestamp, inSameDayAs: today)
        }
        return todayEntries.reduce(0) { $0 + $1.amountML }
    }
    
    // Calculate progress for visual circle (capped at 1.0)
    private var circleProgress: Double {
        let ratio = Double(todayTotal) / Double(dailyGoalML)
        return min(ratio, 1.0)
    }
    
    // Calculate actual percentage (can go above 100%)
    private var percentageValue: Int {
        let ratio = Double(todayTotal) / Double(dailyGoalML)
        return Int(ratio * 100)
    }
    
    private var customAmountValue: Int {
        Int(customAmount) ?? 0
    }
    
    private var isCustomAmountValid: Bool {
        customAmountValue > 0 && customAmountValue <= 5000
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Progress Circle
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(lineWidth: 20)
                            .foregroundStyle(.gray.opacity(0.2))
                        
                        // Progress circle
                        Circle()
                            .trim(from: 0, to: circleProgress)
                            .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round))
                            .foregroundStyle(circleProgress >= 1.0 ? .green : .blue)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: circleProgress)
                        
                        // Center text
                        VStack(spacing: 8) {
                            Text("\(todayTotal)")
                                .font(.system(size: 48, weight: .bold))
                                .contentTransition(.numericText())
                            Text("/ \(dailyGoalML) mL")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Text("\(percentageValue)%")
                                .font(.headline)
                                .foregroundStyle(circleProgress >= 1.0 ? .green : .blue)
                        }
                        
                        // Goal reached badge
                        if circleProgress >= 1.0 {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.title)
                                        .foregroundStyle(.green)
                                        .offset(x: 10, y: 10)
                                }
                            }
                        }
                    }
                    .frame(width: 250, height: 250)
                    .padding(.top, 20)
                    
                    // Quick add buttons (no label)
                    HStack(spacing: 20) {
                        QuickAddButton(amount: 100, action: addWater)
                        QuickAddButton(amount: 250, action: addWater)
                        QuickAddButton(amount: 500, action: addWater)
                    }
                    .padding(.horizontal)
                    .padding(.top, 40)
                    
                    // Custom amount input (inline)
                    HStack(spacing: 12) {
                        HStack {
                            TextField("Custom amount", text: $customAmount)
                                .keyboardType(.numberPad)
                                .font(.title3)
                                .multilineTextAlignment(.center)
                                .focused($isCustomFieldFocused)
                            
                            Text("mL")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Button(action: {
                            if isCustomAmountValid {
                                addWater(amount: customAmountValue)
                                customAmount = ""
                                isCustomFieldFocused = false
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(isCustomAmountValid ? .blue : .gray.opacity(0.5))
                        }
                        .disabled(!isCustomAmountValid)
                    }
                    .padding(.horizontal)
                    
                    // Reset button
                    Button(action: {
                        showResetAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red.opacity(0.1))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    Spacer()
                }
            }
            .dismissKeyboardOnTap()
            .navigationTitle("Today")
            .overlay(
                // Celebration overlay
                Group {
                    if circleProgress >= 1.0 {
                        ZStack {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                            
                            VStack(spacing: 20) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 100))
                                    .foregroundStyle(.green)
                                    .scaleEffect(confettiCounter > 0 ? 1.0 : 0.5)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: confettiCounter)
                                
                                Text("Goal Reached! 🎉")
                                    .font(.title.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        .opacity(confettiCounter > 0 && confettiCounter < 2 ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.3), value: confettiCounter)
                    }
                }
            )
            .alert("Reset Today's Data?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetTodayData()
                }
            } message: {
                Text("This will delete all water entries for today. This action cannot be undone.")
            }
        }
    }
    
    // Function to add water entry with haptics & celebration
    private func addWater(amount: Int) {
        let oldProgress = circleProgress
        
        // Add entry
        let entry = WaterEntry(timestamp: Date(), amountML: amount)
        modelContext.insert(entry)
        
        // Light haptic feedback for button tap
        HapticManager.shared.impact(style: .light)
        
        // Check if goal was just reached
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if oldProgress < 1.0 && circleProgress >= 1.0 {
                // Goal reached! Success haptic + celebration
                HapticManager.shared.notification(type: .success)
                confettiCounter = 1
                
                // Auto-dismiss after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    confettiCounter = 2
                }
            }
        }
    }
    
    // Function to reset today's data
    private func resetTodayData() {
        let today = Calendar.current.startOfDay(for: Date())
        let todayEntries = allEntries.filter { entry in
            Calendar.current.isDate(entry.timestamp, inSameDayAs: today)
        }
        
        for entry in todayEntries {
            modelContext.delete(entry)
        }
        
        // Reset celebration counter
        confettiCounter = 0
        
        HapticManager.shared.impact(style: .medium)
    }
}

// Reusable button component
struct QuickAddButton: View {
    let amount: Int
    let action: (Int) -> Void
    
    var body: some View {
        Button(action: { action(amount) }) {
            VStack(spacing: 8) {
                Image(systemName: "drop.fill")
                    .font(.title2)
                Text("+\(amount)")
                    .font(.headline)
                Text("mL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(.blue.opacity(0.1))
            .foregroundStyle(.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WaterEntry.self, inMemory: true)
}
