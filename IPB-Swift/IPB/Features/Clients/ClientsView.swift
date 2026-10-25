import SwiftUI

struct ClientsView: View {
    var body: some View {
        ContentUnavailableView("Clientes", systemImage: "hammer", description: Text("En construcción"))
            .navigationTitle("Clientes")
    }
}
