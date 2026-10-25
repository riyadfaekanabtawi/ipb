# Trama domain specification

Platform-neutral description of Trama's data model and business rules. The iOS app
(`ios/`) is the reference implementation; the Android port (`android/`) must behave
identically. When a rule changes, update this file, the iOS code and its tests together.

Reference implementation:
- Rules: `ios/Trama/Core/Domain/ProductionMath.swift`, `CalculatorEngine.swift`, `Enums.swift`, `UserPolicy.swift`
- Writes: `ios/Trama/Core/Services/ProductionService.swift`, `CatalogService.swift`
- Tests: `ios/TramaTests/` (port them 1:1)

## Entities

| Entity | Key fields | Relationships |
|---|---|---|
| Plant | name, maxCapacity (MXN / month) | assignments (deny delete if any), managers |
| Client | name, address | contacts (cascade), orders (deny delete if any), projects |
| Supplier | name, address | contacts (cascade) |
| Contact | name, role, email, phone, sortIndex | client or supplier |
| Style | name, image | orders |
| CutOrder | code, list, garment, quantity, unitPrice, internalDate, clientDate, notes, editedBy | client, style, assignments (cascade) |
| Assignment | quantity, unitPrice, scheduledDate, cuttingStatus | order, plant, reports (cascade) |
| ProductionReport | kind, author, timestamps + kind fields (below) | assignment |
| Project | clientName, quantity, price, minutes, fabric, status, deliveryDate, notes, photo | client (optional) |
| AppUser | firstName, lastName, email (unique, lowercase), phone, role, passwordHash/salt, isActive, avatar | plant (plant managers) |

Every entity has `id` (UUID), `createdAt`, `updatedAt` and `remoteID` (legacy import key).

## Enumerations (raw values are stable; they appear in backups)

- Role: `Administrador`, `Gerente de Planta`, `Gerente de Cortes`, `Gerente de Envios`
- CutStatus: `en_espera`, `en_mesa_de_corte`, `listo_para_confeccionar`
- ReportKind: `planta`, `corte`, `envio`
- ProjectStatus: `pendiente`, `aceptado`, `declinado`

## Rules

1. **Order assignment state**: assigned = Σ assignment.quantity; remaining = max(0, quantity − assigned).
   `unassigned` if assigned = 0, `assigned` if remaining = 0, else `partial`.
2. **Assignment validation** (in this order): date required → quantity > 0 → quantity ≤ remaining →
   quantity × unitPrice ≤ plant's available capacity in the calendar month of the date.
3. **Capacity**: used(month) = Σ quantity × unitPrice of the plant's assignments scheduled in that
   month; available = maxCapacity − used; utilization = used / maxCapacity.
4. **Reports**
   - planta: snapshot of operators, absences, produced, ironing, packing, warehouse. The latest one wins.
   - corte: exactly one per assignment. It sets cuttingStatus and realQuantity. Creating a second one fails, editing it is allowed. Deleting it resets the status to `en_espera`.
   - envio: shipmentNumber + shippedQuantity. These add up.
5. **Metrics**: shippingBase = realCut if > 0 else quantity; toShip = max(0, shippingBase − shipped);
   revenue = quantity × unitPrice.
6. **Urgency**: urgent ⇔ toShip > 0 ∧ clientDate < startOfToday + window days (default 7, setting).
7. **Totals**: sums of quantity, produced, ironing, packing, warehouse, shipped, toShip, revenue.
8. **Visibility**: plant managers see only assignments of their plant. Section access by role:
   - admin: everything;
   - cuts manager: orders, board, production, calendar;
   - plant manager: production;
   - shipping manager: production, shipments.
9. **Report permissions**: admin can create all kinds. Each manager creates only their own kind (planta / corte / envio).
10. **Users**: an email is unique (case-insensitive). Passwords are at least 6 characters, stored as PBKDF2-SHA256 (120k iterations, 16-byte salt, base64). An admin can't delete, deactivate or demote themselves, and at least one active admin must remain.
11. **Deletes**:
    - a plant with assignments can't be deleted;
    - a client with orders can't be deleted;
    - an order with reports can't be deleted;
    - an assignment with reports can't be unassigned.
12. **Calculator**:
    - gross = qty × pricePerStyle; net = gross − expenses
    - pricePerRealMinute = pricePerStyle / realMinutes
    - dailyGoal = operators × minutesPerDay / realMinutes; weekly = dailyGoal × workDaysPerWeek
    - estimatedDays = qty / dailyGoal; estimatedMonths = estimatedDays / workDaysPerMonth
    - minuteEfficiency = clientMinutes / realMinutes
    - realProductionMinute = minutesPerDay × lineOperators / realDailyProduction
    - Any missing input yields "no value", never an error.

