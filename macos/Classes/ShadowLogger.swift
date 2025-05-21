import Foundation

import os.log

// MARK: - ShadowLogger Class
final class ShadowLogger {
    // MARK: - Singleton
    private static var _shared: ShadowLogger?
    
    static var shared: ShadowLogger {
        guard let logger = _shared else {
            fatalError("ShadowLogger.configure() must be called before accessing ShadowLogger.shared")
        }
        return logger
    }
    
    func forceRotateLogFile() {
        rotateLogFile()
    }
    
    // MARK: - Configuration
    static func configure(subsystem: String,
                          category: String,
                          logDirectory: URL? = nil,
                          retentionDays: Int = 30,
                          minimumLogLevel: LogType = .debug) {
        if _shared == nil {
            _shared = ShadowLogger(subsystem: subsystem,
                                   category: category,
                                   logDirectory: logDirectory,
                                   retentionDays: retentionDays,
                                   minimumLogLevel: minimumLogLevel)
        } else {
            print("Warning: ShadowLogger already configured. Configuration can only be set once at startup.")
        }
    }
    
    // MARK: - Properties
    private let osLog: OSLog
    private var logFileURL: URL
    private var logFileHandle: FileHandle?
    private var rotationTimer: Timer?
    private let dateFormatter: DateFormatter
    private let logQueue = DispatchQueue(label: "com.yourdomain.shadow_plugin.logging", qos: .utility)
    private let retentionDays: Int
    
    // Log level configuration
    var minimumLogLevel: LogType
    
