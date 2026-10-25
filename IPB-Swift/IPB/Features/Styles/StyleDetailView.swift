import SwiftUI

struct StyleDetailView: View {
    @ObservedObject var style: Style

    var body: some View {
        ContentUnavailableView("Estilo", systemImage: "hammer", description: Text("En construcción"))
            .navigationTitle("Estilo")
    }
}
