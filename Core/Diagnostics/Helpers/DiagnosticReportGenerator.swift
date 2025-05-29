import Foundation

/// Generates diagnostic reports from operation tracking data
enum DiagnosticReportGenerator {
    /// Generate a diagnostic report from operation statistics
    /// - Parameters:
    ///   - counts: Operation counts dictionary
    ///   - errors: Operation errors dictionary
    ///   - timings: Operation timings dictionary
    ///   - pendingOperations: Currently pending operations
    /// - Returns: A formatted diagnostic report string
    static func generateReport(
        counts: [String: Int],
        errors: [String: [Error]],
        timings: [String: [TimeInterval]],
        pendingOperations: [UUID: (operation: String, startTime: Date)]
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let systemInfo = SystemInfoProvider.getSystemInfoSection()

        var report = """
        === CodeLooper Diagnostics Report ===
        Generated: \(formatter.string(from: Date()))

        \(systemInfo)

        == Operation Statistics ==
        """

        // Sort operations alphabetically
        let sortedOperations = counts.keys.sorted()

        for operation in sortedOperations {
            let count = counts[operation, default: 0]
            let operationErrors = errors[operation, default: []]
            let operationTimings = timings[operation, default: []]

            var avgDuration = "N/A"
            if !operationTimings.isEmpty {
                let total = operationTimings.reduce(0, +)
                avgDuration = String(format: "%.2fs", total / Double(operationTimings.count))
            }

            report += """

            \(operation):
            Count: \(count)
            Errors: \(operationErrors.count)
            Average Duration: \(avgDuration)
            """

            // Include last 3 error details if available
            if !operationErrors.isEmpty {
                report += "\n  Recent Errors:"
                for (index, error) in operationErrors.suffix(3).enumerated() {
                    let nsError = error as NSError
                    report += """

                    Error \(index + 1): [\(nsError.domain):\(nsError.code)] \
                    \(error.localizedDescription)
                    """
                }
            }
        }

        // Add pending operations
        if !pendingOperations.isEmpty {
            report += "\n\n== Pending Operations =="

            for (operationId, info) in pendingOperations {
                let operation = info.operation
                let startTime = info.startTime
                let duration = Date().timeIntervalSince(startTime)
                report += """

                * \(operation) (ID: \(operationId.uuidString)): \
                Running for \(String(format: "%.2f", duration))s
                """
            }
        }

        report += "\n\n=== End of Diagnostics Report ==="

        return report
    }

    /// Save a diagnostic report to a file
    /// - Parameter report: The report content to save
    /// - Returns: URL to the saved file or nil if saving failed
    static func saveReport(_ report: String) -> URL? {
        guard let logDir = FileLogger.shared.getLogDirectoryURL() else {
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        let reportURL = logDir.appendingPathComponent("CodeLooper_DiagnosticReport_\(timestamp).txt")

        do {
            try report.write(to: reportURL, atomically: true, encoding: .utf8)
            return reportURL
        } catch {
            return nil
        }
    }
}
