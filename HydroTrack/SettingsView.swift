import SwiftUI

struct SettingsView: View {
    @AppStorage("dailyGoalML") private var dailyGoalML = 2000
    @AppStorage("notifStartHour") private var notifStartHour = 9
    @AppStorage("notifEndHour") private var notifEndHour = 21
    @AppStorage("notifIntervalHours") private var notifIntervalHours = 2
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    
    @FocusState private var isGoalFieldFocused: Bool
    @State private var showPermissionDeniedAlert = false
    
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
                        Task {
                            await handleNotificationToggle(enabled: newValue)
                        }
                    }
                    
                    if notificationsEnabled {
                        Picker("Start Time", selection: $notifStartHour) {
                            ForEach(6..<24) { hour in
                                Text(hourString(hour)).tag(hour)
                            }
                        }
                        
                        Picker("End Time", selection: $notifEndHour) {
                            ForEach(6..<24) { hour in
                                Text(hourString(hour)).tag(hour)
                            }
                        }
                        
                        Picker("Remind Every", selection: $notifIntervalHours) {
                            Text("1 hour").tag(1)
                            Text("2 hours").tag(2)
                            Text("3 hours").tag(3)
                            Text("4 hours").tag(4)
                        }
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    if notificationsEnabled {
                        Text("Changes are saved automatically")
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
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 8)
            }
            .dismissKeyboardOnTap()
            .alert("Notifications Disabled", isPresented: $showPermissionDeniedAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {
                    notificationsEnabled = false
                }
            } message: {
                Text("Please enable notifications in Settings to receive water reminders.")
            }
            .onDisappear {
                if notificationsEnabled {
                    Task {
                        await NotificationManager.shared.scheduleWaterReminders(
                            startHour: notifStartHour,
                            endHour: notifEndHour,
                            intervalHours: notifIntervalHours
                        )
                    }
                }
            }
        }
    }
    
    private func hourString(_ hour: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour):00 \(period)"
    }
    
    private func handleNotificationToggle(enabled: Bool) async {
        if enabled {
            let granted = await NotificationManager.shared.requestAuthorization()
            
            if granted {
                await NotificationManager.shared.scheduleWaterReminders(
                    startHour: notifStartHour,
                    endHour: notifEndHour,
                    intervalHours: notifIntervalHours
                )
                HapticManager.shared.notification(type: .success)
            } else {
                await MainActor.run {
                    notificationsEnabled = false
                    showPermissionDeniedAlert = true
                }
                HapticManager.shared.notification(type: .error)
            }
        } else {
            NotificationManager.shared.cancelAllNotifications()
            HapticManager.shared.impact(style: .light)
        }
    }
}

#Preview {
    SettingsView()
}
