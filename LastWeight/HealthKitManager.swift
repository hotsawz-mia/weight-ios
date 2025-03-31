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

        if HKHealthStore.isHealthDataAvailable() {
            let typesToRead: Set = [weightType]

            print("🔍 Requesting read access to HealthKit (non-interactive if already granted)")
            healthStore.requestAuthorization(toShare: [], read: typesToRead) { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("✅ HealthKit read permission confirmed.")
                    } else {
                        print("❌ Failed to confirm HealthKit access: \(error?.localizedDescription ?? "Unknown error")")
                    }
                    completion(success)
                }
            }
        } else {
            print("❌ Health data not available on this device.")
            completion(false)
        }
    }

    // MARK: - Fetch Weight Data from HealthKit
    func fetchWeightData(daysToIgnore: Int = 7) {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }

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
            guard let samples = samples as? [HKQuantitySample], error == nil else {
                print("❌ Failed to fetch weight data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            let weightData = samples.map {
                ($0.startDate, $0.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo)))
            }

            DispatchQueue.main.async {
                self.weightData = weightData
                print("📦 HealthKit returned \(weightData.count) weight samples")
                if let first = weightData.first {
                    print("👉 Most recent: \(first.1) kg on \(first.0)")
                }
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
