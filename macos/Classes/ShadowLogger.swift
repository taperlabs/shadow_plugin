import Foundation
import os.log

final class ShadowLogger {
    static let shared = ShadowLogger()
    
    // System logger for debugging
    private let systemLogger = Logger(subsystem: "com.taperlabs.shadow", category: "main")
    
    private let logQueue = DispatchQueue(label: "com.shadowPlugin.app.logger")
    private var currentFileHandle: FileHandle?
    private var currentDate: String
    
    // Buffer for collecting log messages
    private var logBuffer: [String] = []
    private let maxBufferSize = 50
    private var bufferTimer: DispatchSourceTimer?
    private let flushInterval: TimeInterval = 5
    private var notificationToken: Any?
    
    private enum DateFormat: String {
        case fullDateTime = "yyyy-MM-dd HH:mm:ss"
        case dateOnly = "yyyy-MM-dd"
        
        var description: String {
            return self.rawValue
        }
    }
    
    private static func formatDate(with format: DateFormat, date: Date = Date()) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format.description
        return dateFormatter.string(from: date)
    }
    
    private var fileURL: URL {
        guard let documentDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return FileManager.default.temporaryDirectory.appendingPathComponent("com.taperlabs.shadow/logs")
        }
        
        let folderURL = documentDirectory
            .appendingPathComponent("com.taperlabs.shadow")
            .appendingPathComponent("logs")
        
        return folderURL.appendingPathComponent("s_logs_\(currentDate).txt")
    }
    
    private init() {
        self.currentDate = Self.formatDate(with: .dateOnly)
        setupLogger()
        setupBufferTimer()
        setupTerminationHandler()
    }
    
    
    deinit {
        NotificationCenter.default.removeObserver(notificationToken as Any)
        bufferTimer?.cancel()
        handleTermination()
    }
    
    private func setupLogger() {
        ensureDirectoryExists()
        openCurrentLogFile()
    }
    
    private func setupBufferTimer() {
        bufferTimer = DispatchSource.makeTimerSource(queue: logQueue)
        bufferTimer?.schedule(deadline: .now() + flushInterval, repeating: flushInterval)
        bufferTimer?.setEventHandler { [weak self] in
            self?.flushBuffer()
        }
        bufferTimer?.resume()
    }
    
    private func setupTerminationHandler() {
        notificationToken = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.logCritical("Application is terminating - Notification received") // Add this log
            self?.handleTermination()
        }
        
        // Register for sudden termination
        atexit {
            ShadowLogger.shared.logCritical("Application is terminating - atexit called") // Add this log
            ShadowLogger.shared.handleTermination()
        }
    }
    
    private func handleTermination() {
        logQueue.sync {
            flushBuffer()
            closeCurrentFileHandle()
        }
    }
    
    private func ensureDirectoryExists() {
        let folderPath = fileURL.deletingLastPathComponent().path
        if !FileManager.default.fileExists(atPath: folderPath) {
            do {
                try FileManager.default.createDirectory(atPath: folderPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                systemLogger.log(level: .fault, "Failed to create log directory: \(error.localizedDescription)")
            }
        }
    }
    
    private func openCurrentLogFile() {
        closeCurrentFileHandle()
        
        do {
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
            }
            currentFileHandle = try FileHandle(forWritingTo: fileURL)
            try currentFileHandle?.seekToEnd()
        } catch {
            systemLogger.log(level: .error, "Failed to open log file: \(error.localizedDescription)")
        }
    }
    
    private func closeCurrentFileHandle() {
        try? currentFileHandle?.synchronize()
        try? currentFileHandle?.close()
        currentFileHandle = nil
    }

    
    func log(_ message: String) {
        // Log to system logger for debugging
        systemLogger.log("\(message)")
        
        // Log to file for user log collection
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            let dateString = Self.formatDate(with: .fullDateTime)
            let logEntry = "\(dateString): \(message)\n"
            
            self.logBuffer.append(logEntry)
            
            if self.logBuffer.count >= self.maxBufferSize {
                self.flushBuffer()
            }
        }
    }
    
    // Critical logs bypass the buffer
    func logCritical(_ message: String) {
        systemLogger.log(level: .error, "CRITICAL: \(message)")
        
        logQueue.sync {
            let dateString = Self.formatDate(with: .fullDateTime)
            let logEntry = "\(dateString): CRITICAL: \(message)\n"
            
            do {
                guard let data = logEntry.data(using: .utf8) else { return }
                try currentFileHandle?.write(contentsOf: data)
                try currentFileHandle?.synchronize()
            } catch {
                systemLogger.log(level: .fault, "Failed to write critical log: \(error.localizedDescription)")
            }
        }
    }
    
    private func flushBuffer() {
        guard !logBuffer.isEmpty else { return }
        
        ensureCurrentDateFile()
        
        do {
            let combinedData = logBuffer.joined().data(using: .utf8)!
            try currentFileHandle?.write(contentsOf: combinedData)
            try currentFileHandle?.synchronize()
            logBuffer.removeAll()
        } catch {
            systemLogger.log(level: .error, "Failed to flush log buffer: \(error.localizedDescription)")
            // Attempt recovery
            openCurrentLogFile()
            try? currentFileHandle?.write(contentsOf: logBuffer.joined().data(using: .utf8)!)
            try? currentFileHandle?.synchronize()
            logBuffer.removeAll()
        }
    }
    
    private func ensureCurrentDateFile() {
        let newDate = Self.formatDate(with: .dateOnly)
        if newDate != currentDate {
            currentDate = newDate
            openCurrentLogFile()
        }
    }
    
    // Helper method to get logs for sharing
    func getLogFileURL() -> URL? {
        flushBuffer() // Ensure all logs are written
        return fileURL
    }
 
}
