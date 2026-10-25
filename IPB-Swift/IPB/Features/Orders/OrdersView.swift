import SwiftUI

struct OrdersView: View {
    var body: some View {
        ContentUnavailableView("Cortes por asignar", systemImage: "hammer", description: Text("En construcción"))
            .navigationTitle("Cortes por asignar")
    }
}
