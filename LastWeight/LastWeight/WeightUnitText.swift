import SwiftUI

struct WeightUnitText: View {
    let weight: Double
    let weightUnit: WeightUnit
    
    var body: some View {
        Text(String(format: "%.1f", weightUnit.convert(weight)))
            .foregroundColor(.blue)
        Text(" ")
        Text(weightUnit.rawValue)
            .foregroundColor(.blue)
    }
}

#Preview {
    WeightUnitText(weight: 1.2, weightUnit: .kg)
}
