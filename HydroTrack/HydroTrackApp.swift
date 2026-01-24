import SwiftUI
import SwiftData
import UserNotifications

@main
struct HydroTrackApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WaterEntry.self,
        ])
        
        // Use a new configuration that will create a fresh database if schema changes
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If migration fails, delete old database and create new one
            print("⚠️ ModelContainer creation failed: \(error)")
            
            // Try to delete the old database files
            let fileManager = FileManager.default
            if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let storePath = appSupport.appendingPathComponent("default.store")
                try? fileManager.removeItem(at: storePath)
                print("🗑️ Deleted old database, creating fresh one...")
            }
            
            // Try creating container again
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer even after cleanup: \(error)")
            }
        }
    }()
    
    init() {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}

// Notification Delegate Handler
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    // Handle notification actions (On pace / Late buttons)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task {
            switch response.actionIdentifier {
            case "ON_PACE_ACTION":
                await NotificationManager.shared.scheduleNextSmartNotification(isOnPace: true)
            case "LATE_ACTION":
                await NotificationManager.shared.scheduleNextSmartNotification(isOnPace: false)
            default:
                break
            }
            completionHandler()
        }
    }
    
    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
