import Foundation
public import os

#if canImport(UIKit)
    public import UIKit
#endif

/// Resumes a continuation once, from any thread: vendor callbacks may arrive twice or off the main actor.
public final class ResumeOnce<Value: Sendable>: Sendable {
    private let state: OSAllocatedUnfairLock<CheckedContinuation<Value, Never>?>

    /// Wraps a continuation that has not been resumed yet.
    public init(_ continuation: CheckedContinuation<Value, Never>) {
        state = OSAllocatedUnfairLock(initialState: continuation)
    }

    /// Resumes with `value` the first time; later calls do nothing.
    public func resume(_ value: Value) {
        let continuation = state.withLock { current -> CheckedContinuation<Value, Never>? in
            defer { current = nil }
            return current
        }
        continuation?.resume(returning: value)
    }
}

/// Sleeps; injected so tests do not wait.
public typealias Sleep = @Sendable (Duration) async throws -> Void

/// The live sleep.
public let liveSleep: Sleep = { duration in try await Task.sleep(for: duration) }

/// Waits for a vendor SDK to be configured: apps often configure it after pingfront.
public enum Readiness {
    /// Checks `isReady` every `interval`, at most `attempts` times.
    ///
    /// Returns `false` when it never became ready or the task was cancelled.
    @MainActor public static func wait(
        until isReady: @MainActor () async -> Bool, sleep: Sleep, interval: Duration = .milliseconds(500), attempts: Int = 120
    ) async -> Bool {
        for _ in 0..<attempts {
            if await isReady() { return true }
            do { try await sleep(interval) } catch { return false }
        }
        return await isReady()
    }
}

/// Loggers for the adapters.
///
/// Never log tokens, user ids or other personal data with `.public`.
public enum AdapterLog {
    /// A logger for one adapter.
    public static func logger(_ category: String) -> Logger {
        Logger(subsystem: "dev.pingfront.adapters", category: category)
    }
}

/// Signals that should refresh vendor state: the app became active.
public enum AppSignals {
    /// Yields each time the app becomes active (iOS); never yields elsewhere.
    @MainActor public static func becameActive() -> AsyncStream<Void> {
        #if canImport(UIKit)
            AsyncStream { continuation in
                let task = Task { @MainActor in
                    for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                        continuation.yield()
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        #else
            AsyncStream { _ in }
        #endif
    }
}

#if canImport(UIKit)
    /// Presenting vendor UI above the chat.
    @MainActor public enum Presentation {
        /// The foreground window scene.
        public static func activeScene() -> UIWindowScene? {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        }

        /// The view controller on top (the chat sheet, when it is open), to present a paywall over.
        public static func topViewController() -> UIViewController? {
            let window = activeScene()?.windows.first { $0.isKeyWindow } ?? activeScene()?.windows.first
            var top = window?.rootViewController
            while let presented = top?.presentedViewController, !presented.isBeingDismissed { top = presented }
            return top
        }
    }
#endif
