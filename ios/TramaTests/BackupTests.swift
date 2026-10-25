import CoreData
import Foundation
import Testing
import UIKit

@testable import Trama

@MainActor
@Suite("Backup export / restore")
struct BackupTests {
    private func seededStore() -> PersistenceController {
        let persistence = PersistenceController(inMemory: true)
        DemoSeeder.seed(into: persistence.viewContext)
        return persistence
    }

    private func counts(_ context: NSManagedObjectContext) -> [String: Int] {
        [
            "Plant": context.count(Plant.self), "Client": context.count(Client.self), "Supplier": context.count(Supplier.self),
            "Contact": context.count(Contact.self), "Style": context.count(Style.self), "CutOrder": context.count(CutOrder.self),
            "Assignment": context.count(Assignment.self), "ProductionReport": context.count(ProductionReport.self),
            "Project": context.count(Project.self), "AppUser": context.count(AppUser.self),
        ]
    }

    private func pngData() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).pngData { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }

    @Test func roundTripPreservesCountsRelationshipsImagesAndMetrics() throws {
        let source = seededStore()
        let ctx = source.viewContext
        let image = pngData()
        let style = try #require(ctx.fetchAll(Style.self).first)
        style.imageData = image
        let project = try #require(ctx.fetchAll(Project.self).first)
        project.photoData = image
        try ctx.saveIfNeeded()

        let before = counts(ctx)
        let totalsBefore = ProductionTotals(ctx.fetchAll(Assignment.self).map(\.metrics))
        let data = try BackupService.export(context: ctx)

        let target = PersistenceController(inMemory: true)
        try BackupService.restore(data, into: target)
        let restored = target.viewContext

        #expect(counts(restored) == before)
        #expect(ProductionTotals(restored.fetchAll(Assignment.self).map(\.metrics)) == totalsBefore)

        // Relationships by UUID.
        for original in ctx.fetchAll(Assignment.self) {
            let id = try #require(original.id)
            let copy = try #require(restored.fetchAll(Assignment.self, predicate: NSPredicate(format: "id == %@", id as CVarArg)).first)
            #expect(copy.order?.id == original.order?.id)
            #expect(copy.plant?.id == original.plant?.id)
            #expect(Set(copy.reportList.map(\.id)) == Set(original.reportList.map(\.id)))
            #expect(copy.cuttingStatus == original.cuttingStatus)
            #expect(copy.metrics == original.metrics)
        }
        let restoredClient = try #require(
            restored.fetchAll(Client.self, predicate: NSPredicate(format: "name == %@", "Bayer California")).first)
        #expect(restoredClient.contactList.count == 2)
        let manager = try #require(Session.findUser(email: "planta@demo.local", in: restored))
        #expect(manager.plant?.name == "Planta Norte")

        // Images survive byte-for-byte.
        #expect(restored.fetchAll(Style.self, predicate: NSPredicate(format: "id == %@", style.id! as CVarArg)).first?.imageData == image)
        #expect(
            restored.fetchAll(Project.self, predicate: NSPredicate(format: "id == %@", project.id! as CVarArg)).first?.photoData == image)

        // Passwords still work after restore.
        let session = Session(context: restored, defaults: UserDefaults(suiteName: "backup-tests-\(UUID())")!)
        try session.signIn(email: "admin@demo.local", password: DemoSeeder.demoPassword)
        #expect(session.isSignedIn)
    }

    @Test func restoreReplacesExistingData() throws {
        let data = try BackupService.export(context: seededStore().viewContext)
        let target = seededStore()
        try BackupService.restore(data, into: target)
        #expect(target.viewContext.count(Plant.self) == 3)
    }

    /// Regression: batch deletes skipped Deny-protected rows (plants with assignments) without throwing.
    @Test func eraseAllRemovesEveryEntity() throws {
        let persistence = seededStore()
        try persistence.eraseAll()
        #expect(counts(persistence.viewContext).values.allSatisfy { $0 == 0 })
    }

    @Test func fileHeaderAndFilename() throws {
        let data = try BackupService.export(context: seededStore().viewContext)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["formatVersion"] as? Int == 1)
        #expect(json["exportedAt"] is String)
        #expect(json["appVersion"] is String)
        let summary = try BackupService.inspect(data)
        #expect(summary.counts.first { $0.0 == "Plantas" }?.1 == 3)

        var comps = DateComponents()
        comps.year = 2026; comps.month = 3; comps.day = 9
        #expect(BackupService.filename(for: Calendar.current.date(from: comps)!) == "Trama-respaldo-2026-03-09.json")
    }

    @Test func rejectsNewerVersionAndGarbageWithoutTouchingStore() throws {
        let target = seededStore()
        let newer = Data(#"{"formatVersion": 99, "plants": []}"#.utf8)
        #expect(throws: BackupService.BackupError.unsupportedVersion(99)) { try BackupService.restore(newer, into: target) }
        #expect(throws: BackupService.BackupError.invalidFile) { try BackupService.restore(Data("nope".utf8), into: target) }
        #expect(throws: BackupService.BackupError.invalidFile) { try BackupService.restore(Data("{}".utf8), into: target) }
        #expect(target.viewContext.count(Plant.self) == 3)
    }

    @Test func toleratesMissingOptionalKeys() throws {
        let plantID = UUID()
        let json = """
            {"formatVersion": 1,
             "plants": [{"id": "\(plantID.uuidString)", "name": "Mínima"}],
             "assignments": [{"quantity": 10, "plantID": "\(plantID.uuidString)", "futureField": true}],
             "somethingNew": {"x": 1}}
            """
        let target = PersistenceController(inMemory: true)
        try BackupService.restore(Data(json.utf8), into: target)
        let plant = try #require(target.viewContext.fetchAll(Plant.self).first)
        #expect(plant.maxCapacity == 0)
        #expect(plant.assignmentList.count == 1)
        #expect(plant.assignmentList.first?.cuttingStatus == .waiting)
        #expect(plant.assignmentList.first?.id != nil)
    }

    /// Guards against model drift: every attribute (and to-one relationship as `<name>ID`) must be in a DTO.
    @Test func dtosCoverEveryModelAttribute() {
        let dtoFields: [String: Set<String>] = [
            "Plant": fields(PlantDTO()), "Client": fields(ClientDTO()), "Supplier": fields(SupplierDTO()),
            "Contact": fields(ContactDTO()), "Style": fields(StyleDTO()), "CutOrder": fields(CutOrderDTO()),
            "Assignment": fields(AssignmentDTO()), "ProductionReport": fields(ProductionReportDTO()),
            "Project": fields(ProjectDTO()), "AppUser": fields(AppUserDTO()),
        ]
        for entity in PersistenceController.model.entities {
            let name = entity.name!
            let expected = Set(entity.attributesByName.keys)
                .union(entity.relationshipsByName.values.filter { !$0.isToMany }.map { "\($0.name)ID" })
            let covered = dtoFields[name] ?? []
            #expect(expected.subtracting(covered).isEmpty, "\(name) missing \(expected.subtracting(covered))")
        }
    }

    private func fields(_ value: Any) -> Set<String> {
        Set(Mirror(reflecting: value).children.compactMap(\.label))
    }
}
