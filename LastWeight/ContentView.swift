
import SwiftUI
import UIKit // Needed for opening Settings



struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var lastClosestWeight: (date: Date, weight: Double)? = nil
    @State private var currentEmoji: String = "🎉"
    @State private var showPermissionAlert = false
    @State private var isHealthKitAuthorized = true

    
    enum DateDisplayMode {
        case daysAgo
        case ageAtTime
    }

    @State private var dateDisplayMode: DateDisplayMode = .daysAgo
    
    let celebratoryEmojis = ["🎉", "🎊", "🏆", "🥳", "👏", "🚀", "🎈", "✨", "💪"]
    
    var body: some View {
        ZStack {
            // MARK: - Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            NavigationView {
                VStack(spacing: 30) {
                    
                    // MARK: - Glowing Emoji Badge
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#FACC38"))
                            .frame(width: 120, height: 120)
                            .shadow(color: Color(hex: "#FACC38").opacity(0.5), radius: 10, x: 0, y: 4)
                        
                        Text(currentEmoji)
                            .font(.system(size: 60))
                            .transition(.scale.combined(with: .opacity))
                            .animation(.spring(), value: currentEmoji)
                    }

                    // MARK: - Result Text
                    if let closestWeight = lastClosestWeight {
                        let currentWeight = healthKitManager.weightData.first?.weight ?? closestWeight.weight
                        let difference = currentWeight - closestWeight.weight
                        let cutoffDate = closestWeight.date

                        VStack(spacing: 8) {
                            Text("Weight déjà vu achieved 🌀")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                Text(displayString(for: closestWeight.date))
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)

                                Button(action: {
                                    withAnimation {
                                        switch dateDisplayMode {
                                        case .daysAgo:
                                            dateDisplayMode = .ageAtTime
                                        case .ageAtTime:
                                            dateDisplayMode = .daysAgo
                                        }
                                    }
                                }) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundColor(.gray)
                                        .imageScale(.medium)
                                }
                                .buttonStyle(.plain)
                            }

                            if abs(difference) > 0.1 {
                                Text("You're \(String(format: "%.1f", abs(difference))) kg away from matching that weight.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            // 🔽 Find and show next older/lower weight milestone
                            if let nextOlder = healthKitManager.weightData.first(where: {
                                $0.date < cutoffDate && $0.weight < currentWeight
                            }) {
                                let nextDiff = currentWeight - nextOlder.weight

                                Text("Lose \(String(format: "%.1f", nextDiff)) kg to match your weight from \(formatDateWithDaysAgo(nextOlder.date))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Text("Scanning your time-warped body data…")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }

                    // MARK: - HealthKit Permission Badge
                    if !isHealthKitAuthorized {
                        Label("Health access not granted", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }

                    // MARK: - Buttons
                    VStack(spacing: 16) {
                        Button(action: {
                            print("🔄 Refresh button tapped")
                            healthKitManager.checkHealthKitAuthorization { authorized in
                                isHealthKitAuthorized = authorized
                                if authorized {
                                    print("✅ Refresh authorized. Fetching and updating.")
                                    healthKitManager.fetchWeightData()
                                    lastClosestWeight = healthKitManager.findLastClosestWeight()
                                    currentEmoji = randomCelebratoryEmoji()
                                } else {
                                    print("❌ HealthKit access not granted. Prompt user.")
                                    showPermissionAlert = true
                                }
                            }
                        }) {
                            Text("Refresh")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(hex: "#FACC38"))
                                .foregroundColor(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                        }
                        
                        NavigationLink(destination: LastWeightHistoryView(healthKitManager: healthKitManager)) {
                            Text("View Weight History")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)

                    // MARK: - Footer Fun
                    Spacer()
                    Text("Your past self says hi 👋")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .onAppear {
                checkAndFetchHealthData()
            }
        }
        .alert("Health Access Needed", isPresented: $showPermissionAlert) {
            Button("Open Health App") {
                // While we can't deep link to Health permissions, we clarify instructions in the message below
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("""
Last Weight needs access to your weight data in the Health app to work properly.

To enable it:
1. Open the Health app
2. Tap your profile (top right)
3. Go to Privacy > Apps > Last Weight
4. Enable Body Mass access
""")
        }
    }
    
    // MARK: - Helpers

    func checkAndFetchHealthData() {
        print("📡 Checking HealthKit authorization...")
        healthKitManager.checkHealthKitAuthorization { authorized in
            isHealthKitAuthorized = authorized
            print("🔁 Authorization result: \(authorized)")
            if authorized {
                print("🚀 Fetching data from HealthKit")
                healthKitManager.fetchWeightData()
                lastClosestWeight = healthKitManager.findLastClosestWeight()
            } else {
                print("⚠️ HealthKit access missing.")
                showPermissionAlert = true
            }
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    func randomCelebratoryEmoji() -> String {
        celebratoryEmojis.randomElement() ?? "🎉"
    }

    func daysAgo(from date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }

    func formatDateWithDaysAgo(_ date: Date) -> String {
        let dateString = formatDate(date)
        let days = daysAgo(from: date)
        return "\(dateString) (\(days) days ago)"
    }
    
    func displayString(for date: Date) -> String {
        switch dateDisplayMode {
        case .daysAgo:
            let days = daysAgo(from: date)
            return "\(days) days ago"
        case .ageAtTime:
            let ageComponents = Calendar.current.dateComponents([.year, .month], from: DateComponents(calendar: .current, year: 1980, month: 1, day: 18).date!, to: date)
            let years = ageComponents.year ?? 0
            let months = ageComponents.month ?? 0
            return "Age: \(years)y \(months)m"
        }
    }
}

#Preview {
    ContentView()
}

// MARK: - Hex Color Support
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var int: UInt64 = 0
        scanner.scanHexInt64(&int)

        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
