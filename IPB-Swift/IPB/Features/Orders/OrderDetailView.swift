import SwiftUI

struct OrderDetailView: View {
    @ObservedObject var order: CutOrder

    var body: some View {
        ContentUnavailableView("Corte", systemImage: "hammer", description: Text("En construcción"))
            .navigationTitle("Corte")
    }
}
