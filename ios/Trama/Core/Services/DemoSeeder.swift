import CoreData
import Foundation

/// Realistic demo data so the app can be explored offline (and for previews/tests).
/// Demo accounts all use the password `trama123`.
enum DemoSeeder {
    static let demoPassword = "trama123"

    static func seed(into context: NSManagedObjectContext, now: Date = .now) {
        let cal = Calendar.current
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now))! }

        // Plants (capacity in MXN per month).
        let plantSpecs: [(String, Double)] = [("Planta Norte", 1_800_000), ("Planta Sur", 1_200_000), ("Planta Bajío", 950_000)]
        let plants = plantSpecs.map { name, cap -> Plant in
            let p = Plant(context: context)
            p.stampCreated()
            p.name = name
            p.maxCapacity = cap
            return p
        }

        // Clients with contacts.
        let clientSpecs: [(String, String, [(String, String, String, String)])] = [
            (
                "Bayer California", "Av. Insurgentes Sur 1458, CDMX",
                [
                    ("Laura Méndez", "Compras", "laura.mendez@bayerca.com", "55 2345 9988"),
                    ("Óscar Ruiz", "Calidad", "oscar.ruiz@bayerca.com", "55 2345 9900"),
                ]
            ),
            (
                "Best Girl", "Blvd. Díaz Ordaz 230, Monterrey",
                [("Sofía Treviño", "Directora de producto", "sofia@bestgirl.mx", "81 1122 3344")]
            ),
            (
                "Andes Denim Co.", "Calle 5 de Mayo 77, Guadalajara",
                [("Diego Paredes", "Gerente de abasto", "dparedes@andesdenim.com", "33 9988 7766")]
            ),
            (
                "Lumen Activewear", "Parque Industrial Querétaro, Nave 12",
                [("Mariana Sosa", "Planeación", "mariana@lumenactive.com", "442 555 1010")]
            ),
        ]
        let clients = clientSpecs.map { name, address, contacts -> Client in
            let c = Client(context: context)
            c.stampCreated()
            c.name = name
            c.address = address
            for (i, spec) in contacts.enumerated() {
                let contact = Contact(context: context)
                contact.id = UUID()
                contact.name = spec.0; contact.role = spec.1; contact.email = spec.2; contact.phone = spec.3
                contact.sortIndex = Int16(i)
                contact.client = c
            }
            return c
        }

        // Suppliers.
        for (name, address, contact) in [
            ("Hilados del Bajío", "León, Gto.", ("Ramón Ibarra", "Ventas", "ventas@hiladosbajio.mx", "477 210 3030")),
            ("Avíos y Etiquetas MX", "Puebla, Pue.", ("Claudia Romo", "Ejecutiva de cuenta", "claudia@aviosmx.com", "222 404 5050")),
            ("Telas Finas del Norte", "Torreón, Coah.", ("Héctor Garza", "Director comercial", "hgarza@telasfinas.mx", "871 300 2020")),
        ] {
            let s = Supplier(context: context)
            s.stampCreated()
            s.name = name
            s.address = address
            let c = Contact(context: context)
            c.id = UUID()
            c.name = contact.0; c.role = contact.1; c.email = contact.2; c.phone = contact.3
            c.supplier = s
        }

        // Styles.
        let styles = ["Falda plisada SK-210", "Jeans skinny DN-88", "Blusa lino BL-14", "Legging sport LG-301", "Chamarra mezclilla JK-05"]
            .map { name -> Style in
                let s = Style(context: context)
                s.stampCreated()
                s.name = name
                return s
            }

        // Orders, assignments and reports.
        let service = ProductionService(context: context, author: "Demo")
        struct OrderSpec {
            var code, list, garment: String; var qty: Int; var price: Double; var client, style: Int; var internalDue, clientDue: Int
        }
        let orderSpecs = [
            OrderSpec(code: "C-1042", list: "L-340", garment: "Falda", qty: 4_000, price: 68, client: 0, style: 0, internalDue: -20, clientDue: 4),
            OrderSpec(
                code: "C-1043", list: "L-340", garment: "Jeans", qty: 6_500, price: 112, client: 2, style: 1, internalDue: -15, clientDue: 12),
            OrderSpec(code: "C-1050", list: "L-352", garment: "Blusa", qty: 2_800, price: 74, client: 1, style: 2, internalDue: -9, clientDue: 2),
            OrderSpec(
                code: "C-1051", list: "L-352", garment: "Legging", qty: 9_000, price: 58, client: 3, style: 3, internalDue: -6, clientDue: 21),
            OrderSpec(
                code: "C-1060", list: "L-360", garment: "Chamarra", qty: 1_500, price: 260, client: 2, style: 4, internalDue: -2, clientDue: 35),
            OrderSpec(code: "C-1061", list: "L-360", garment: "Falda", qty: 3_200, price: 70, client: 0, style: 0, internalDue: 0, clientDue: 40),
            OrderSpec(code: "C-1062", list: "L-361", garment: "Blusa", qty: 5_000, price: 76, client: 1, style: 2, internalDue: 1, clientDue: 45),
        ]
        var orders: [CutOrder] = []
        for spec in orderSpecs {
            if let order = try? service.createOrder(
                code: spec.code, list: spec.list, garment: spec.garment, quantity: spec.qty, unitPrice: spec.price,
                client: clients[spec.client], style: styles[spec.style], internalDate: day(spec.internalDue), clientDate: day(spec.clientDue), notes: nil
            ) {
                order.createdAt = day(spec.internalDue)
                orders.append(order)
            }
        }

        func assign(_ o: Int, _ p: Int, _ qty: Int, _ offset: Int) -> Assignment? {
            try? service.assign(order: orders[o], to: plants[p], quantity: qty, date: day(offset))
        }

        // Fully in production, partially shipped — urgent.
        if let a = assign(0, 0, 4_000, -18) {
            _ = try? service.setCutReport(status: .ready, realQuantity: 3_960, on: a)
            _ = try? service.addPlantReport(
                .init(operators: 42, absences: 3, produced: 3_400, ironing: 600, packing: 900, warehouse: 1_400), to: a)
            _ = try? service.addShipmentReport(number: "E-501", quantity: 1_200, to: a)
        }
        // Split between two plants.
        if let a = assign(1, 0, 4_000, -10) {
            _ = try? service.setCutReport(status: .onTable, realQuantity: 0, on: a)
        }
        if let a = assign(1, 1, 2_500, -8) {
            _ = try? service.setCutReport(status: .ready, realQuantity: 2_480, on: a)
            _ = try? service.addPlantReport(
                .init(operators: 28, absences: 1, produced: 1_100, ironing: 300, packing: 200, warehouse: 300), to: a)
        }
        // Due in 2 days, behind schedule.
        if let a = assign(2, 2, 2_800, -7) {
            _ = try? service.setCutReport(status: .ready, realQuantity: 2_790, on: a)
            _ = try? service.addPlantReport(
                .init(operators: 19, absences: 2, produced: 2_100, ironing: 450, packing: 380, warehouse: 900), to: a)
            _ = try? service.addShipmentReport(number: "E-512", quantity: 800, to: a)
        }
        // Partially assigned big order.
        if let a = assign(3, 1, 5_000, 3) { _ = a }
        // Next month bookings for capacity charts.
        _ = assign(4, 0, 900, 30)
        _ = assign(5, 2, 1_600, 32)

        // Projects (quotes).
        for (client, qty, price, minutes, fabric, status, due, notes) in [
            (
                "Lumen Activewear", 12_000, 61.5, 14.0, "Supplex 220g", ProjectStatus.pending, 60,
                "Muestra física aprobada, falta precio final."
            ),
            ("Bayer California", 8_000, 72.0, 11.5, "Popelina 100% algodón", .accepted, 75, "Entregas parciales cada 15 días."),
            ("Best Girl", 3_000, 95.0, 22.0, "Lino lavado", .declined, 30, "Cliente buscó proveedor más barato."),
        ] {
            let p = Project(context: context)
            p.stampCreated()
            p.clientName = client
            p.client = clients.first { $0.name == client }
            p.quantity = Int64(qty); p.price = price; p.minutes = minutes; p.fabric = fabric
            p.status = status; p.deliveryDate = day(due); p.notes = notes
        }

        // Users.
        for (first, last, email, role, plant) in [
            ("Mariana", "Treviño", "admin@demo.local", Role.admin, nil as Plant?),
            ("Carmen", "Ruiz", "cortes@demo.local", .cutManager, nil),
            ("Jorge", "Salinas", "planta@demo.local", .plantManager, plants[0]),
            ("Ana", "Villarreal", "envios@demo.local", .shippingManager, nil),
        ] {
            _ = try? Session.createUser(
                firstName: first, lastName: last, email: email, phone: "", password: demoPassword,
                role: role, plant: plant, avatar: nil, in: context)
        }

        try? context.saveIfNeeded()
    }
}
