package com.nevutech.trama.core.data

import com.nevutech.trama.core.domain.CutStatus
import com.nevutech.trama.core.domain.ProjectStatus
import com.nevutech.trama.core.domain.Role
import java.time.LocalDate

/**
 * Same demo dataset as ios/Trama/Core/Services/DemoSeeder.swift, so both platforms demo identically.
 * Demo accounts all use the password [DEMO_PASSWORD].
 */
object DemoSeeder {
    const val DEMO_PASSWORD = "trama123"
    const val DEMO_COMPANY = "Textiles Demo"

    suspend fun seed(db: TramaDatabase, today: LocalDate = LocalDate.now()) {
        val dao = db.dao()
        fun day(offset: Int) = today.plusDays(offset.toLong())

        val plants = listOf("Planta Norte" to 1_800_000.0, "Planta Sur" to 1_200_000.0, "Planta Bajío" to 950_000.0)
            .map { (name, cap) -> PlantEntity(name = name, maxCapacity = cap).also { dao.upsert(it) } }

        val clientSpecs = listOf(
            Triple("Bayer California", "Av. Insurgentes Sur 1458, CDMX", listOf(
                listOf("Laura Méndez", "Compras", "laura.mendez@bayerca.com", "55 2345 9988"),
                listOf("Óscar Ruiz", "Calidad", "oscar.ruiz@bayerca.com", "55 2345 9900"),
            )),
            Triple("Best Girl", "Blvd. Díaz Ordaz 230, Monterrey", listOf(listOf("Sofía Treviño", "Directora de producto", "sofia@bestgirl.mx", "81 1122 3344"))),
            Triple("Andes Denim Co.", "Calle 5 de Mayo 77, Guadalajara", listOf(listOf("Diego Paredes", "Gerente de abasto", "dparedes@andesdenim.com", "33 9988 7766"))),
            Triple("Lumen Activewear", "Parque Industrial Querétaro, Nave 12", listOf(listOf("Mariana Sosa", "Planeación", "mariana@lumenactive.com", "442 555 1010"))),
        )
        val clients = clientSpecs.map { (name, address, contacts) ->
            val client = ClientEntity(name = name, address = address).also { dao.upsert(it) }
            contacts.forEachIndexed { i, c -> dao.upsert(ContactEntity(name = c[0], role = c[1], email = c[2], phone = c[3], sortIndex = i, clientId = client.id)) }
            client
        }

        listOf(
            listOf("Hilados del Bajío", "León, Gto.", "Ramón Ibarra", "Ventas", "ventas@hiladosbajio.mx", "477 210 3030"),
            listOf("Avíos y Etiquetas MX", "Puebla, Pue.", "Claudia Romo", "Ejecutiva de cuenta", "claudia@aviosmx.com", "222 404 5050"),
            listOf("Telas Finas del Norte", "Torreón, Coah.", "Héctor Garza", "Director comercial", "hgarza@telasfinas.mx", "871 300 2020"),
        ).forEach { s ->
            val supplier = SupplierEntity(name = s[0], address = s[1]).also { dao.upsert(it) }
            dao.upsert(ContactEntity(name = s[2], role = s[3], email = s[4], phone = s[5], supplierId = supplier.id))
        }

        val styles = listOf("Falda plisada SK-210", "Jeans skinny DN-88", "Blusa lino BL-14", "Legging sport LG-301", "Chamarra mezclilla JK-05")
            .map { StyleEntity(name = it).also { s -> dao.upsert(s) } }

        val service = ProductionService(db, "Demo")
        data class Spec(val code: String, val list: String, val garment: String, val qty: Long, val price: Double, val client: Int, val style: Int, val internal: Int, val due: Int)
        val orders = listOf(
            Spec("C-1042", "L-340", "Falda", 4_000, 68.0, 0, 0, -20, 4),
            Spec("C-1043", "L-340", "Jeans", 6_500, 112.0, 2, 1, -15, 12),
            Spec("C-1050", "L-352", "Blusa", 2_800, 74.0, 1, 2, -9, 2),
            Spec("C-1051", "L-352", "Legging", 9_000, 58.0, 3, 3, -6, 21),
            Spec("C-1060", "L-360", "Chamarra", 1_500, 260.0, 2, 4, -2, 35),
            Spec("C-1061", "L-360", "Falda", 3_200, 70.0, 0, 0, 0, 40),
            Spec("C-1062", "L-361", "Blusa", 5_000, 76.0, 1, 2, 1, 45),
        ).map { s ->
            val order = service.saveOrder(null, s.code, s.list, s.garment, s.qty, s.price, clients[s.client].id, styles[s.style].id, day(s.internal), day(s.due), null)
            order.copy(createdAt = day(s.internal).toEpochMillis()).also { dao.upsert(it) }
        }

        suspend fun assign(o: Int, p: Int, qty: Int, offset: Int) =
            runCatching { service.assign(orders[o].id, plants[p].id, qty, day(offset)) }.getOrNull()

        assign(0, 0, 4_000, -18)?.let { a ->
            service.saveCutReport(CutStatus.Ready, 3_960, a.id)
            service.savePlantReport(ProductionService.PlantReportInput(42, 3, 3_400, 600, 900, 1_400), a.id)
            service.saveShipmentReport("E-501", 1_200, a.id)
        }
        assign(1, 0, 4_000, -10)?.let { a -> service.saveCutReport(CutStatus.OnTable, 0, a.id) }
        assign(1, 1, 2_500, -8)?.let { a ->
            service.saveCutReport(CutStatus.Ready, 2_480, a.id)
            service.savePlantReport(ProductionService.PlantReportInput(28, 1, 1_100, 300, 200, 300), a.id)
        }
        assign(2, 2, 2_800, -7)?.let { a ->
            service.saveCutReport(CutStatus.Ready, 2_790, a.id)
            service.savePlantReport(ProductionService.PlantReportInput(19, 2, 2_100, 450, 380, 900), a.id)
            service.saveShipmentReport("E-512", 800, a.id)
        }
        assign(3, 1, 5_000, 3)
        assign(4, 0, 900, 30)
        assign(5, 2, 1_600, 32)

        listOf(
            listOf("Lumen Activewear", 12_000L, 61.5, 14.0, "Supplex 220g", ProjectStatus.Pending, 60, "Muestra física aprobada, falta precio final."),
            listOf("Bayer California", 8_000L, 72.0, 11.5, "Popelina 100% algodón", ProjectStatus.Accepted, 75, "Entregas parciales cada 15 días."),
            listOf("Best Girl", 3_000L, 95.0, 22.0, "Lino lavado", ProjectStatus.Declined, 30, "Cliente buscó proveedor más barato."),
        ).forEach { p ->
            val name = p[0] as String
            dao.upsert(ProjectEntity(
                clientName = name, clientId = clients.firstOrNull { it.name == name }?.id, quantity = p[1] as Long,
                price = p[2] as Double, minutes = p[3] as Double, fabric = p[4] as String, status = (p[5] as ProjectStatus).raw,
                deliveryDate = day(p[6] as Int).toEpochMillis(), notes = p[7] as String,
            ))
        }

        listOf(
            listOf("Mariana", "Treviño", "admin@demo.local", Role.Admin, null),
            listOf("Carmen", "Ruiz", "cortes@demo.local", Role.CutManager, null),
            listOf("Jorge", "Salinas", "planta@demo.local", Role.PlantManager, plants[0].id),
            listOf("Ana", "Villarreal", "envios@demo.local", Role.ShippingManager, null),
        ).forEach { u ->
            runCatching {
                Session.createUser(dao, u[0] as String, u[1] as String, u[2] as String, "", DEMO_PASSWORD, u[3] as Role, u[4] as String?)
            }
        }
    }
}
