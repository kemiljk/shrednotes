import Foundation
import WatchConnectivity
import SwiftData

class SessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = SessionManager()
    @Published var receivedSessions: [SkateSession] = []
    
    override private init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Handle activation completion
    }
    
    // iOS-specific methods
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        // Handle session becoming inactive
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // Handle session deactivation
        WCSession.default.activate()
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        // Handle watch state changes
    }
    #endif
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let sessionData = message["session"] as? Data {
            do {
                let decoder = JSONDecoder()
                let receivedSession = try decoder.decode(SkateSession.self, from: sessionData)
                DispatchQueue.main.async {
                    self.addReceivedSessionToSwiftData(receivedSession)
                }
            } catch {
                print("Error decoding received session: \(error)")
            }
        }
    }
    
    func sendSession(_ session: SkateSession) {
        guard WCSession.default.isReachable else {
            print("Counterpart is not reachable")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            let sessionData = try encoder.encode(session)
            WCSession.default.sendMessage(["session": sessionData], replyHandler: nil) { error in
                print("Error sending session: \(error.localizedDescription)")
            }
        } catch {
            print("Error encoding session: \(error)")
        }
    }
    
    // Method to add received session to SwiftData
    @MainActor
    private func addReceivedSessionToSwiftData(_ session: SkateSession) {
        let modelContext = watchExtensionModelContainer.mainContext
        
        // Check if a session with the same ID already exists
        let fetchDescriptor = FetchDescriptor<SkateSession>(predicate: #Predicate { $0.id == session.id })
        do {
            let existingSessions = try modelContext.fetch(fetchDescriptor)
            if let existingSession = existingSessions.first {
                // Update existing session
                existingSession.title = session.title
                existingSession.date = session.date
                existingSession.note = session.note
                existingSession.feeling = session.feeling
                existingSession.media = session.media
                existingSession.tricks = session.tricks
                existingSession.latitude = session.latitude
                existingSession.longitude = session.longitude
                existingSession.location = session.location
            } else {
                // Insert new session
                modelContext.insert(session)
            }
            
            try modelContext.save()
            print("Session saved/updated in SwiftData")
        } catch {
            print("Error saving received session to SwiftData: \(error)")
        }
    }
}
