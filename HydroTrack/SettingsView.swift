import SwiftUI

enum NotificationStyle: String, CaseIterable, Identifiable {
    case off = "Off"
    case periodic = "Periodic"
    case smart = "Smart"
    
    var id: String { rawValue }
}

struct SettingsView: View {
    @AppStorage("dailyGoalML") private var dailyGoalML = 2000
    @AppStorage("notificationStyle") private var notificationStyleRaw = NotificationStyle.off.rawValue
    
    // Periodic settings
    @AppStorage("notifStartHour") private var notifStartHour = 9
    @AppStorage("notifEndHour") private var notifEndHour = 21
    @AppStorage("notifIntervalHours") private var notifIntervalHours = 2
    
    // Smart notification settings
    @AppStorage("smartNotifMilestones") private var smartNotifMilestones = true
    @AppStorage("smartNotifInactivity") private var smartNotifInactivity = true
    @AppStorage("smartNotifAchievement") private var smartNotifAchievement = true
    
    @AppStorage("containers") private var containersJSON = Container.defaults.toJSON()
    
    @FocusState private var isGoalFieldFocused: Bool
    @State private var showPermissionDeniedAlert = false
    @State private var showAddContainerSheet = false
    @State private var editingContainer: Container?
    @State private var containers: [Container] = []
    
    // Local state for notification style
    @State private var selectedNotificationStyle: NotificationStyle = .off
    
