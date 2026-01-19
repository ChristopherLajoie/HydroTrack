import SwiftUI

struct SettingsView: View {
    @AppStorage("dailyGoalML") private var dailyGoalML = 2000
    @AppStorage("notifStartHour") private var notifStartHour = 9
    @AppStorage("notifEndHour") private var notifEndHour = 21
    @AppStorage("notifIntervalHours") private var notifIntervalHours = 2
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("containers") private var containersJSON = Container.defaults.toJSON()
    
    @FocusState private var isGoalFieldFocused: Bool
    @State private var showPermissionDeniedAlert = false
    @State private var showAddContainerSheet = false
    @State private var editingContainer: Container?
    
    // Local state synced with AppStorage
    @State private var containers: [Container] = []
    
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
                
                // Container Management Section
                Section {
                    ForEach(containers) { container in
                        HStack {
                            Text(container.emoji)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(container.name)
                                    .font(.headline)
                                Text("\(container.volumeML) mL")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                editingContainer = container
                            }) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteContainers)
                    .onMove(perform: moveContainers)
                    
                    Button(action: {
                        showAddContainerSheet = true
                    }) {
                        Label("Add Container", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Containers")
                } footer: {
                    Text("Tap and hold to reorder. First 6 containers show as quick-add buttons.")
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
            .sheet(isPresented: $showAddContainerSheet) {
                AddContainerView(containers: $containers)
            }
            .sheet(item: $editingContainer) { container in
                EditContainerView(container: container, containers: $containers)
            }
            .onAppear {
                // Load containers from AppStorage
                containers = Array<Container>.fromJSON(containersJSON)
            }
            .onChange(of: containers) { _, newValue in
                // Save containers to AppStorage whenever they change
                containersJSON = newValue.toJSON()
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
    
    private func deleteContainers(at offsets: IndexSet) {
        containers.remove(atOffsets: offsets)
        HapticManager.shared.impact(style: .medium)
    }
    
    private func moveContainers(from source: IndexSet, to destination: Int) {
        containers.move(fromOffsets: source, toOffset: destination)
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

// MARK: - Add Container View
struct AddContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var containers: [Container]
    
    @State private var name = ""
    @State private var volumeML = ""
    @State private var selectedEmoji = "💧"
    
    let emojiOptions = ["💧", "🥤", "🍶", "☕️", "🧃", "🍵", "🥛", "🧋", "🍺", "🥃"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Container Details") {
                    TextField("Name (e.g., Water Bottle)", text: $name)
                    
                    TextField("Volume (mL)", text: $volumeML)
                        .keyboardType(.numberPad)
                    
                    Picker("Emoji", selection: $selectedEmoji) {
                        ForEach(emojiOptions, id: \.self) { emoji in
                            Text(emoji).tag(emoji)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            }
            .navigationTitle("Add Container")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addContainer()
                    }
                    .disabled(name.isEmpty || volumeML.isEmpty)
                }
            }
        }
    }
    
    private func addContainer() {
        guard let volume = Int(volumeML), volume > 0 else { return }
        
        let newContainer = Container(name: name, volumeML: volume, emoji: selectedEmoji)
        containers.append(newContainer)
        
        HapticManager.shared.impact(style: .medium)
        dismiss()
    }
}

// MARK: - Edit Container View
struct EditContainerView: View {
    @Environment(\.dismiss) private var dismiss
    let container: Container
    @Binding var containers: [Container]
    
    @State private var name = ""
    @State private var volumeML = ""
    @State private var selectedEmoji = ""
    
    let emojiOptions = ["💧", "🥤", "🍶", "☕️", "🧃", "🍵", "🥛", "🧋", "🍺", "🥃"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Container Details") {
                    TextField("Name", text: $name)
                    
                    TextField("Volume (mL)", text: $volumeML)
                        .keyboardType(.numberPad)
                    
                    Picker("Emoji", selection: $selectedEmoji) {
                        ForEach(emojiOptions, id: \.self) { emoji in
                            Text(emoji).tag(emoji)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            }
            .navigationTitle("Edit Container")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveContainer()
                    }
                    .disabled(name.isEmpty || volumeML.isEmpty)
                }
            }
            .onAppear {
                name = container.name
                volumeML = String(container.volumeML)
                selectedEmoji = container.emoji
            }
        }
    }
    
    private func saveContainer() {
        guard let volume = Int(volumeML), volume > 0 else { return }
        
        if let index = containers.firstIndex(where: { $0.id == container.id }) {
            containers[index].name = name
            containers[index].volumeML = volume
            containers[index].emoji = selectedEmoji
        }
        
        HapticManager.shared.impact(style: .medium)
        dismiss()
    }
}

#Preview {
    SettingsView()
}
