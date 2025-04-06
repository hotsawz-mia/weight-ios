import HealthKit
import SwiftUI
import Photos // make sure this is imported at the top

// MARK: - Utility to detect limited photo access
func hasLimitedPhotoAccess() -> Bool {
    return PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited
}

// MARK: - HealthKitManager: Handles permissions and weight data from HealthKit
class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore() // Interface to HealthKit
    private let imageManager = PHCachingImageManager() // Manages photo caching and retrieval

    // Publishes weight data and selfie image to any observing SwiftUI views
    @Published var weightData: [(date: Date, weight: Double)] = []
    @Published var selfieForDate: UIImage? = nil

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

    // MARK: - Fetch Weight Data from HealthKit with optional completion handler
    func fetchWeightData(daysToIgnore: Int = 7, completion: (() -> Void)? = nil) {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            completion?()
            return
        }

        let startDate = Calendar.current.date(byAdding: .year, value: -15, to: Date()) // Look back up to 15 years
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
                DispatchQueue.main.async {
                    completion?()
                }
                return
            }

            // Transform the data into a simpler format: (Date, weight in kg)
            let weightData = samples.map {
                ($0.startDate, $0.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo)))
            }

            DispatchQueue.main.async {
                self.weightData = weightData
                print("📦 HealthKit returned \(weightData.count) weight samples")
                if let first = weightData.first {
                    let (date, weight) = first
                    print("👉 Most recent: \(weight) kg on \(date)")
                }
                completion?()
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Logic to Find "Last Time You Were This Weight"
    func findLastClosestWeight(daysToIgnore: Int = 14) -> (date: Date, weight: Double)? {
        guard let latestWeightSample = weightData.first else { return nil }
        let latestWeight = latestWeightSample.weight

        // Ignore recent days to avoid false positives
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysToIgnore, to: Date())!
        let pastWeights = weightData.filter { $0.date < cutoffDate }

        // Find the past weight closest to the latest one
        let closestWeightEntry = pastWeights.min(by: {
            abs($0.weight - latestWeight) < abs($1.weight - latestWeight)
        })

        return closestWeightEntry
    }

    // MARK: - Fetch Selfie Closest to a Given Date
    func fetchClosestSelfie(to targetDate: Date) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            break // Carry on below
        case .notDetermined:
            print("📸 Requesting photo library permission...")
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        print("✅ Photo access granted after request.")
                        self.fetchClosestSelfie(to: targetDate) // Try again now that we have access
                    } else {
                        print("❌ Photo access denied after request.")
                    }
                }
            }
            return
        case .denied, .restricted:
            print("❌ Photo access denied or restricted.")
            return
        @unknown default:
            print("❓ Unknown photo permission status.")
            return
        }

        // Fetch selfies sorted by creation date
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let selfies = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumSelfPortraits, options: nil)

        guard let album = selfies.firstObject else {
            print("❌ No selfies album found.")
            return
        }

        let assets = PHAsset.fetchAssets(in: album, options: options)
        guard assets.count > 0 else {
            print("❌ No selfies found in album.")
            return
        }

        // Look for selfie closest to target date (within ~30 days)
        var closestAsset: PHAsset?
        var smallestDiff: TimeInterval = .greatestFiniteMagnitude

        assets.enumerateObjects { asset, _, _ in
            if let creationDate = asset.creationDate {
                let diff = abs(creationDate.timeIntervalSince(targetDate))
                let photoDateGap: TimeInterval = 60 * 60 * 24 * 30

                if diff < smallestDiff && diff <= photoDateGap {
                    smallestDiff = diff
                    closestAsset = asset
                }
            }
        }

        // Fetch the image from the chosen asset
        if let asset = closestAsset {
            print("📸 Closest selfie: \(asset.creationDate ?? Date())")
            let size = CGSize(width: 200, height: 200)
            imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: nil) { image, _ in
                DispatchQueue.main.async {
                    if let image = image {
                        self.selfieForDate = image
                        print("✅ Loaded selfie image")
                    } else {
                        print("❌ Failed to load image from asset")
                    }
                }
            }
        } else {
            print("❌ No suitable selfie found within 30 days.")
        }
    }
}
