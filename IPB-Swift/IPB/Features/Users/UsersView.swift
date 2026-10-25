import SwiftUI

struct UsersView: View {
    var body: some View {
        ContentUnavailableView("Usuarios", systemImage: "hammer", description: Text("En construcción"))
            .navigationTitle("Usuarios")
    }
}
