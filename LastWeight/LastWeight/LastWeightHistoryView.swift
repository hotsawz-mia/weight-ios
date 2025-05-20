import SwiftUI // Import SwiftUI for building the UI

// MARK: - LastWeightHistoryView: Shows a list of historical weight entries
struct LastWeightHistoryView: View {
    // Connects to the shared HealthKit manager (data must be observed)
    @ObservedObject var healthKitManager: HealthKitManager
    
    // Use the user's preferred weight unit
    @AppStorage("preferredWeightUnit") private var weightUnit: WeightUnit = .kg

    var body: some View {
        VStack(spacing: 20) {
            // 🏷️ Title
            Text("Weight History")
                .font(.largeTitle)
                .bold()

            // 📜 List of weight records
            List(healthKitManager.weightData, id: \.date) { entry in
                let convertedWeight = weightUnit.convert(entry.weight)
                Text("\(formatDate(entry.date)): \(convertedWeight, specifier: "%.1f") \(weightUnit.rawValue)")
                // Example: "Mar 28, 2025: 72.3 kg" or "Mar 28, 2025: 159.2 lb"
            }
        }
        .padding()
        .onAppear {
            // 🔄 Fetch the latest weight data when the view appears
            healthKitManager.fetchWeightData()
        }
    }

    // MARK: - Helper: Format a Date object into a readable string
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    // This creates a preview version with a fresh HealthKitManager
    LastWeightHistoryView(healthKitManager: HealthKitManager())
}
