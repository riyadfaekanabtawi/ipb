import SwiftUI

struct PlantCalendarView: View {
    var body: some View {
        ContentUnavailableView("Calendario de plantas", systemImage: "hammer", description: Text("En construcción"))
            .navigationTitle("Calendario de plantas")
    }
}
