import Foundation

//MARK: - Custom Error Handler
enum CaptureError: Error {
    case missingParameters
    case streamOutputNotInitialized
}
