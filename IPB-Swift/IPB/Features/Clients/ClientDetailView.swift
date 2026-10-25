import SwiftUI

struct ClientDetailView: View {
    @ObservedObject var client: Client

    var body: some View {
        ContentUnavailableView("Cliente", systemImage: "hammer", description: Text("En construcción"))
            .navigationTitle("Cliente")
    }
}
