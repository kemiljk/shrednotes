//
//  BackgroundNotificationsClass.swift
//  Shrednotes
//
//  Created by Karl Koch on 14/12/2024.
//

import SwiftUI
import SwiftData
import UserNotifications

// Create an observable object to handle skate session monitoring
@MainActor
@Observable
class SkateSessionMonitor {
    let modelContext: ModelContext
    private let calendar = Calendar.current
    private let defaults = UserDefaults.standard
    private let lastNotificationKey = "lastSkateReminderDate"
    private let lastInactivityCheckKey = "lastInactivityCheckDate"

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func checkInactivity(sessions: [SkateSession]) {
        // Throttle: only run once per 24h (was firing on every foreground transition).
        if let last = defaults.object(forKey: lastInactivityCheckKey) as? Date,
           Date().timeIntervalSince(last) < 24 * 60 * 60 {
            return
        }
        defaults.set(Date(), forKey: lastInactivityCheckKey)

        // Skip notification if we already sent one in the past 7 days.
        if let lastNotificationDate = defaults.object(forKey: lastNotificationKey) as? Date {
            let minimumInterval = calendar.date(byAdding: .day, value: -7, to: Date())!
            if lastNotificationDate > minimumInterval {
                return
            }
        }

        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!

        if let lastSession = sessions.first,
           let lastSessionDate = lastSession.date {
            if lastSessionDate < weekAgo {
                scheduleSkateReminder()
            }
        } else {
            // No sessions yet — defer the reminder; the empty Home state already nudges the user.
            return
        }
    }

    private func scheduleSkateReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Time to Skate!"
        content.body = "It's been a week since your last skate session."
        content.sound = .default

        // Schedule for 10 AM next occurrence
        var components = DateComponents()
        components.hour = 10
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let identifier = "skate-reminder-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            guard error == nil, let self else { return }
            Task { @MainActor in
                self.defaults.set(Date(), forKey: self.lastNotificationKey)
            }
        }
    }
}

struct InactivityCheckModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var monitor: SkateSessionMonitor?
    @Query(sort: \SkateSession.date, order: .reverse) private var sessions: [SkateSession]

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    if monitor == nil {
                        monitor = SkateSessionMonitor(modelContext: modelContext)
                    }
                    monitor?.checkInactivity(sessions: sessions)
                default:
                    break
                }
            }
    }
}

extension View {
    func checkSkateInactivity() -> some View {
        modifier(InactivityCheckModifier())
    }
}
