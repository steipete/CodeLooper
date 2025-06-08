import Foundation
import Diagnostics
import Darwin

// MARK: - Claude Terminal Title Management Service

/// Dedicated service for managing terminal window titles for Claude instances
@MainActor
final class ClaudeTerminalTitleManager: Loggable {
    
    // MARK: - Configuration
    
    private struct Configuration {
        static let titlePrefix = "🔄"
        static let titleSeparator = " — "
        static let escapeSequence = "\u{001B}]2;"
        static let bellSequence = "\u{0007}"
    }
    
    // MARK: - Public API
    
    /// Update terminal titles for all provided Claude instances
    func updateTitles(for instances: [ClaudeInstance]) async {
        logger.info("Updating terminal titles for \(instances.count) Claude instances")
        
        await withTaskGroup(of: Void.self) { group in
            for instance in instances {
                group.addTask { [weak self] in
                    await self?.updateTitle(for: instance)
                }
            }
        }
    }
    
    /// Update terminal title for a specific Claude instance
    func updateTitle(for instance: ClaudeInstance) async {
        guard !instance.ttyPath.isEmpty else {
            logger.debug("Skipping title update for \(instance.folderName) - no TTY path")
            return
        }
        
        let title = buildTitle(for: instance)
        
        // First try to find the window using the shared service
        if TTYWindowMappingService.shared.findWindowForTTY(instance.ttyPath) != nil {
            logger.debug("Found window via TTYWindowMappingService for TTY \(instance.ttyPath)")
            // We could potentially set the window title directly here if the terminal supports it
            // For now, we'll still write to the TTY
        }
        
        writeTitleToTTY(title: title, ttyPath: instance.ttyPath, instance: instance)
    }
    
    // MARK: - Title Construction
    
    private func buildTitle(for instance: ClaudeInstance) -> String {
        let statusText = formatActivityForTitle(instance.currentActivity)
        
        return [
            Configuration.titlePrefix,
            " ",
            instance.folderName,
            Configuration.titleSeparator,
            statusText
        ].joined()
    }
    
    private func formatActivityForTitle(_ activity: ClaudeActivity) -> String {
        switch activity.type {
        case .idle:
            return "idle"
        default:
            // For active states, use the full activity text
            return activity.text
        }
    }
    
    // MARK: - TTY Writing
    
    private func writeTitleToTTY(title: String, ttyPath: String, instance: ClaudeInstance) {
        logger.debug("Writing title to TTY \(ttyPath) for \(instance.folderName): '\(title)'")
        
        // Verify TTY exists and is accessible
        guard FileManager.default.fileExists(atPath: ttyPath) else {
            logger.warning("TTY does not exist: \(ttyPath)")
            return
        }
        
        // Construct the full terminal escape sequence
        let titleCommand = Configuration.escapeSequence + title + Configuration.bellSequence
        
        // Open TTY for writing
        let fd = open(ttyPath, O_WRONLY | O_NONBLOCK)
        guard fd >= 0 else {
            let error = String(cString: strerror(errno))
            logger.error("Failed to open TTY \(ttyPath): \(error)")
            return
        }
        
        defer { close(fd) }
        
        // Write title command to TTY
        guard let data = titleCommand.data(using: .utf8) else {
            logger.error("Failed to encode title command as UTF-8")
            return
        }
        
        let bytesWritten = data.withUnsafeBytes { bytes in
            write(fd, bytes.baseAddress, bytes.count)
        }
        
        if bytesWritten > 0 {
            logger.info("✅ Updated terminal title for \(instance.folderName)")
            logger.debug("Title: '\(title)' (\(bytesWritten) bytes written)")
        } else {
            let error = String(cString: strerror(errno))
            logger.error("Failed to write title to TTY \(ttyPath): \(error)")
        }
    }
}

// MARK: - Title Format Extensions

extension ClaudeActivity {
    /// Formatted version suitable for terminal titles
    var titleFormat: String {
        switch type {
        case .idle:
            return "idle"
        case .working, .generating:
            if let duration = duration, let tokenCount = tokenCount {
                return "\(type.rawValue.capitalized) (\(Int(duration))s • \(formatTokenCount(tokenCount)))"
            } else if let duration = duration {
                return "\(type.rawValue.capitalized) (\(Int(duration))s)"
            } else {
                return "\(type.rawValue.capitalized)…"
            }
        default:
            // For other types, use the original text but ensure it's reasonably short
            let maxLength = 50
            if text.count <= maxLength {
                return text
            } else {
                return String(text.prefix(maxLength - 1)) + "…"
            }
        }
    }
    
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1000 {
            let kCount = Double(count) / 1000.0
            return String(format: "%.1fk tokens", kCount)
        } else {
            return "\(count) tokens"
        }
    }
}