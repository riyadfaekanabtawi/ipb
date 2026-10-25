import CoreData
import Network
import Observation
import SwiftUI

/// Network reachability. The app never requires it; it only drives the status badge and optional sync.
@MainActor
@Observable
final class ConnectivityMonitor {
    private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: DispatchQueue(label: "trama.connectivity"))
    }

    deinit { monitor.cancel() }
}

/// Lightweight non-blocking feedback, replacing the legacy "Bien!" alert after every action.
@MainActor
@Observable
final class ToastCenter {
    struct Toast: Identifiable, Equatable {
        enum Style { case success, error, info }
        let id = UUID()
        var message: String
        var style: Style
    }

    private(set) var current: Toast?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, style: Toast.Style = .success) {
        current = Toast(message: message, style: style)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(style == .error ? .error : .success)
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(style == .error ? 4 : 2.4))
            guard !Task.isCancelled else { return }
            withAnimation(.spring) { self?.current = nil }
        }
    }

    func error(_ error: Error) { show(error.localizedDescription, style: .error) }

    func dismiss() { withAnimation(.spring) { current = nil } }
}

/// Sidebar selection + per-section navigation stacks + command palette.
@MainActor
@Observable
final class AppRouter {
    var selection: AppSection? = .dashboard
    var paths: [AppSection: NavigationPath] = [:]
    var isCommandPalettePresented = false

    func path(for section: AppSection) -> Binding<NavigationPath> {
        Binding(
            get: { self.paths[section] ?? NavigationPath() },
            set: { self.paths[section] = $0 }
        )
    }

    func open(_ section: AppSection) {
        selection = section
    }

    /// Jump to a section and push a destination onto its stack.
    func open<D: Hashable>(_ section: AppSection, pushing destination: D) {
        selection = section
        var path = NavigationPath()
        path.append(destination)
        paths[section] = path
    }
}

/// Navigation destinations carried in `NavigationPath`. Object IDs keep them Hashable and cheap.
enum Route: Hashable {
    case assignment(NSManagedObjectID)
    case order(NSManagedObjectID)
    case plant(NSManagedObjectID)
    case client(NSManagedObjectID)
    case supplier(NSManagedObjectID)
    case style(NSManagedObjectID)
}
