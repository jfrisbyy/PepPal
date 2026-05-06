import Foundation
import UIKit
import Supabase
import Functions

private nonisolated struct ClientErrorPayload: Encodable, Sendable {
    let message: String
    let severity: String
    let platform: String
    let app_version: String
    let os_version: String
    let device_model: String
    let screen: String?
    let context: [String: String]?
}

private nonisolated struct ClientErrorEnvelope: Encodable, Sendable {
    let action: String
    let payload: ClientErrorPayload
}

/// Lightweight crash / error reporter. Forwards user-visible errors to the
/// `client_errors` table on Supabase via the `super-action` edge function.
///
/// Designed to be drop-in (no third-party SDK) so we have a single throat to
/// choke at scale. Usage:
///
/// ```swift
/// ErrorLogger.shared.log(error, screen: "FeedView")
/// ```
///
/// Submissions are best-effort and silently dropped on failure — we never want
/// the logger itself to surface an error to the user. A small in-memory buffer
/// dedupes repeat fires of the same error so a tight loop doesn't spam the
/// backend.
@MainActor
final class ErrorLogger {
    static let shared = ErrorLogger()
    private init() {}

    private struct Entry: Hashable {
        let message: String
        let screen: String?
        let bucket: Date  // 60-second bucket
    }

    private var recent: Set<Entry> = []
    private var pruneTask: Task<Void, Never>?

    enum Severity: String {
        case info, warning, error, fatal
    }

    /// Log a Swift `Error`. Pulls `localizedDescription` and the type name.
    func log(
        _ error: Error,
        screen: String? = nil,
        severity: Severity = .error,
        context: [String: String] = [:]
    ) {
        let nsError = error as NSError
        var ctx = context
        ctx["domain"] = nsError.domain
        ctx["code"] = String(nsError.code)
        ctx["type"] = String(describing: type(of: error))
        log(
            message: error.localizedDescription,
            screen: screen,
            severity: severity,
            context: ctx
        )
    }

    /// Log a free-form message.
    func log(
        message: String,
        screen: String? = nil,
        severity: Severity = .error,
        context: [String: String] = [:]
    ) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Deduplicate within a 60s window per (message, screen).
        let bucket = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970 / 60) * 60)
        let entry = Entry(message: trimmed, screen: screen, bucket: bucket)
        if recent.contains(entry) { return }
        recent.insert(entry)
        schedulePrune()

        let envelope = ClientErrorEnvelope(
            action: "logClientError",
            payload: ClientErrorPayload(
                message: trimmed,
                severity: severity.rawValue,
                platform: "ios",
                app_version: appVersion(),
                os_version: UIDevice.current.systemVersion,
                device_model: deviceModel(),
                screen: screen,
                context: context.isEmpty ? nil : context
            )
        )

        Task.detached(priority: .background) {
            try? await SupabaseService.shared.client.functions.invoke(
                "super-action",
                options: FunctionInvokeOptions(body: envelope)
            )
        }
    }

    private func schedulePrune() {
        pruneTask?.cancel()
        pruneTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(120))
            if !Task.isCancelled {
                self.recent.removeAll()
            }
        }
    }

    private func appVersion() -> String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.compactMap { element -> String? in
            guard let value = element.value as? Int8, value != 0 else { return nil }
            return String(UnicodeScalar(UInt8(value)))
        }.joined()
    }
}
