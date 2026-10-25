import CoreData
import Foundation
import Testing

@testable import IPB

@MainActor
@Suite("Production flow")
struct ProductionFlowTests {
    let persistence = PersistenceController(inMemory: true)

    @Test func plantManagersOnlySeeTheirPlant() throws {
        let context = persistence.viewContext
        DemoSeeder.seed(into: context)
        let session = Session(context: context, defaults: UserDefaults(suiteName: "flow-\(UUID())")!)
        try session.signIn(email: "planta@ipb.mx", password: DemoSeeder.demoPassword)
        let all = context.fetchAll(Assignment.self)
        let visible = session.visibleAssignments(all)
        #expect(!visible.isEmpty)
        #expect(visible.count < all.count)
        #expect(visible.allSatisfy { $0.plant == session.user?.plant })

        try session.signIn(email: "admin@ipb.mx", password: DemoSeeder.demoPassword)
        #expect(session.visibleAssignments(all).count == all.count)
    }

    @Test func kanbanMoveCreatesThenReusesTheCutReport() throws {
        let context = persistence.viewContext
        let service = ProductionService(context: context, author: "QA")
        let plant = Plant(context: context)
        plant.stampCreated()
        plant.maxCapacity = 1_000_000
        let order = try service.createOrder(
            code: "C-9", list: "L", garment: "Falda", quantity: 100, unitPrice: 5,
            client: nil, style: nil, ipbDate: nil, clientDate: nil, notes: nil)
        let assignment = try service.assign(order: order, to: plant, quantity: 100, date: .now)
        try service.move(assignment, to: .onTable)
        try service.setCutReport(status: .onTable, realQuantity: 97, on: assignment, editing: assignment.cutReport)
        try service.move(assignment, to: .ready)
        #expect(assignment.cutReport?.realQuantity == 97)
        #expect(assignment.cuttingStatus == .ready)
        #expect(assignment.reportList.count == 1)
    }

    @Test func csvEscapesAndIncludesHeader() throws {
        let context = persistence.viewContext
        DemoSeeder.seed(into: context)
        let rows = context.fetchAll(Assignment.self).map(ProductionRow.init)
        let csv = ProductionCSV(rows: rows).csv
        let lines = csv.split(separator: "\n")
        #expect(lines.count == rows.count + 1)
        #expect(lines.first?.hasPrefix("Corte,Lista,Cliente") == true)
    }
}
