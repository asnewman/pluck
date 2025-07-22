import Foundation
import ApplicationServices
import os.log

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

class Logger {
    static let shared = Logger()
    
    private let logFileURL: URL
    private let dateFormatter: DateFormatter
    private let fileManager = FileManager.default
    private let logQueue = DispatchQueue(label: "com.pluck.logger", qos: .background)
    private let maxLogFileSize: Int = 10 * 1024 * 1024 // 10MB
    private let maxLogFiles: Int = 3
    
    private init() {
        // Create logs directory in Application Support
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let logsDirectory = appSupportURL.appendingPathComponent("Pluck/Logs")
        
        try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // Current log file
        logFileURL = logsDirectory.appendingPathComponent("pluck.log")
        
        // Setup date formatter
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        // Log session start
        log(.info, "=== Pluck Session Started ===")
        log(.info, "Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
        log(.info, "Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")")
        log(.info, "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
    }
    
    func log(_ level: LogLevel, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = dateFormatter.string(from: Date())
        let logEntry = "[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line)] \(function) - \(message)\n"
        
        logQueue.async { [weak self] in
            self?.writeToFile(logEntry)
        }
        
        // Also log to console in debug builds
        #if DEBUG
        print(logEntry.trimmingCharacters(in: .newlines))
        #endif
    }
    
    private func writeToFile(_ entry: String) {
        // Check if we need to rotate logs
        rotateLogsIfNeeded()
        
        // Write to file
        if let data = entry.data(using: .utf8) {
            if fileManager.fileExists(atPath: logFileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logFileURL)
            }
        }
    }
    
    private func rotateLogsIfNeeded() {
        guard let attributes = try? fileManager.attributesOfItem(atPath: logFileURL.path),
              let fileSize = attributes[.size] as? Int,
              fileSize > maxLogFileSize else {
            return
        }
        
        // Rotate log files
        let logsDirectory = logFileURL.deletingLastPathComponent()
        
        // Delete oldest log if we have too many
        for i in stride(from: maxLogFiles - 1, through: 1, by: -1) {
            let oldFile = logsDirectory.appendingPathComponent("pluck.\(i).log")
            try? fileManager.removeItem(at: oldFile)
        }
        
        // Rename existing logs
        for i in stride(from: maxLogFiles - 2, through: 0, by: -1) {
            let sourceFile = i == 0 ? logFileURL : logsDirectory.appendingPathComponent("pluck.\(i).log")
            let destFile = logsDirectory.appendingPathComponent("pluck.\(i + 1).log")
            try? fileManager.moveItem(at: sourceFile, to: destFile)
        }
        
        // Start fresh log
        log(.info, "=== Log Rotated ===")
    }
    
    func exportLogs() -> URL? {
        let tempDirectory = fileManager.temporaryDirectory
        let exportDirectory = tempDirectory.appendingPathComponent("PluckLogs_\(Date().timeIntervalSince1970)")
        
        do {
            try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true, attributes: nil)
            
            // Copy all log files
            let logsDirectory = logFileURL.deletingLastPathComponent()
            let logFiles = try fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "log" && $0.lastPathComponent.hasPrefix("pluck") }
            
            for logFile in logFiles {
                let destFile = exportDirectory.appendingPathComponent(logFile.lastPathComponent)
                try fileManager.copyItem(at: logFile, to: destFile)
            }
            
            // Create system info file
            let systemInfo = """
            Pluck System Information
            ========================
            Date: \(Date())
            Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
            Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
            macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
            Processor: \(getProcessorInfo())
            Memory: \(getMemoryInfo())
            
            Accessibility Permissions: \(checkAccessibilityPermissions() ? "Granted" : "Not Granted")
            """
            
            let systemInfoFile = exportDirectory.appendingPathComponent("system_info.txt")
            try systemInfo.write(to: systemInfoFile, atomically: true, encoding: .utf8)
            
            // Create zip file
            let zipFile = tempDirectory.appendingPathComponent("PluckLogs_\(dateFormatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")).zip")
            
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            task.arguments = ["-r", zipFile.path, exportDirectory.lastPathComponent]
            task.currentDirectoryURL = tempDirectory
            try task.run()
            task.waitUntilExit()
            
            // Cleanup temp directory
            try? fileManager.removeItem(at: exportDirectory)
            
            return zipFile
        } catch {
            log(.error, "Failed to export logs: \(error)")
            return nil
        }
    }
    
    private func getProcessorInfo() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var result = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &result, &size, nil, 0)
        return String(cString: result)
    }
    
    private func getMemoryInfo() -> String {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        return ByteCountFormatter.string(fromByteCount: Int64(physicalMemory), countStyle: .memory)
    }
    
    private func checkAccessibilityPermissions() -> Bool {
        let checkOptionPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [checkOptionPrompt: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

// Convenience functions
func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(.debug, message, file: file, function: function, line: line)
}

func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(.info, message, file: file, function: function, line: line)
}

func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(.warning, message, file: file, function: function, line: line)
}

func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(.error, message, file: file, function: function, line: line)
}