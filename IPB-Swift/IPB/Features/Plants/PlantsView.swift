import SwiftUI

struct PlantsView: View {
    var body: some View {
        ContentUnavailableView("Plantas", systemImage: "hammer", description: Text("En construcción"))
            .navigationTitle("Plantas")
    }
}