    var body: some View {
        NavigationStack {
            Form {
                // Daily Goal Section
                Section {
                    HStack(spacing: 0) {
                        TextField("Goal", value: $dailyGoalML, format: .number)
                            .keyboardType(.numberPad)
                            .font(.title2.bold())
                            .multilineTextAlignment(.trailing)  // Changed from .leading to .trailing
                            .fixedSize()  // Added this - makes it only as wide as needed
                            .focused($isGoalFieldFocused)
                        
                        Text(" mL")  // Added space inside the text itself
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Image(systemName: "target")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Daily Goal")
                } footer: {
                    Text("Recommended: 2000-3000 mL for adults")
                }
                
                // Container Management Section
                Section {
                    ForEach(containers) { container in
                        HStack {
                            ContainerIconView(container: container, size: 36)
                            
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
                    Text("Tap and hold to reorder")
                }
                
                // Notifications Section
                Section {
                    Picker("Notification Style", selection: $selectedNotificationStyle) {
                        ForEach(NotificationStyle.allCases) { style in
                            Text(style.rawValue)
                                .tag(style)
                        }
                    }

                    .onChange(of: selectedNotificationStyle) { oldValue, newValue in
                        notificationStyleRaw = newValue.rawValue
                        Task {
                            await handleNotificationStyleChange(newValue)
                        }
                    }
                    
                    // Periodic Settings
                    if selectedNotificationStyle == .periodic {
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
                    
                    // Smart Settings
                    if selectedNotificationStyle == .smart {
                        Toggle(isOn: $smartNotifMilestones) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Progress Milestones")
                                    .font(.headline)
                                Text("12pm, 3pm, 6pm, 9pm")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onChange(of: smartNotifMilestones) { _, _ in
                            rescheduleSmartNotifications()
                        }
                        
                        Toggle(isOn: $smartNotifInactivity) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Inactivity Alerts")
                                    .font(.headline)
                                Text("Reminds you if inactive")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onChange(of: smartNotifInactivity) { _, _ in
                            rescheduleSmartNotifications()
                        }
                        
                        Toggle(isOn: $smartNotifAchievement) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Achievement Reminders")
                                    .font(.headline)
                                Text("Motivational push to finish")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onChange(of: smartNotifAchievement) { _, _ in
                            rescheduleSmartNotifications()
                        }
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    if selectedNotificationStyle == .periodic {
                        Text("Receive reminders at regular intervals during your active hours")
                    } else if selectedNotificationStyle == .smart {
                        Text("Reminders adapt to your progress and habits")
                    } else {
                        Text("No notifications will be sent")
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
                    selectedNotificationStyle = .off
                    notificationStyleRaw = NotificationStyle.off.rawValue
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
                containers = Array<Container>.fromJSON(containersJSON)
                // Load notification style from AppStorage
                if let style = NotificationStyle(rawValue: notificationStyleRaw) {
                    selectedNotificationStyle = style
                }
            }
            .onChange(of: containers) { _, newValue in
                containersJSON = newValue.toJSON()
            }
        }
    }
    
    private func handleNotificationStyleChange(_ style: NotificationStyle) async {
        if style == .off {
            NotificationManager.shared.cancelAllNotifications()
            HapticManager.shared.impact(style: .light)
            return
        }
        
        // Request permission
        let granted = await NotificationManager.shared.requestAuthorization()
        
        if granted {
            if style == .periodic {
                await NotificationManager.shared.schedulePeriodicReminders(
                    startHour: notifStartHour,
                    endHour: notifEndHour,
                    intervalHours: notifIntervalHours
                )
            } else if style == .smart {
                await NotificationManager.shared.scheduleSmartReminders(
                    dailyGoal: dailyGoalML,
                    enableMilestones: smartNotifMilestones,
                    enableInactivity: smartNotifInactivity,
                    enableAchievement: smartNotifAchievement
                )
            }
            HapticManager.shared.notification(type: .success)
        } else {
            await MainActor.run {
                selectedNotificationStyle = .off
                notificationStyleRaw = NotificationStyle.off.rawValue
                showPermissionDeniedAlert = true
            }
            HapticManager.shared.notification(type: .error)
        }
    }
    
    private func rescheduleSmartNotifications() {
        if selectedNotificationStyle == .smart {
            Task {
                await NotificationManager.shared.scheduleSmartReminders(
                    dailyGoal: dailyGoalML,
                    enableMilestones: smartNotifMilestones,
                    enableInactivity: smartNotifInactivity,
                    enableAchievement: smartNotifAchievement
                )
            }
        }
    }
    
    private func deleteContainers(at offsets: IndexSet) {
        // Delete associated images before removing containers
        for index in offsets {
            if let imageName = containers[index].imageName {
                Container.deleteImage(filename: imageName)
            }
        }
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
}

// MARK: - Container Icon View
struct ContainerIconView: View {
    let container: Container
    let size: CGFloat
    
    var body: some View {
        Group {
            if let imageName = container.imageName,
               let uiImage = Container.loadImage(filename: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()  // Changed from scaledToFill
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
            } else {
                Text(container.emoji)
                    .font(.system(size: size * 0.7))
            }
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
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var useImage = false
    
    let emojiOptions = ["💧", "🥤", "🍶", "☕️", "🧃", "🍵", "🥛", "🧋", "🍺", "🥃"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Container Details") {
                    TextField("Name (e.g., Water Bottle)", text: $name)
                    
                    TextField("Volume (mL)", text: $volumeML)
                        .keyboardType(.numberPad)
                }
                
                Section("Icon") {
                    Picker("Icon Type", selection: $useImage) {
                        Text("Emoji").tag(false)
                        Text("Photo").tag(true)
                    }
                    .pickerStyle(.segmented)
                    
                    if useImage {
                        Button(action: {
                            showImagePicker = true
                        }) {
                            HStack {
                                if let image = selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.largeTitle)
                                        .foregroundStyle(.blue)
                                        .frame(width: 60, height: 60)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(selectedImage == nil ? "Choose Photo" : "Change Photo")
                                        .font(.headline)
                                    Text("Take a photo or select from library")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Picker("Emoji", selection: $selectedEmoji) {
                            ForEach(emojiOptions, id: \.self) { emoji in
                                Text(emoji).tag(emoji)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
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
                    .disabled(name.isEmpty || volumeML.isEmpty || (useImage && selectedImage == nil))
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
        }
    }
    
    private func addContainer() {
        guard let volume = Int(volumeML), volume > 0 else { return }
        
        var imageName: String?
        if useImage, let image = selectedImage {
            imageName = Container.saveImage(image)
        }
        
        let newContainer = Container(
            name: name,
            volumeML: volume,
            emoji: selectedEmoji,
            imageName: imageName
        )
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
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var useImage = false
    @State private var currentImageName: String?
    
    let emojiOptions = ["💧", "🥤", "🍶", "☕️", "🧃", "🍵", "🥛", "🧋", "🍺", "🥃"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Container Details") {
                    TextField("Name", text: $name)
                    
                    TextField("Volume (mL)", text: $volumeML)
                        .keyboardType(.numberPad)
                }
                
                Section("Icon") {
                    Picker("Icon Type", selection: $useImage) {
                        Text("Emoji").tag(false)
                        Text("Photo").tag(true)
                    }
                    .pickerStyle(.segmented)
                    
                    if useImage {
                        Button(action: {
                            showImagePicker = true
                        }) {
                            HStack {
                                if let image = selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else if let imageName = currentImageName,
                                          let image = Container.loadImage(filename: imageName) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.largeTitle)
                                        .foregroundStyle(.blue)
                                        .frame(width: 60, height: 60)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text("Change Photo")
                                        .font(.headline)
                                    Text("Take a photo or select from library")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Picker("Emoji", selection: $selectedEmoji) {
                            ForEach(emojiOptions, id: \.self) { emoji in
                                Text(emoji).tag(emoji)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
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
                currentImageName = container.imageName
                useImage = container.imageName != nil
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
        }
    }
    
    private func saveContainer() {
        guard let volume = Int(volumeML), volume > 0 else { return }
        
        if let index = containers.firstIndex(where: { $0.id == container.id }) {
            var imageName: String? = currentImageName
            
            // Handle image changes
            if useImage {
                if let newImage = selectedImage {
                    // Delete old image if exists
                    if let oldImageName = currentImageName {
                        Container.deleteImage(filename: oldImageName)
                    }
                    // Save new image
                    imageName = Container.saveImage(newImage)
                }
            } else {
                // Switched to emoji, delete image
                if let oldImageName = currentImageName {
                    Container.deleteImage(filename: oldImageName)
                }
                imageName = nil
            }
            
            containers[index].name = name
            containers[index].volumeML = volume
            containers[index].emoji = selectedEmoji
            containers[index].imageName = imageName
        }
        
        HapticManager.shared.impact(style: .medium)
        dismiss()
    }
}

#Preview {
    SettingsView()
}
