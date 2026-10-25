# Trama for Android

Native Kotlin + Jetpack Compose port of the iPad app, tablet-first and also usable on phones.
It behaves exactly like iOS: the contract is [`docs/DOMAIN.md`](../docs/DOMAIN.md), and the iOS
unit tests were ported 1:1.

## Stack

| Concern | iOS | Android |
|---|---|---|
| UI | SwiftUI, `NavigationSplitView` | Jetpack Compose, Material 3; sidebar ≥1000dp, rail ≥600dp, drawer on phones |
| Local DB | Core Data | Room (SQLite) + a live in-memory `Graph` snapshot |
| Writes | `ProductionService`, `CatalogService` | same names, `core/data/` |
| Auth | PBKDF2-SHA256 (CommonCrypto) | PBKDF2WithHmacSHA256, same parameters (cross-checked in tests) |
| Settings | UserDefaults | DataStore (same keys) |
| Images | Core Data external storage | JPEG files in `filesDir/images` (rows keep the file name) |
| Backup | JSON v1 | JSON v1, the same schema: iPad backups restore on Android and vice versa |
| Charts | Swift Charts | Compose Canvas |

## Layout

```
app/src/main/java/com/nevutech/trama/
├── app/            container wiring, navigation, adaptive shell, connectivity
├── core/domain/    pure rules (ported from Swift; JVM tests)
├── core/data/      Room entities/DAO, Graph, services, auth, settings, images, backup, demo seed
├── designsystem/   Trama tokens, woven texture, loom animation, components, toasts
└── feature/        one package per area (orders, production, reports, shipments, plants,
                    clients, styles, projects, users, dashboard, calculator, settings, auth)
```

## Build, test, run

```bash
cd android
./gradlew :app:testDebugUnitTest      # 47 tests (domain, Room, services, catalog, backup)
./gradlew :app:installDebug           # on a running emulator/device
```

Requires JDK 17+ and the Android SDK (compileSdk 36, minSdk 26). `local.properties` with
`sdk.dir=…` is git-ignored.

**QA hook (debug builds):** in-memory demo data + auto sign-in, same contract as iOS `-uiTestDemo`:

```bash
adb shell am start -n com.nevutech.trama/.MainActivity --ez uiTestDemo true \
  --es loginAs admin@demo.local --es openSection Board [--es openRoute firstAssignment]
```

Demo accounts: `admin@`, `cortes@`, `planta@`, `envios@demo.local`, password `trama123`.

## Distribution

Private: Managed Google Play (private app) or direct APK/AAB for each licensed company. No public listing.
