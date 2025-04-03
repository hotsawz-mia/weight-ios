import SwiftUI
import UIKit // Needed for opening Settings
import PhotosUI // For PHPicker to trigger full photo access

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var lastClosestWeight: (date: Date, weight: Double)? = nil
    @State private var currentEmoji: String = "🎉"
    @State private var showPermissionAlert = false
    @State private var isHealthKitAuthorized = true
    @State private var showPermissionPrompt = false
    @State private var showUpgradePhotoAccessAlert = false

    enum DateDisplayMode {
        case daysAgo
        case ageAtTime
        case photo
    }

    @State private var dateDisplayMode: DateDisplayMode = .daysAgo

    let celebratoryEmojis = ["🎉", "🎊", "🏆", "🥳", "👏", "🚀", "🎈", "✨", "💪"]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            NavigationView {
                VStack(spacing: 30) {
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

                    if let closestWeight = lastClosestWeight {
                        let currentWeight = healthKitManager.weightData.first?.weight ?? closestWeight.weight
                        let difference = currentWeight - closestWeight.weight
                        let cutoffDate = closestWeight.date

                        VStack(spacing: 8) {
                            Text("Weight déjà vu achieved 🌀")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                Group {
                                    switch dateDisplayMode {
                                    case .daysAgo, .ageAtTime:
                                        Text(displayString(for: closestWeight.date))
                                    case .photo:
                                        if let image = healthKitManager.selfieForDate {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                .shadow(radius: 3)
                                        } else {
                                            Text("No photo found 📷")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                                Button(action: {
                                    withAnimation {
                                        switch dateDisplayMode {
                                        case .daysAgo:
                                            dateDisplayMode = .ageAtTime
                                        case .ageAtTime:
                                            dateDisplayMode = .photo
                                        case .photo:
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

                    if !isHealthKitAuthorized {
                        Label("Health access not granted", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }

                    VStack(spacing: 16) {
                        Button(action: {
                            print("🔄 Refresh button tapped")
                            healthKitManager.checkHealthKitAuthorization { authorized in
                                isHealthKitAuthorized = authorized
                                if authorized {
                                    print("✅ Refresh authorized. Fetching and updating.")
                                    healthKitManager.fetchWeightData()
                                    lastClosestWeight = healthKitManager.findLastClosestWeight()
                                    if let match = lastClosestWeight, dateDisplayMode == .photo {
                                        healthKitManager.fetchClosestSelfie(to: match.date)
                                    }
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

                    Spacer()
                    Text("Your past self says hi 👋")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .onAppear {
                print("📱 App appeared. Checking HealthKit and photo permissions…")
                checkAndFetchHealthData()
                let photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                print("📸 Current photo auth status: \(readablePhotoStatus())")

                if photoStatus == .limited {
                    print("⚠️ User has limited photo access. Will show upgrade alert.")
                    showUpgradePhotoAccessAlert = true
                } else if photoStatus == .notDetermined {
                    print("🟡 Photo permission not yet requested. Will show prompt.")
                    showPermissionPrompt = true
                } else {
                    print("✅ Full photo access already granted. No need to prompt.")
                }
            }
        }
        .onChange(of: dateDisplayMode) {
            if dateDisplayMode == .photo, let match = lastClosestWeight {
                healthKitManager.fetchClosestSelfie(to: match.date)
            }
        }
        .alert("Health Access Needed", isPresented: $showPermissionAlert) {
            Button("Open Health App") {
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
        .sheet(isPresented: $showPermissionPrompt) {
            PhotoPermissionRequestView {
                showUpgradePhotoAccessAlert = true
            }
        }
        .onChange(of: showPermissionPrompt) {
            if showPermissionPrompt {
                print("📤 Showing photo picker to trigger initial permission request")
            }
        }
        .alert("Want Better Selfie Matching?", isPresented: $showUpgradePhotoAccessAlert) {
            Button("Go to Settings") {
                print("🔗 User tapped 'Go to Settings' to upgrade photo access")
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not Now", role: .cancel) { }
        } message: {
            Text("To allow Last Weight to find selfies from key moments, please enable full photo access in Settings.")
        }
    }

    func checkAndFetchHealthData() {
        print("📡 Checking HealthKit authorization…")
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
            let ageComponents = Calendar.current.dateComponents(
                [.year, .month],
                from: DateComponents(calendar: .current, year: 1980, month: 1, day: 18).date!,
                to: date
            )
            let years = ageComponents.year ?? 0
            let months = ageComponents.month ?? 0
            return "Age: \(years)y \(months)m"
        case .photo:
            return ""
        }
    }

    func readablePhotoStatus() -> String {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .limited: return "limited"
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        @unknown default: return "unknown"
        }
    }
}

#Preview {
    ContentView()
}

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
