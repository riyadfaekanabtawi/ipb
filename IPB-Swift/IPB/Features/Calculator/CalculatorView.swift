import SwiftUI

struct CalculatorView: View {
    var body: some View {
        ContentUnavailableView("Calculadora", systemImage: "hammer", description: Text("En construcción"))
            .navigationTitle("Calculadora")
    }
}
