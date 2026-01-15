import SwiftUI

struct SettingsView: View {
    // AppStorage automatically persists to UserDefaults
    @AppStorage("dailyGoalML") private var dailyGoalML = 2000
    @AppStorage("notifStartHour") private var notifStartHour = 9
    @AppStorage("notifEndHour") private var notifEndHour = 21
    @AppStorage("notifIntervalHours") private var notifIntervalHours = 2
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    
    // Focus state for keyboard dismissal
    @FocusState private var isGoalFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                // Daily Goal Section
                Section {
                    HStack {
                        TextField("Goal", value: $dailyGoalML, format: .number)
                            .keyboardType(.numberPad)
                            .font(.title2.bold())
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: 100)
                            .focused($isGoalFieldFocused)
                        
                        Text("mL")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Image(systemName: "target")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Hydration Goal")
                } footer: {
                    Text("Recommended: 2000-3000 mL per day for most adults")
                }
                
                // Notifications Section
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(.orange)
                            Text("Enable Reminders")
                        }
                    }
                    .onChange(of: notificationsEnabled) { oldValue, newValue in
                        if newValue {
                            // Request permission and schedule (Phase 4)
                            HapticManager.shared.impact(style: .medium)
                        } else {
                            // Cancel all notifications (Phase 4)
                            HapticManager.shared.impact(style: .light)
                        }
                    }
                    
                    if notificationsEnabled {
                        // Start time picker
                        Picker("Start Time", selection: $notifStartHour) {
                            ForEach(6..<24) { hour in
                                Text("\(formatHour(hour))")
                                    .tag(hour)
                            }
                        }
                        
                        // End time picker
                        Picker("End Time", selection: $notifEndHour) {
                            ForEach(6..<24) { hour in
                                Text("\(formatHour(hour))")
                                    .tag(hour)
                            }
                        }
                        
                        // Interval picker
                        Picker("Remind Every", selection: $notifIntervalHours) {
                            Text("1 hour").tag(1)
                            Text("2 hours").tag(2)
                            Text("3 hours").tag(3)
                            Text("4 hours").tag(4)
                        }
                        
                        // Preview of notification times
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You'll receive reminders at:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(notificationTimesPreview())
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    if notificationsEnabled {
                        Text("Notifications will remind you to drink water during your active hours")
                    }
                }
                
                // App Info Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("2026.01")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .dismissKeyboardOnTap()
        }
    }
    
    // Helper function to format hours
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:00 a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
    
    // Generate preview of notification times
    private func notificationTimesPreview() -> String {
        var times: [String] = []
        var currentHour = notifStartHour
        
        while currentHour <= notifEndHour {
            times.append(formatHour(currentHour))
            currentHour += notifIntervalHours
        }
        
        return times.joined(separator: ", ")
    }
}

#Preview {
    SettingsView()
}
