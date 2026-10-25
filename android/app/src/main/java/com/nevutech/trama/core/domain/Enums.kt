package com.nevutech.trama.core.domain

import androidx.annotation.StringRes
import com.nevutech.trama.R
import com.nevutech.trama.core.l10n.L10n

// Raw values are stable: they are stored in Room and in JSON backups shared with iOS
// (see docs/DOMAIN.md). Never rename them. Display names come from string resources
// (`titleRes`); `title` resolves them in the app's current language.

/** Job title ("puesto") of a user. Drives navigation and report permissions. */
enum class Role(val raw: String, @StringRes val titleRes: Int) {
    Admin("Administrador", R.string.role_admin),
    PlantManager("Gerente de Planta", R.string.role_plant_manager),
    CutManager("Gerente de Cortes", R.string.role_cut_manager),
    ShippingManager("Gerente de Envios", R.string.role_shipping_manager);

    val title: String get() = L10n.str(titleRes)

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
enum class CutStatus(val raw: String, @StringRes val titleRes: Int) {
    Waiting("en_espera", R.string.cut_status_waiting),
    OnTable("en_mesa_de_corte", R.string.cut_status_on_table),
    Ready("listo_para_confeccionar", R.string.cut_status_ready);

    val title: String get() = L10n.str(titleRes)

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

enum class ReportKind(val raw: String, @StringRes val titleRes: Int, @StringRes val shortTitleRes: Int) {
    Plant("planta", R.string.report_kind_plant, R.string.report_kind_plant_short),
    Cut("corte", R.string.report_kind_cut, R.string.report_kind_cut_short),
    Shipment("envio", R.string.report_kind_shipment, R.string.report_kind_shipment_short);

    val title: String get() = L10n.str(titleRes)
    val shortTitle: String get() = L10n.str(shortTitleRes)

    companion object {
        fun fromRaw(raw: String?): ReportKind = entries.firstOrNull { it.raw == raw } ?: Plant
    }
}

enum class ProjectStatus(val raw: String, @StringRes val titleRes: Int) {
    Pending("pendiente", R.string.project_status_pending),
    Accepted("aceptado", R.string.project_status_accepted),
    Declined("declinado", R.string.project_status_declined);

    val title: String get() = L10n.str(titleRes)

    companion object {
        fun fromRaw(raw: String?): ProjectStatus = entries.firstOrNull { it.raw == raw } ?: Pending
    }
}

/** Assignment state of a cut order, derived from how much of it has been sent to plants. */
enum class OrderAssignmentState(@StringRes val titleRes: Int) {
    Unassigned(R.string.order_state_unassigned),
    Partial(R.string.order_state_partial),
    Assigned(R.string.order_state_assigned);

    val title: String get() = L10n.str(titleRes)

    companion object {
        fun of(quantity: Long, assigned: Long): OrderAssignmentState = when {
            assigned == 0L -> Unassigned
            assigned >= quantity -> Assigned
            else -> Partial
        }
    }
}

enum class AppSection(@StringRes val titleRes: Int, val group: Group) {
    Dashboard(R.string.section_dashboard, Group.Operations),
    Orders(R.string.section_orders, Group.Operations),
    Board(R.string.section_board, Group.Operations),
    Production(R.string.section_production, Group.Operations),
    Shipments(R.string.section_shipments, Group.Operations),
    Calendar(R.string.section_calendar, Group.Operations),
    Plants(R.string.section_plants, Group.Catalogs),
    Clients(R.string.section_clients, Group.Catalogs),
    Suppliers(R.string.section_suppliers, Group.Catalogs),
    Styles(R.string.section_styles, Group.Catalogs),
    Projects(R.string.section_projects, Group.Catalogs),
    Users(R.string.section_users, Group.Catalogs),
    Calculator(R.string.section_calculator, Group.Tools),
    Settings(R.string.section_settings, Group.Tools);

    val title: String get() = L10n.str(titleRes)

    enum class Group(@StringRes val titleRes: Int) {
        Operations(R.string.section_group_operations), Catalogs(R.string.section_group_catalogs), Tools(R.string.section_group_tools);

        val title: String get() = L10n.str(titleRes)
    }
}
