import Foundation
import ScreenCaptureKit
import AVFoundation
import Combine

//MARK: - ScreenCaptureKit System Audio Service
final class ScreenCaptureService: NSObject, ObservableObject {
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var audioInput: AVAssetWriterInput?
    private let outputURL: URL
    private let systemAudioQueue = DispatchQueue(label: "systemAudioQueue")
    private let videioQueue = DispatchQueue(label: "videoQueue")
    
    init(outputURL: URL) {
        self.outputURL = outputURL
    }
    
    
    func startCapture() throws {
        
    }
    
    func stopCapture() throws {
        
    }
    
    private func configureStream() async throws {}
    
    private func setSCStreamConfig() {}
    
    
}

extension ScreenCaptureService: SCStreamOutput, SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        <#code#>
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        <#code#>
    }
}
