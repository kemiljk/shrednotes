//
//  HealthKitManager.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//

import HealthKit
import UserNotifications
import SwiftData

@MainActor
@Observable
final class HealthKitManager {
    @ObservationIgnored private lazy var healthStore: HKHealthStore = {
        return HKHealthStore()
    }()

    private(set) var latestWorkout: HKWorkout?
    private(set) var allSkateboardingWorkouts: [HKWorkout] = []
    private(set) var activeEnergyBurned: Double = 0
    private(set) var energyBurnedCache: [UUID: Double] = [:]

    var latestActiveEnergyBurned: Double = 0
    var latestTotalDuration: TimeInterval = 0

    @ObservationIgnored private let workoutType = HKObjectType.workoutType()
    @ObservationIgnored private let energyBurnedType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!

    @ObservationIgnored private var workoutObserverQuery: HKAnchoredObjectQuery?

    @MainActor static let shared = HealthKitManager()

    init() {}

    func requestAuthorization(completion: @MainActor @Sendable @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            completion(false)
            return
        }

        let typesToShare: Set = [HKObjectType.workoutType()]
        let typesToRead: Set = [HKObjectType.workoutType(), HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
            if let error = error {
                print("HealthKit authorization error: \(error.localizedDescription)")
            }
            Task { @MainActor in
                if success {
                    UserDefaults.standard.set(true, forKey: "HealthAccessGranted")
                    HealthKitManager.shared.fetchLatestWorkout()
                }
                completion(success)
            }
        }
    }

    func fetchLatestWorkout() {
        let predicate = HKQuery.predicateForWorkouts(with: .skatingSports)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let samples = samples as? [HKWorkout], let latestWorkout = samples.first else { return }
            Task { @MainActor in
                let manager = HealthKitManager.shared
                manager.latestWorkout = latestWorkout
                manager.latestTotalDuration = latestWorkout.duration

                let energy = await manager.fetchActiveEnergyBurnedAsync(for: latestWorkout)
                manager.latestActiveEnergyBurned = energy
            }
        }

        healthStore.execute(query)
    }

    func fetchAllSkateboardingWorkouts() {
        let predicate = HKQuery.predicateForWorkouts(with: .skatingSports)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let samples = samples as? [HKWorkout] else { return }
            Task { @MainActor in
                HealthKitManager.shared.allSkateboardingWorkouts = samples
            }
        }

        healthStore.execute(query)
    }

    func sumWorkoutData(workouts: [HKWorkout]) async -> (TimeInterval, Double) {
        let totalDuration = workouts.reduce(0) { $0 + $1.duration }
        let totalEnergy = await withTaskGroup(of: Double.self) { group in
            for workout in workouts {
                group.addTask { [weak self] in
                    guard let self else { return 0 }
                    return await self.fetchActiveEnergyBurnedAsync(for: workout)
                }
            }
            var sum: Double = 0
            for await energy in group {
                sum += energy
            }
            return sum
        }
        return (totalDuration, totalEnergy)
    }

    // Backwards-compatible callback wrapper for older call sites.
    func sumWorkoutData(workouts: [HKWorkout], completion: @MainActor @Sendable @escaping (TimeInterval, Double) -> Void) {
        Task { @MainActor in
            let result = await self.sumWorkoutData(workouts: workouts)
            completion(result.0, result.1)
        }
    }

    func fetchWorkoutsForDate(_ date: Date, completion: @MainActor @Sendable @escaping ([HKWorkout]) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let datePredicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let skatingSportsPredicate = HKQuery.predicateForWorkouts(with: .skatingSports)
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, skatingSportsPredicate])

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

        let workoutType: HKSampleType = HKObjectType.workoutType()

        let query = HKSampleQuery(sampleType: workoutType, predicate: compoundPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            let workouts = (samples as? [HKWorkout]) ?? []
            Task { @MainActor in
                completion(workouts)
            }
        }

        healthStore.execute(query)
    }

    private func fetchActiveEnergyBurned(for workout: HKWorkout) {
        let predicate = HKQuery.predicateForObjects(from: workout)
        let query = HKStatisticsQuery(quantityType: energyBurnedType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else { return }
            let value = sum.doubleValue(for: .kilocalorie())
            Task { @MainActor in
                HealthKitManager.shared.activeEnergyBurned = value
            }
        }

        healthStore.execute(query)
    }

    func fetchActiveEnergyBurnedAsync(for workout: HKWorkout) async -> Double {
        await withCheckedContinuation { (cont: CheckedContinuation<Double, Never>) in
            let predicate = HKQuery.predicateForObjects(from: workout)
            let energyBurnedType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            let query = HKStatisticsQuery(quantityType: energyBurnedType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                guard let result = result, let sum = result.sumQuantity() else {
                    cont.resume(returning: 0.0)
                    return
                }
                cont.resume(returning: sum.doubleValue(for: .kilocalorie()))
            }
            healthStore.execute(query)
        }
    }

    func fetchActiveEnergyBurnedForSingleWorkout(for workout: HKWorkout, completion: @MainActor @Sendable @escaping (Double) -> Void) {
        Task { @MainActor in
            let value = await self.fetchActiveEnergyBurnedAsync(for: workout)
            completion(value)
        }
    }
}
