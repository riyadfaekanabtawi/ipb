import SwiftUI

struct ProductionReportsView: View {
    var body: some View {
        ContentUnavailableView("Reportes de producción", systemImage: "hammer", description: Text("En construcción"))
            .navigationTitle("Reportes de producción")
    }
}
