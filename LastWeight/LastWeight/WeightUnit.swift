enum WeightUnit: String {
    case kg = "kg"
    case lb = "lb"
    
    var conversionFactor: Double {
        switch self {
        case .kg: return 1.0
        case .lb: return 2.20462
        }
    }
    
    func convert(_ weight: Double) -> Double {
        return weight * conversionFactor
    }
}
