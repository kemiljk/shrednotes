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
@Observable
class SkateSessionMonitor {
    let modelContext: ModelContext
    private let calendar = Calendar.current
    private let defaults = UserDefaults.standard
    private let lastNotificationKey = "lastSkateReminderDate"
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        print("SkateSessionMonitor initialized")
    }
    
    func checkInactivity(sessions: [SkateSession]) {
        print("Checking inactivity...")
        print("Number of sessions found: \(sessions.count)")
        
        // Check when we last sent a notification
        if let lastNotificationDate = defaults.object(forKey: lastNotificationKey) as? Date {
            let minimumInterval = calendar.date(byAdding: .day, value: -7, to: Date())!
            
            if lastNotificationDate > minimumInterval {
                print("Too soon since last notification (\(lastNotificationDate)), skipping check")
                return
            }
        }
        
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        
        if let lastSession = sessions.first,
           let lastSessionDate = lastSession.date {
            print("Last session date: \(lastSessionDate)")
            print("Week ago: \(weekAgo)")
            
            if lastSessionDate < weekAgo {
                print("No skating activity detected in the last week, scheduling reminder...")
                scheduleSkateReminder()
            } else {
                print("Recent skating activity found, no reminder needed")
            }
        } else {
            // No sessions at all - definitely should notify!
            print("No skating sessions found at all, scheduling reminder...")
            scheduleSkateReminder()
        }
    }
    
    private func scheduleSkateReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Time to Skate!"
        content.body = "It's been a week since your last skate session."
        content.sound = .default
        
        // Schedule for 10 AM tomorrow
        var components = DateComponents()
        components.hour = 10
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let identifier = "skate-reminder-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        print("Attempting to schedule inactivity reminder...")
        
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Inactivity reminder scheduled successfully")
                // Store the notification date
                self?.defaults.set(Date(), forKey: self?.lastNotificationKey ?? "")
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
            .onChange(of: scenePhase) { oldPhase, newPhase in
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
