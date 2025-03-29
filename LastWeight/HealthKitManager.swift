import HealthKit
import SwiftUI

// MARK: - HealthKitManager: Handles permissions and weight data from HealthKit
class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()

    // Publishes weight data to SwiftUI views that use this manager
    @Published var weightData: [(date: Date, weight: Double)] = []

    // MARK: - Authorization: Check if app has access to HealthKit data
    func checkHealthKitAuthorization(completion: @escaping (Bool) -> Void) {
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            print("❌ HealthKit weight type not available.")
            completion(false)
            return
        }

        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit is not available on this device.")
            completion(false)
            return
        }

        // Check current authorization status
        let authorizationStatus = healthStore.authorizationStatus(for: weightType)

        switch authorizationStatus {
        case .sharingAuthorized:
            print("✅ HealthKit access is already granted.")
            completion(true)

        case .notDetermined:
            print("⚠️ HealthKit access is NOT granted. Requesting permission...")
            self.requestAuthorization { success, _ in
                completion(success)
            }

        default:
            print("⚠️ HealthKit access previously denied or restricted.")
            completion(false)
        }
    }

    // MARK: - Request Authorization from the user
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            print("❌ HealthKit weight type not available.")
            completion(false, nil)
            return
        }

        let typesToRead: Set = [weightType]

        print("🔍 Requesting HealthKit permission...")

        healthStore.requestAuthorization(toShare: [], read: typesToRead) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ HealthKit permissions granted.")
                } else {
                    print("❌ HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
                }
                completion(success, error)
            }
        }
    }

    // MARK: - Fetch Weight Data from HealthKit
    func fetchWeightData(daysToIgnore: Int = 7) {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            print("❌ Could not get quantity type for body mass.")
            return
        }

        let startDate = Calendar.current.date(byAdding: .year, value: -15, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        let query = HKSampleQuery(
            sampleType: weightType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [
                NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            ]
        ) { _, samples, error in
            if let error = error {
                print("❌ Error fetching weight samples: \(error.localizedDescription)")
                return
            }

            guard let samples = samples as? [HKQuantitySample] else {
                print("❌ Unable to cast samples to HKQuantitySample")
                return
            }

            let weightData = samples.map {
                ($0.startDate, $0.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo)))
            }

            DispatchQueue.main.async {
                self.weightData = weightData
                print("✅ Retrieved \(weightData.count) weight entries from HealthKit.")
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Logic to Find "Last Time You Were This Weight"
    func findLastClosestWeight(daysToIgnore: Int = 14) -> (date: Date, weight: Double)? {
        guard let latestWeightSample = weightData.first else { return nil }
        let latestWeight = latestWeightSample.weight

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysToIgnore, to: Date())!

        let pastWeights = weightData.filter { $0.date < cutoffDate }

        let closestWeightEntry = pastWeights.min(by: {
            abs($0.weight - latestWeight) < abs($1.weight - latestWeight)
        })

        return closestWeightEntry
    }
}
