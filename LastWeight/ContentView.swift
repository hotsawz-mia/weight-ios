import SwiftUI
import UIKit
import PhotosUI
import Combine
import FirebaseAnalytics

struct ContentView: View {
    // MARK: - State and Storage

    @StateObject private var healthKitManager = HealthKitManager() // Manages HealthKit interactions
    @State private var lastClosestWeight: (date: Date, weight: Double)? = nil // Holds the most recent matching weight
    @State private var showPermissionAlert = false // Triggers alert if HealthKit permissions aren't granted
    @State private var isHealthKitAuthorized = true // Reflects HealthKit permission status
    @State private var showPermissionPrompt = false // Triggers photo access prompt
    @State private var showUpgradePhotoAccessAlert = false // Triggers alert for upgrading limited photo access

    @AppStorage("userDOB") private var storedDOB: Double = 0 // Stores the user's date of birth as timeIntervalSince1970
    @State private var showDOBPicker = false // Controls visibility of date picker
    @State private var dob: Date = Calendar.current.date(from: DateComponents(year: 1980, month: 1, day: 18)) ?? Date() // Local DOB state used in date picker

    @State private var showCelebration = false // Controls celebratory emoji animation

    @State private var currentWeightMatchDate: Date? // For daysAgo and ageAtTime
    
    // Enum for display mode selector
    enum DateDisplayMode: String, CaseIterable {
        case daysAgo = "Days"
        case ageAtTime = "Age"
        case photo = "Photo"
    }

    @State private var dateDisplayMode: DateDisplayMode = .daysAgo // Controls current display mode

    // Computed property for safely accessing stored DOB
    var dateOfBirth: Date {
        if storedDOB > 0 {
            return Date(timeIntervalSince1970: storedDOB)
        } else {
            return Calendar.current.date(from: DateComponents(year: 1980, month: 1, day: 18)) ?? Date()
        }
    }

