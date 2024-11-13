//
//  HealthKitManager.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//

import HealthKit
import UserNotifications
import SwiftData

class HealthKitManager: ObservableObject {
    private lazy var healthStore: HKHealthStore = {
        return HKHealthStore()
    }()
    
    @Published private(set) var latestWorkout: HKWorkout?
    @Published private(set) var allSkateboardingWorkouts: [HKWorkout] = []
    @Published private(set) var activeEnergyBurned: Double = 0
    @Published private(set) var energyBurnedCache: [UUID: Double] = [:]
    
    @Published var latestActiveEnergyBurned: Double = 0
    @Published var latestTotalDuration: TimeInterval = 0
    
    private let workoutType = HKObjectType.workoutType()
    private let energyBurnedType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    
    private var workoutObserverQuery: HKAnchoredObjectQuery?
    
    static let shared = HealthKitManager()
    
//    init() {
//        setupWorkoutObserver()
//        clearNotificationsAtStartOfDay()
//    }
    
//    private func setupWorkoutObserver() {
//        let query = HKAnchoredObjectQuery(type: workoutType, predicate: nil, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] (query, samples, deletedObjects, anchor, error) in
//            self?.handleWorkoutUpdates(samples: samples, deletedObjects: deletedObjects)
//        }
//        
//        query.updateHandler = { [weak self] (query, samples, deletedObjects, anchor, error) in
//            self?.handleWorkoutUpdates(samples: samples, deletedObjects: deletedObjects)
//        }
//        
//        healthStore.execute(query)
//        workoutObserverQuery = query
//    }

//    private func handleWorkoutUpdates(samples: [HKSample]?, deletedObjects: [HKDeletedObject]?) {
//        guard let workouts = samples as? [HKWorkout] else { return }
//        DispatchQueue.main.async {
//            for workout in workouts {
//                self.scheduleNotificationsForWorkout(workout)
//            }
//        }
//    }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            completion(false)
            return
        }

        let typesToShare: Set = [HKObjectType.workoutType()]
        let typesToRead: Set = [HKObjectType.workoutType()]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
            if let error = error {
                print("HealthKit authorization error: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                if success {
                    UserDefaults.standard.set(true, forKey: "HealthAccessGranted")
                    self.fetchLatestWorkout()
//                    self.setupWorkoutObserver()
                }
                completion(success)
            }
        }
    }
    
    func fetchLatestWorkout() {
        let predicate = HKQuery.predicateForWorkouts(with: .skatingSports)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            guard let self = self, let samples = samples as? [HKWorkout], let latestWorkout = samples.first else { return }
            DispatchQueue.main.async {
                self.latestWorkout = latestWorkout
//                self.scheduleNotificationsForWorkout(latestWorkout)
                
                self.latestTotalDuration = latestWorkout.duration
                
                // Fetch active energy burned
                self.fetchActiveEnergyBurnedForSingleWorkout(for: latestWorkout) { energy in
                    DispatchQueue.main.async {
                        self.latestActiveEnergyBurned = energy
                    }
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchAllSkateboardingWorkouts() {
        let predicate = HKQuery.predicateForWorkouts(with: .skatingSports)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            guard let self = self, let samples = samples as? [HKWorkout] else { return }
            DispatchQueue.main.async {
                self.allSkateboardingWorkouts = samples
                print("Fetched \(samples.count) skateboarding workouts")
            }
        }
        
        healthStore.execute(query)
    }

    func sumWorkoutData(workouts: [HKWorkout], completion: @escaping (TimeInterval, Double) -> Void) {
        let totalDuration = workouts.reduce(0) { $0 + $1.duration }
        var totalEnergyBurned: Double = 0
        
        let group = DispatchGroup()
        
        for workout in workouts {
            group.enter()
            fetchActiveEnergyBurnedForSingleWorkout(for: workout) { energy in
                totalEnergyBurned += energy
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(totalDuration, totalEnergyBurned)
        }
    }
    
    func fetchWorkoutsForDate(_ date: Date, completion: @escaping ([HKWorkout]) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        
        // Explicitly declare workoutType
        let workoutType: HKSampleType = HKObjectType.workoutType()
        
        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            guard let workouts = samples as? [HKWorkout] else {
                completion([])
                return
            }
            DispatchQueue.main.async {
                completion(workouts)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func fetchActiveEnergyBurned(for workout: HKWorkout) {
        let predicate = HKQuery.predicateForObjects(from: workout)
        let query = HKStatisticsQuery(quantityType: energyBurnedType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            guard let self = self, let result = result, let sum = result.sumQuantity() else { return }
            DispatchQueue.main.async {
                self.activeEnergyBurned = sum.doubleValue(for: .kilocalorie())
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchActiveEnergyBurnedForSingleWorkout(for workout: HKWorkout, completion: @escaping (Double) -> Void) {
        let predicate = HKQuery.predicateForObjects(from: workout)
        let energyBurnedType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        
        let query = HKStatisticsQuery(quantityType: energyBurnedType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else {
                DispatchQueue.main.async {
                    completion(0.0)
                }
                return
            }
            let energyBurned = sum.doubleValue(for: .kilocalorie())
            DispatchQueue.main.async {
                completion(energyBurned)
            }
        }
        
        healthStore.execute(query)
    }
    
//    func checkAndScheduleNotifications(sessions: [SkateSession]) {
//        clearNotificationsAtStartOfDay()
//        
//        let calendar = Calendar.current
//        let currentDate = Date()
//        let startOfDay = calendar.startOfDay(for: currentDate)
//        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
//        
//        let todaySessions = sessions.filter { session in
//            guard let date = session.date else { return false }
//            return date >= startOfDay && date < endOfDay
//        }
//        
//        if !todaySessions.isEmpty {
//            print("Skipped scheduling notifications: SkateSession already exists for today")
//            return
//        }
//        
//        if let latestWorkout = latestWorkout {
//            scheduleNotificationsForWorkout(latestWorkout)
//        }
//    }
    
//    private func clearNotificationsAtStartOfDay() {
//        let calendar = Calendar.current
//        let startOfDay = calendar.startOfDay(for: Date())
//        
//        // Schedule the clearing of notifications at the start of each day
//        let content = UNMutableNotificationContent()
//        content.title = "Clear Notifications"
//        content.body = "Clearing old notifications"
//        content.sound = .default
//        
//        let trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.hour, .minute, .second], from: startOfDay), repeats: true)
//        
//        let request = UNNotificationRequest(identifier: "ClearNotifications", content: content, trigger: trigger)
//        
//        UNUserNotificationCenter.current().add(request) { error in
//            if let error = error {
//                print("Error scheduling clear notifications: \(error)")
//            } else {
//                print("Clear notifications scheduled successfully")
//            }
//        }
//        
//        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
//    }

//    private func scheduleNotificationsForWorkout(_ workout: HKWorkout) {
//        let notificationInterval: TimeInterval = 30 * 60 // 30 minutes
//        
//        let content = UNMutableNotificationContent()
//        content.title = "Skate Session Completed"
//        content.body = "Don't forget to log your skate session!"
//        content.sound = .default
//        
//        let triggerDate = workout.endDate.addingTimeInterval(notificationInterval)
//        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
//        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
//        
//        let request = UNNotificationRequest(identifier: "SkateSessionReminder_\(workout.uuid)", content: content, trigger: trigger)
//        
//        UNUserNotificationCenter.current().add(request) { error in
//            if let error = error {
//                print("Error scheduling notification: \(error)")
//            } else {
//                print("Notification scheduled successfully for: \(triggerDate)")
//            }
//        }
//    }
//
//    func handleBackgroundUpdate() {
//        fetchLatestWorkout()
//        if let latestWorkout = latestWorkout {
//            scheduleNotificationsForWorkout(latestWorkout)
//        }
//    }
}
