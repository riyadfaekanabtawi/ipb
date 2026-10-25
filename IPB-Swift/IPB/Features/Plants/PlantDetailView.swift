import SwiftUI

struct PlantDetailView: View {
    @ObservedObject var plant: Plant

    var body: some View {
        ContentUnavailableView("Planta", systemImage: "hammer", description: Text("En construcción"))
            .navigationTitle("Planta")
    }
}
