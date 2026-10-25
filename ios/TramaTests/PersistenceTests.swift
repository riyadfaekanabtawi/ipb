import CoreData
import Foundation
import Testing

@testable import Trama

@MainActor
@Suite("Core Data + services")
struct PersistenceTests {
    let persistence = PersistenceController(inMemory: true)
    var context: NSManagedObjectContext { persistence.viewContext }

    private func makePlant(capacity: Double = 100_000) -> Plant {
        let p = Plant(context: context)
        p.stampCreated()
        p.name = "Planta Test"
        p.maxCapacity = capacity
        return p
    }

    private func makeOrder(qty: Int = 1_000, price: Double = 10) throws -> CutOrder {
        try ProductionService(context: context, author: "Test").createOrder(
            code: "C-1", list: "L-1", garment: "Falda", quantity: qty, unitPrice: price,
            client: nil, style: nil, internalDate: .now, clientDate: .now, notes: nil
        )
    }

    @Test func assignReducesRemainingAndUpdatesState() throws {
        let service = ProductionService(context: context, author: "Test")
        let plant = makePlant()
        let order = try makeOrder()
        #expect(order.assignmentState == .unassigned)
        try service.assign(order: order, to: plant, quantity: 400, date: .now)
        #expect(order.remainingQuantity == 600)
        #expect(order.assignmentState == .partial)
        try service.assign(order: order, to: plant, quantity: 600, date: .now)
        #expect(order.assignmentState == .assigned)
        #expect(throws: AssignmentError.self) { try service.assign(order: order, to: plant, quantity: 1, date: .now) }
    }

    @Test func assignRespectsMonthlyCapacity() throws {
        let service = ProductionService(context: context, author: "Test")
        let plant = makePlant(capacity: 5_000)
        let order = try makeOrder(qty: 1_000, price: 10)
        #expect(throws: AssignmentError.self) { try service.assign(order: order, to: plant, quantity: 600, date: .now) }
        try service.assign(order: order, to: plant, quantity: 500, date: .now)
        #expect(plant.ledger.available(inMonthOf: .now) == 0)
    }

    @Test func onlyOneCutReportPerAssignment() throws {
        let service = ProductionService(context: context, author: "Test")
        let a = try service.assign(order: try makeOrder(), to: makePlant(), quantity: 100, date: .now)
        try service.setCutReport(status: .onTable, realQuantity: 0, on: a)
        #expect(a.cuttingStatus == .onTable)
        #expect(throws: ProductionService.ServiceError.self) { try service.setCutReport(status: .ready, realQuantity: 99, on: a) }
        try service.move(a, to: .ready)
        #expect(a.cuttingStatus == .ready)
        #expect(a.reportList.filter { $0.kind == .cut }.count == 1)
    }

    @Test func metricsFlowThroughReports() throws {
        let service = ProductionService(context: context, author: "Test")
        let a = try service.assign(order: try makeOrder(), to: makePlant(), quantity: 300, date: .now)
        try service.addPlantReport(.init(operators: 5, produced: 120), to: a)
        try service.addShipmentReport(number: "E-1", quantity: 100, to: a)
        try service.addShipmentReport(number: "E-2", quantity: 50, to: a)
        #expect(a.metrics.produced == 120)
        #expect(a.metrics.shipped == 150)
        #expect(a.metrics.toShip == 150)
    }

    @Test func guardedDeletes() throws {
        let service = ProductionService(context: context, author: "Test")
        let plant = makePlant()
        let order = try makeOrder()
        let a = try service.assign(order: order, to: plant, quantity: 10, date: .now)
        #expect(throws: ProductionService.ServiceError.self) { try service.delete(plant) }
        try service.addShipmentReport(number: "1", quantity: 1, to: a)
        #expect(throws: ProductionService.ServiceError.self) { try service.delete(order) }
    }

    @Test func authHashesAndVerifies() throws {
        let user = try Session.createUser(
            firstName: "Ana", lastName: "P", email: "Ana@DEMO.local", phone: "", password: "secreto1",
            role: .shippingManager, plant: nil, avatar: nil, in: context)
        #expect(user.email == "ana@demo.local")
        #expect(user.passwordHash != "secreto1")
        let session = Session(context: context, defaults: UserDefaults(suiteName: "auth-\(UUID())")!)
        #expect(throws: AuthError.wrongPassword) { try session.signIn(email: "ana@demo.local", password: "nope") }
        #expect(throws: AuthError.unknownEmail) { try session.signIn(email: "x@demo.local", password: "secreto1") }
        try session.signIn(email: "ANA@demo.local", password: "secreto1")
        #expect(session.role == .shippingManager)
        #expect(throws: AuthError.emailTaken) {
            try Session.createUser(
                firstName: "A", lastName: "", email: "ana@demo.local", phone: "", password: "123456",
                role: .admin, plant: nil, avatar: nil, in: context)
        }
    }

    @Test func demoSeedIsConsistent() {
        DemoSeeder.seed(into: context)
        #expect(context.count(Plant.self) == 3)
        #expect(context.count(AppUser.self) == 4)
        let assignments = context.fetchAll(Assignment.self)
        #expect(!assignments.isEmpty)
        #expect(assignments.contains { $0.isUrgent(windowDays: 7) })
        for plant in context.fetchAll(Plant.self) {
            #expect(plant.ledger.utilization(inMonthOf: .now) <= 1)
        }
    }
}
