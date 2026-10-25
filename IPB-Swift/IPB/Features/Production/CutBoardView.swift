import SwiftUI

struct CutBoardView: View {
    var body: some View {
        ContentUnavailableView("Tablero de corte", systemImage: "hammer", description: Text("En construcción"))
            .navigationTitle("Tablero de corte")
    }
}
