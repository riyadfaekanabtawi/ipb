package com.nevutech.trama.core.domain

// Raw values are stable: they are stored in Room and in JSON backups shared with iOS
// (see docs/DOMAIN.md). Never rename them.

/** Job title ("puesto") of a user. Drives navigation and report permissions. */
enum class Role(val raw: String, val title: String) {
    Admin("Administrador", "Administrador"),
    PlantManager("Gerente de Planta", "Gerente de planta"),
    CutManager("Gerente de Cortes", "Gerente de cortes"),
    ShippingManager("Gerente de Envios", "Gerente de envíos");

    /** Report kinds this role may create. Admin chooses among all. */
    val creatableReports: List<ReportKind>
        get() = when (this) {
            Admin -> ReportKind.entries
            PlantManager -> listOf(ReportKind.Plant)
            CutManager -> listOf(ReportKind.Cut)
            ShippingManager -> listOf(ReportKind.Shipment)
        }

    fun canEdit(kind: ReportKind) = kind in creatableReports

    /** Sections visible in navigation, mirroring the legacy menu gating. */
    val sections: List<AppSection>
        get() = when (this) {
            Admin -> AppSection.entries
            CutManager -> listOf(AppSection.Orders, AppSection.Board, AppSection.Production, AppSection.Calendar, AppSection.Settings)
            PlantManager -> listOf(AppSection.Production, AppSection.Settings)
            ShippingManager -> listOf(AppSection.Production, AppSection.Shipments, AppSection.Settings)
        }

    val landing: AppSection
        get() = when (this) {
            Admin -> AppSection.Dashboard
            CutManager -> AppSection.Orders
            PlantManager, ShippingManager -> AppSection.Production
        }

    companion object {
        fun fromRaw(raw: String?): Role = entries.firstOrNull { it.raw == raw } ?: PlantManager
    }
}

/** Cutting-table status of an assignment, set through the cut report. */
enum class CutStatus(val raw: String, val title: String) {
    Waiting("en_espera", "En espera"),
    OnTable("en_mesa_de_corte", "En mesa de corte"),
    Ready("listo_para_confeccionar", "Listo para confeccionar");

    companion object {
        fun fromRaw(raw: String?): CutStatus? = entries.firstOrNull { it.raw == raw }

        /** Accepts both new raw values and the legacy free-text statuses. */
        fun fromLegacy(value: String?): CutStatus = when (value?.trim()?.lowercase()) {
            "en mesa de corte", OnTable.raw -> OnTable
            "listo para confeccionar", Ready.raw -> Ready
            else -> Waiting
        }
    }
}

enum class ReportKind(val raw: String, val title: String, val shortTitle: String) {
    Plant("planta", "Reporte de planta", "Planta"),
    Cut("corte", "Reporte de corte", "Corte"),
    Shipment("envio", "Reporte de envío", "Envío");

    companion object {
        fun fromRaw(raw: String?): ReportKind = entries.firstOrNull { it.raw == raw } ?: Plant
    }
}

enum class ProjectStatus(val raw: String, val title: String) {
    Pending("pendiente", "Pendiente"),
    Accepted("aceptado", "Aceptado"),
    Declined("declinado", "Declinado");

    companion object {
        fun fromRaw(raw: String?): ProjectStatus = entries.firstOrNull { it.raw == raw } ?: Pending
    }
}

/** Assignment state of a cut order, derived from how much of it has been sent to plants. */
enum class OrderAssignmentState(val title: String) {
    Unassigned("Por asignar"),
    Partial("Parcial"),
    Assigned("Asignado");

    companion object {
        fun of(quantity: Long, assigned: Long): OrderAssignmentState = when {
            assigned == 0L -> Unassigned
            assigned >= quantity -> Assigned
            else -> Partial
        }
    }
}

enum class AppSection(val title: String, val group: Group) {
    Dashboard("Dashboard", Group.Operations),
    Orders("Cortes por asignar", Group.Operations),
    Board("Tablero de corte", Group.Operations),
    Production("Reportes de producción", Group.Operations),
    Shipments("Envíos urgentes", Group.Operations),
    Calendar("Calendario de plantas", Group.Operations),
    Plants("Plantas", Group.Catalogs),
    Clients("Clientes", Group.Catalogs),
    Suppliers("Proveedores", Group.Catalogs),
    Styles("Estilos", Group.Catalogs),
    Projects("Proyectos", Group.Catalogs),
    Users("Usuarios", Group.Catalogs),
    Calculator("Calculadora", Group.Tools),
    Settings("Ajustes", Group.Tools);

    enum class Group(val title: String) { Operations("Operación"), Catalogs("Catálogos"), Tools("Herramientas") }
}
