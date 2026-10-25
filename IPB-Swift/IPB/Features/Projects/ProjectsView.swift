import SwiftUI

struct ProjectsView: View {
    var body: some View {
        ContentUnavailableView("Proyectos", systemImage: "hammer", description: Text("En construcción"))
            .navigationTitle("Proyectos")
    }
}
