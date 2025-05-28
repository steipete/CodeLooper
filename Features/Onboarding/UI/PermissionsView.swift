import AXorcist
import Diagnostics
import SwiftUI

/// A reusable view component that displays accessibility permission status
/// and provides a button to request permissions if needed
struct PermissionsView: View {
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
                Text("Accessibility Permissions")
                    .font(.headline)
            }

            if !(compact && viewModel.hasPermissions) {
                HStack(spacing: 12) {
                    Image(systemName: viewModel
                        .hasPermissions ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(viewModel.hasPermissions ? .green : .orange)
                        .font(.system(size: compact ? 16 : 20))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.hasPermissions ? "Permissions Granted" : "Permissions Required")
                            .font(compact ? .callout : .body)
                            .fontWeight(.medium)

                        if !compact {
                            Text(viewModel.hasPermissions
                                ? "CodeLooper has the necessary accessibility permissions."
                                : "CodeLooper needs accessibility permissions to monitor and assist with Cursor.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineSpacing(3)
                        }
                    }

                    Spacer()

                    if !viewModel.hasPermissions {
                        Button(action: viewModel.requestPermissions) {
                            Text("Grant Permissions")
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

    @StateObject private var viewModel = PermissionsViewModel()
}

@MainActor
class PermissionsViewModel: ObservableObject {
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

    func requestPermissions() {
        logger.info("Requesting accessibility permissions")
        Task {
            let granted = await AXPermissionHelpers.requestPermissions()
            await MainActor.run {
                self.hasPermissions = granted
                self.logger.info("Accessibility permissions request result: \(granted)")
            }
        }
    }

    // MARK: Private

    private var monitoringTask: Task<Void, Never>?
    private let logger = Logger(category: .permissions)

    private func checkPermissions() {
        hasPermissions = AXPermissionHelpers.hasAccessibilityPermissions()
        logger.info("Accessibility permissions status: \(hasPermissions)")
    }

    private func startMonitoring() {
        monitoringTask = Task {
            for await permissionGranted in AXPermissionHelpers.permissionChanges() {
                guard !Task.isCancelled else { break }

                await MainActor.run {
                    self.hasPermissions = permissionGranted
                    self.logger.info("Accessibility permissions changed to: \(permissionGranted)")

                    // Post notification for other parts of the app
                    NotificationCenter.default.post(
                        name: .accessibilityPermissionsChanged,
                        object: nil,
                        userInfo: ["granted": permissionGranted]
                    )
                }
            }
        }
    }
}

// MARK: - Preview

struct PermissionsView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            PermissionsView(showTitle: true, compact: false)
                .padding()

            PermissionsView(showTitle: false, compact: true)
                .padding()
        }
    }
}
