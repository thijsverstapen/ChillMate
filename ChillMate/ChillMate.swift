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
        guard UserDefaults.standard.bool(forKey: "hasActiveDrugTimer") else { return }
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

        let today = Calendar.current.startOfDay(for: .now)
        let lastScheduled = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: "lastInactivityScheduleDay"))
        if lastScheduled < today {
            UserDefaults.standard.set(today.timeIntervalSince1970, forKey: "lastInactivityScheduleDay")
            let lastUseDate = Date(timeIntervalSince1970: lastAppUseTimestamp)
            NotificationService.shared.scheduleInactivityReminders(from: lastUseDate)
        }

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
        if UserDefaults.standard.bool(forKey: "iCloudBackupEnabled") {
            application.registerForRemoteNotifications()
        }
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


// MARK: - Localized enum display

extension RawRepresentable where RawValue == String {
    /// Localized display text for a String-backed enum, resolved from the String Catalog
    /// by rawValue. The rawValue stays the stable storage key; this is display-only.
    var localizedDisplayName: String {
        Bundle.main.localizedString(forKey: rawValue, value: rawValue, table: nil)
    }
}

enum LocalizedEnumStrings {
    /// Extraction anchors. These keep every displayed enum rawValue present in the
    /// String Catalog (so they are translated and never flagged stale), even though
    /// they are rendered at runtime via `localizedDisplayName` rather than literals.
    static let anchors: [String] = [
        String(localized: "Prefer not to say"),
        String(localized: "24 h"),
        String(localized: "3MMC"),
        String(localized: "6 h"),
        String(localized: "Accessibility"),
        String(localized: "Account data"),
        String(localized: "Adaptive"),
        String(localized: "Alcohol"),
        String(localized: "Anxiety"),
        String(localized: "Anxious"),
        String(localized: "App date"),
        String(localized: "Appearance"),
        String(localized: "Apple Watch"),
        String(localized: "Around sex"),
        String(localized: "Bereavement"),
        String(localized: "Bisexual"),
        String(localized: "Body"),
        String(localized: "Boredom"),
        String(localized: "Bottom"),
        String(localized: "Breakup"),
        String(localized: "Cannabis"),
        String(localized: "Celebration"),
        String(localized: "Chlamydia"),
        String(localized: "Cocaine"),
        String(localized: "Conflict"),
        String(localized: "Cycling"),
        String(localized: "Daily"),
        String(localized: "Depressed"),
        String(localized: "Depression"),
        String(localized: "Did not redose"),
        String(localized: "Direct"),
        String(localized: "Dissociated"),
        String(localized: "Driving"),
        String(localized: "Dusk"),
        String(localized: "Exhausted"),
        String(localized: "Female"),
        String(localized: "GBL"),
        String(localized: "GHB"),
        String(localized: "Gay"),
        String(localized: "Gentle"),
        String(localized: "Gonorrhea"),
        String(localized: "Grief"),
        String(localized: "Grounded"),
        String(localized: "HIV"),
        String(localized: "HPV"),
        String(localized: "HRV read/write"),
        String(localized: "Health"),
        String(localized: "Heart rate read/write"),
        String(localized: "Heartbreak"),
        String(localized: "Hepatitis B"),
        String(localized: "Hepatitis C"),
        String(localized: "Herpes"),
        String(localized: "Horny"),
        String(localized: "Housing"),
        String(localized: "I didn't use"),
        String(localized: "I used"),
        String(localized: "Identity"),
        String(localized: "Impulsive"),
        String(localized: "Inconclusive"),
        String(localized: "Injected"),
        String(localized: "Invited"),
        String(localized: "Kamagra"),
        String(localized: "Ketamine"),
        String(localized: "Known interaction"),
        String(localized: "Likely risk"),
        String(localized: "Limited evidence"),
        String(localized: "Liquid purple"),
        String(localized: "Loneliness"),
        String(localized: "Lonely"),
        String(localized: "Low"),
        String(localized: "MDMA"),
        String(localized: "Male"),
        String(localized: "Medication"),
        String(localized: "Medication change"),
        String(localized: "Minimal"),
        String(localized: "Mint glass"),
        String(localized: "Money"),
        String(localized: "Mycoplasma genitalium"),
        String(localized: "Myself"),
        String(localized: "Negative"),
        String(localized: "Non-binary"),
        String(localized: "Not applicable"),
        String(localized: "Notifications"),
        String(localized: "Numb"),
        String(localized: "Okay"),
        String(localized: "Other"),
        String(localized: "Others"),
        String(localized: "Overstimulated"),
        String(localized: "Overwhelmed"),
        String(localized: "Party"),
        String(localized: "Pending"),
        String(localized: "Permissions"),
        String(localized: "Photo"),
        String(localized: "Planned"),
        String(localized: "Playful"),
        String(localized: "Poppers"),
        String(localized: "Positive"),
        String(localized: "Privacy & lock"),
        String(localized: "Privacy dashboard"),
        String(localized: "Psychedelics"),
        String(localized: "Queer"),
        String(localized: "Questioning"),
        String(localized: "Reduction goals"),
        String(localized: "Relationship"),
        String(localized: "Safety review"),
        String(localized: "Same session"),
        String(localized: "Sexual activity read/write"),
        String(localized: "Shaky"),
        String(localized: "Side"),
        String(localized: "Sleep read/write"),
        String(localized: "Smoked"),
        String(localized: "Sniffed"),
        String(localized: "Social pressure"),
        String(localized: "Still redosed"),
        String(localized: "Straight"),
        String(localized: "Stress"),
        String(localized: "Sunrise"),
        String(localized: "Swallowed"),
        String(localized: "Syphilis"),
        String(localized: "Tender"),
        String(localized: "Top"),
        String(localized: "Transit"),
        String(localized: "Trauma"),
        String(localized: "Trichomoniasis"),
        String(localized: "Undecided"),
        String(localized: "Unknown"),
        String(localized: "Versatile"),
        String(localized: "Viagra"),
        String(localized: "Work pressure"),
        String(localized: "Workout read/write"),
        String(localized: "iCloud backup")
    ]
}
