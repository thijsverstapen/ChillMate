import ActivityKit
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

@main
struct ChillMateApp: App {
    @UIApplicationDelegateAdaptor(ChillMateAppDelegate.self) private var appDelegate
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("dailyAffirmationsEnabled") private var dailyAffirmationsEnabled = false
    @AppStorage("lastAppUseTimestamp") private var lastAppUseTimestamp = Date.now.timeIntervalSince1970
    @AppStorage("localEncryptionEnabled") private var localEncryptionEnabled = true
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            // Single onboarding path: AppLockView → AppHomeView.
            // AppHomeView shows ProfileSetupView when no UserProfile exists,
            // which is the sole first-run onboarding experience.
            AppLockView {
                AppHomeView()
            }
            .modelContainer(ChillMateModelContainer.container())
            .onAppear {
                recordAppUse()
                refreshPrivacyAndNotificationState()
                WatchConnectivityService.shared.activate()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    recordAppUse()
                    refreshLiveActivities()
                }

                refreshPrivacyAndNotificationState()
            }
        }
    }

    private func recordAppUse() {
        lastAppUseTimestamp = Date.now.timeIntervalSince1970
    }

    private func refreshLiveActivities() {
        NotificationCenter.default.post(name: .chillMateRefreshTimers, object: nil)
    }

    private func refreshPrivacyAndNotificationState() {
        if localEncryptionEnabled {
            LocalSecurityService.applyFileProtection()
        }

        guard notificationsEnabled else {
            NotificationService.shared.clearInactivityReminders()
            NotificationService.shared.clearDailyAffirmations()
            return
        }

        let lastUseDate = Date(timeIntervalSince1970: lastAppUseTimestamp)
        NotificationService.shared.scheduleInactivityReminders(from: lastUseDate)

        if dailyAffirmationsEnabled {
            NotificationService.shared.scheduleDailyAffirmations()
        } else {
            NotificationService.shared.clearDailyAffirmations()
        }
    }
}

final class ChillMateAppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationService.shared.registerCategories()
        // Required for CloudKit silent-push sync and HealthKit background delivery
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcut = options.shortcutItem {
            handleShortcut(shortcut)
        }

        return UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(handleShortcut(shortcutItem))
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case NotificationService.ActionIdentifier.logNow:
            UserDefaults.standard.set(NotificationDestination.log.rawValue, forKey: "pendingAppDestination")
        case NotificationService.ActionIdentifier.snooze:
            NotificationService.shared.snoozeCurrentCheckIn()
        default:
            if let destination = response.notification.request.content.userInfo["destination"] as? String {
                UserDefaults.standard.set(destination, forKey: "pendingAppDestination")
            }
        }
        completionHandler()
    }

    @discardableResult
    private func handleShortcut(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        let destination: NotificationDestination?

        switch shortcutItem.type {
        case "com.BIJTHIJS.ChillMate.shortcut.log":
            destination = .log
        case "com.BIJTHIJS.ChillMate.shortcut.timers":
            destination = .timers
        case "com.BIJTHIJS.ChillMate.shortcut.panic":
            destination = .panic
        case "com.BIJTHIJS.ChillMate.shortcut.route":
            destination = .safeRoute
        default:
            destination = nil
        }

        guard let destination else {
            return false
        }

        UserDefaults.standard.set(destination.rawValue, forKey: "pendingAppDestination")
        return true
    }
}
