import Foundation
import Sentry
import UIKit

/// Thin wrapper around the Sentry Cocoa SDK so the rest of the app doesn't
/// import Sentry directly. Reads the DSN from `Config.EXPO_PUBLIC_SENTRY_DSN`;
/// when the DSN is empty (e.g. local builds) the service no-ops cleanly.
///
/// PII hygiene:
///  - `sendDefaultPii = false` so emails / IPs aren't auto-attached.
///  - We also install a `beforeSend` hook that scrubs anything that looks
///    like a JWT or bearer token from the message string.
///  - We never attach prompts, response bodies, or health values; only
///    screen names + error types via `ErrorLogger`.
@MainActor
enum CrashReportingService {
    private static var didStart = false

    static func start() {
        guard !didStart else { return }
        let dsn = Config.EXPO_PUBLIC_SENTRY_DSN.trimmingCharacters(in: .whitespaces)
        guard !dsn.isEmpty else {
            print("Sentry: DSN not configured, skipping init")
            return
        }
        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = isDebugBuild() ? "debug" : "release"
            options.releaseName = appVersion()
            options.sendDefaultPii = false
            options.attachScreenshot = false
            options.attachViewHierarchy = false
            // Sample at 10% in release; full in debug for easier verification.
            options.tracesSampleRate = isDebugBuild() ? 1.0 : 0.1
            options.beforeSend = { event in
                scrub(event: event)
                return event
            }
        }
        didStart = true
    }

    static func capture(
        error: Error,
        screen: String?,
        severity: SentryLevel,
        context: [String: String]
    ) {
        guard didStart else { return }
        SentrySDK.capture(error: error) { scope in
            scope.setLevel(severity)
            if let screen { scope.setTag(value: screen, key: "screen") }
            for (k, v) in context where !looksSensitive(k) {
                scope.setTag(value: v, key: k)
            }
        }
    }

    static func capture(
        message: String,
        screen: String?,
        severity: SentryLevel,
        context: [String: String]
    ) {
        guard didStart else { return }
        SentrySDK.capture(message: scrubString(message)) { scope in
            scope.setLevel(severity)
            if let screen { scope.setTag(value: screen, key: "screen") }
            for (k, v) in context where !looksSensitive(k) {
                scope.setTag(value: v, key: k)
            }
        }
    }

    static func breadcrumb(category: String, message: String, level: SentryLevel = .info) {
        guard didStart else { return }
        let crumb = Breadcrumb(level: level, category: category)
        crumb.message = scrubString(message)
        SentrySDK.addBreadcrumb(crumb)
    }

    static func setUser(id: String?) {
        guard didStart else { return }
        if let id, !id.isEmpty {
            let user = User(userId: id)
            SentrySDK.setUser(user)
        } else {
            SentrySDK.setUser(nil)
        }
    }

    // MARK: - Helpers

    private static func isDebugBuild() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    private static func appVersion() -> String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "0.0"
        let b = info?["CFBundleVersion"] as? String ?? "0"
        let bundleId = Bundle.main.bundleIdentifier ?? "com.peppal.app"
        return "\(bundleId)@\(v)+\(b)"
    }

    private static func looksSensitive(_ key: String) -> Bool {
        let lower = key.lowercased()
        return lower.contains("token") || lower.contains("secret")
            || lower.contains("password") || lower.contains("auth")
            || lower.contains("email")
    }

    private static func scrubString(_ s: String) -> String {
        // Strip eyJ-prefixed JWTs and "Bearer ..." headers.
        var out = s
        if let regex = try? NSRegularExpression(pattern: "eyJ[A-Za-z0-9_\\-]+\\.[A-Za-z0-9_\\-]+\\.[A-Za-z0-9_\\-]+") {
            out = regex.stringByReplacingMatches(
                in: out,
                range: NSRange(out.startIndex..., in: out),
                withTemplate: "[redacted-jwt]"
            )
        }
        if let regex = try? NSRegularExpression(pattern: "(?i)bearer\\s+[A-Za-z0-9._\\-]+") {
            out = regex.stringByReplacingMatches(
                in: out,
                range: NSRange(out.startIndex..., in: out),
                withTemplate: "[redacted-bearer]"
            )
        }
        return out
    }

    private static func scrub(event: Event) {
        if let msg = event.message?.formatted {
            event.message = SentryMessage(formatted: scrubString(msg))
        }
        // Drop any breadcrumb messages that looked sensitive.
        event.breadcrumbs = event.breadcrumbs?.map { crumb in
            if let m = crumb.message {
                crumb.message = scrubString(m)
            }
            return crumb
        }
    }
}