## Backup format

Versioned JSON (`formatVersion: 1`) with every entity and attribute. Relationships are referenced by UUID, images are base64. See `ios/Trama/Core/Services/BackupService.swift`. Android must read and write the same format, so customers can move data between platforms.

The sync outbox (below) is device-local bookkeeping and is never part of a backup.

## Licence and sync (platform API)

Reference: `ios/Trama/Core/Sync/` (`SyncEngine`, `SyncOutbox`, `SyncApplier`, `APIClient`), server
contract in `platform/src/sync.ts` and `platform/src/routes/auth.ts`. Tests: `ios/TramaTests/SyncTests.swift`.

13. **Modes.** Without a licence the app is local-only and behaves exactly as before (no outbox,
    no network). "Conectar con mi licencia" (login, onboarding, Ajustes) links the device to a company:
    `POST /api/auth/login {email, password, device: {id, platform, name}}`. The device id is a UUID
    generated once and kept in the Keychain; the refresh token is Keychain-only (never preferences);
    the access token lives in memory. Server errors are shown with the server's Spanish message
    (`bad_credentials`, `plan_web_only`, `device_limit`, `licence_suspended`, `user_inactive`, …).
14. **Offline login.** The login response and pulled users carry `passwordHash`/`passwordSalt`
    (same PBKDF2 scheme as rule 10), so a synced user signs in with no internet. The login screen
    checks local credentials first; when linked, it re-binds the device session to that user in the
    background, and falls back to the platform when the local check fails (new user or password
    reset on the web). A user arriving from the server with the email of a local user adopts the
    server id instead of creating a duplicate.
15. **When linking a device that already has data**, the user chooses: replace it with the company's
    data, or keep it (and, for an administrator, upload all of it once). Restoring a backup and loading
    demo data are local-only actions (hidden while linked); erasing all data also unlinks.
16. **Outbox.** While linked, every write through the services (`saveTracked`) stamps `updatedAt`
    (and `createdAt`/`id` if missing) on each changed record and queues one outbox entry per record
    (`entityName`, `recordID`, `changedAt`, `tombstone`) in the same Core Data transaction. Entries are
    coalesced per record; deletes (including cascades, e.g. a client's contacts) become tombstones.
    Updates that only touch the inverse side of a to-many relationship are not queued.
17. **Push.** `POST /api/sync/push {changes:[{entity, id, updatedAt, deleted, data}]}` in batches
    (≤ 200 changes, ≤ 3 MB). `entity` is one of `plants clients suppliers contacts styles orders
    assignments reports projects users`; `updatedAt` is the outbox `changedAt`; `data` is exactly the
    backup DTO of the record (same keys, ISO-8601 dates with milliseconds, base64 images, relations as
    `…ID`). **Every UUID on the wire is lowercase** (`id` and every `…ID`): the server binds each
    ciphertext to `tenant/entity/id` as sent, while Postgres canonicalizes UUIDs to lowercase.
    `applied` entries leave the outbox (unless the record changed again during the request);
    `stale` rejections adopt the returned `server` copy; `forbidden`/`limit`/`invalid`/`conflict`
    rejections are dropped and surfaced as a toast with the server message.
18. **Pull.** `GET /api/sync/pull?cursor=N&limit=500`, looping while `hasMore`; the cursor is stored
    per device and only advanced after the changes are applied. All pages are applied together:
    upserts by id in dependency order (plants, clients, suppliers, styles, users, contacts, orders,
    projects, assignments, reports), then tombstones in reverse order. A tombstone for a record that
    still has dependents on this device (Deny rules of rule 11) is skipped. Applying never queues
    outbox entries.
19. **Conflicts: last writer wins on `updatedAt`.** A pulled change loses only to a pending local
    change with a newer `changedAt` (which is then pushed); otherwise the server copy is applied and
    the pending entry dropped. The server clamps client times to now + 5 min.
20. **Triggers.** After connecting, app foreground, network reconnect, 3 s after local writes
    (debounced) and "Sincronizar" in Ajustes (which shows company, plan, licence state, last sync,
    pending changes and the last error). Push runs before pull.
21. **Tokens.** A `401` on an authorized call refreshes once (`POST /api/auth/refresh`, rotating the
    refresh token) and retries. If refresh fails, sync pauses and the app asks to connect again; data
    and the outbox stay. "Cerrar sesión" calls `POST /api/auth/logout` (revokes the device session).
    "Desconectar licencia" (admin) also drops the outbox and cursor but keeps local data.
22. **Read-only licence.** When `licence.writable` is false (expired or suspended; push answers `402`),
    service writes fail with "solo lectura", a banner is shown above every section, queued changes
    stay in the outbox, and pulling keeps working.