    var celebratoryEmojis = ["🎉", "🎊", "🏆", "🥳", "👏", "🚀", "🎈", "✨", "💪"]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            NavigationView {
                VStack(spacing: 0) {
                    // MARK: - Top Bar (Refresh Button)
                    HStack {
                        Spacer()
                        Button(action: {
                            refresh()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                        .padding()
                    }

                    // MARK: - Celebration Emoji
                    if showCelebration {
                        Text(celebratoryEmojis.randomElement() ?? "🎉")
                            .font(.system(size: 48))
                            .scaleEffect(1.3)
                            .opacity(0.9)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.spring(), value: showCelebration)
                    }

                    // MARK: - Main Display
                    if let closestWeight = lastClosestWeight {
                        Group {
                            switch dateDisplayMode {
                            case .daysAgo:
                                if let matchDate = currentWeightMatchDate {
                                    Text(displayString(for: matchDate))
                                    // Text("🧪 Days mode date: \(formatDate(matchDate))") // ← DEBUG

                                } else {
                                    if let current = healthKitManager.weightData.first {
                                        let cutoffDate = Calendar.current.date(byAdding: .day, value: -weightMatchCutoffDays, to: Date())!
                                        let currentWeight = current.weight
                                        let allWeights = healthKitManager.weightData.count
                                        let matchingWeights = healthKitManager.weightData
                                            .filter { $0.date < cutoffDate && $0.weight < currentWeight - 0.1 }

                                        let message = """
                                        No match found
                                        Current weight: \(String(format: "%.1f", currentWeight))kg
                                        Total records: \(allWeights)
                                        Matching records: \(matchingWeights.count)
                                        \(matchingWeights.first.map { "Example: \($0.weight)kg on \(formatDate($0.date))" } ?? "")
                                        """

                                        Text(message)
                                            .font(.caption)
                                            .foregroundColor(.red)
                                            .multilineTextAlignment(.center)
                                            .padding()
                                    } else {
                                        Text("No data available")
                                    }
                                }
                            case .ageAtTime:
                                HStack(spacing: 4) {
                                    Button(action: {
                                        showDOBPicker = true
                                    }) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(6)
                                            .background(Circle().fill(Color.blue))
                                    }
                                    Text(displayString(for: closestWeight.date))
                                    // Text("🧪 Age mode date: \(formatDate(closestWeight.date))") // ← DEBUG
                                }
                            case .photo:
                                if let image = healthKitManager.selfieForDate {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: .infinity, maxHeight: 300)
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
                        .padding()
                    } else {
                        Text("Scanning your time-warped body data…")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding()
                    }

                    Spacer()

                    // MARK: - Footer Section
                    VStack(spacing: 32) {
                        if let currentSample = healthKitManager.weightData.first {
                            let currentWeight = currentSample.weight
                            let currentWeightDate = currentSample.date

                            // 👇 Show the current weight and its date
                            // Text("Current weight: \(String(format: "%.1f", currentWeight)) kg on \(formatDate(currentWeightDate))")
                                // .font(.footnote)
                                // foregroundColor(.gray)
                                // .padding(.bottom, 4)

                            let cutoffDate = Date()
                            let nextLower = healthKitManager.weightData
                                .filter { $0.date < cutoffDate && $0.weight < currentWeight - 0.1 } // Apply small buffer
                                .sorted(by: { $0.date > $1.date }) // Sort most recent first
                                .first

                            if let referenceWeight = lastClosestWeight {
                                let previousLowerMatch = healthKitManager.weightData
                                    .filter { $0.date < referenceWeight.date && $0.weight < referenceWeight.weight - 0.1 }
                                    .sorted(by: { $0.date > $1.date })
                                    .first

                                if let match = previousLowerMatch {
                                    let diff = referenceWeight.weight - match.weight
                                    Text("Lose \(String(format: "%.1f", diff)) kg to match your weight from \(formatDateWithDaysAgo(match.date))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                            }
                        }

                        // MARK: - Segmented Picker
                        Picker("Display Mode", selection: $dateDisplayMode) {
                            ForEach(DateDisplayMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        .onChange(of: dateDisplayMode) { _, newValue in
                            Analytics.logEvent("switched_display_mode", parameters: [
                                "mode": newValue.rawValue
                            ])

                            switch newValue {
                            case .photo:
                                if let match = lastClosestWeight {
                                    healthKitManager.fetchClosestSelfie(to: match.date)
                                }
                            case .ageAtTime:
                                if storedDOB == 0 {
                                    showDOBPicker = true
                                    Analytics.logEvent("shown_dob_picker", parameters: nil)
                                }
                            case .daysAgo:
                                break
                            }
                        }

                        HStack(spacing: 32) {
                            NavigationLink(destination: LastWeightHistoryView(healthKitManager: healthKitManager)) {
                                Text("Weight History")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                Analytics.logEvent("tapped_weight_history", parameters: nil)
                            })

                            Text("Your past self says hi 👋")
                                .font(.caption)
                                .foregroundColor(.gray)

                            Button(action: {
                                Analytics.logEvent("tapped_feedback", parameters: nil)
                                if let url = URL(string: "mailto:lastweight@markchristianjames.com") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("Feedback")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.bottom)
                }
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    checkAndFetchHealthData()
                    
//                    Analytics.logEvent("debug_test_event", parameters: [
//                        "source": "launch"
//                    ])
//                    
//                    print("📡 Logging debug event now...")
//                    Analytics.logEvent("debug_test_event", parameters: ["context": "manual_debug"])
                    
                    let photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

                    if photoStatus == .authorized {
                        Analytics.logEvent("accepted_photo_permission", parameters: nil)
                    } else if photoStatus == .limited {
                        showUpgradePhotoAccessAlert = true
                    } else if photoStatus == .notDetermined {
                        Analytics.logEvent("shown_photo_permission", parameters: nil)
                        showPermissionPrompt = true
                    }

                    withAnimation {
                        showCelebration = true
                    }
                }
            }
        }
        // MARK: - Sheets and Alerts
        .sheet(isPresented: $showPermissionPrompt) {
            PhotoPermissionRequestView(onLimitedAccessDetected: {
                showUpgradePhotoAccessAlert = true
            })
        }
        .sheet(isPresented: $showDOBPicker) {
            VStack(spacing: 16) {
                Text("When were you born?")
                    .font(.headline)

                DatePicker("Select your date of birth", selection: $dob, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()

                Button("Done") {
                    storedDOB = dob.timeIntervalSince1970
                    Analytics.logEvent("set_dob", parameters: [
                        "year": Calendar.current.component(.year, from: dob),
                        "month": Calendar.current.component(.month, from: dob)
                    ])
                    showDOBPicker = false
                }
                .padding()
            }
            .padding()
        }
        .onChange(of: storedDOB) {
            if dateDisplayMode == .ageAtTime {
                   lastClosestWeight = healthKitManager.findLastClosestWeight()
                   updateCurrentWeightMatchDate()
               }
            if dateDisplayMode == .ageAtTime {
                lastClosestWeight = healthKitManager.findLastClosestWeight()
                if let current = healthKitManager.weightData.first {
                    let cutoffDate = Calendar.current.date(byAdding: .day, value: -weightMatchCutoffDays, to: Date())!
                    let match = healthKitManager.weightData
                        .filter { $0.date < cutoffDate && $0.weight < current.weight - 0.1 }
                        .sorted(by: { $0.date > $1.date })
                        .first

                    currentWeightMatchDate = match?.date
                }
            }
        }
        .alert("Health Access Needed", isPresented: $showPermissionAlert) {
            Button("Open Health App") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
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
        .alert("Want Better Selfie Matching?", isPresented: $showUpgradePhotoAccessAlert) {
            Button("Go to Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("To allow Last Weight to find selfies from key moments, please enable full photo access in Settings.")
        }
    }

    // MARK: - Refresh Handler
    func refresh() {
        print("🔄 Manual refresh triggered")
        Analytics.logEvent("tapped_refresh", parameters: nil)

        healthKitManager.checkHealthKitAuthorization { authorized in
            isHealthKitAuthorized = authorized

            if authorized {
                healthKitManager.fetchWeightData {
                    lastClosestWeight = healthKitManager.findLastClosestWeight()
                    updateCurrentWeightMatchDate()

                    if dateDisplayMode == .photo, let match = lastClosestWeight {
                        healthKitManager.fetchClosestSelfie(to: match.date)
                    }
                }
            } else {
                showPermissionAlert = true
            }
        }
    }
    func updateCurrentWeightMatchDate() {
        if let current = healthKitManager.weightData.first {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -weightMatchCutoffDays, to: Date())!
            let match = healthKitManager.weightData
                .filter { $0.date < cutoffDate && $0.weight < current.weight - 0.1 }
                .sorted(by: { $0.date > $1.date })
                .first

            currentWeightMatchDate = match?.date
        }
    }

    // MARK: - Initial HealthKit Fetch
    func checkAndFetchHealthData() {
        healthKitManager.checkHealthKitAuthorization { authorized in
            isHealthKitAuthorized = authorized

            if authorized {
                Analytics.logEvent("accepted_healthkit_permission", parameters: nil)
                healthKitManager.fetchWeightData {
                    lastClosestWeight = healthKitManager.findLastClosestWeight()
                    updateCurrentWeightMatchDate()

                    if dateDisplayMode == .photo, let match = lastClosestWeight {
                        healthKitManager.fetchClosestSelfie(to: match.date)
                    }
                }
            } else {
                Analytics.logEvent("shown_healthkit_permission", parameters: nil)
                showPermissionAlert = true
            }
        }
    }

    // MARK: - Utility Formatters
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
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
            return "\(daysAgo(from: date)) days ago"
        case .ageAtTime:
            guard storedDOB != 0 else { return "Age unknown" }
            let dobDate = dateOfBirth
            let ageComponents = Calendar.current.dateComponents([.year, .month], from: dobDate, to: date)
            let years = ageComponents.year ?? 0
            let months = ageComponents.month ?? 0
            return "Age: \(years)y \(months)m"
        case .photo:
            return ""
        }
    }
}

// MARK: - Live Preview
#Preview {
    ContentView()
}

// MARK: - Color Hex Extension
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

