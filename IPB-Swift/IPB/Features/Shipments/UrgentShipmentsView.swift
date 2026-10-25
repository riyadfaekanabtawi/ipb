import SwiftUI

struct UrgentShipmentsView: View {
    var body: some View {
        ContentUnavailableView("Envíos urgentes", systemImage: "hammer", description: Text("En construcción"))
            .navigationTitle("Envíos urgentes")
    }
}
