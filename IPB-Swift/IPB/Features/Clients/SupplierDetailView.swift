import SwiftUI

struct SupplierDetailView: View {
    @ObservedObject var supplier: Supplier

    var body: some View {
        ContentUnavailableView("Proveedor", systemImage: "hammer", description: Text("En construcción"))
            .navigationTitle("Proveedor")
    }
}
