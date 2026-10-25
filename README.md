# Trama

**Control de producción textil para iPad, sin conexión.**

Trama runs a garment manufacturer's floor: cut orders are assigned to plants against their
monthly capacity, plant, cut and shipment managers report progress from their iPads, and the
owner sees revenue in production, capacity per plant and urgent shipments at a glance.
Everything lives on the device (Core Data), so it works with no internet at all.

Trama started as the internal app of **Industrial Peña Balles (IPB)**. It was rebuilt from a
2016 UIKit/Storyboard app into SwiftUI and is now licensed to other textile companies.

## Repository layout (monorepo)

| Folder | What | Status |
|---|---|---|
| [`ios/`](ios/) | iPad app: SwiftUI + Core Data, iOS 17+ | ✅ Production |
| [`web/`](web/) | Sales landing page (static site, deployed to Hugging Face Spaces) | ✅ |
| [`android/`](android/) | Kotlin / Jetpack Compose port | 🗺️ Planned ([plan](android/README.md)) |
| [`docs/`](docs/) | Platform-neutral domain spec shared by all apps ([DOMAIN.md](docs/DOMAIN.md)) | ✅ |

## Features (iPad)

- **Cortes por asignar**: cut orders (code, list, garment, style, client, quantity, unit price, internal and client dates) with assignment progress.
- **Asignación por capacidad**: split a cut across plants; each plant previews its monthly capacity (MXN) live before you confirm.
- **Tablero de corte**: drag-and-drop kanban of cutting status (en espera → en mesa de corte → listo para confeccionar).
- **Reportes de producción**: plant (staff, produced, ironing, packing, warehouse), cut (real quantity, status) and shipment reports, a production funnel per cut, totals, filters and CSV export.
- **Envíos urgentes**: what's due soon or overdue, with quick shipment registration.
- **Calendario de plantas**: monthly production starts, client deliveries and capacity.
- **Dashboard**: KPIs, capacity and revenue charts, cutting pipeline, recent activity.
- **Catálogos**: plants, clients and suppliers with unlimited contacts, a style photo gallery, projects/quotes, users.
- **Roles**: Administrador, Gerente de Cortes, Gerente de Planta (sees only their plant), Gerente de Envíos.
- **Calculadora** de producción: daily goal, estimated days and months, price per minute, income.
- **Offline first**: local database, offline login (PBKDF2), JSON backup/restore, optional import from the legacy IPB server.
- ⌘K search everywhere, keyboard shortcuts, light/dark mode, portrait and landscape.

## Getting started (iOS)

Requirements: Xcode 16+ (tested on Xcode 26.3), [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
cd ios
xcodegen generate          # creates Trama.xcodeproj from project.yml
open Trama.xcodeproj       # run the "Trama" scheme on an iPad simulator
```

The first launch asks you to create the company's admin account, or to load demo data. Demo accounts use the password `trama123`:

| Email | Role |
|---|---|
| `admin@demo.local` | Administrador |
| `cortes@demo.local` | Gerente de Cortes |
| `planta@demo.local` | Gerente de Planta |
| `envios@demo.local` | Gerente de Envíos |

Tests (Swift Testing, 56 tests):

```bash
cd ios
SIM=$(xcrun simctl list devices available | grep -m1 -E "iPad (Pro|Air)" | grep -oE '[0-9A-F-]{36}')
xcodebuild -project Trama.xcodeproj -scheme Trama -destination "platform=iOS Simulator,id=$SIM" test
```

## Architecture (iOS)

```
ios/Trama
├── App/            entry point, session/router/toast/connectivity services, root view
├── Core/
│   ├── Domain/       pure business rules (no Core Data), fully unit tested
│   ├── Persistence/  Core Data model + stack + entity conveniences
│   └── Services/     ProductionService & CatalogService (single write paths), auth,
│                     backup, demo seed, legacy importer
├── DesignSystem/   Theme tokens, formatting, reusable components (cards, KPIs, charts, forms)
└── Features/       one folder per area (Orders, Production, Reports, Plants, …)
```

See [`CLAUDE.md`](CLAUDE.md) for conventions and [`docs/DOMAIN.md`](docs/DOMAIN.md) for the rules.

## Licensing

Trama is proprietary software, distributed privately under a licence (no public App Store download).
See the website in [`web/`](web/) or write to riyad.faek@gmail.com.

Proprietary software. All rights reserved.
