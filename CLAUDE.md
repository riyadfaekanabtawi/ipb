# Trama: agent guide

Trama is a licensed, offline-first production-control product for textile manufacturers
(originally built for Industrial Peña Balles, "IPB"). The flow: cut orders → assignment to plants
by monthly capacity → production reports (plant, cut, shipment) → urgent shipments. It also has
catalogs (plants, clients, suppliers, styles, users, projects) and a production calculator.

## Monorepo

| Path | Contents |
|---|---|
| `ios/` | iPad app: SwiftUI + Core Data, XcodeGen (`ios/project.yml`) |
| `web/` | Static sales landing page, deployed to a Hugging Face Space by GitHub Actions |
| `android/` | Android app: Kotlin + Jetpack Compose + Room; same rules and backup format as iOS (see `android/README.md`) |
| `contact-api/` | Vercel serverless endpoint for the licence form (Gmail SMTP via nodemailer); see its README |
| `docs/DOMAIN.md` | **The behavior contract shared by all platforms.** Update it with any rule change |

## Commands (iOS)

```bash
cd ios
xcodegen generate                 # regenerate Trama.xcodeproj (the post-edit hook does this on project.yml edits)
SIM=$(xcrun simctl list devices available | grep -m1 -E "iPad (Pro|Air)" | grep -oE '[0-9A-F-]{36}')
xcodebuild -project Trama.xcodeproj -scheme Trama -destination "platform=iOS Simulator,id=$SIM" build
xcodebuild -project Trama.xcodeproj -scheme Trama -destination "platform=iOS Simulator,id=$SIM" test
```

- Use a private `-derivedDataPath` when several agents build in parallel, and delete it afterwards (disk space is tight on this machine).
- DEBUG launch args for QA and screenshots: `-uiTestDemo` (in-memory demo store), `-loginAs admin@demo.local`, `-openSection <AppSection rawValue>`, `-openRoute firstAssignment|firstOrder`.
- Demo password `trama123`. Accounts: `admin@`, `cortes@`, `planta@`, `envios@demo.local`.
- The bundle id stays `com.nevutech.ipb` so IPB's installed iPads update in place.

## Commands (Android)

```bash
cd android && ./gradlew :app:testDebugUnitTest   # 65 JVM/Robolectric tests
./gradlew :app:installDebug                         # needs a running emulator (AVD `trama_tablet`)
```

Rule changes must land in `docs/DOMAIN.md`, iOS and Android together, with tests on both sides.

## Commands (web)

`web/` is plain HTML/CSS/JS with no build step. Preview it with `python3 -m http.server -d web 8000`. Live at https://ranabtawi-trama.static.hf.space (Space `ranabtawi/trama`). Publish with `web/deploy.sh` (uses the local `hf` login) or let CI do it on pushes to `main` (`.github/workflows/deploy-web.yml`, needs the `HF_TOKEN` secret and `HF_SPACE=ranabtawi/trama`).

## iOS architecture

- **SwiftUI only, iOS 17+, iPad.** No storyboards, no third-party dependencies.
- **Offline-first.** Core Data is the source of truth. The network is never required. The legacy importer (`Core/Services/Legacy`) is optional.
- Layers:
  - `Core/Domain`: pure rules, unit tested.
  - `Core/Persistence`: model `Trama.xcdatamodeld` (Xcode codegen) + `Entities+Domain.swift`.
  - `Core/Services`: `ProductionService` and `CatalogService` (**all writes**, saved with `saveTracked`), `Session` (auth), `BackupService`, `DemoSeeder`, legacy import.
  - `Core/Sync`: optional licence + sync with the platform API (`SyncEngine`, outbox, `APIClient`). Inert without a licence. Rules in `docs/DOMAIN.md` (13–22). API base URL: `TRAMA_API_BASE_URL` build setting; DEBUG launch arg `-apiBase http://localhost:8787/api`.
  - `DesignSystem`: `Theme`/`Brand`/`Fmt` + components.
  - `Features/<Area>`: the screens.
- Environment: `Session`, `AppRouter`, `ToastCenter`, `ConnectivityMonitor`, `\.managedObjectContext`, `\.persistence`.
- Navigation: `AppRouter.selection` + per-section `NavigationPath` of `Route` (object IDs).
- iPadOS 26 quirk: SwiftUI `Table` lays out under the floating sidebar, so use custom lists.

## Conventions

- UI copy in **Spanish (Mexico)**; code and comments in **English**.
- Never hard-code colors; use `Theme` and the existing components (`card()`, `KPITile`, `Pill`, `CapacityBar`, `FormSheet`, `IntField`, `DecimalField`, `PhotoField`, `ChartCard`, …).
- Feedback through `ToastCenter`; confirm destructive actions with `confirmDelete`.
- Views never save Core Data directly; call the services inside `do/catch`.
- Model changes: add a new model version, keep it lightweight-migratable, and carry the change through `BackupService`, `DemoSeeder`, tests and `docs/DOMAIN.md` (ask `coredata-steward`).
- Every rule gets a Swift Testing test in `ios/TramaTests`.

## Roles

| Role | Sections | Creates reports |
|---|---|---|
| Administrador | all | all |
| Gerente de Cortes | orders, board, production, calendar | corte |
| Gerente de Planta | production (own plant only) | planta |
| Gerente de Envíos | production, shipments | envío |

## Workflow and policy

- Branch per change, then `gh pr create`. Never push to `main`. Deploys (App Store / Hugging Face) run through CI or by the owner, never by an agent.
- **No AI attribution**: no `Co-Authored-By` lines and no "generated with" text in commits or PRs. The `guard-bash` hook enforces this.
- Hooks (`.claude/settings.json`): Bash guard, swift-format on edit, XcodeGen regeneration, Core Data reminder, session context.
- Subagents (`.claude/agents/`): `ipb-domain-expert`, `swiftui-feature-builder`, `coredata-steward`, `ipb-reviewer`.
