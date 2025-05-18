import SwiftUI

struct WeightUnitToggle: View {
    @AppStorage("preferredWeightUnit") private var weightUnit: WeightUnit = .kg
    
    var body: some View {
        Text(weightUnit.rawValue)
            .font(.subheadline)
            .foregroundColor(.blue)
            .padding(.horizontal, 4)
            .onTapGesture {
                weightUnit = weightUnit == .kg ? .lb : .kg
            }
    }
}

#Preview {
    WeightUnitToggle()
}
