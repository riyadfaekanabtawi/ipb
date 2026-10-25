import CoreData
import Foundation
import Testing
import UIKit

@testable import Trama

/// The legacy server (ipb.railsplayground.net) is gone, so these fixtures, shaped after the
/// Objective-C models in IPB/Common/*.m, are the only verification of the mapping.
enum LegacyFixtures {
    static let plants = #"""
        {"api": [
          {"id": 1, "name": "Planta Norte", "max_capacity": "1800000", "used_capacity": 0, "january_min": null},
          {"id": "2", "name": "Planta Sur", "max_capacity": 950000.5},
          {"name": "Sin id"}
        ]}
        """#

    static let clients = #"""
        {"api": [
          {"id": 10, "nombre": "Bayer California", "direccion": "Av. Insurgentes 1458",
           "nombre_contacto1": "Laura Méndez", "email_contacto1": "laura@bayer.com", "telefono_contacto1": "55 2345 9988", "puesto_contacto1": "Compras",
           "nombre_contacto2": "", "email_contacto2": null, "telefono_contacto2": null, "puesto_contacto2": null,
           "nombre_contacto3": null, "email_contacto3": "calidad@bayer.com", "telefono_contacto3": null, "puesto_contacto3": null}
        ]}
        """#

    static let suppliers = #"""
        {"api": [{"id": 5, "nombre": "Hilados del Bajío", "direccion": "León", "nombre_contacto1": "Ramón", "telefono_contacto1": 4772103030}]}
        """#

    static let styles = #"""
        {"api": [
          {"id": 7, "name": "Falda plisada", "photo": "/system/styles/photos/000/007/original/falda.jpg", "plants": []},
          {"id": 8, "name": "Jeans", "photo": "/photos/original/missing.png"}
        ]}
        """#

    static let users = #"""
        {"api": [
          {"id": 100, "nombre": "Jorge", "apellido": "Salinas", "email": "JORGE@demo.local", "puesto": "Gerente de Planta", "telefono": "8112345678", "plant_name": "planta norte"},
          {"id": 101, "nombre": "Ana", "apellido": "Villarreal", "email": "envios@demo.local", "puesto": "Gerente de Envíos", "telefono": null, "plant_name": null},
          {"user": {"id": 102, "nombre": "Admin", "apellido": "IPB", "email": "admin@demo.local", "puesto": "Administrador"}}
        ]}
        """#

    static let projects = #"""
        {"api": [
          {"id": 30, "cantidad": "12000", "precio": "61.5", "minutaje": 14, "status": "Aceptado", "cliente": "Bayer California",
           "tela": "Supplex", "fecha_entrega": "15-11-2026", "notes": "Muestra aprobada", "photo": null},
          {"id": 31, "cantidad": 300, "precio": 95, "minutaje": "22.5", "status": "declinado", "cliente": "Nuevo Cliente",
           "tela": null, "fecha_entrega": "2026-12-01", "notes": null}
        ]}
        """#

    static let pendingCuts = #"""
        {"api": [
          {"id": 200, "cliente": "Bayer California", "estilo": "Falda plisada", "cantidad": "4000", "precio_unitario": "68",
           "corte": "C-1042", "lista": "L-340", "prenda": "Falda", "fecha_ipb": "01-10-2026", "fecha_cliente": "28-10-2026", "editado_por": "Carmen"},
          {"id": 201, "cliente": "Best Girl", "estilo": "Blusa lino", "cantidad": 2800, "precio_unitario": 74,
           "corte": "C-1050", "lista": "L-352", "prenda": "Blusa", "fecha_ipb": null, "fecha_cliente": "2026-11-02", "editado_por": null}
        ]}
        """#

    static let cuts = #"""
        {"api": [
          {"id": 300, "plant_id": 1, "cantidad": "2500", "precio_unitario": "68", "fecha_ipb": "05-10-2026", "status": "En mesa de corte",
           "corte": "C-1042", "lista": "L-340", "cliente": "Bayer California", "estilo_cliente": "Falda plisada"},
          {"id": 301, "plant_id": "2", "cantidad": 1500, "precio_unitario": 68, "fecha_ipb": "2026-10-20", "status": null,
           "corte": "c-1042", "lista": "l-340"},
          {"id": 302, "plant_id": 2, "cantidad": 900, "precio_unitario": 260, "fecha_ipb": "10-11-2026", "status": "listo_para_confeccionar",
           "corte": "C-0999", "lista": "L-100", "cliente": "Andes Denim", "estilo_cliente": "Chamarra", "prenda": "Chamarra", "fecha_cliente": "01-12-2026"}
        ]}
        """#

    static let reports = #"""
        {"api": [
          {"id": 400, "tipo": "planta", "cut_id": 300, "operarios": 42, "faltas": "3", "produciad": 1200, "en_plancha": 100,
           "en_empaque": 50, "bodega": 400, "created_at": "2026-10-10T09:30:00-05:00"},
          {"id": 401, "tipo": "corte", "cut_id": 300, "status": "listo para confeccionar", "cantidad_real_envio": 2480,
           "created_at": "2026-10-08T12:00:00.000Z"},
          {"id": 402, "tipo": "envio", "cut_id": 300, "numero_de_envio": 501, "cantidad_de_envio": "800",
           "created_at": "2026-10-12T16:00:00-05:00"},
          {"id": 403, "tipo": "corte", "cut_id": 300, "status": "en espera", "cantidad_real_envio": 1},
          {"id": 404, "tipo": "planta", "cut_id": 9999}
        ]}
        """#

    static func rows(_ json: String) -> [LegacyRow] {
        (try? LegacyAPIClient.decodeRows(Data(json.utf8), endpoint: "fixture")) ?? []
    }
}

/// In-memory `LegacySource` returning the fixtures.
struct FixtureSource: LegacySource {
    var overrides: [LegacyResource: String] = [:]
    var image: Data?

    func rows(for resource: LegacyResource) async throws -> [LegacyRow] {
        if let json = overrides[resource] { return LegacyFixtures.rows(json) }
        let json: String =
            switch resource {
            case .plants: LegacyFixtures.plants
            case .clients: LegacyFixtures.clients
            case .suppliers: LegacyFixtures.suppliers
            case .styles: LegacyFixtures.styles
            case .users: LegacyFixtures.users
            case .projects: LegacyFixtures.projects
            case .pendingCuts: LegacyFixtures.pendingCuts
            case .cuts: LegacyFixtures.cuts
            case .reports: LegacyFixtures.reports
            }
        return LegacyFixtures.rows(json)
    }

    func asset(at path: String) async throws -> Data {
        guard let image, LegacyAPIClient.assetURL(path, base: URL(string: "https://legacy.test/")!) != nil else {
            throw LegacyError.http(404, path)
        }
        return image
    }
}

@Suite("Legacy JSON mapping")
struct LegacyMappingTests {
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test func envelopeDecoding() throws {
        #expect(LegacyFixtures.rows(LegacyFixtures.plants).count == 3)
        #expect(try LegacyAPIClient.decodeRows(Data(#"[{"id":1}]"#.utf8), endpoint: "x").count == 1)
        #expect(try LegacyAPIClient.decodeRows(Data(#"{"api": null}"#.utf8), endpoint: "x").isEmpty)
        #expect(throws: LegacyError.malformed("x")) { try LegacyAPIClient.decodeRows(Data("<html>".utf8), endpoint: "x") }
        #expect(throws: LegacyError.malformed("x")) { try LegacyAPIClient.decodeRows(Data(#"{"error": "boom"}"#.utf8), endpoint: "x") }
    }

    @Test func dates() {
        #expect(LegacyDates.parse("28-10-2026") == day(2026, 10, 28))
        #expect(LegacyDates.parse("2026-11-02") == day(2026, 11, 2))
        #expect(LegacyDates.parse("2026-11-02 10:00:00") == day(2026, 11, 2))
        #expect(LegacyDates.parse("2026-10-10T09:30:00-05:00") != nil)
        #expect(LegacyDates.parse("2026-10-08T12:00:00.000Z") != nil)
        #expect(LegacyDates.parse("") == nil)
        #expect(LegacyDates.parse("32-13-2026") == nil)
        #expect(LegacyDates.parse(nil) == nil)
    }

    @Test func plantAndLenientNumbers() throws {
        let rows = LegacyFixtures.rows(LegacyFixtures.plants)
        #expect(LegacyMapper.plant(rows[0]) == LegacyPlant(remoteID: 1, name: "Planta Norte", maxCapacity: 1_800_000))
        #expect(LegacyMapper.plant(rows[1])?.remoteID == 2)
        #expect(LegacyMapper.plant(rows[1])?.maxCapacity == 950_000.5)
        #expect(LegacyMapper.plant(rows[2]) == nil)
    }

    @Test func companyContactsSkipEmptySlots() throws {
        let client = try #require(LegacyMapper.company(LegacyFixtures.rows(LegacyFixtures.clients)[0]))
        #expect(client.name == "Bayer California")
        #expect(client.address == "Av. Insurgentes 1458")
        #expect(client.contacts.count == 2)
        #expect(client.contacts[0] == LegacyContact(name: "Laura Méndez", email: "laura@bayer.com", phone: "55 2345 9988", role: "Compras"))
        #expect(client.contacts[1].email == "calidad@bayer.com")
        let supplier = try #require(LegacyMapper.company(LegacyFixtures.rows(LegacyFixtures.suppliers)[0]))
        #expect(supplier.contacts.first?.phone == "4772103030")
    }

    @Test func usersAndRoles() throws {
        let rows = LegacyFixtures.rows(LegacyFixtures.users)
        let jorge = try #require(LegacyMapper.user(rows[0]))
        #expect(jorge.email == "jorge@demo.local")
        #expect(jorge.role == .plantManager)
        #expect(jorge.plantName == "planta norte")
        #expect(LegacyMapper.user(rows[1])?.role == .shippingManager)
        #expect(LegacyMapper.user(rows[2])?.role == .admin)
        #expect(LegacyMapper.user(rows[2])?.remoteID == 102)
        #expect(LegacyMapper.role("Gerente de Cortes") == .cutManager)
        #expect(LegacyMapper.role(nil) == .plantManager)
    }

    @Test func projects() throws {
        let rows = LegacyFixtures.rows(LegacyFixtures.projects)
        let p = try #require(LegacyMapper.project(rows[0]))
        #expect(p.quantity == 12_000)
        #expect(p.price == 61.5)
        #expect(p.minutes == 14)
        #expect(p.status == .accepted)
        #expect(p.deliveryDate == day(2026, 11, 15))
        #expect(p.photoPath == nil)
        let q = try #require(LegacyMapper.project(rows[1]))
        #expect(q.status == .declined)
        #expect(q.minutes == 22.5)
        #expect(q.deliveryDate == day(2026, 12, 1))
        #expect(LegacyMapper.projectStatus("algo") == .pending)
    }

    @Test func pendingCutAndCut() throws {
        let order = try #require(LegacyMapper.pendingCut(LegacyFixtures.rows(LegacyFixtures.pendingCuts)[0]))
        #expect(order.code == "C-1042")
        #expect(order.list == "L-340")
        #expect(order.quantity == 4_000)
        #expect(order.unitPrice == 68)
        #expect(order.clientDate == day(2026, 10, 28))
        #expect(order.editedBy == "Carmen")

        let cuts = LegacyFixtures.rows(LegacyFixtures.cuts)
        let cut = try #require(LegacyMapper.cut(cuts[0]))
        #expect(cut.plantRemoteID == 1)
        #expect(cut.status == .onTable)
        #expect(cut.scheduledDate == day(2026, 10, 5))
        #expect(LegacyMapper.cut(cuts[1])?.status == .waiting)
        #expect(LegacyMapper.cut(cuts[1])?.plantRemoteID == 2)
        #expect(LegacyMapper.cut(cuts[2])?.status == .ready)
    }

    @Test func reportsByKind() throws {
        let rows = LegacyFixtures.rows(LegacyFixtures.reports)
        let plant = try #require(LegacyMapper.report(rows[0]))
        #expect(plant.kind == .plant)
        #expect(plant.cutRemoteID == 300)
        #expect(plant.operators == 42 && plant.absences == 3 && plant.produced == 1_200)
        #expect(plant.ironing == 100 && plant.packing == 50 && plant.warehouse == 400)
        let cut = try #require(LegacyMapper.report(rows[1]))
        #expect(cut.kind == .cut && cut.cutStatus == .ready && cut.realQuantity == 2_480)
        let shipment = try #require(LegacyMapper.report(rows[2]))
        #expect(shipment.kind == .shipment && shipment.shipmentNumber == "501" && shipment.shippedQuantity == 800)
    }

    @Test func clientURLNormalizationAndAssets() throws {
        let client = try LegacyAPIClient(baseString: "  ipb.example.com ")
        #expect(client.baseURL.absoluteString == "https://ipb.example.com/")
        #expect(throws: LegacyError.invalidURL) { try LegacyAPIClient(baseString: "") }
        #expect(throws: LegacyError.invalidURL) { try LegacyAPIClient(baseString: "ftp://x.com") }
        let base = URL(string: "https://ipb.example.com/")!
        #expect(LegacyAPIClient.assetURL("/system/a.jpg", base: base)?.absoluteString == "https://ipb.example.com/system/a.jpg")
        #expect(LegacyAPIClient.assetURL("/photos/original/missing.png", base: base) == nil)
        #expect(LegacyAPIClient.assetURL("", base: base) == nil)
    }
}

@MainActor
@Suite("Legacy importer → Core Data")
struct LegacyImporterTests {
    let persistence = PersistenceController(inMemory: true)
    var context: NSManagedObjectContext { persistence.viewContext }

    private func png() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).pngData { ctx in
            UIColor.systemOrange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }

    private func entityCounts() -> [Int] {
        [
            context.count(Plant.self), context.count(Client.self), context.count(Supplier.self), context.count(Contact.self),
            context.count(Style.self), context.count(AppUser.self), context.count(Project.self), context.count(CutOrder.self),
            context.count(Assignment.self), context.count(ProductionReport.self),
        ]
    }

    @Test func importsFixturesIntoEntities() async throws {
        let summary = try await LegacyImporter(context: context).run(from: FixtureSource(image: png()))

        #expect(summary[.plants].created == 2)
        #expect(summary[.plants].skipped == 1)
        let norte = try #require(context.fetchAll(Plant.self, predicate: NSPredicate(format: "remoteID == 1")).first)
        #expect(norte.maxCapacity == 1_800_000)

        let bayer = try #require(context.fetchAll(Client.self, predicate: NSPredicate(format: "remoteID == 10")).first)
        #expect(bayer.contactList.map(\.name) == ["Laura Méndez", nil])
        #expect(context.count(Supplier.self) == 1)

        // Style photo downloaded best-effort; the "missing" placeholder is skipped.
        let falda = try #require(context.fetchAll(Style.self, predicate: NSPredicate(format: "remoteID == 7")).first)
        #expect(falda.imageData != nil)
        #expect(context.fetchAll(Style.self, predicate: NSPredicate(format: "remoteID == 8")).first?.imageData == nil)
        #expect(summary.imagesDownloaded == 1)

        // Imported users are locked until an admin sets a password.
        let jorge = try #require(Session.findUser(email: "jorge@demo.local", in: context))
        #expect(jorge.isActive == false)
        #expect(jorge.role == .plantManager)
        #expect(jorge.plant == norte)
        #expect(jorge.passwordHash != nil)

        let project = try #require(context.fetchAll(Project.self, predicate: NSPredicate(format: "remoteID == 30")).first)
        #expect(project.client == bayer)
        #expect(project.status == .accepted)
        let orphanProject = try #require(context.fetchAll(Project.self, predicate: NSPredicate(format: "remoteID == 31")).first)
        #expect(orphanProject.client == nil)
        #expect(orphanProject.clientName == "Nuevo Cliente")

        // Pending cuts link client/style by name, creating missing ones.
        let order = try #require(context.fetchAll(CutOrder.self, predicate: NSPredicate(format: "remoteID == 200")).first)
        #expect(order.client == bayer)
        #expect(order.style == falda)
        let blusa = try #require(context.fetchAll(CutOrder.self, predicate: NSPredicate(format: "remoteID == 201")).first)
        #expect(blusa.client?.name == "Best Girl")
        #expect(blusa.style?.name == "Blusa lino")

        // Cuts link to orders by code + lista (case-insensitive) and to plants by remoteID.
        #expect(order.assignmentList.count == 2)
        #expect(order.assignedQuantity == 4_000)
        #expect(order.remainingQuantity == 0)
        let a300 = try #require(context.fetchAll(Assignment.self, predicate: NSPredicate(format: "remoteID == 300")).first)
        #expect(a300.plant == norte)
        #expect(a300.metrics.revenue == 2_500 * 68)
        // A fully assigned cut missing from getPendingCuts gets its order created.
        let a302 = try #require(context.fetchAll(Assignment.self, predicate: NSPredicate(format: "remoteID == 302")).first)
        #expect(a302.order?.code == "C-0999")
        #expect(a302.order?.quantity == 900)
        #expect(a302.order?.client?.name == "Andes Denim")
        #expect(a302.cuttingStatus == .ready)

        // Reports: one cut report per assignment, the cut report drives the board status.
        #expect(a300.reportList.count == 3)
        #expect(a300.cuttingStatus == .ready)
        #expect(summary[.reports].skipped == 2)
        let m = a300.metrics
        #expect(m.realCut == 2_480)
        #expect(m.produced == 1_200)
        #expect(m.shipped == 800)
        #expect(m.toShip == 1_680)
    }

    @Test func reimportIsIdempotent() async throws {
        let first = try await LegacyImporter(context: context).run(from: FixtureSource(image: png()))
        let countsAfterFirst = entityCounts()
        #expect(first.totalCreated > 0)

        let second = try await LegacyImporter(context: context).run(from: FixtureSource(image: png()))
        #expect(entityCounts() == countsAfterFirst)
        #expect(second.totalCreated == 0)
        #expect(second[.plants].updated == 2)
        #expect(second.imagesDownloaded == 0)  // already have the photo
    }

    @Test func upsertUpdatesChangedFieldsAndKeepsLocalData() async throws {
        // A local admin created before import keeps password and active state, and gets linked.
        let admin = try Session.createUser(
            firstName: "Mariana", lastName: "T", email: "admin@demo.local", phone: "", password: "secreto1",
            role: .admin, plant: nil, avatar: nil, in: context)
        let localPlant = Plant(context: context)
        localPlant.stampCreated()
        localPlant.name = "Planta local"
        try context.saveIfNeeded()

        _ = try await LegacyImporter(context: context).run(from: FixtureSource())
        #expect(admin.remoteID == 102)
        #expect(admin.isActive)
        #expect(PasswordHasher.verify("secreto1", hash: admin.passwordHash, salt: admin.passwordSalt))
        #expect(context.count(AppUser.self) == 3)

        let changed = #"{"api": [{"id": 1, "name": "Planta Norte II", "max_capacity": 2000000}]}"#
        let summary = try await LegacyImporter(context: context).run(from: FixtureSource(overrides: [.plants: changed]))
        #expect(summary[.plants].updated == 1)
        let norte = try #require(context.fetchAll(Plant.self, predicate: NSPredicate(format: "remoteID == 1")).first)
        #expect(norte.name == "Planta Norte II")
        #expect(norte.maxCapacity == 2_000_000)
        #expect(!localPlant.isDeleted)
        #expect(context.count(Plant.self) == 3)
    }
}
