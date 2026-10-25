# IPB: agent guide

IPB (Industrial Peña Balles) is an iPad app that runs a garment manufacturer's operation:
cut orders → assignment to plants by monthly capacity → production reports (plant, cut,
shipment) → urgent shipments, plus catalogs (plants, clients, suppliers, styles, users,
projects) and a production cost calculator.

> **Migration in progress.** The legacy UIKit/Storyboard/CocoaPods app lives in `IPB/`,
> `IPB.xcodeproj`, `Pods/`. The new SwiftUI + Core Data app is being built in `IPB-Swift/`.
> The final migration PR deletes the legacy app and moves `IPB-Swift/` to the repo root.
> Until then, prefix the paths below with `IPB-Swift/`.

## Commands

```bash
cd IPB-Swift                      # repo root after the migration
xcodegen generate                 # regenerate IPB.xcodeproj from project.yml (hook does this on edit)

# Build + test on an iPad simulator (iPad-only app)
SIM=$(xcrun simctl list devices available | grep -m1 -E "iPad (Pro|Air)" | grep -oE '[0-9A-F-]{36}')
xcodebuild -project IPB.xcodeproj -scheme IPB -destination "platform=iOS Simulator,id=$SIM" build
xcodebuild -project IPB.xcodeproj -scheme IPB -destination "platform=iOS Simulator,id=$SIM" test
```

- Use a private `-derivedDataPath` when several agents build in parallel.
- Launch argument `-uiTestDemo` boots an in-memory store seeded with demo data.
- Demo accounts (Ajustes → load demo, or onboarding): `admin@ipb.mx`, `cortes@ipb.mx`,
  `planta@ipb.mx`, `envios@ipb.mx`, password `ipb123`.

## Architecture

- **SwiftUI only, iOS 17+, iPad.** No storyboards, no third-party dependencies.
- **Offline-first.** Core Data (`Core/Persistence`) is the source of truth. The network is
  never required. `ConnectivityMonitor` only drives a status badge. The optional legacy
  importer (`Core/Services/Legacy`) pulls from the old Rails API when a URL is configured.
- **Layers**
  - `Core/Domain`: pure Swift business rules (no Core Data): `ProductionMath`, `CalculatorEngine`, enums. Unit-test everything here.
  - `Core/Persistence`: model (`IPB.xcdatamodeld`, Xcode-generated classes) + `Entities+Domain.swift` convenience accessors.
  - `Core/Services`: `ProductionService` (**all production writes**), `Session`/`PasswordHasher` (offline auth, PBKDF2), `DemoSeeder`, backup and legacy import.
  - `DesignSystem`: `Theme` tokens, `Fmt` formatting, reusable components (`card()`, `KPITile`, `Pill`, `CapacityBar`, `ProgressRing`, `AvatarView`, `SwatchImage`, `FormSheet`, `IntField`, `DecimalField`, `PhotoField`, `ZoomableImageViewer`, `LoomBackdrop`).
  - `Features/<Area>`: one folder per sidebar area. `Features/Shell` holds `MainShell` (split view + role gating), `Sidebar` and `CommandPalette` (⌘K).
- Environment objects: `Session`, `AppRouter`, `ToastCenter`, `ConnectivityMonitor` (Observation framework), plus `\.managedObjectContext`.
- Navigation: `AppRouter.selection` (sidebar) + per-section `NavigationPath`; push `Route` values (object IDs).

## Conventions

- UI copy in **Spanish (Mexico)**; code, identifiers and comments in **English**.
- Never hard-code colors or fonts; use `Theme` and the components above.
- Feedback goes through `ToastCenter` (`toasts.show`, `toasts.error`), never `UIAlertController`. Use `confirmDelete` before destructive actions.
- Views never save Core Data directly for production data; call `ProductionService` (or `Session` for users) inside `do/catch`.
- Money is MXN, formatted with `Fmt.money`. Quantities are `Int`, prices `Double`.
- Every new rule gets a test in `IPBTests` (Swift Testing, `@Test`, `#expect`).

## Domain

| Term | Meaning |
|------|---------|
| Corte (`CutOrder`) | A cut order: code, lista (batch/list), prenda (garment), estilo, client, quantity, unit price, fecha IPB, fecha cliente. |
| Asignación (`Assignment`) | Part of a cut sent to a plant for a month. Sum of assignments ≤ order quantity. |
| Capacidad | Plant capacity is **MXN per calendar month**; assignment value = qty × unit price. |
| Reporte de planta | Snapshot: operarios, faltas, producidas, en plancha, en empaque, en bodega. Latest wins. |
| Reporte de corte | Exactly **one** per assignment: status (en espera / en mesa de corte / listo para confeccionar) + real cut quantity. |
| Reporte de envío | Shipment number + quantity; additive. |
| Por enviar | (real cut, else planned qty) − shipped. |
| Envío urgente | Por enviar > 0 and client date within `settings.urgencyWindowDays` (default 7) or overdue. |
| Minutaje | Standard minutes per garment (calculator, projects). |

## Roles

| Role (`puesto`) | Sections | Reports it can create |
|---|---|---|
| Administrador | everything | all |
| Gerente de Cortes | cortes por asignar, tablero, producción, calendario | corte |
| Gerente de Planta | producción (own plant only) | planta |
| Gerente de Envíos | producción, envíos urgentes | envío |

## Workflow and policy

- Branch per change (`feat/…`, `fix/…`, `chore/…`), then open a PR with `gh pr create`. Never push to `main`.
- **No AI attribution anywhere**: no `Co-Authored-By` trailers or "generated with" lines in commits or PRs. The `guard-bash` hook enforces this.
- Hooks (`.claude/settings.json`): Bash guard, swift-format on edited Swift files, XcodeGen regeneration when `project.yml` changes, Core Data model change reminder, session context.
- Subagents (`.claude/agents/`): `ipb-domain-expert` (read-only rules), `swiftui-feature-builder` (screens), `coredata-steward` (model, migrations, backup), `ipb-reviewer` (PR review + build/test).
