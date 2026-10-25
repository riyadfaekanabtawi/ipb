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
./gradlew :app:testDebugUnitTest      # 65 tests (domain, Room, services, catalog, backup, sync)
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

## Languages

Spanish (Mexico) is the default (`res/values/`); English (`values-en/`) and Portuguese (Brazil,
`values-pt-rBR/`) are translated. A build step copies `values-pt-rBR` to `values-pt`, so every
Portuguese locale gets it; any other device language falls back to Spanish.

- Copy lives in `strings*.xml` (one file per area). `StringResourcesTest` fails when a key or a
  format argument is missing in a translation.
- Compose uses `stringResource`/`pluralStringResource`; services, sync and toasts use
  `L10n.str`/`L10n.plural` (`core/l10n/L10n.kt`). Enum raw values (roles, statuses, report kinds)
  are never translated; their `titleRes` is.
- The language follows the device, or the picker in Ajustes (and Android 13+ Settings → Apps →
  Trama → Language; `res/xml/locales_config.xml`). Android 12 and older store the choice in the app.
- `Fmt` formats numbers and dates in the current locale; amounts are always MXN.
- Demo data is seeded in the current language. API calls send `Accept-Language` (`es-MX`, `en`,
  `pt-BR`) so the server can answer in the same language.

## Cloud sync (optional)

The app works fully offline; "Conectar con mi licencia" (sign-in/onboarding, or Ajustes → Nube)
links the device to a company on the Trama platform (`platform/`). Code lives in `core/data/sync/`:

| Piece | Role |
|---|---|
| `SyncSchema.kt` | Room v2 (`MIGRATION_1_2`): `sync_outbox` + `sync_state`; SQLite triggers queue every write and enforce the read-only licence |
| `SyncCodec.kt` | Row ↔ payload, identical to the backup DTO elements |
| `SyncStore.kt` | Applies pulls (upsert/delete, parents first, last writer wins), builds pushes |
| `SyncEngine.kt` | Login/link, push + pull loop, token refresh, logout |
| `TramaApi.kt` / `SyncPrefs.kt` | HTTP client; refresh token sealed with an Android Keystore AES-GCM key |

Sync runs after sign-in, on app start/resume, when the network returns, ~3 s after local writes,
every 30 min (WorkManager) and from the "Sincronizar" button. The API base is
`BuildConfig.API_BASE`; debug builds accept an override (cleartext allowed to the emulator host):

```bash
adb shell am start -n com.nevutech.trama/.MainActivity --es apiBase http://10.0.2.2:8787/api
```

## Distribution

Private: Managed Google Play (private app) or direct APK/AAB for each licensed company. No public listing.
