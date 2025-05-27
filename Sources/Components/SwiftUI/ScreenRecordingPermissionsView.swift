import AppKit
import Diagnostics
import SwiftUI
@preconcurrency import ScreenCaptureKit

/// A view component that displays screen recording permission status
/// and provides a button to grant permissions if needed
struct ScreenRecordingPermissionsView: View {
    // MARK: Lifecycle

    init(showTitle: Bool = true, compact: Bool = false) {
        self.showTitle = showTitle
        self.compact = compact
    }

    // MARK: Internal

    let showTitle: Bool
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            if showTitle {
                Text("Screen Recording Permissions")
                    .font(.headline)
            }

            if !(compact && viewModel.hasPermissions) {
                HStack(spacing: 12) {
                    Image(systemName: viewModel
                        .hasPermissions ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(viewModel.hasPermissions ? .green : .orange)
                        .font(.system(size: compact ? 16 : 20))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.hasPermissions ? "Screen Recording Granted" : "Screen Recording Required")
                            .font(compact ? .callout : .body)
                            .fontWeight(.medium)

                        if !compact {
                            Text(viewModel.hasPermissions
                                ? "CodeLooper can capture Cursor windows for AI analysis."
                                : "CodeLooper needs permission to capture Cursor windows without shadows for AI analysis.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if !viewModel.hasPermissions {
                        Button(action: viewModel.openSystemSettings) {
                            Text("Grant Permission")
                                .font(compact ? .caption : .callout)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(compact ? 8 : 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(viewModel.hasPermissions
                            ? Color.green.opacity(0.1)
                            : Color.orange.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(viewModel.hasPermissions
                            ? Color.green.opacity(0.3)
                            : Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    // MARK: Private

    @StateObject private var viewModel = ScreenRecordingPermissionsViewModel()
}

@MainActor
class ScreenRecordingPermissionsViewModel: ObservableObject {
    // MARK: Lifecycle

    init() {
        checkPermissions()
        startMonitoring()
    }

    deinit {
        monitoringTask?.cancel()
    }

    // MARK: Internal

    @Published var hasPermissions: Bool = false

    func openSystemSettings() {
        logger.info("Opening System Settings for screen recording permissions")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Private

    private var monitoringTask: Task<Void, Never>?
    private let logger = Logger(category: .permissions)

    private func checkPermissions() {
        Task {
            hasPermissions = await checkScreenRecordingPermission()
            logger.info("Screen recording permissions status: \(hasPermissions)")
        }
    }

    private func checkScreenRecordingPermission() async -> Bool {
        do {
            // Try to get shareable content - this will fail if we don't have permission
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            // If we get an error, we likely don't have permission
            return false
        }
    }

    private func startMonitoring() {
        monitoringTask = Task {
            var lastState = hasPermissions

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

                let currentState = await checkScreenRecordingPermission()

                if currentState != lastState {
                    lastState = currentState
                    hasPermissions = currentState
                    logger.info("Screen recording permissions changed to: \(currentState)")

                    // Post notification for other parts of the app
                    NotificationCenter.default.post(
                        name: .screenRecordingPermissionsChanged,
                        object: nil,
                        userInfo: ["granted": currentState]
                    )
                }
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let screenRecordingPermissionsChanged = Notification.Name("screenRecordingPermissionsChanged")
}

// MARK: - Preview

struct ScreenRecordingPermissionsView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ScreenRecordingPermissionsView(showTitle: true, compact: false)
                .padding()

            ScreenRecordingPermissionsView(showTitle: false, compact: true)
                .padding()
        }
    }
}