    // Log levels
    enum LogType: String, Comparable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            }
        }
        
        // Add Comparable conformance to enable log level filtering
        static func < (lhs: LogType, rhs: LogType) -> Bool {
            let order: [LogType] = [.debug, .info, .warning, .error]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }
    }
    
    // MARK: - Initialization
    private init(subsystem: String,
                 category: String,
                 logDirectory: URL? = nil,
                 retentionDays: Int = 7,
                 minimumLogLevel: LogType = .debug) {
        
        // Initialize OSLog
        self.osLog = OSLog(subsystem: subsystem, category: category)
        
        // Set log level
        self.minimumLogLevel = minimumLogLevel
        
        // Set retention period
        self.retentionDays = retentionDays
        
        // Initialize date formatter for log files
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Setup log file path
        let fileManager = FileManager.default
        let baseDirectory: URL
        
        if let customLogDirectory = logDirectory {
            baseDirectory = customLogDirectory
        } else {
            baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("com.taperlabs.shadow", isDirectory: true)
        }
        
        // Create logs directory if it doesn't exist
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        }
        
        // Set initial log file URL
        self.logFileURL = baseDirectory.appendingPathComponent("\(self.dateFormatter.string(from: Date()))-shadow.log")
        
        // Initialize log file
        self.initializeLogFile()
        
        // Setup log rotation timer
        self.scheduleLogRotation()
        
        // Log initialization
        self.log(message: "ShadowLogger initialized with subsystem: \(subsystem), category: \(category), minimumLogLevel: \(minimumLogLevel.rawValue), retentionDays: \(retentionDays)",
                 type: .info, file: #file, function: #function, line: #line)
    }
    
    deinit {
        // Clean up resources
        self.rotationTimer?.invalidate()
        try? self.logFileHandle?.close()
        
        // Log deinitialization
        self.log(message: "ShadowLogger deinitialized", type: .info)
    }
    
    // MARK: - Public Methods
    
    /// Log a message with a specific log level and source location information
    func log(message: String,
             type: LogType,
             file: String = #file,
             function: String = #function,
             line: Int = #line) {
        
        // Skip logging if below minimum log level
        guard type >= minimumLogLevel else {
            return
        }
        
        // Log to OSLog with source info
        os_log("%{public}@", log: self.osLog, type: type.osLogType, message)
        
        // Extract filename from path
        let filename = URL(fileURLWithPath: file).lastPathComponent
        
        // Format log entry with both UTC and local timestamps
        let utcTimestamp = ISO8601DateFormatter().string(from: Date())
        
        let localFormatter = DateFormatter()
        localFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        localFormatter.timeZone = TimeZone.current
        let localTimestamp = localFormatter.string(from: Date())
        
        let threadID = Thread.current.hashValue
//        let logEntry = "[UTC: \(utcTimestamp)] [LOCAL: \(localTimestamp)] [\(type.rawValue)] [Thread: \(threadID)] [\(filename):\(line) \(function)] \(message)\n"        
        
        let logEntry = "[UTC: \(utcTimestamp)] [LOCAL: \(localTimestamp)] [\(type.rawValue)] [Thread: \(threadID)] [\(function)] \(message)\n"
        
        // Write to file asynchronously
        logQueue.async { [weak self] in
            guard let self = self, let data = logEntry.data(using: .utf8) else { return }
            
            self.logFileHandle?.write(data)
            try? self.logFileHandle?.synchronize()
        }
    }
    
    /// Convenience methods for different log levels with source location
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message: message, type: .debug, file: file, function: function, line: line)
        print("message: \(message), file: \(file), function: \(function), line: \(line)")
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message: message, type: .info, file: file, function: function, line: line)
        print("message: \(message), file: \(file), function: \(function), line: \(line)")
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message: message, type: .warning, file: file, function: function, line: line)
        print("message: \(message), file: \(file), function: \(function), line: \(line)")
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message: message, type: .error, file: file, function: function, line: line)
        print("message: \(message), file: \(file), function: \(function), line: \(line)")
    }
    
    // MARK: - Runtime Configuration
    
    /// Change the minimum log level at runtime
    func setMinimumLogLevel(_ level: LogType) {
        minimumLogLevel = level
        info("Minimum log level changed to: \(level.rawValue)")
    }
    
    // MARK: - Private Methods
    
    private func initializeLogFile() {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            let fileManager = FileManager.default
            
            // Create log file if it doesn't exist
            if !fileManager.fileExists(atPath: self.logFileURL.path) {
                fileManager.createFile(atPath: self.logFileURL.path, contents: nil)
            }
            
            // Open file handle for writing
            do {
                self.logFileHandle = try FileHandle(forWritingTo: self.logFileURL)
                self.logFileHandle?.seekToEndOfFile()
                
                // Write header if this is a new file
                if self.logFileHandle?.offsetInFile == 0 {
                    let header = "--- Shadow Plugin Log File: \(self.dateFormatter.string(from: Date())) ---\n"
                    if let headerData = header.data(using: .utf8) {
                        self.logFileHandle?.write(headerData)
                    }
                }
            } catch {
                os_log("Failed to open log file: %{public}@", log: self.osLog, type: .error, error.localizedDescription)
            }
        }
    }
    
    private func scheduleLogRotation() {
        // Calculate time until next midnight
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        guard let tomorrow = calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) else {
            return
        }
        
        let timeInterval = tomorrow.timeIntervalSince(Date())
        
        // Schedule timer for midnight
        self.rotationTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            self?.rotateLogFile()
            // Reschedule for next day
            self?.scheduleLogRotation()
        }
        
        // Make sure timer fires even during sleep
        RunLoop.main.add(self.rotationTimer!, forMode: .common)
    }
    
    private func rotateLogFile() {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Close current log file
            try? self.logFileHandle?.close()
            self.logFileHandle = nil
            
            // Create new log file with today's date
            let newLogFileName = "\(self.dateFormatter.string(from: Date()))-shadow.log"
            let logsDirectory = self.logFileURL.deletingLastPathComponent()
            self.logFileURL = logsDirectory.appendingPathComponent(newLogFileName)
            
            // Initialize the new log file
            self.initializeLogFile()
            
            // Clean up old log files using configured retention days
            self.cleanupOldLogFiles(olderThan: self.retentionDays)
        }
    }
    
    private func cleanupOldLogFiles(olderThan days: Int) {
        let fileManager = FileManager.default
        let logsDirectory = self.logFileURL.deletingLastPathComponent()
        
        guard let files = try? fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        
        for fileURL in files where fileURL.pathExtension == "log" {
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let creationDate = attributes[.creationDate] as? Date else {
                continue
            }
            
            if creationDate < cutoffDate {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
}


//final class ShadowLogger {
//    static let shared = ShadowLogger()
//    
//    // System logger for debugging
//    private let systemLogger = Logger(subsystem: "com.taperlabs.shadow", category: "main")
//    
//    private let logQueue = DispatchQueue(label: "com.shadowPlugin.app.logger")
//    private var currentFileHandle: FileHandle?
//    private var currentDate: String
//    
//    // Buffer for collecting log messages
//    private var logBuffer: [String] = []
//    private let maxBufferSize = 50
//    private var bufferTimer: DispatchSourceTimer?
//    private let flushInterval: TimeInterval = 5
//    private var notificationToken: Any?
//    
//    private enum DateFormat: String {
//        case fullDateTime = "yyyy-MM-dd HH:mm:ss"
//        case dateOnly = "yyyy-MM-dd"
//        
//        var description: String {
//            return self.rawValue
//        }
//    }
//    
//    private static func formatDate(with format: DateFormat, date: Date = Date()) -> String {
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateFormat = format.description
//        return dateFormatter.string(from: date)
//    }
//    
//    private var fileURL: URL {
//        guard let documentDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
//            return FileManager.default.temporaryDirectory.appendingPathComponent("com.taperlabs.shadow/logs")
//        }
//        
//        let folderURL = documentDirectory
//            .appendingPathComponent("com.taperlabs.shadow")
//            .appendingPathComponent("logs")
//        
//        return folderURL.appendingPathComponent("s_logs_\(currentDate).txt")
//    }
//    
//    private init() {
//        self.currentDate = Self.formatDate(with: .dateOnly)
//        setupLogger()
//        setupBufferTimer()
//        setupTerminationHandler()
//    }
//    
//    
//    deinit {
//        NotificationCenter.default.removeObserver(notificationToken as Any)
//        bufferTimer?.cancel()
//        handleTermination()
//    }
//    
//    private func setupLogger() {
//        ensureDirectoryExists()
//        openCurrentLogFile()
//    }
//    
//    private func setupBufferTimer() {
//        bufferTimer = DispatchSource.makeTimerSource(queue: logQueue)
//        bufferTimer?.schedule(deadline: .now() + flushInterval, repeating: flushInterval)
//        bufferTimer?.setEventHandler { [weak self] in
//            self?.flushBuffer()
//        }
//        bufferTimer?.resume()
//    }
//    
//    private func setupTerminationHandler() {
//        notificationToken = NotificationCenter.default.addObserver(
//            forName: NSApplication.willTerminateNotification,
//            object: nil,
//            queue: nil
//        ) { [weak self] _ in
//            self?.logCritical("Application is terminating - Notification received") // Add this log
//            self?.handleTermination()
//        }
//        
//        // Register for sudden termination
//        atexit {
//            ShadowLogger.shared.logCritical("Application is terminating - atexit called") // Add this log
//            ShadowLogger.shared.handleTermination()
//        }
//    }
//    
//    private func handleTermination() {
//        logQueue.sync {
//            flushBuffer()
//            closeCurrentFileHandle()
//        }
//    }
//    
//    private func ensureDirectoryExists() {
//        let folderPath = fileURL.deletingLastPathComponent().path
//        if !FileManager.default.fileExists(atPath: folderPath) {
//            do {
//                try FileManager.default.createDirectory(atPath: folderPath, withIntermediateDirectories: true, attributes: nil)
//            } catch {
//                systemLogger.log(level: .fault, "Failed to create log directory: \(error.localizedDescription)")
//            }
//        }
//    }
//    
//    private func openCurrentLogFile() {
//        closeCurrentFileHandle()
//        
//        do {
//            if !FileManager.default.fileExists(atPath: fileURL.path) {
//                FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
//            }
//            currentFileHandle = try FileHandle(forWritingTo: fileURL)
//            try currentFileHandle?.seekToEnd()
//        } catch {
//            systemLogger.log(level: .error, "Failed to open log file: \(error.localizedDescription)")
//        }
//    }
//    
//    private func closeCurrentFileHandle() {
//        try? currentFileHandle?.synchronize()
//        try? currentFileHandle?.close()
//        currentFileHandle = nil
//    }
//
//    
//    func log(_ message: String) {
//        // Log to system logger for debugging
//        systemLogger.log("\(message)")
//        
//        // Log to file for user log collection
//        logQueue.async { [weak self] in
//            guard let self = self else { return }
//            
//            let dateString = Self.formatDate(with: .fullDateTime)
//            let logEntry = "\(dateString): \(message)\n"
//            
//            self.logBuffer.append(logEntry)
//            
//            if self.logBuffer.count >= self.maxBufferSize {
//                self.flushBuffer()
//            }
//        }
//    }
//    
//    // Critical logs bypass the buffer
//    func logCritical(_ message: String) {
//        systemLogger.log(level: .error, "CRITICAL: \(message)")
//        
//        logQueue.sync {
//            let dateString = Self.formatDate(with: .fullDateTime)
//            let logEntry = "\(dateString): CRITICAL: \(message)\n"
//            
//            do {
//                guard let data = logEntry.data(using: .utf8) else { return }
//                try currentFileHandle?.write(contentsOf: data)
//                try currentFileHandle?.synchronize()
//            } catch {
//                systemLogger.log(level: .fault, "Failed to write critical log: \(error.localizedDescription)")
//            }
//        }
//    }
//    
//    private func flushBuffer() {
//        guard !logBuffer.isEmpty else { return }
//        
//        ensureCurrentDateFile()
//        
//        do {
//            let combinedData = logBuffer.joined().data(using: .utf8)!
//            try currentFileHandle?.write(contentsOf: combinedData)
//            try currentFileHandle?.synchronize()
//            logBuffer.removeAll()
//        } catch {
//            systemLogger.log(level: .error, "Failed to flush log buffer: \(error.localizedDescription)")
//            // Attempt recovery
//            openCurrentLogFile()
//            try? currentFileHandle?.write(contentsOf: logBuffer.joined().data(using: .utf8)!)
//            try? currentFileHandle?.synchronize()
//            logBuffer.removeAll()
//        }
//    }
//    
//    private func ensureCurrentDateFile() {
//        let newDate = Self.formatDate(with: .dateOnly)
//        if newDate != currentDate {
//            currentDate = newDate
//            openCurrentLogFile()
//        }
//    }
//    
//    // Helper method to get logs for sharing
//    func getLogFileURL() -> URL? {
//        flushBuffer() // Ensure all logs are written
//        return fileURL
//    }
// 
//}
