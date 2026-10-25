# Trama for Android (planned)

Native Kotlin port of the iPad app. This folder is a placeholder until the port starts.

## Target stack

| Concern | iOS (reference) | Android |
|---|---|---|
| UI | SwiftUI, `NavigationSplitView` | Jetpack Compose, Material 3, `ListDetailPaneScaffold` (tablet first) |
| Local DB | Core Data | Room (SQLite) |
| State | Observation (`@Observable`) | ViewModel + `StateFlow` |
| Auth | PBKDF2-SHA256 in CommonCrypto | `javax.crypto` PBKDF2WithHmacSHA256, same parameters |
| Charts | Swift Charts | Vico (or Compose Canvas) |
| Images | PhotosPicker / camera | Photo Picker / CameraX |
| Backup | JSON v1 | JSON v1, same schema |
| Distribution | Apple Business Manager custom app | Managed Google Play (private app) |

## Rules of the port

1. The behavior contract is [`docs/DOMAIN.md`](../docs/DOMAIN.md). Port the iOS unit tests in
   `ios/TramaTests/` first, then implement until they pass.
2. Keep the same design tokens (`ios/Trama/DesignSystem/Theme.swift`): petrol teal `#145C6E`,
   thread yellow `#E8B314` / `#F4C430`, linen canvas `#F4F1EA`, and the same Spanish copy.
3. Backups made on iPad must restore on Android and vice versa.
4. Gradle project lives in this folder (`android/app`, `android/core/...`). Build with `./gradlew build`.
