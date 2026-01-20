import UserNotifications
import SwiftUI

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
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
    
    // MARK: - Periodic Notifications (Traditional)
    
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
            content.title = "Time to Hydrate! 💧"
            content.body = "Don't forget to drink water and stay healthy"
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
    
    // MARK: - Smart Notifications (Hybrid)
    
    func scheduleSmartReminders(
        dailyGoal: Int,
        enableMilestones: Bool,
        enableInactivity: Bool,
        enableAchievement: Bool
    ) async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        var notificationCount = 0
        
        // Milestone Reminders (12pm, 3pm, 6pm, 9pm)
        if enableMilestones {
            notificationCount += await scheduleMilestoneReminders(dailyGoal: dailyGoal)
        }
        
        // Inactivity Reminders (every 3 hours during day)
        if enableInactivity {
            notificationCount += await scheduleInactivityReminders()
        }
        
        // Achievement Reminder (8-9pm)
        if enableAchievement {
            notificationCount += await scheduleAchievementReminder(dailyGoal: dailyGoal)
        }
        
        print("✅ Scheduled \(notificationCount) smart notifications")
    }
    
    private func scheduleMilestoneReminders(dailyGoal: Int) async -> Int {
        let milestones = [
            (hour: 12, expectedProgress: 0.30, message: "Morning check: Stay on track with your hydration! 🌅"),
            (hour: 15, expectedProgress: 0.50, message: "Afternoon reminder: You're halfway through the day! ☀️"),
            (hour: 18, expectedProgress: 0.70, message: "Evening check: Keep up the good work! 🌆"),
            (hour: 21, expectedProgress: 0.90, message: "Last call: Time to finish strong! 🌙")
        ]
        
        var count = 0
        
        for milestone in milestones {
            var dateComponents = DateComponents()
            dateComponents.hour = milestone.hour
            dateComponents.minute = 0
            
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )
            
            let content = UNMutableNotificationContent()
            content.title = "Hydration Milestone 💧"
            content.body = milestone.message
            content.sound = .default
            content.categoryIdentifier = "MILESTONE_REMINDER"
            
            let request = UNNotificationRequest(
                identifier: "milestone-\(milestone.hour)",
                content: content,
                trigger: trigger
            )
            
            do {
                try await UNUserNotificationCenter.current().add(request)
                count += 1
            } catch {
                print("Failed to schedule milestone: \(error)")
            }
        }
        
        return count
    }
    
    private func scheduleInactivityReminders() async -> Int {
        // Inactivity checks at 10am, 1pm, 4pm, 7pm
        let checkTimes = [10, 13, 16, 19]
        var count = 0
        
        for hour in checkTimes {
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = 0
            
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )
            
            let content = UNMutableNotificationContent()
            content.title = "Don't Forget to Hydrate! 💧"
            content.body = "It's been a while since you logged water. Time for a drink?"
            content.sound = .default
            content.categoryIdentifier = "INACTIVITY_REMINDER"
            
            let request = UNNotificationRequest(
                identifier: "inactivity-\(hour)",
                content: content,
                trigger: trigger
            )
            
            do {
                try await UNUserNotificationCenter.current().add(request)
                count += 1
            } catch {
                print("Failed to schedule inactivity reminder: \(error)")
            }
        }
        
        return count
    }
    
    private func scheduleAchievementReminder(dailyGoal: Int) async -> Int {
        // Evening achievement reminder (8:30 PM)
        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 30
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        
        let content = UNMutableNotificationContent()
        content.title = "Almost There! 🎯"
        content.body = "You're so close to hitting your daily goal! Finish strong!"
        content.sound = .default
        content.categoryIdentifier = "ACHIEVEMENT_REMINDER"
        
        let request = UNNotificationRequest(
            identifier: "achievement-evening",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            return 1
        } catch {
            print("Failed to schedule achievement reminder: \(error)")
            return 0
        }
    }
    
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
}
