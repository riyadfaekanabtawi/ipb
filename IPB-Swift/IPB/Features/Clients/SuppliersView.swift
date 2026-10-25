import SwiftUI

struct SuppliersView: View {
    var body: some View {
        ContentUnavailableView("Proveedores", systemImage: "hammer", description: Text("En construcción"))
            .navigationTitle("Proveedores")
    }
}
