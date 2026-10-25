import SwiftUI

struct AssignmentDetailView: View {
    @ObservedObject var assignment: Assignment

    var body: some View {
        ContentUnavailableView("Corte", systemImage: "hammer", description: Text("En construcción"))
            .navigationTitle("Corte")
    }
}
