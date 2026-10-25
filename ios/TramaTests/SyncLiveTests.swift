import CoreData
import Foundation
import Testing

@testable import Trama

/// Opt-in end-to-end check against a real platform API (`npm run dev:api` in platform/):
///
///     TEST_RUNNER_TRAMA_LIVE_API=http://localhost:8787/api \
///     TEST_RUNNER_TRAMA_LIVE_EMAIL=admin@empresa.test TEST_RUNNER_TRAMA_LIVE_PASSWORD=… \
///     xcodebuild … test -only-testing:TramaTests/SyncLiveTests
///
/// Use a dedicated company (admin of a fresh tenant): the test writes records into it.
@MainActor
@Suite("Live platform API", .enabled(if: ProcessInfo.processInfo.environment["TRAMA_LIVE_API"] != nil))
struct SyncLiveTests {
    private var env: [String: String] { ProcessInfo.processInfo.environment }

    @MainActor private struct Device {
        let persistence = PersistenceController(inMemory: true)
        let session: Session
        let toasts = ToastCenter()
        let engine: SyncEngine
        var context: NSManagedObjectContext { persistence.viewContext }

        init(base: URL) {
            let defaults = UserDefaults(suiteName: "trama.live.\(UUID().uuidString)")!
            let secrets = MemorySecretStore()
            session = Session(context: persistence.viewContext, defaults: defaults)
            engine = SyncEngine(
                persistence: persistence, session: session, toasts: toasts, api: APIClient(baseURL: base, secrets: secrets),
                secrets: secrets, defaults: defaults, debounce: .seconds(3600))
        }
    }

    @Test func twoDevicesConvergeThroughTheServer() async throws {
        let base = try #require(URL(string: env["TRAMA_LIVE_API"] ?? ""))
        let email = try #require(env["TRAMA_LIVE_EMAIL"])
        let password = try #require(env["TRAMA_LIVE_PASSWORD"])

        // Device A: activate, write through the services, push.
        let a = Device(base: base)
        try await a.engine.connect(email: email, password: password)
        #expect(a.session.user?.email == email.lowercased())
        #expect(a.engine.licence?.writable == true)

        let stamp = UUID().uuidString.prefix(6)
        let catalog = CatalogService(context: a.context)
        let service = ProductionService(context: a.context, author: "QA")
        let plant = try a.context.fetchAll(Plant.self).first ?? catalog.savePlant(nil, name: "Planta QA \(stamp)", maxCapacity: 10_000_000)
        let client = try catalog.saveClient(nil, name: "Cliente QA \(stamp)", address: "CDMX", contacts: [ContactDraft(name: "Luz")])
        let order = try service.createOrder(
            code: "QA-\(stamp)", list: "L", garment: "Falda", quantity: 100, unitPrice: 20, client: client, style: nil,
            internalDate: .now, clientDate: .now, notes: "e2e")
        let assignment = try service.assign(order: order, to: plant, quantity: 60, date: .now)
        try service.addShipmentReport(number: "1", quantity: 25, to: assignment)
        await a.engine.sync()
        #expect(a.engine.lastError == nil)
        #expect(SyncOutbox.count(in: a.context) == 0)

        // Device B: activate (pulls everything), verify relationships and metrics.
        let b = Device(base: base)
        try await b.engine.connect(email: email, password: password, localData: .replace)
        let copy = try #require(b.context.fetchAll(CutOrder.self, predicate: NSPredicate(format: "id == %@", order.id! as CVarArg)).first)
        #expect(copy.client?.name == client.name)
        #expect(copy.client?.contactList.first?.name == "Luz")
        let copyAssignment = try #require(copy.assignmentList.first)
        #expect(copyAssignment.plant?.id == plant.id)
        #expect(copyAssignment.metrics.shipped == 25)

        // B edits and deletes; A pulls and converges.
        try ProductionService(context: b.context, author: "QA B").update(
            copy, code: copy.code!, list: "L2", garment: "Falda", quantity: 100, unitPrice: 20, client: copy.client, style: nil,
            internalDate: copy.internalDate, clientDate: copy.clientDate, notes: "editado en B")
        let report = try #require(copyAssignment.reportList.first)
        try ProductionService(context: b.context, author: "QA B").delete(report)
        await b.engine.sync()
        #expect(b.engine.lastError == nil)

        await a.engine.sync()
        #expect(order.notes == "editado en B")
        #expect(order.list == "L2")
        #expect(assignment.reportList.isEmpty)

        // Plan limit (Planta = 1 plant) comes back as a rejection, surfaced as a toast.
        if a.context.count(Plant.self) >= 1 {
            _ = try catalog.savePlant(nil, name: "Planta extra \(stamp)", maxCapacity: 1)
            await a.engine.sync()
            #expect(a.toasts.current?.message.contains("planta") == true)
        }

        await a.engine.signOut()
        await b.engine.signOut()
        #expect(!a.engine.api.hasRefreshToken)
    }
}
