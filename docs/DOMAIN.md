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

## Sync (optional cloud, `platform/`)

Local storage stays the source of truth; sync never blocks a screen. Contract (see `platform/src/sync.ts`):

- **Payload** = one backup element (`data`), same keys and formats as the backup file. Ids may be sent in
  any case; the server stores and returns them lowercase.
- **Push** queued local changes (`entity`, `id`, `updatedAt`, `deleted`, `data`). Every local write,
  including cascaded deletes, must be queued; changes applied from the server must not be.
- **Pull** pages after a persisted cursor; apply by id (upsert, `deleted` → delete), parents before children.
- **Conflicts:** last writer wins on `updatedAt`. A pulled change does not overwrite a newer unpushed local
  edit; a `stale` push rejection carries the server copy, which the device adopts. `forbidden`, `limit`,
  `conflict` and `invalid` rejections are shown to the user and dropped.
- **Licence:** when `licence.writable` is false the data stays readable, local writes are blocked and the
  queue is kept until renewal.
- **First link of a device:** an empty company is seeded with the device's data; otherwise the device backs
  up and replaces its local data with the company's. Demo data is never uploaded.
- Synced users carry `passwordHash`/`passwordSalt`, so offline sign-in keeps working (rule 10).
