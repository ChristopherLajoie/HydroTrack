import SwiftUI
import SwiftData
import ConfettiSwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [WaterEntry]
    
    // State for celebration
    @State private var confettiCounter = 0
    @State private var previousProgress: Double = 0
    
    // State for custom amount
    @State private var showCustomInput = false
    @State private var customAmount = ""
    
    // Hardcoded goal for now
    private let dailyGoalML = 2000
    
    // Calculate today's total
    private var todayTotal: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let todayEntries = allEntries.filter { entry in
            Calendar.current.isDate(entry.timestamp, inSameDayAs: today)
        }
        return todayEntries.reduce(0) { $0 + $1.amountML }
    }
    
    // Calculate progress (0.0 to 1.0)
    private var progress: Double {
        let ratio = Double(todayTotal) / Double(dailyGoalML)
        return min(ratio, 1.0)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Progress Circle
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(lineWidth: 20)
                        .foregroundStyle(.gray.opacity(0.2))
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .foregroundStyle(progress >= 1.0 ? .green : .blue)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: progress)
                    
                    // Center text
                    VStack(spacing: 8) {
                        Text("\(todayTotal)")
                            .font(.system(size: 48, weight: .bold))
                            .contentTransition(.numericText())
                        Text("/ \(dailyGoalML) mL")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("\(Int(progress * 100))%")
                            .font(.headline)
                            .foregroundStyle(progress >= 1.0 ? .green : .blue)
                    }
                    
                    // Goal reached badge
                    if progress >= 1.0 {
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
                .padding(.top, 40)
                
                // Quick add buttons
                VStack(spacing: 16) {
                    Text("Quick Add")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 20) {
                        QuickAddButton(amount: 100, action: addWater)
                        QuickAddButton(amount: 250, action: addWater)
                        QuickAddButton(amount: 500, action: addWater)
                    }
                    
                    // Custom amount button
                    Button(action: {
                        showCustomInput = true
                    }) {
                        HStack {
                            Image(systemName: "pencil.circle.fill")
                            Text("Custom Amount")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.gray.opacity(0.1))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Today")
            .overlay(
                // Celebration overlay
                Group {
                    if progress >= 1.0 {
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
            .sheet(isPresented: $showCustomInput) {
                CustomAmountSheet(addWater: addWater, isPresented: $showCustomInput)
            }


        }
    }

    
    // Function to add water entry with haptics & celebration
    private func addWater(amount: Int) {
        let oldProgress = progress
        
        // Add entry
        let entry = WaterEntry(timestamp: Date(), amountML: amount)
        modelContext.insert(entry)
        
        // Light haptic feedback for button tap
        HapticManager.shared.impact(style: .light)
        
        // Check if goal was just reached
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if oldProgress < 1.0 && progress >= 1.0 {
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

// Custom amount input sheet
struct CustomAmountSheet: View {
    let addWater: (Int) -> Void
    @Binding var isPresented: Bool
    
    @State private var amountText = ""
    @FocusState private var isFocused: Bool
    
    private var amount: Int {
        Int(amountText) ?? 0
    }
    
    private var isValid: Bool {
        amount > 0 && amount <= 5000
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Water drop icon
                Image(systemName: "drop.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
                    .padding(.top, 40)
                
                // Input field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter Amount")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        TextField("0", text: $amountText)
                            .keyboardType(.numberPad)
                            .font(.system(size: 48, weight: .bold))
                            .multilineTextAlignment(.center)
                            .focused($isFocused)
                        
                        Text("mL")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                
                // Quick suggestions
                HStack(spacing: 12) {
                    ForEach([100, 250, 330, 500], id: \.self) { suggested in
                        Button(action: {
                            amountText = "\(suggested)"
                            HapticManager.shared.impact(style: .soft)
                        }) {
                            Text("\(suggested)")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer()
                
                // Add button
                Button(action: {
                    if isValid {
                        addWater(amount)
                        isPresented = false
                        HapticManager.shared.impact(style: .medium)
                    }
                }) {
                    Text("Add Water")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValid ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!isValid)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("Custom Amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WaterEntry.self, inMemory: true)
}
