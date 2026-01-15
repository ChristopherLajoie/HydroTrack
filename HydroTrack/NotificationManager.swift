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
    
    // Schedule water reminders
    func scheduleWaterReminders(startHour: Int, endHour: Int, intervalHours: Int) async {
        // First remove all pending notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Schedule notifications for each interval
        var currentHour = startHour
        var notificationCount = 0
        
        while currentHour <= endHour && notificationCount < 20 { // iOS limit is ~64
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
            content.badge = 0
            
            let request = UNNotificationRequest(
                identifier: "water-reminder-\(currentHour)",
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
        
        print("✅ Scheduled \(notificationCount) water reminders")
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
