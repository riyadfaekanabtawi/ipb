import SwiftUI

struct SettingsView: View {
    var body: some View {
        ContentUnavailableView("Ajustes", systemImage: "hammer", description: Text("En construcción"))
            .navigationTitle("Ajustes")
    }
}
