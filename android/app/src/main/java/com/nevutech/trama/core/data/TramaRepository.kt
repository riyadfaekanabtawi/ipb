package com.nevutech.trama.core.data

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn

/** Exposes the whole database as one live [Graph]. Room is the source of truth; the app never needs the network. */
class TramaRepository(val db: TramaDatabase, scope: CoroutineScope) {
    val dao = db.dao()

    @Suppress("UNCHECKED_CAST")
    val graph: StateFlow<Graph> = combine(
        dao.plants(), dao.clients(), dao.suppliers(), dao.contacts(), dao.styles(),
        dao.orders(), dao.assignments(), dao.reports(), dao.projects(), dao.users(),
    ) { tables ->
        Graph(
            plants = tables[0] as List<PlantEntity>,
            clients = tables[1] as List<ClientEntity>,
            suppliers = tables[2] as List<SupplierEntity>,
            contacts = tables[3] as List<ContactEntity>,
            styles = tables[4] as List<StyleEntity>,
            orders = tables[5] as List<CutOrderEntity>,
            assignments = tables[6] as List<AssignmentEntity>,
            reports = tables[7] as List<ReportEntity>,
            projects = tables[8] as List<ProjectEntity>,
            users = tables[9] as List<UserEntity>,
        )
    }.stateIn(scope, SharingStarted.Eagerly, Graph())
}
