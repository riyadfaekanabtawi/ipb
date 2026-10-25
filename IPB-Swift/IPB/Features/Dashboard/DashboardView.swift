import SwiftUI

struct DashboardView: View {
    var body: some View {
        ContentUnavailableView("Dashboard", systemImage: "hammer", description: Text("En construcción"))
            .navigationTitle("Dashboard")
    }
}
