import UserNotifications
import SwiftUI

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {
        setupNotificationCategories()
    }
    
    // MARK: - Setup
    
    private func setupNotificationCategories() {
        // Define actions for smart notifications
        let onPaceAction = UNNotificationAction(
            identifier: "ON_PACE_ACTION",
            title: "On pace ✅",
            options: [.foreground]
        )
        
        let lateAction = UNNotificationAction(
            identifier: "LATE_ACTION",
            title: "Late ⏰",
            options: [.foreground]
        )
        
        // Create category with actions
        let smartCategory = UNNotificationCategory(
            identifier: "SMART_REMINDER",
            actions: [onPaceAction, lateAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Register categories
        UNUserNotificationCenter.current().setNotificationCategories([smartCategory])
    }
    
    // Request notification permission
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Failed to request authorization: \(error)")
            return false
        }
    }
    
    // MARK: - Periodic Notifications (Time-Aware)
    
    func schedulePeriodicReminders(startHour: Int, endHour: Int, intervalHours: Int) async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        var currentHour = startHour
        var notificationCount = 0
        
        while currentHour <= endHour && notificationCount < 20 {
            var dateComponents = DateComponents()
            dateComponents.hour = currentHour
            dateComponents.minute = 0
            
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )
            
            let content = UNMutableNotificationContent()
            content.title = "Time to Hydrate"
            content.body = getTimeAwareMessage(for: currentHour)
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: "periodic-reminder-\(currentHour)",
                content: content,
                trigger: trigger
            )
            
            do {
                try await UNUserNotificationCenter.current().add(request)
                notificationCount += 1
            } catch {
                print("Failed to schedule notification: \(error)")
            }
            
            currentHour += intervalHours
        }
        
        print("✅ Scheduled \(notificationCount) periodic reminders")
    }
    
    private func getTimeAwareMessage(for hour: Int) -> String {
        switch hour {
        case 6..<12:
            return "Good morning! Start your day hydrated"
        case 12..<15:
            return "Lunch time! Don't forget to drink water"
        case 15..<18:
            return "Afternoon boost needed"
        case 18..<21:
            return "Evening hydration"
        default:
            return "Last call before bed"
        }
    }
    
    // MARK: - Smart Notifications (Truly Adaptive)
    
    func scheduleSmartReminders() async {
        // Cancel any existing smart notifications
        await cancelSmartNotificationsAsync()
        
        // Only schedule the initial 11 AM notification
        // All other notifications are triggered by responses or backups
        await scheduleInitialSmartNotification()
        
        print("✅ Scheduled initial smart notification at 11 AM")
    }
    
    private func scheduleInitialSmartNotification() async {
        var dateComponents = DateComponents()
        dateComponents.hour = 11
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        
        let content = UNMutableNotificationContent()
        content.title = "Hydration Check"
        content.body = "How's your progress so far today?"
        content.sound = .default
        content.categoryIdentifier = "SMART_REMINDER"
        
        let request = UNNotificationRequest(
            identifier: "smart-11am",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            
            // Schedule a backup for if they don't respond to 11 AM
            await scheduleBackupNotification(afterHours: 3, fromHour: 11)
        } catch {
            print("Failed to schedule initial smart notification: \(error)")
        }
    }
    
    // Schedule backup notification if user doesn't respond
    private func scheduleBackupNotification(afterHours: Int, fromHour: Int) async {
        let targetHour = fromHour + afterHours
        
        // Don't schedule if after 9 PM
        if targetHour >= 21 {
            print("⏰ Backup would be after 9 PM, skipping")
            return
        }
        
        var dateComponents = DateComponents()
        dateComponents.hour = targetHour
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        
        let content = UNMutableNotificationContent()
        content.title = "Hydration Check"
        content.body = "Still there? How are you doing?"
        content.sound = .default
        content.categoryIdentifier = "SMART_REMINDER"
        
        let request = UNNotificationRequest(
            identifier: "smart-backup-\(targetHour)h",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Scheduled backup notification at \(targetHour):00")
        } catch {
            print("Failed to schedule backup notification: \(error)")
        }
    }
    
    // Schedule next smart notification based on user response
    func scheduleNextSmartNotification(isOnPace: Bool) async {
        // Clear all existing smart notifications except the 11 AM one
        await clearAllExceptInitial()
        
        // Calculate next check time
        let hoursUntilNext = isOnPace ? 4 : 2
        let nextCheckTime = Calendar.current.date(
            byAdding: .hour,
            value: hoursUntilNext,
            to: Date()
        )!
        
        let nextHour = Calendar.current.component(.hour, from: nextCheckTime)
        
        // Don't schedule if after 9 PM
        if nextHour >= 21 {
            print("⏰ Next check would be after 9 PM, stopping for today")
            return
        }
        
        // Schedule the follow-up
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(hoursUntilNext * 3600),
            repeats: false
        )
        
        let content = UNMutableNotificationContent()
        content.title = "Hydration Check"
        content.body = isOnPace ?
            "Keep up the great work! How are you doing now?" :
            "Time for another check-in. Making progress?"
        content.sound = .default
        content.categoryIdentifier = "SMART_REMINDER"
        
        let request = UNNotificationRequest(
            identifier: "smart-response-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Scheduled next smart notification in \(hoursUntilNext) hours")
            
            // Schedule backup in case they don't respond to this one either
            let backupHours = isOnPace ? 3 : 2  // Shorter backup if they're late
            await scheduleOneTimeBackup(afterSeconds: TimeInterval((hoursUntilNext + backupHours) * 3600))
        } catch {
            print("Failed to schedule follow-up notification: \(error)")
        }
    }
    
    // Schedule a one-time backup (not repeating)
    private func scheduleOneTimeBackup(afterSeconds: TimeInterval) async {
        let calendar = Calendar.current
        let futureDate = Date().addingTimeInterval(afterSeconds)
        let futureHour = calendar.component(.hour, from: futureDate)
        
        // Don't schedule if after 9 PM
        if futureHour >= 21 {
            print("⏰ Backup would be after 9 PM, skipping")
            return
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: afterSeconds,
            repeats: false
        )
        
        let content = UNMutableNotificationContent()
        content.title = "Hydration Check"
        content.body = "Just checking in. How's it going?"
        content.sound = .default
        content.categoryIdentifier = "SMART_REMINDER"
        
        let request = UNNotificationRequest(
            identifier: "smart-backup-onetime-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Scheduled one-time backup notification")
        } catch {
            print("Failed to schedule backup: \(error)")
        }
    }
    
    // Clear all smart notifications except the initial 11 AM one
    private func clearAllExceptInitial() async {
        let currentIds = await getCurrentPendingIds()
        let toRemove = currentIds.filter { $0.starts(with: "smart-") && $0 != "smart-11am" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: toRemove)
        print("🧹 Cleared \(toRemove.count) old smart notifications")
    }
    
    // Helper to get current pending notification IDs
    private func getCurrentPendingIds() async -> [String] {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.map { $0.identifier }
    }
    
    // Async version of cancelSmartNotifications
    private func cancelSmartNotificationsAsync() async {
        let currentIds = await getCurrentPendingIds()
        let smartIds = currentIds.filter { $0.starts(with: "smart-") }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: smartIds)
    }
    
    // Disable all notifications when goal is reached
    func disableNotificationsForToday() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("🎉 Goal reached! Disabled all notifications for today")
    }
    
    // MARK: - Legacy Smart Notifications (Deprecated)
    
    func scheduleSmartReminders(
        dailyGoal: Int,
        enableMilestones: Bool,
        enableInactivity: Bool,
        enableAchievement: Bool
    ) async {
        // This method is deprecated - use scheduleSmartReminders() instead
        await scheduleSmartReminders()
    }
    
    // MARK: - Utilities
    
    // Cancel all notifications
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("❌ Cancelled all notifications")
    }
    
    // Check current notification permission status
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
    
    // Get pending notification count (for debugging)
    func getPendingNotificationCount() async -> Int {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.count
    }
    
    // MARK: - Testing / Debug
    
    #if DEBUG
    /// Trigger a test smart notification in 5 seconds
    func scheduleTestSmartNotification(delay: TimeInterval = 5) async {
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: delay,
            repeats: false
        )
        
        let content = UNMutableNotificationContent()
        content.title = "Test: Hydration Check"
        content.body = "This is a test notification. How's your progress?"
        content.sound = .default
        content.categoryIdentifier = "SMART_REMINDER"
        
        let request = UNNotificationRequest(
            identifier: "test-notification",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Test notification scheduled for \(delay) seconds from now")
        } catch {
            print("❌ Failed to schedule test notification: \(error)")
        }
    }
    
    /// Trigger a test periodic notification in 5 seconds
    func scheduleTestPeriodicNotification(delay: TimeInterval = 5) async {
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: delay,
            repeats: false
        )
        
        let content = UNMutableNotificationContent()
        content.title = "Test: Time to Hydrate"
        content.body = "This is a test periodic notification"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "test-periodic",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Test periodic notification scheduled for \(delay) seconds from now")
        } catch {
            print("❌ Failed to schedule test notification: \(error)")
        }
    }
    
    /// Show all pending notifications with details
    func debugPendingNotifications() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        print("\n📋 PENDING NOTIFICATIONS: \(requests.count)")
        for request in requests {
            print("  • ID: \(request.identifier)")
            print("    Title: \(request.content.title)")
            print("    Body: \(request.content.body)")
            print("    Category: \(request.content.categoryIdentifier)")
            if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                print("    Trigger: Calendar - \(trigger.dateComponents)")
            } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                print("    Trigger: Interval - \(trigger.timeInterval)s, repeats: \(trigger.repeats)")
            }
            print("")
        }
    }
    #endif
}
